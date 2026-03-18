#!/usr/bin/env bash
# configure-repo-protection.sh
# Idempotent configuration of GitHub environment protection rules and branch
# protection rules for the Azure Resume IaC project.
#
# The script defines a desired state for 4 resources (production environment,
# development environment, main branch protection, develop branch protection),
# compares current state against desired state, and only applies changes when
# drift is detected.
#
# Usage:
#   bash scripts/configure-repo-protection.sh [options]
#
# Options:
#   --dry-run           Audit current state vs desired — no changes (exit 0=compliant, 2=drift)
#   --reviewer <user>   GitHub username for required reviewer (default: repo owner)
#   --repo <owner/repo> Target repository (default: auto-detect from git origin remote)
#   --wait-timer <min>  Wait timer in minutes for production (default: 5)
#   --skip-branch       Skip branch protection rules (environment only)
#   --skip-environment  Skip environment protection rules (branch only)
#   -h, --help          Show usage
#
# Exit codes:
#   0  Success (all compliant, or drift fixed)
#   1  Error (prerequisite failure, API error)
#   2  Drift detected (--dry-run only)
#
# Prerequisites:
#   - gh CLI authenticated with 'repo' scope (verify with: gh auth status -t)
#   - jq installed
#   - git (for auto-detect repo from origin remote)
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
  --dry-run           Audit current state vs desired — no changes (exit 0=compliant, 2=drift)
  --reviewer <user>   GitHub username for required reviewer (default: repo owner)
  --repo <owner/repo> Target repository (default: auto-detect from git origin)
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

require_arg() {
  if [[ $# -lt 2 || -z "${2:-}" ]]; then
    fail "Option '$1' requires a value."
    usage
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)        DRY_RUN=true; shift ;;
    --reviewer)       require_arg "$1" "${2:-}"; REVIEWER="$2"; shift 2 ;;
    --repo)           require_arg "$1" "${2:-}"; REPO="$2"; shift 2 ;;
    --wait-timer)     require_arg "$1" "${2:-}"; WAIT_TIMER="$2"; shift 2 ;;
    --skip-branch)    SKIP_BRANCH=true; shift ;;
    --skip-environment) SKIP_ENVIRONMENT=true; shift ;;
    -h|--help)        usage ;;
    *)                echo "Unknown option: $1"; usage ;;
  esac
done

# Validate wait timer is a non-negative integer
if ! [[ "$WAIT_TIMER" =~ ^[0-9]+$ ]]; then
  fail "--wait-timer must be a non-negative integer, got: '$WAIT_TIMER'"
  exit 1
fi

# =============================================================================
# Prerequisite Checks
# =============================================================================

header "Prerequisite Checks"

for cmd in gh jq git; do
  if ! command -v "$cmd" &>/dev/null; then
    fail "Required command '$cmd' is not installed."
    exit 1
  fi
done
success "Required tools found (gh, jq, git)"

if ! gh auth status &>/dev/null; then
  fail "GitHub CLI not authenticated. Run: gh auth login --scopes repo"
  fail "Verify scopes with: gh auth status -t"
  exit 1
fi
GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
success "GitHub CLI authenticated as: $GH_USER"

# Auto-detect repo from git origin remote (not gh repo view, which follows
# fork parents and can resolve to the wrong repository)
if [[ -z "$REPO" ]]; then
  ORIGIN_URL=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ -n "$ORIGIN_URL" ]]; then
    REPO=$(echo "$ORIGIN_URL" | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')
  fi
  if [[ -z "$REPO" || "$REPO" == "$ORIGIN_URL" ]]; then
    fail "Could not detect repository from git origin remote. Use --repo owner/repo"
    exit 1
  fi
fi
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

# Validate the detected repo is accessible
if ! gh api "repos/${REPO}" --jq '.full_name' &>/dev/null; then
  fail "Repository '${REPO}' is not accessible. Check permissions or use --repo owner/repo"
  exit 1
fi
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
  warn "DRY RUN MODE — audit only, no changes will be made"
fi

# =============================================================================
# Temp Directory
# =============================================================================

SNAPSHOT_DIR=$(mktemp -d)
trap 'rm -rf "$SNAPSHOT_DIR"' EXIT

# =============================================================================
# Desired State Functions
# =============================================================================
# These define the single source of truth for what each resource should look
# like. The capture functions produce comparable JSON so we can diff.

desired_env_production() {
  cat <<EOF
{
  "exists": true,
  "protection_rules": [
    {
      "type": "required_reviewers",
      "wait_timer": null,
      "reviewers": [
        {
          "login": "${REVIEWER}",
          "type": "User"
        }
      ]
    },
    {
      "type": "wait_timer",
      "wait_timer": ${WAIT_TIMER},
      "reviewers": []
    }
  ],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  },
  "deployment_branch_policies": [
    {
      "name": "main",
      "type": "branch"
    }
  ]
}
EOF
}

