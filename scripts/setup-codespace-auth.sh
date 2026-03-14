#!/usr/bin/env bash
# setup-codespace-auth.sh
# Authenticates Azure CLI, GitHub CLI, and Cloudflare API for a Codespace session.
# Designed for the Technologist role working on "Copilot: Partial" issues.
#
# Usage:
#   bash scripts/setup-codespace-auth.sh [owner/repo]
#
# Arguments:
#   owner/repo  (optional) Repository in owner/repo format.
#               Defaults to the repository detected by `gh repo view`.
#
# Prerequisites (one-time setup in GitHub Settings → Secrets → Codespaces):
#   AZURE_SP_APP_ID       — Azure Service Principal Application (client) ID
#   AZURE_SP_PASSWORD     — Azure Service Principal secret
#   AZURE_SP_TENANT       — Azure AD Tenant ID
#   AZURE_SUBSCRIPTION_ID — Azure Subscription ID (optional, auto-detected if SP has one sub)
#   CF_API_TOKEN          — Cloudflare API Token with DNS Edit permission
#
# These Codespace Secrets are automatically injected as environment variables
# into every new Codespace. No manual export needed.
#
# For GitHub CLI: The Codespace GITHUB_TOKEN is auto-available.
# For project board access, run: gh auth login --scopes "project,repo,read:org"

set -euo pipefail

REPO_ARG="${1:-}"

PASS=0
WARN=0
FAIL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

# =============================================================================
# Step 1: Validate prerequisites (install az/gh CLI if missing)
# =============================================================================
echo "=== Step 1: Prerequisites ==="

# Install Azure CLI if not present
if ! command -v az &>/dev/null; then
  echo "  ⏳ Azure CLI not found — installing..."
  # Remove broken third-party apt sources (e.g. Yarn with expired GPG keys)
  # that cause apt-get update to fail inside the Microsoft install script.
  for f in /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/docker.list; do
    [[ -f "$f" ]] && sudo rm -f "$f" && echo "  ℹ️  Removed stale apt source: $f"
  done
  if curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash 2>&1 | tail -5; then
    pass "az installed at $(command -v az)"
  else
    fail "az install failed — see https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux"
  fi
fi

# Install GitHub CLI if not present
if ! command -v gh &>/dev/null; then
  echo "  ⏳ GitHub CLI not found — installing..."
  if sudo mkdir -p -m 755 /etc/apt/keyrings \
     && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
     && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
     && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
     && sudo apt-get update && sudo apt-get install -y gh 2>&1 | tail -5; then
    pass "gh installed at $(command -v gh)"
  else
    fail "gh install failed — see https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
  fi
fi

for cmd in az gh curl python3 git jq; do
  if command -v "$cmd" &>/dev/null; then
    pass "$cmd $(command -v "$cmd")"
  else
    fail "$cmd not found on PATH"
  fi
done
echo ""

# Resolve repository now that gh is available
if [[ -n "$REPO_ARG" ]]; then
  REPO="$REPO_ARG"
elif command -v gh &>/dev/null; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "unknown")
else
  REPO="unknown"
fi

echo "========================================"
echo "  Codespace Auth Setup"
echo "  Repository: $REPO"
echo "========================================"
echo ""

# =============================================================================
# Step 2: Azure CLI Authentication
# =============================================================================
echo "=== Step 2: Azure CLI ==="

if az account show &>/dev/null; then
  CURRENT_ACCOUNT=$(az account show --query '{name:name, id:id, user:user.name}' -o tsv 2>/dev/null || echo "unknown")
  pass "Already logged in: $CURRENT_ACCOUNT"
elif [[ -n "${AZURE_SP_APP_ID:-}" && -n "${AZURE_SP_PASSWORD:-}" && -n "${AZURE_SP_TENANT:-}" ]]; then
  echo "  Logging in with Service Principal..."
  if az login --service-principal \
       -u "$AZURE_SP_APP_ID" \
       -p "$AZURE_SP_PASSWORD" \
       --tenant "$AZURE_SP_TENANT" \
       --output none 2>/dev/null; then
    pass "Service Principal login successful"
  else
    fail "Service Principal login failed — check AZURE_SP_APP_ID, AZURE_SP_PASSWORD, AZURE_SP_TENANT"
  fi
