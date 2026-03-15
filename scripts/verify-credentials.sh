#!/usr/bin/env bash
# verify-credentials.sh
# Comprehensive credential verification for Azure Resume IaC project.
# Checks Azure SP validity/expiry, Cloudflare token, and GitHub access.
#
# Usage:
#   bash scripts/verify-credentials.sh [--dev | --prod | --all]
#
# Options:
#   --dev   Verify dev environment resources (default)
#   --prod  Verify production environment resources
#   --all   Verify both environments
#
# Prerequisites:
#   - Authenticated Azure CLI (run scripts/setup-codespace-auth.sh first)
#   - CF_API_TOKEN environment variable set
#   - GitHub CLI authenticated

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

ENV="${1:---dev}"

# Dev environment resource names
DEV_BACKEND_RG="cus1-resume-be-dev-v1-rg"
DEV_FRONTEND_RG="cus1-resume-fe-dev-v1-rg"
DEV_KEYVAULT="cus1-resume-dev-v1-kv"
DEV_FUNCTIONAPP="cus1-resumectr-dev-v1-fa"
DEV_COSMOSDB="cus1-resume-dev-v1-cmsdb"
DEV_DNS_RECORD="resumedevv1.ryanmcvey.me"

# Production environment resource names
PROD_BACKEND_RG="cus1-resume-be-prod-v1-rg"
PROD_FRONTEND_RG="cus1-resume-fe-prod-v1-rg"
PROD_KEYVAULT="cus1-resume-prod-v1-kv"
PROD_FUNCTIONAPP="cus1-resumectr-prod-v1-fa"
PROD_COSMOSDB="cus1-resume-prod-v1-cmsdb"
PROD_DNS_RECORD="resume.ryanmcvey.me"

DNS_ZONE="ryanmcvey.me"
SP_DISPLAY_NAME="github-azure-resume"

PASS=0
WARN=0
FAIL=0
INFO=0

pass()  { echo "  ✅ $1"; PASS=$((PASS + 1)); }
warn()  { echo "  ⚠️  $1"; WARN=$((WARN + 1)); }
fail()  { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
info()  { echo "  ℹ️  $1"; INFO=$((INFO + 1)); }
header() { echo ""; echo "=== $1 ==="; }

# =============================================================================
# Step 1: Azure CLI Authentication
# =============================================================================
header "Step 1: Azure CLI Authentication"

if ! command -v az &>/dev/null; then
  fail "Azure CLI not installed — run: scripts/setup-codespace-auth.sh"
else
  if az account show &>/dev/null; then
    ACCOUNT_NAME=$(az account show --query name -o tsv 2>/dev/null || echo "unknown")
    ACCOUNT_ID=$(az account show --query id -o tsv 2>/dev/null || echo "unknown")
    TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null || echo "unknown")
    pass "Azure CLI authenticated: $ACCOUNT_NAME ($ACCOUNT_ID)"
    info "Tenant: $TENANT_ID"
  else
    fail "Azure CLI not authenticated — run: scripts/setup-codespace-auth.sh"
  fi
fi

# =============================================================================
# Step 2: Azure Service Principal Credential Expiry
# =============================================================================
header "Step 2: Azure Service Principal — Credential Expiry"