desired_env_development() {
  cat <<EOF
{
  "exists": true,
  "protection_rules": [],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  },
  "deployment_branch_policies": [
    {
      "name": "develop",
      "type": "branch"
    }
  ]
}
EOF
}

desired_branch_protection() {
  # Same desired state for both main and develop branches
  cat <<EOF
{
  "exists": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "enforce_admins": false,
  "required_status_checks": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF
}

# =============================================================================
# State Capture Functions
# =============================================================================

capture_environment_state() {
  local env_name="$1"
  local output_file="$2"

  local env_data
  env_data=$(gh api "repos/${REPO}/environments/${env_name}" 2>/dev/null || echo '{"error": "not found"}')

  if echo "$env_data" | jq -e '.error' &>/dev/null; then
    echo '{"exists": false}' > "$output_file"
    return
  fi

  # Extract protection rules in the same shape as desired state.
  # Filter out "branch_policy" type — GitHub auto-adds this when
  # custom_branch_policies is true; it's not in our PUT payload.
  local protection_rules
  protection_rules=$(echo "$env_data" | jq '{
    exists: true,
    protection_rules: [.protection_rules[]? | select(.type != "branch_policy") | {
      type: .type,
      wait_timer: .wait_timer,
      reviewers: [.reviewers[]? | {login: .reviewer.login, type: .type}]
    }] | sort_by(.type),
    deployment_branch_policy: .deployment_branch_policy
  }' 2>/dev/null || echo '{"exists": true, "error": "parse_failed"}')

  echo "$protection_rules" > "$output_file"

  # Also capture deployment branch policies if they exist
  local branch_policy_type
  branch_policy_type=$(echo "$env_data" | jq -r '.deployment_branch_policy.custom_branch_policies // false' 2>/dev/null)

  if [[ "$branch_policy_type" == "true" ]]; then
    local branch_policies
    branch_policies=$(gh api "repos/${REPO}/environments/${env_name}/deployment-branch-policies" 2>/dev/null || echo '{"branch_policies": []}')
    # Merge deployment_branch_policies (name + type only, to match desired state shape)
    local merged
    merged=$(jq -s '.[0] * {deployment_branch_policies: [.[1].branch_policies[]? | {name: .name, type: .type}]}' \
      "$output_file" <(echo "$branch_policies") 2>/dev/null || cat "$output_file")
    echo "$merged" > "$output_file"
  fi
}

capture_branch_protection_state() {
  local branch="$1"
  local output_file="$2"

  local protection_data
  local api_exit_code=0
  protection_data=$(gh api "repos/${REPO}/branches/${branch}/protection" 2>/dev/null) || api_exit_code=$?

  if [[ "$api_exit_code" -ne 0 ]] || echo "$protection_data" | jq -e '.message // .error' &>/dev/null; then
    local err_msg
    err_msg=$(echo "$protection_data" | jq -r '.message // .error // "not configured"' 2>/dev/null || echo "API call failed (exit code: $api_exit_code)")
    echo '{"exists": false, "message": "'"$err_msg"'"}' > "$output_file"
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
# Drift Detection
# =============================================================================
# Compares current state JSON against desired state JSON.
# Returns 0 if compliant, 1 if drift detected.
# Writes the diff to stdout when drift is found.

check_drift() {
  local label="$1"
  local current_file="$2"
  local desired_file="$3"

  # Check for API permission errors — can't determine compliance
  local current_msg
  current_msg=$(jq -r '.message // empty' "$current_file" 2>/dev/null || echo "")
  if [[ "$current_msg" == *"not accessible"* ]] || [[ "$current_msg" == *"integration"* ]]; then
    warn "SKIPPED: $label — insufficient API permissions (${current_msg})"
    info "  Branch protection requires 'administration' permission on the token"
    info "  Re-run outside Codespace with a PAT, or use --skip-branch"
    # Return special code 2 to distinguish from real drift
    return 2
  fi

  local current_sorted desired_sorted
  current_sorted=$(jq --sort-keys '.' "$current_file" 2>/dev/null || cat "$current_file")
  desired_sorted=$(jq --sort-keys '.' "$desired_file" 2>/dev/null || cat "$desired_file")

  if diff -q <(echo "$current_sorted") <(echo "$desired_sorted") &>/dev/null; then
    success "IN COMPLIANCE: $label"
    return 0
  else
    warn "DRIFT DETECTED: $label"
    diff --color=always \
      <(echo "$current_sorted") \
      <(echo "$desired_sorted") \
      | sed 's/^/  /' || true
    echo "  (left = current, right = desired)"
    return 1
  fi
}

# =============================================================================
# Apply Functions (only called when drift is detected)
# =============================================================================

apply_environment() {
  local env_name="$1"
  local allowed_branch="$2"
  local payload="$3"

  info "Applying configuration for '${env_name}' environment..."

  # Create/update the environment with protection rules
  local response
  response=$(echo "$payload" | gh api -X PUT "repos/${REPO}/environments/${env_name}" --input - 2>&1) || {
    fail "Failed to update '${env_name}' environment:"
    echo "$response" | sed 's/^/  /'
    return 1
  }

  # Sync deployment branch policies: compute delta
  local existing_names desired_name="$allowed_branch"
  existing_names=$(gh api "repos/${REPO}/environments/${env_name}/deployment-branch-policies" \
    --jq '[.branch_policies[] | {id: .id, name: .name}]' 2>/dev/null || echo '[]')

  # Remove policies that don't match the desired branch
  local ids_to_remove
  ids_to_remove=$(echo "$existing_names" | jq -r --arg desired "$desired_name" \
    '.[] | select(.name != $desired) | .id' 2>/dev/null || echo "")
  while IFS= read -r policy_id; do
    if [[ -n "$policy_id" ]]; then
      local del_response
      del_response=$(gh api -X DELETE "repos/${REPO}/environments/${env_name}/deployment-branch-policies/${policy_id}" 2>&1) || {
        fail "Failed to remove deployment branch policy ${policy_id}:"
        echo "$del_response" | sed 's/^/  /'
      }
      info "  Removed stale policy ID: $policy_id"
    fi
  done <<< "$ids_to_remove"

  # Add the desired branch policy if it doesn't already exist
  local has_desired
  has_desired=$(echo "$existing_names" | jq -r --arg desired "$desired_name" \
    '[.[] | select(.name == $desired)] | length' 2>/dev/null || echo "0")
  if [[ "$has_desired" == "0" ]]; then
    local add_response
    add_response=$(gh api -X POST "repos/${REPO}/environments/${env_name}/deployment-branch-policies" \
      -f name="$desired_name" -f type="branch" 2>&1) || {
      fail "Failed to add deployment branch policy '${desired_name}':"
      echo "$add_response" | sed 's/^/  /'
      return 1
    }
    info "  Added deployment branch policy: $desired_name"
  else
    info "  Deployment branch policy '$desired_name' already exists"
  fi

  success "'${env_name}' environment configured"
}

apply_branch_protection() {
  local branch="$1"

  info "Applying branch protection for '${branch}'..."

  local response
  response=$(gh api -X PUT "repos/${REPO}/branches/${branch}/protection" \
    --input - <<EOF 2>&1
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
  ) || {
    fail "Failed to configure '${branch}' branch protection:"
    echo "$response" | sed 's/^/  /'
    return 1
  }

  success "'${branch}' branch protection configured"
}

# =============================================================================
# Step 1: Capture Current State
# =============================================================================

header "Step 1: Capturing Current State"

capture_environment_state "production" "${SNAPSHOT_DIR}/current_env_production.json"
capture_environment_state "development" "${SNAPSHOT_DIR}/current_env_development.json"
capture_branch_protection_state "main" "${SNAPSHOT_DIR}/current_branch_main.json"
capture_branch_protection_state "develop" "${SNAPSHOT_DIR}/current_branch_develop.json"

display_state "Production Environment (current)" "${SNAPSHOT_DIR}/current_env_production.json"
display_state "Development Environment (current)" "${SNAPSHOT_DIR}/current_env_development.json"
display_state "Main Branch Protection (current)" "${SNAPSHOT_DIR}/current_branch_main.json"
display_state "Develop Branch Protection (current)" "${SNAPSHOT_DIR}/current_branch_develop.json"

# =============================================================================
# Step 2: Write Desired State
# =============================================================================

header "Step 2: Desired State"

desired_env_production  | jq '.' > "${SNAPSHOT_DIR}/desired_env_production.json"
desired_env_development | jq '.' > "${SNAPSHOT_DIR}/desired_env_development.json"
desired_branch_protection | jq '.' > "${SNAPSHOT_DIR}/desired_branch_main.json"
desired_branch_protection | jq '.' > "${SNAPSHOT_DIR}/desired_branch_develop.json"

display_state "Production Environment (desired)" "${SNAPSHOT_DIR}/desired_env_production.json"
display_state "Development Environment (desired)" "${SNAPSHOT_DIR}/desired_env_development.json"
display_state "Main Branch Protection (desired)" "${SNAPSHOT_DIR}/desired_branch_main.json"
display_state "Develop Branch Protection (desired)" "${SNAPSHOT_DIR}/desired_branch_develop.json"

# =============================================================================
# Step 3: Drift Detection
# =============================================================================

header "Step 3: Drift Detection (Current vs Desired)"

DRIFT_COUNT=0
SKIP_COUNT=0
DRIFT_ENV_PROD=false
DRIFT_ENV_DEV=false
DRIFT_BRANCH_MAIN=false
DRIFT_BRANCH_DEVELOP=false

run_drift_check() {
  local label="$1"
  local current_file="$2"
  local desired_file="$3"
  local drift_var="$4"

  local rc=0
  check_drift "$label" "$current_file" "$desired_file" || rc=$?
  case "$rc" in
    0) ;; # compliant
    1) DRIFT_COUNT=$((DRIFT_COUNT + 1)); eval "${drift_var}=true" ;;
    2) SKIP_COUNT=$((SKIP_COUNT + 1)) ;; # insufficient permissions
  esac
}