else
  echo "  No Azure SP env vars found. Starting device code login..."
  echo "  (Set AZURE_SP_APP_ID, AZURE_SP_PASSWORD, AZURE_SP_TENANT as Codespace Secrets for non-interactive login)"
  if az login --use-device-code; then
    pass "Interactive login successful"
  else
    fail "Azure login failed"
  fi
fi

# Set subscription if provided
if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
  az account set --subscription "$AZURE_SUBSCRIPTION_ID" --output none 2>/dev/null
  pass "Subscription set: $AZURE_SUBSCRIPTION_ID"
elif az account show &>/dev/null; then
  SUB_ID=$(az account show --query id -o tsv 2>/dev/null)
  SUB_NAME=$(az account show --query name -o tsv 2>/dev/null)
  pass "Using default subscription: $SUB_NAME ($SUB_ID)"
fi

# Verify Azure access by listing resource groups
if az account show &>/dev/null; then
  RG_COUNT=$(az group list --query 'length(@)' -o tsv 2>/dev/null || echo "0")
  pass "Azure access verified: $RG_COUNT resource groups visible"
fi
echo ""

# =============================================================================
# Step 3: GitHub CLI Authentication
# =============================================================================
echo "=== Step 3: GitHub CLI ==="

if gh auth status &>/dev/null; then
  GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
  pass "Authenticated as: $GH_USER"

  # Check for project scope
  if gh project list --owner "$(echo "$REPO" | cut -d/ -f1)" --limit 1 &>/dev/null; then
    pass "Project scope available"
  else
    warn "No project scope — run: gh auth login --scopes \"project,repo,read:org\" (needed for project board updates)"
  fi

  # Verify repo access
  if gh repo view "$REPO" --json name &>/dev/null; then
    pass "Repository access verified: $REPO"
  else
    fail "Cannot access repository: $REPO"
  fi
else
  fail "GitHub CLI not authenticated — run: gh auth login"
fi
echo ""

# =============================================================================
# Step 4: Cloudflare API Validation
# =============================================================================
echo "=== Step 4: Cloudflare API ==="

if [[ -n "${CF_API_TOKEN:-}" ]]; then
  CF_RESULT=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null || echo '{"success":false}')

  CF_SUCCESS=$(echo "$CF_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")
  CF_STATUS=$(echo "$CF_RESULT" | python3 -c "import json,sys; r=json.load(sys.stdin).get('result',{}); print(r.get('status','unknown'))" 2>/dev/null || echo "unknown")

  if [[ "$CF_SUCCESS" == "True" && "$CF_STATUS" == "active" ]]; then
    pass "Cloudflare API token verified (status: active)"
  else
    fail "Cloudflare API token validation failed (status: $CF_STATUS)"
  fi
else
  warn "CF_API_TOKEN not set — Cloudflare commands will not work"
  echo "       Set CF_API_TOKEN as a Codespace Secret for automatic injection"
  echo ""
  echo "       To set locally for this session:"
  echo "         export CF_API_TOKEN=\"your-cloudflare-api-token\""
fi
echo ""

# =============================================================================
# Step 5: Connection Summary
# =============================================================================
echo "========================================"
echo "  Connection Summary"
echo "========================================"
echo "  ✅ Passed:  $PASS"
echo "  ⚠️  Warnings: $WARN"
echo "  ❌ Failed:  $FAIL"
echo "========================================"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "Some connections failed. Fix the issues above before proceeding."
  echo ""
  echo "Quick reference — Codespace Secrets (one-time setup):"
  echo "  https://github.com/settings/codespaces"
  echo ""
  echo "  AZURE_SP_APP_ID       — az ad sp show --id <app-id>"
  echo "  AZURE_SP_PASSWORD     — Service principal client secret"
  echo "  AZURE_SP_TENANT       — az account show --query tenantId"
  echo "  AZURE_SUBSCRIPTION_ID — az account show --query id"
  echo "  CF_API_TOKEN          — Cloudflare Dashboard → My Profile → API Tokens"
  exit 1
else
  echo "All connections ready. You can now work on the issue."
fi
