#!/usr/bin/env bash
# configure-repo-protection.sh
# Configures GitHub environment protection rules and branch protection rules
# for the Azure Resume IaC project.
#
# This script:
#   1. Captures pre-configuration state snapshot
#   2. Configures production environment (required reviewer, wait timer, branch policy)
#   3. Configures development environment (branch policy)
#   4. Configures main branch protection (require PR, admin bypass)
#   5. Configures develop branch protection (require PR, admin bypass)
#   6. Captures post-configuration state snapshot
#   7. Compares and displays pre/post differences
#
# Usage:
#   bash scripts/configure-repo-protection.sh [options]
#
# Options:
#   --dry-run           Assess current state only, make no changes
#   --reviewer <user>   GitHub username for required reviewer (default: repo owner)
#   --repo <owner/repo> Target repository (default: auto-detect from gh)
#   --wait-timer <min>  Wait timer in minutes for production (default: 5)
#   --skip-branch       Skip branch protection rules (environment only)
#   --skip-environment  Skip environment protection rules (branch only)
#   -h, --help          Show usage
#
# Prerequisites:
#   - gh CLI authenticated with admin scope
#   - jq installed
#   - Repository admin permissions

set -euo pipefail

# =============================================================================
# Configuration & Defaults
# =============================================================================

DRY_RUN=false
REVIEWER=""
REPO=""
WAIT_TIMER=5
SKIP_BRANCH=false
SKIP_ENVIRONMENT=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# =============================================================================
# Helper Functions
# =============================================================================

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dry-run           Assess current state only, make no changes
  --reviewer <user>   GitHub username for required reviewer (default: repo owner)
  --repo <owner/repo> Target repository (default: auto-detect)
  --wait-timer <min>  Wait timer in minutes for production (default: 5)
  --skip-branch       Skip branch protection rules
  --skip-environment  Skip environment protection rules
  -h, --help          Show this help

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --reviewer rmcveyhsawaknow
  $(basename "$0") --repo rmcveyhsawaknow/azure-resume-iac
EOF
  exit 0
}

info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✅${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠️${NC}  $1"; }
fail()    { echo -e "${RED}❌${NC} $1"; }
header()  { echo ""; echo -e "${BOLD}${CYAN}=== $1 ===${NC}"; }
subhead() { echo -e "${BOLD}--- $1 ---${NC}"; }

# =============================================================================
# Parse Arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)        DRY_RUN=true; shift ;;
    --reviewer)       REVIEWER="$2"; shift 2 ;;
    --repo)           REPO="$2"; shift 2 ;;
    --wait-timer)     WAIT_TIMER="$2"; shift 2 ;;
    --skip-branch)    SKIP_BRANCH=true; shift ;;
    --skip-environment) SKIP_ENVIRONMENT=true; shift ;;
    -h|--help)        usage ;;
    *)                echo "Unknown option: $1"; usage ;;
  esac
done

# =============================================================================
# Prerequisite Checks
# =============================================================================

header "Prerequisite Checks"

for cmd in gh jq; do
  if ! command -v "$cmd" &>/dev/null; then
    fail "Required command '$cmd' is not installed."
    exit 1
  fi
done
success "Required tools found (gh, jq)"

if ! gh auth status &>/dev/null; then
  fail "GitHub CLI not authenticated. Run: gh auth login --scopes admin:org,repo"
  exit 1
fi
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
success "GitHub CLI authenticated as: $GH_USER"

# Auto-detect repo
if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
  if [[ -z "$REPO" ]]; then
    fail "Could not detect repository. Use --repo owner/repo"
    exit 1
  fi
fi
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)
success "Target repository: $REPO"

# Default reviewer to repo owner
if [[ -z "$REVIEWER" ]]; then
  REVIEWER="$OWNER"
fi
info "Required reviewer: $REVIEWER"

# Get reviewer's user ID (needed for environment protection API)
REVIEWER_ID=$(gh api "users/${REVIEWER}" --jq '.id' 2>/dev/null || echo "")
if [[ -z "$REVIEWER_ID" ]]; then
  fail "Could not find GitHub user ID for: $REVIEWER"
  exit 1
fi
info "Reviewer user ID: $REVIEWER_ID"

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  warn "DRY RUN MODE — no changes will be made"
fi

# =============================================================================
# State Snapshot Functions
# =============================================================================

SNAPSHOT_DIR=$(mktemp -d)
trap 'rm -rf "$SNAPSHOT_DIR"' EXIT