if az account show &>/dev/null; then
  # Find the SP
  SP_APP_ID=$(az ad sp list --display-name "$SP_DISPLAY_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

  if [[ -z "$SP_APP_ID" || "$SP_APP_ID" == "None" ]]; then
    warn "Service Principal '$SP_DISPLAY_NAME' not found. Trying current logged-in SP..."
    SP_APP_ID=$(az account show --query user.name -o tsv 2>/dev/null || echo "")
  fi

  if [[ -n "$SP_APP_ID" && "$SP_APP_ID" != "None" ]]; then
    info "Service Principal App ID: $SP_APP_ID"

    # List credentials and check expiry
    CRED_JSON=$(az ad app credential list --id "$SP_APP_ID" -o json 2>/dev/null || echo "[]")
    CRED_COUNT=$(echo "$CRED_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [[ "$CRED_COUNT" -eq 0 ]]; then
      fail "No client secrets found for SP $SP_APP_ID"
    else
      info "Found $CRED_COUNT client secret(s)"

      # Check each credential's expiry
      echo "$CRED_JSON" | python3 -c "
import json, sys
from datetime import datetime, timezone

creds = json.load(sys.stdin)
now = datetime.now(timezone.utc)

for c in creds:
    end = c.get('endDateTime', '')
    display = c.get('displayName', c.get('keyId', 'unknown')[:8])
    if end:
        try:
            exp = datetime.fromisoformat(end.replace('Z', '+00:00'))
            days_left = (exp - now).days
            exp_str = exp.strftime('%Y-%m-%d')
            if days_left < 0:
                print(f'  ❌ Secret \"{display}\" EXPIRED on {exp_str} ({abs(days_left)} days ago)')
            elif days_left <= 30:
                print(f'  ⚠️  Secret \"{display}\" expires {exp_str} ({days_left} days — ROTATION RECOMMENDED)')
            elif days_left <= 90:
                print(f'  ℹ️  Secret \"{display}\" expires {exp_str} ({days_left} days remaining)')
            else:
                print(f'  ✅ Secret \"{display}\" expires {exp_str} ({days_left} days remaining)')
        except Exception as e:
            print(f'  ⚠️  Secret \"{display}\" — could not parse expiry: {end}')
    else:
        print(f'  ⚠️  Secret \"{display}\" — no expiry date set')
" 2>/dev/null || warn "Could not parse credential expiry dates"
    fi

    # Check role assignments
    echo ""
    info "Role assignments:"
    az role assignment list --assignee "$SP_APP_ID" \
      --query "[].{Role:roleDefinitionName, Scope:scope}" -o table 2>/dev/null \
      || warn "Could not list role assignments"
  else
    fail "Could not determine Service Principal App ID"
  fi
else
  warn "Skipping SP check — not authenticated to Azure"
fi

# =============================================================================
# Step 3: Cloudflare Token
# =============================================================================
header "Step 3: Cloudflare API Token"

if [[ -n "${CF_API_TOKEN:-}" ]]; then
  info "CF_API_TOKEN is set (${#CF_API_TOKEN} chars)"

  # Verify token
  CF_RESULT=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null || echo '{"success":false}')

  CF_SUCCESS=$(echo "$CF_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")
  CF_STATUS=$(echo "$CF_RESULT" | python3 -c "import json,sys; r=json.load(sys.stdin).get('result',{}); print(r.get('status','unknown'))" 2>/dev/null || echo "unknown")
  CF_EXPIRES=$(echo "$CF_RESULT" | python3 -c "import json,sys; r=json.load(sys.stdin).get('result',{}); print(r.get('expires_on','No expiry set'))" 2>/dev/null || echo "unknown")

  if [[ "$CF_SUCCESS" == "True" && "$CF_STATUS" == "active" ]]; then
    pass "Cloudflare token verified (status: active)"
    info "Token expires: $CF_EXPIRES"
  else
    fail "Cloudflare token invalid (status: $CF_STATUS)"
  fi

  # Check zone access
  ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DNS_ZONE" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null \
    | python3 -c "import json,sys; r=json.load(sys.stdin).get('result',[]); print(r[0]['id'] if r else '')" 2>/dev/null || echo "")

  if [[ -n "$ZONE_ID" ]]; then
    pass "Zone access verified: $DNS_ZONE (ID: $ZONE_ID)"
  else
    fail "Cannot access zone $DNS_ZONE — token may lack DNS permissions"
  fi
else
  fail "CF_API_TOKEN not set — cannot verify Cloudflare access"
  echo "       Set via: https://github.com/settings/codespaces"
fi

# =============================================================================
# Step 4: GitHub CLI
# =============================================================================
header "Step 4: GitHub CLI Authentication"

if ! command -v gh &>/dev/null; then
  fail "GitHub CLI not installed"
else
  if gh auth status &>/dev/null; then
    GH_USER=$(gh api user --jq .login 2>/dev/null || echo "unknown")
    pass "GitHub CLI authenticated as: $GH_USER"

    # Check repo access
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "unknown")
    if [[ "$REPO" != "unknown" ]]; then
      pass "Repository access: $REPO"
    else
      warn "Could not detect repository context"
    fi
  else
    fail "GitHub CLI not authenticated — run: gh auth login"
  fi
fi

# =============================================================================
# Step 5: Environment Resource Accessibility
# =============================================================================