if [[ "$SKIP_ENVIRONMENT" != true ]]; then
  run_drift_check "Production Environment" "${SNAPSHOT_DIR}/current_env_production.json" "${SNAPSHOT_DIR}/desired_env_production.json" DRIFT_ENV_PROD
  run_drift_check "Development Environment" "${SNAPSHOT_DIR}/current_env_development.json" "${SNAPSHOT_DIR}/desired_env_development.json" DRIFT_ENV_DEV
fi

if [[ "$SKIP_BRANCH" != true ]]; then
  run_drift_check "Main Branch Protection" "${SNAPSHOT_DIR}/current_branch_main.json" "${SNAPSHOT_DIR}/desired_branch_main.json" DRIFT_BRANCH_MAIN
  run_drift_check "Develop Branch Protection" "${SNAPSHOT_DIR}/current_branch_develop.json" "${SNAPSHOT_DIR}/desired_branch_develop.json" DRIFT_BRANCH_DEVELOP
fi

# =============================================================================
# Dry Run: Report and Exit
# =============================================================================

if [[ "$DRY_RUN" == true ]]; then
  header "Audit Complete"
  if [[ "$SKIP_COUNT" -gt 0 ]]; then
    warn "${SKIP_COUNT} resource(s) skipped due to insufficient permissions"
  fi
  if [[ "$DRIFT_COUNT" -gt 0 ]]; then
    warn "${DRIFT_COUNT} resource(s) have configuration drift"
    info "Run without --dry-run to remediate"
    exit 2
  else
    success "All auditable resources are in compliance — no changes needed"
    exit 0
  fi
