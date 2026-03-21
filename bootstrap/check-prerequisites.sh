#!/usr/bin/env bash
# check-prerequisites.sh
# Verifies that all tools, authentication, and permissions required for the
# AgentGitOps workflow are present and correctly configured.
#
# Usage:
#   ./bootstrap/check-prerequisites.sh [owner/repo]
#
# Exit codes:
#   0 — All checks passed (Good to Go)
#   1 — One or more checks failed (see output for details)

set -euo pipefail

# --- Configuration ---
REPO="${1:-}"
PASS=0
FAIL=0
WARN=0
RESULTS=()

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  GREEN='' RED='' YELLOW='' BOLD='' NC=''
fi

pass() {
  PASS=$((PASS + 1))
  RESULTS+=("${GREEN}✅ PASS${NC}: $1")
  echo -e "  ${GREEN}✅${NC} $1"
}

fail() {
  FAIL=$((FAIL + 1))
  RESULTS+=("${RED}❌ FAIL${NC}: $1")
  echo -e "  ${RED}❌${NC} $1"
}

warn() {
  WARN=$((WARN + 1))
  RESULTS+=("${YELLOW}⚠️  WARN${NC}: $1")
  echo -e "  ${YELLOW}⚠️${NC}  $1"
}

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       AgentGitOps — Prerequisite Check              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ─── Section 1: Required Tools ─────────────────────────────────────
echo -e "${BOLD}1. Required Tools${NC}"
echo "   ─────────────────────────────────────────"