capture_environment_state() {
  local env_name="$1"
  local output_file="$2"

  local env_data
  env_data=$(gh api "repos/${REPO}/environments/${env_name}" 2>/dev/null || echo '{"error": "not found"}')

  if echo "$env_data" | jq -e '.error' &>/dev/null 2>&1; then
    echo '{"exists": false}' > "$output_file"
    return
  fi

  # Extract protection rules
  local protection_rules
  protection_rules=$(echo "$env_data" | jq '{
    exists: true,
    protection_rules: [.protection_rules[]? | {
      type: .type,
      wait_timer: .wait_timer,
      reviewers: [.reviewers[]? | {login: .reviewer.login, type: .type}]
    }],
    deployment_branch_policy: .deployment_branch_policy
  }' 2>/dev/null || echo '{"exists": true, "error": "parse_failed"}')

  echo "$protection_rules" > "$output_file"

  # Also capture deployment branch policies if they exist
  local branch_policy_type
  branch_policy_type=$(echo "$env_data" | jq -r '.deployment_branch_policy.custom_branch_policies // false' 2>/dev/null)

  if [[ "$branch_policy_type" == "true" ]]; then
    local branch_policies
    branch_policies=$(gh api "repos/${REPO}/environments/${env_name}/deployment-branch-policies" 2>/dev/null || echo '{"branch_policies": []}')
    local merged
    merged=$(jq -s '.[0] * {deployment_branch_policies: .[1].branch_policies}' "$output_file" <(echo "$branch_policies") 2>/dev/null || cat "$output_file")
    echo "$merged" > "$output_file"
  fi
}

capture_branch_protection_state() {
  local branch="$1"
  local output_file="$2"

  local protection_data
  protection_data=$(gh api "repos/${REPO}/branches/${branch}/protection" 2>/dev/null || echo '{"error": "not found"}')

  if echo "$protection_data" | jq -e '.message' &>/dev/null 2>&1; then
    echo '{"exists": false, "message": "'"$(echo "$protection_data" | jq -r '.message // "not configured"')"'"}' > "$output_file"
    return
  fi

  echo "$protection_data" | jq '{
    exists: true,
    required_pull_request_reviews: {
      required_approving_review_count: .required_pull_request_reviews.required_approving_review_count,
      dismiss_stale_reviews: .required_pull_request_reviews.dismiss_stale_reviews,
      require_code_owner_reviews: .required_pull_request_reviews.require_code_owner_reviews
    },
    enforce_admins: .enforce_admins.enabled,
    required_status_checks: .required_status_checks,
    allow_force_pushes: .allow_force_pushes.enabled,
    allow_deletions: .allow_deletions.enabled,
    required_conversation_resolution: .required_conversation_resolution.enabled
  }' > "$output_file" 2>/dev/null || echo '{"exists": true, "error": "parse_failed"}' > "$output_file"
}

display_state() {
  local label="$1"
  local file="$2"

  subhead "$label"
  if [[ -f "$file" ]]; then
    jq '.' "$file" 2>/dev/null || cat "$file"
  else
    echo "  (no data captured)"
  fi
}

# =============================================================================
# Step 1: Capture Pre-Configuration State
# =============================================================================

header "Step 1: Capturing Pre-Configuration State"

capture_environment_state "production" "${SNAPSHOT_DIR}/pre_env_production.json"
capture_environment_state "development" "${SNAPSHOT_DIR}/pre_env_development.json"
capture_branch_protection_state "main" "${SNAPSHOT_DIR}/pre_branch_main.json"
capture_branch_protection_state "develop" "${SNAPSHOT_DIR}/pre_branch_develop.json"

display_state "Production Environment (before)" "${SNAPSHOT_DIR}/pre_env_production.json"
display_state "Development Environment (before)" "${SNAPSHOT_DIR}/pre_env_development.json"
display_state "Main Branch Protection (before)" "${SNAPSHOT_DIR}/pre_branch_main.json"
display_state "Develop Branch Protection (before)" "${SNAPSHOT_DIR}/pre_branch_develop.json"

if [[ "$DRY_RUN" == true ]]; then
  header "Dry Run Complete"
  info "No changes were made. Review the current state above."
  info "Run without --dry-run to apply protection rules."
  exit 0
fi

# =============================================================================
# Step 2: Configure Production Environment
# =============================================================================