fi

# =============================================================================
# Step 4: Apply Remediations (only for drifted resources)
# =============================================================================

if [[ "$DRIFT_COUNT" -eq 0 ]]; then
  header "Step 4: Apply"
  success "All resources already match desired state — nothing to do"
else
  header "Step 4: Applying Remediations (${DRIFT_COUNT} resource(s) drifted)"

  APPLY_FAILURES=0

  if [[ "$DRIFT_ENV_PROD" == true ]]; then
    subhead "Remediating: Production Environment"
    info "Desired: reviewer=${REVIEWER}, wait_timer=${WAIT_TIMER}min, branch=main"
    apply_environment "production" "main" "$(cat <<PAYLOAD
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
PAYLOAD
)" || APPLY_FAILURES=$((APPLY_FAILURES + 1))
  fi

  if [[ "$DRIFT_ENV_DEV" == true ]]; then
    subhead "Remediating: Development Environment"
    info "Desired: no reviewers, branch=develop"
    apply_environment "development" "develop" "$(cat <<PAYLOAD
{
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true
  }
}
PAYLOAD
)" || APPLY_FAILURES=$((APPLY_FAILURES + 1))
  fi

  if [[ "$DRIFT_BRANCH_MAIN" == true ]]; then
    subhead "Remediating: Main Branch Protection"
    apply_branch_protection "main" || APPLY_FAILURES=$((APPLY_FAILURES + 1))
  fi

  if [[ "$DRIFT_BRANCH_DEVELOP" == true ]]; then
    subhead "Remediating: Develop Branch Protection"
    apply_branch_protection "develop" || APPLY_FAILURES=$((APPLY_FAILURES + 1))
  fi

  if [[ "$APPLY_FAILURES" -gt 0 ]]; then
    fail "${APPLY_FAILURES} remediation(s) failed"
  fi