check_env_resources() {
  local env_name="$1"
  local backend_rg="$2"
  local frontend_rg="$3"
  local keyvault="$4"
  local functionapp="$5"
  local cosmosdb="$6"
  local dns_record="$7"

  header "Step 5 ($env_name): Environment Resources"

  if ! az account show &>/dev/null; then
    warn "Skipping $env_name resource checks — not authenticated to Azure"
    return
  fi

  # Resource groups
  if az group show --name "$backend_rg" --query name -o tsv &>/dev/null; then
    pass "Backend RG exists: $backend_rg"
  else
    info "Backend RG not found: $backend_rg (will be created on first deploy)"
  fi

  if az group show --name "$frontend_rg" --query name -o tsv &>/dev/null; then
    pass "Frontend RG exists: $frontend_rg"
  else
    info "Frontend RG not found: $frontend_rg (will be created on first deploy)"
  fi

  # Key Vault
  if az keyvault show --name "$keyvault" --query name -o tsv &>/dev/null 2>&1; then
    pass "Key Vault accessible: $keyvault"
  else
    info "Key Vault not found: $keyvault (will be created on first deploy)"
  fi

  # Function App
  if az functionapp show --name "$functionapp" --resource-group "$backend_rg" --query name -o tsv &>/dev/null 2>&1; then
    FA_STATE=$(az functionapp show --name "$functionapp" --resource-group "$backend_rg" --query state -o tsv 2>/dev/null || echo "unknown")
    pass "Function App accessible: $functionapp (state: $FA_STATE)"
  else
    info "Function App not found: $functionapp (will be created on first deploy)"
  fi

  # Cosmos DB
  if az cosmosdb show --name "$cosmosdb" --resource-group "$backend_rg" --query name -o tsv &>/dev/null 2>&1; then
    pass "Cosmos DB accessible: $cosmosdb"
  else
    info "Cosmos DB not found: $cosmosdb (will be created on first deploy)"
  fi

  # DNS record (via Cloudflare)
  if [[ -n "${ZONE_ID:-}" ]]; then
    DNS_CHECK=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$dns_record" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" 2>/dev/null \
      | python3 -c "import json,sys; r=json.load(sys.stdin).get('result',[]); print(len(r))" 2>/dev/null || echo "0")

    if [[ "$DNS_CHECK" -gt 0 ]]; then
      pass "DNS record exists: $dns_record"
    else
      info "DNS record not found: $dns_record (will be created on first deploy)"
    fi
  fi
}

case "$ENV" in
  --dev)
    check_env_resources "Development" "$DEV_BACKEND_RG" "$DEV_FRONTEND_RG" "$DEV_KEYVAULT" "$DEV_FUNCTIONAPP" "$DEV_COSMOSDB" "$DEV_DNS_RECORD"
    ;;
  --prod)
    check_env_resources "Production" "$PROD_BACKEND_RG" "$PROD_FRONTEND_RG" "$PROD_KEYVAULT" "$PROD_FUNCTIONAPP" "$PROD_COSMOSDB" "$PROD_DNS_RECORD"
    ;;
  --all)
    check_env_resources "Development" "$DEV_BACKEND_RG" "$DEV_FRONTEND_RG" "$DEV_KEYVAULT" "$DEV_FUNCTIONAPP" "$DEV_COSMOSDB" "$DEV_DNS_RECORD"
    check_env_resources "Production" "$PROD_BACKEND_RG" "$PROD_FRONTEND_RG" "$PROD_KEYVAULT" "$PROD_FUNCTIONAPP" "$PROD_COSMOSDB" "$PROD_DNS_RECORD"
    ;;
  *)
    echo "Usage: $0 [--dev | --prod | --all]"
    exit 1
    ;;
esac

# =============================================================================
# Summary
# =============================================================================
header "Credential Verification Summary"
echo ""
echo "  ✅ Passed:   $PASS"
echo "  ⚠️  Warnings: $WARN"
echo "  ❌ Failed:   $FAIL"
echo "  ℹ️  Info:     $INFO"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "❌ RESULT: $FAIL check(s) failed. Resolve failures before proceeding with deployment."
  echo ""
  echo "Quick fix reference:"
  echo "  Azure SP:    az ad app credential reset --id <APP_ID> --years 1"
  echo "  Cloudflare:  Cloudflare Dashboard → My Profile → API Tokens → Create Token"
  echo "  Codespace:   https://github.com/settings/codespaces"
  echo "  Actions:     Repo → Settings → Environments → [env] → Environment secrets"
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo "⚠️  RESULT: All critical checks passed but $WARN warning(s) found. Review warnings above."
  exit 0
else
  echo "✅ RESULT: All credential checks passed. Ready for deployment."
  exit 0
fi