if [[ "$SKIP_ENVIRONMENT" != true ]]; then
  header "Step 2: Configuring Production Environment"

  subhead "Creating/updating production environment with protection rules"
  info "Setting required reviewer: $REVIEWER (ID: $REVIEWER_ID)"
  info "Setting wait timer: ${WAIT_TIMER} minutes"
  info "Setting deployment branch policy: main only"

  # Create/update the environment with protection rules
  # The PUT endpoint creates the environment if it doesn't exist
  gh api -X PUT "repos/${REPO}/environments/production" \
    --input - <<EOF
{
  "wait_timer": ${WAIT_TIMER},
  "prevent_self_review": false,
  "reviewers": [
    {
      "type": "User",
      "id": ${REVIEWER_ID}
    }
  ],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF
  success "Production environment protection rules configured"

  # Set deployment branch policy to main only
  # First, remove any existing deployment branch policies
  subhead "Configuring deployment branch policies for production"

  EXISTING_POLICIES=$(gh api "repos/${REPO}/environments/production/deployment-branch-policies" --jq '.branch_policies[].id' 2>/dev/null || echo "")
  if [[ -n "$EXISTING_POLICIES" ]]; then
    info "Removing existing deployment branch policies..."
    while IFS= read -r policy_id; do
      if [[ -n "$policy_id" ]]; then
        gh api -X DELETE "repos/${REPO}/environments/production/deployment-branch-policies/${policy_id}" --silent 2>/dev/null || true
        info "  Removed policy ID: $policy_id"
      fi
    done <<< "$EXISTING_POLICIES"
  fi

  # Add main branch policy
  gh api -X POST "repos/${REPO}/environments/production/deployment-branch-policies" \
    --input - <<EOF
{
  "name": "main",
  "type": "branch"
}
EOF
  success "Production deployment restricted to 'main' branch only"

  # =========================================================================
  # Step 3: Configure Development Environment
  # =========================================================================

  header "Step 3: Configuring Development Environment"

  subhead "Creating/updating development environment with branch policy"
  info "Setting deployment branch policy: develop only"
  info "No required reviewers (fast iteration for dev)"

  # Create/update the development environment
  # No reviewers, no wait timer — just branch restriction
  gh api -X PUT "repos/${REPO}/environments/development" \
    --input - <<EOF
{
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
EOF
  success "Development environment configured"

  # Set deployment branch policy to develop only
  subhead "Configuring deployment branch policies for development"

  EXISTING_DEV_POLICIES=$(gh api "repos/${REPO}/environments/development/deployment-branch-policies" --jq '.branch_policies[].id' 2>/dev/null || echo "")
  if [[ -n "$EXISTING_DEV_POLICIES" ]]; then
    info "Removing existing deployment branch policies..."
    while IFS= read -r policy_id; do
      if [[ -n "$policy_id" ]]; then
        gh api -X DELETE "repos/${REPO}/environments/development/deployment-branch-policies/${policy_id}" --silent 2>/dev/null || true
        info "  Removed policy ID: $policy_id"
      fi
    done <<< "$EXISTING_DEV_POLICIES"
  fi

  # Add develop branch policy
  gh api -X POST "repos/${REPO}/environments/development/deployment-branch-policies" \
    --input - <<EOF
{
  "name": "develop",
  "type": "branch"
}
EOF
  success "Development deployment restricted to 'develop' branch only"
fi

# =============================================================================
# Step 4: Configure Main Branch Protection
# =============================================================================

if [[ "$SKIP_BRANCH" != true ]]; then
  header "Step 4: Configuring Main Branch Protection"

  subhead "Setting branch protection for 'main'"
  info "Require pull request: yes (1 approving review)"
  info "Require code owner reviews: no (allows self-approve as admin)"
  info "Dismiss stale reviews: no (flexibility for iterative PRs)"
  info "Enforce admins: no (admin bypass for sole contributor)"
  info "Require conversation resolution: yes"
  info "Allow force pushes: no"
  info "Allow deletions: no"

  gh api -X PUT "repos/${REPO}/branches/main/protection" \
    --input - <<EOF
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
  success "Main branch protection configured"

  # =========================================================================
  # Step 5: Configure Develop Branch Protection
  # =========================================================================

  header "Step 5: Configuring Develop Branch Protection"

  subhead "Setting branch protection for 'develop'"
  info "Require pull request: yes (1 approving review)"
  info "Require code owner reviews: no"
  info "Dismiss stale reviews: no"
  info "Enforce admins: no (admin bypass for sole contributor)"
  info "Require conversation resolution: yes"
  info "Allow force pushes: no"
  info "Allow deletions: no"

  gh api -X PUT "repos/${REPO}/branches/develop/protection" \
    --input - <<EOF
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
  success "Develop branch protection configured"
fi

# =============================================================================
# Step 6: Capture Post-Configuration State
# =============================================================================

header "Step 6: Capturing Post-Configuration State"

capture_environment_state "production" "${SNAPSHOT_DIR}/post_env_production.json"
capture_environment_state "development" "${SNAPSHOT_DIR}/post_env_development.json"
capture_branch_protection_state "main" "${SNAPSHOT_DIR}/post_branch_main.json"
capture_branch_protection_state "develop" "${SNAPSHOT_DIR}/post_branch_develop.json"

display_state "Production Environment (after)" "${SNAPSHOT_DIR}/post_env_production.json"
display_state "Development Environment (after)" "${SNAPSHOT_DIR}/post_env_development.json"
display_state "Main Branch Protection (after)" "${SNAPSHOT_DIR}/post_branch_main.json"
display_state "Develop Branch Protection (after)" "${SNAPSHOT_DIR}/post_branch_develop.json"

# =============================================================================
# Step 7: Compare Pre/Post State
# =============================================================================

header "Step 7: Configuration Changes Summary"

CHANGES=0

compare_state() {
  local label="$1"
  local pre_file="$2"
  local post_file="$3"

  if ! diff -q "$pre_file" "$post_file" &>/dev/null; then
    subhead "CHANGED: $label"
    diff --color=always \
      <(jq --sort-keys '.' "$pre_file" 2>/dev/null) \
      <(jq --sort-keys '.' "$post_file" 2>/dev/null) \
      || true
    CHANGES=$((CHANGES + 1))
  else
    info "No change: $label"
  fi
}

compare_state "Production Environment" "${SNAPSHOT_DIR}/pre_env_production.json" "${SNAPSHOT_DIR}/post_env_production.json"
compare_state "Development Environment" "${SNAPSHOT_DIR}/pre_env_development.json" "${SNAPSHOT_DIR}/post_env_development.json"
compare_state "Main Branch Protection" "${SNAPSHOT_DIR}/pre_branch_main.json" "${SNAPSHOT_DIR}/post_branch_main.json"
compare_state "Develop Branch Protection" "${SNAPSHOT_DIR}/pre_branch_develop.json" "${SNAPSHOT_DIR}/post_branch_develop.json"

# =============================================================================
# Summary
# =============================================================================

header "Configuration Complete"
echo ""

if [[ "$CHANGES" -gt 0 ]]; then
  success "$CHANGES configuration(s) changed"
else
  info "No changes detected (settings may have already been configured)"
fi

echo ""
echo -e "${BOLD}Protection Rules Applied:${NC}"
echo ""

if [[ "$SKIP_ENVIRONMENT" != true ]]; then
  echo "  Production Environment:"
  echo "    • Required reviewer: $REVIEWER"
  echo "    • Wait timer: ${WAIT_TIMER} minutes"
  echo "    • Deployment branches: main only"
  echo ""
  echo "  Development Environment:"
  echo "    • No required reviewers"
  echo "    • Deployment branches: develop only"
  echo ""
fi

if [[ "$SKIP_BRANCH" != true ]]; then
  echo "  Main Branch Protection:"
  echo "    • Require PR with 1 approval"
  echo "    • Admin bypass enabled (enforce_admins: false)"
  echo "    • Conversation resolution required"
  echo "    • Force pushes and deletions blocked"
  echo ""
  echo "  Develop Branch Protection:"
  echo "    • Require PR with 1 approval"
  echo "    • Admin bypass enabled (enforce_admins: false)"
  echo "    • Conversation resolution required"
  echo "    • Force pushes and deletions blocked"
fi

echo ""
echo -e "${BOLD}Verification Commands:${NC}"
echo ""
echo "  # Check production environment"
echo "  gh api repos/${REPO}/environments/production | jq '.protection_rules, .deployment_branch_policy'"
echo ""
echo "  # Check development environment"
echo "  gh api repos/${REPO}/environments/development | jq '.deployment_branch_policy'"
echo ""
echo "  # Check main branch protection"
echo "  gh api repos/${REPO}/branches/main/protection | jq '.required_pull_request_reviews, .enforce_admins'"
echo ""
echo "  # Check develop branch protection"
echo "  gh api repos/${REPO}/branches/develop/protection | jq '.required_pull_request_reviews, .enforce_admins'"
echo ""

echo -e "${BOLD}Workflow Notes:${NC}"
echo ""
echo "  Solo contributor (admin) workflow:"
echo "    • Your PRs: Merge via admin bypass (no self-approval needed)"
echo "    • Copilot PRs: Review & approve normally, then merge"
echo "    • Production deploys: Approve deployment when prompted in Actions"
echo "    • Emergency: Admin bypass allows immediate action"
echo ""