fi

# =============================================================================
# Step 5: Post-Apply Verification
# =============================================================================

if [[ "$DRIFT_COUNT" -gt 0 ]]; then
  header "Step 5: Post-Apply Verification"

  capture_environment_state "production" "${SNAPSHOT_DIR}/post_env_production.json"
  capture_environment_state "development" "${SNAPSHOT_DIR}/post_env_development.json"
  capture_branch_protection_state "main" "${SNAPSHOT_DIR}/post_branch_main.json"
  capture_branch_protection_state "develop" "${SNAPSHOT_DIR}/post_branch_develop.json"

  VERIFY_FAILURES=0

  if [[ "$SKIP_ENVIRONMENT" != true ]]; then
    check_drift "Production Environment (verify)" "${SNAPSHOT_DIR}/post_env_production.json" "${SNAPSHOT_DIR}/desired_env_production.json" || {
      VERIFY_FAILURES=$((VERIFY_FAILURES + 1))
    }
    check_drift "Development Environment (verify)" "${SNAPSHOT_DIR}/post_env_development.json" "${SNAPSHOT_DIR}/desired_env_development.json" || {
      VERIFY_FAILURES=$((VERIFY_FAILURES + 1))
    }
  fi

  if [[ "$SKIP_BRANCH" != true ]]; then
    check_drift "Main Branch Protection (verify)" "${SNAPSHOT_DIR}/post_branch_main.json" "${SNAPSHOT_DIR}/desired_branch_main.json" || {
      VERIFY_FAILURES=$((VERIFY_FAILURES + 1))
    }
    check_drift "Develop Branch Protection (verify)" "${SNAPSHOT_DIR}/post_branch_develop.json" "${SNAPSHOT_DIR}/desired_branch_develop.json" || {
      VERIFY_FAILURES=$((VERIFY_FAILURES + 1))
    }
  fi

  if [[ "$VERIFY_FAILURES" -gt 0 ]]; then
    warn "${VERIFY_FAILURES} resource(s) still show drift after remediation"
  else
    success "All resources verified — post-apply state matches desired state"
  fi

  # Show what actually changed (pre vs post)
  header "Changes Applied (before vs after)"

  CHANGES=0

  compare_pre_post() {
    local label="$1"
    local pre_file="$2"
    local post_file="$3"

    if ! diff -q <(jq --sort-keys '.' "$pre_file" 2>/dev/null) <(jq --sort-keys '.' "$post_file" 2>/dev/null) &>/dev/null; then
      subhead "CHANGED: $label"
      diff --color=always \
        <(jq --sort-keys '.' "$pre_file" 2>/dev/null) \
        <(jq --sort-keys '.' "$post_file" 2>/dev/null) \
        | sed 's/^/  /' || true
      CHANGES=$((CHANGES + 1))
    else
      info "No change: $label"
    fi
  }

  if [[ "$SKIP_ENVIRONMENT" != true ]]; then
    compare_pre_post "Production Environment" "${SNAPSHOT_DIR}/current_env_production.json" "${SNAPSHOT_DIR}/post_env_production.json"
    compare_pre_post "Development Environment" "${SNAPSHOT_DIR}/current_env_development.json" "${SNAPSHOT_DIR}/post_env_development.json"
  fi
  if [[ "$SKIP_BRANCH" != true ]]; then
    compare_pre_post "Main Branch Protection" "${SNAPSHOT_DIR}/current_branch_main.json" "${SNAPSHOT_DIR}/post_branch_main.json"
    compare_pre_post "Develop Branch Protection" "${SNAPSHOT_DIR}/current_branch_develop.json" "${SNAPSHOT_DIR}/post_branch_develop.json"
  fi
fi

# =============================================================================
# Summary
# =============================================================================

header "Summary"
echo ""

if [[ "$DRIFT_COUNT" -eq 0 ]]; then
  success "All resources were already in compliance — no changes made"
else
  success "${DRIFT_COUNT} resource(s) remediated"
fi

echo ""
echo -e "${BOLD}Desired Protection Rules:${NC}"
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