# gh CLI
if command -v gh &>/dev/null; then
  GH_VERSION=$(gh --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  pass "gh CLI installed (v${GH_VERSION})"
else
  fail "gh CLI not found — install from https://cli.github.com"
fi

# git
if command -v git &>/dev/null; then
  GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  pass "git installed (v${GIT_VERSION})"
else
  fail "git not found — install from https://git-scm.com"
fi

# python3
if command -v python3 &>/dev/null; then
  PY_VERSION=$(python3 --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  pass "python3 installed (v${PY_VERSION})"
else
  fail "python3 not found — required for project field setup scripts"
fi

# jq
if command -v jq &>/dev/null; then
  JQ_VERSION=$(jq --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' || echo "unknown")
  pass "jq installed (v${JQ_VERSION})"
else
  warn "jq not found — optional but recommended for JSON processing"
fi

echo ""

# ─── Section 2: GitHub CLI Authentication ──────────────────────────
echo -e "${BOLD}2. GitHub CLI Authentication${NC}"
echo "   ─────────────────────────────────────────"

if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    AUTH_USER=$(
      gh api user --jq .login 2>/dev/null || \
      gh auth status 2>&1 | awk '/Logged in to github\.com account/ {print $NF; exit}' || \
      gh auth status 2>&1 | awk '/account/ {print $NF; exit}' || \
      echo "unknown"
    )
    pass "gh CLI authenticated as ${AUTH_USER}"

    # Check scopes
    SCOPES=$(gh auth status 2>&1 | grep -i 'token scopes' || echo "")
    if echo "$SCOPES" | grep -qi 'repo'; then
      pass "Token has 'repo' scope"
    else
      # In Codespaces, GITHUB_TOKEN may not list scopes but still works
      if [[ -n "${CODESPACES:-}" ]]; then
        warn "Cannot verify 'repo' scope in Codespace — GITHUB_TOKEN should include it by default"
      else
        warn "Could not verify 'repo' scope — ensure your token includes repo permissions"
      fi
    fi

    if echo "$SCOPES" | grep -qi 'project'; then
      pass "Token has 'project' scope"
    else
      warn "Token does not have 'project' scope — required for GitHub Project setup (Step 5). Run: gh auth login --scopes \"project,repo,read:org\""
    fi
  else
    fail "gh CLI not authenticated — run: gh auth login"
  fi
else
  fail "gh CLI not installed — cannot check authentication"
fi

echo ""

# ─── Section 3: Repository Access ─────────────────────────────────
echo -e "${BOLD}3. Repository Access${NC}"
echo "   ─────────────────────────────────────────"

# Try to detect repo from git remote if not provided
if [[ -z "$REPO" ]]; then
  REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#' || echo "")
fi

if [[ -n "$REPO" ]]; then
  pass "Repository detected: ${REPO}"

  if command -v gh &>/dev/null && gh auth status &>/dev/null; then
    # Check repo access
    if gh repo view "$REPO" --json name &>/dev/null; then
      pass "Can read repository ${REPO}"
    else
      fail "Cannot access repository ${REPO} — check permissions"
    fi

    # Check issue creation permission
    if gh api "repos/${REPO}" --jq '.permissions.push // false' 2>/dev/null | grep -q 'true'; then
      pass "Write access to ${REPO} (can create issues/PRs)"
    else
      warn "Could not verify write access — you may need collaborator or admin permissions"
    fi

    # Check if issues are enabled
    ISSUES_ENABLED=$(gh api "repos/${REPO}" --jq '.has_issues' 2>/dev/null || echo "unknown")
    if [[ "$ISSUES_ENABLED" == "true" ]]; then
      pass "Issues are enabled on ${REPO}"
    elif [[ "$ISSUES_ENABLED" == "false" ]]; then
      fail "Issues are DISABLED on ${REPO} — enable in Settings → Features → Issues"
    else
      warn "Could not verify if issues are enabled"
    fi
  fi
else
  warn "No repository detected — run from inside a git repo or pass owner/repo as argument"
fi

echo ""

# ─── Section 4: Script Files ──────────────────────────────────────
echo -e "${BOLD}4. Required Scripts${NC}"
echo "   ─────────────────────────────────────────"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_script() {
  local path="$1"
  local desc="$2"
  if [[ -f "${SCRIPT_DIR}/${path}" ]]; then
    if [[ -x "${SCRIPT_DIR}/${path}" ]]; then
      pass "${desc} — found and executable"
    else
      warn "${desc} — found but not executable. Run: chmod +x ${path}"
    fi
  else
    warn "${desc} — not found at ${path}"
  fi
}

check_script "scripts/setup-github-labels.sh" "setup-github-labels.sh"
check_script "scripts/setup-github-milestones.sh" "setup-github-milestones.sh"
check_script "scripts/create-backlog-issues.sh" "create-backlog-issues.sh"
check_script "scripts/setup-github-project.sh" "setup-github-project.sh"
check_script "scripts/generate-phase-retrospective.sh" "generate-phase-retrospective.sh"

echo ""

# ─── Section 5: Optional Tools ────────────────────────────────────
echo -e "${BOLD}5. Optional Tools (for Backlog Burn-Down)${NC}"
echo "   ─────────────────────────────────────────"

# Azure CLI
if command -v az &>/dev/null; then
  AZ_VERSION=$(az version --output tsv 2>/dev/null | head -1 | cut -f1 || az --version 2>&1 | grep -oE 'azure-cli[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
  pass "Azure CLI installed (v${AZ_VERSION})"
else
  warn "Azure CLI not found — needed for infrastructure deployment, not for backlog setup"
fi

# .NET SDK
if command -v dotnet &>/dev/null; then
  DOTNET_VERSION=$(dotnet --version 2>/dev/null || echo "unknown")
  pass ".NET SDK installed (v${DOTNET_VERSION})"
else
  warn ".NET SDK not found — needed for backend development, not for backlog setup"
fi

echo ""

# ─── Summary ──────────────────────────────────────────────────────
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}✅ Good to Go!${NC}"
  echo ""
  echo "  All required checks passed. You are ready to run the AgentGitOps workflow."
  echo ""
  if [[ $WARN -gt 0 ]]; then
    echo -e "  ${YELLOW}${WARN} warning(s)${NC} — review the items above for optional improvements."
    echo ""
  fi
  echo "  Next step: Follow the Phase Guide in bootstrap/agentgitops-instructions.md"
  echo ""
  exit 0
else
  echo -e "  ${RED}${BOLD}❌ Missing Prerequisites${NC}"
  echo ""
  echo -e "  ${RED}${FAIL} check(s) failed${NC} — resolve the issues below before proceeding."
  if [[ $WARN -gt 0 ]]; then
    echo -e "  ${YELLOW}${WARN} warning(s)${NC} — also review optional items above."
  fi
  echo ""
  echo "  ── Remediation Steps ──"
  echo ""

  if ! command -v gh &>/dev/null; then
    echo "  • Install GitHub CLI:"
    echo "    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
    echo "    echo 'deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list"
    echo "    sudo apt update && sudo apt install gh"
    echo ""
  fi

  if command -v gh &>/dev/null && ! gh auth status &>/dev/null; then
    echo "  • Authenticate GitHub CLI:"
    echo "    gh auth login"
    echo ""
    echo "  • For full permissions (including GitHub Projects):"
    echo "    gh auth login --scopes \"project,repo,read:org\""
    echo ""
  fi

  if ! command -v python3 &>/dev/null; then
    echo "  • Install Python 3:"
    echo "    sudo apt install python3"
    echo ""
  fi

  echo "  • For organization repositories, ask an org admin to grant you:"
  echo "    - Repository write access (for issues and PRs)"
  echo "    - Project access (for GitHub Projects V2)"
  echo ""
  echo "  • For personal repositories, ensure you are the repo owner or a collaborator."
  echo ""

  exit 1
fi
