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
# Prerequisite checks
# =============================================================================

REQUIRED_CMDS=("az" "gh" "curl" "jq")

for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Required command '$cmd' is not installed or not in PATH." >&2
    echo "Please install '$cmd' and re-run scripts/verify-credentials.sh." >&2
    exit 1
  fi
done

# =============================================================================
# Configuration
# =============================================================================

ENV="${1:---dev}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_WORKFLOW="${SCRIPT_DIR}/../.github/workflows/dev-full-stack-cloudflare.yml"
PROD_WORKFLOW="${SCRIPT_DIR}/../.github/workflows/prod-full-stack-cloudflare.yml"

# Parse a top-level env var from a workflow YAML file.
# Usage: parse_workflow_var <file> <varName>
parse_workflow_var() {
  local file="$1" var="$2"
  grep -E "^\s+${var}:" "$file" | head -1 | sed -E "s/^\s+${var}:\s*['\"]?([^'\"]+)['\"]?.*$/\1/"
}

# Load stack config from a workflow file and set resource name variables.
# Sets: BACKEND_RG, FRONTEND_RG, KEYVAULT, FUNCTIONAPP, COSMOSDB, DNS_RECORD, DNS_ZONE
load_stack_config() {
  local wf_file="$1"
  if [[ ! -f "$wf_file" ]]; then
    echo "Error: Workflow file not found: $wf_file" >&2
    exit 1
  fi
  local ver loc app app_be prefix zone
  ver=$(parse_workflow_var "$wf_file" stackVersion)
  loc=$(parse_workflow_var "$wf_file" stackLocationCode)
  app=$(parse_workflow_var "$wf_file" AppName)
  app_be=$(parse_workflow_var "$wf_file" AppBackendName)
  env_tier=$(parse_workflow_var "$wf_file" stackEnvironment)
  prefix=$(parse_workflow_var "$wf_file" customDomainPrefix)
  zone=$(parse_workflow_var "$wf_file" dnsZone)

  BACKEND_RG="${loc}-${app}-be-${env_tier}-${ver}-rg"
  FRONTEND_RG="${loc}-${app}-fe-${env_tier}-${ver}-rg"
  KEYVAULT="${loc}-${app}-${env_tier}-${ver}-kv"
  FUNCTIONAPP="${loc}-${app_be}-${env_tier}-${ver}-fa"
  COSMOSDB="${loc}-${app}-${env_tier}-${ver}-cmsdb"
  DNS_RECORD="${prefix}.${zone}"
  DNS_ZONE="${zone}"
}

SP_DISPLAY_NAME="azureresumeiac-github-sp"
# DNS zone is the same for all environments — load it early for Cloudflare checks
DNS_ZONE=$(parse_workflow_var "$DEV_WORKFLOW" dnsZone)

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
    warn "Service Principal '$SP_DISPLAY_NAME' not found by display name '$SP_DISPLAY_NAME'."
    LOGIN_TYPE=$(az account show --query user.type -o tsv 2>/dev/null || echo "unknown")
    if [[ "$LOGIN_TYPE" == "servicePrincipal" ]]; then
      info "Trying current logged-in service principal as fallback..."
      SP_APP_ID=$(az account show --query user.name -o tsv 2>/dev/null || echo "")
    else
      warn "Current Azure identity is a user account (type: $LOGIN_TYPE); cannot infer Service Principal App ID automatically."
      warn "Provide an explicit App ID (for example via AZURE_SP_APP_ID) or log in as the target service principal to enable SP expiry checks."
      SP_APP_ID=""
    fi
  fi

  if [[ -n "$SP_APP_ID" && "$SP_APP_ID" != "None" ]]; then
    info "Service Principal App ID: $SP_APP_ID"

    # List credentials and check expiry
    CRED_JSON=$(az ad app credential list --id "$SP_APP_ID" -o json 2>/dev/null || echo "[]")
    CRED_COUNT=$(echo "$CRED_JSON" | jq 'length' 2>/dev/null || echo "0")

    if [[ "$CRED_COUNT" -eq 0 ]]; then
      # When logged in as SP, the SP may lack Application.Read.All to list its own credentials
      LOGIN_TYPE=$(az account show --query user.type -o tsv 2>/dev/null || echo "unknown")
      if [[ "$LOGIN_TYPE" == "servicePrincipal" ]]; then
        warn "Cannot list SP credentials when logged in as SP (requires Application.Read.All). SP login itself confirms the credential is valid."
      else
        fail "No client secrets found for SP $SP_APP_ID"
      fi
    else
      info "Found $CRED_COUNT client secret(s)"

      # Check each credential's expiry using jq + date
      NOW_EPOCH=$(date +%s)
      while IFS=$'\t' read -r display end; do
        if [[ -z "$end" ]]; then
          warn "Secret \"$display\" — no expiry date set"
          continue
        fi
        EXP_EPOCH=$(date -d "$end" +%s 2>/dev/null || echo "0")
        DAYS_LEFT=$(( (EXP_EPOCH - NOW_EPOCH) / 86400 ))
        EXP_STR=$(date -d "$end" +%Y-%m-%d 2>/dev/null || echo "$end")
        if [[ "$DAYS_LEFT" -lt 0 ]]; then
          fail "Secret \"$display\" EXPIRED on $EXP_STR ($(( -DAYS_LEFT )) days ago)"
        elif [[ "$DAYS_LEFT" -le 30 ]]; then
          warn "Secret \"$display\" expires $EXP_STR ($DAYS_LEFT days — ROTATION RECOMMENDED)"
        elif [[ "$DAYS_LEFT" -le 90 ]]; then
          info "Secret \"$display\" expires $EXP_STR ($DAYS_LEFT days remaining)"
        else
          pass "Secret \"$display\" expires $EXP_STR ($DAYS_LEFT days remaining)"
        fi
      done < <(echo "$CRED_JSON" | jq -r '.[] | [.displayName // .keyId, .endDateTime // ""] | @tsv')
    fi

    # Check role assignments
    echo ""
    info "Role assignments:"
    az role assignment list --assignee "$SP_APP_ID" \
      --query "[].{Role:roleDefinitionName, Scope:scope}" -o table 2>/dev/null \
      || warn "Could not list role assignments"
  else
    warn "Skipping Service Principal credential expiry check because App ID could not be determined."
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

  CF_SUCCESS=$(echo "$CF_RESULT" | jq -r '.success // false' 2>/dev/null || echo "false")
  CF_STATUS=$(echo "$CF_RESULT" | jq -r '.result.status // "unknown"' 2>/dev/null || echo "unknown")
  CF_EXPIRES=$(echo "$CF_RESULT" | jq -r '.result.expires_on // "No expiry set"' 2>/dev/null || echo "unknown")

  if [[ "$CF_SUCCESS" == "true" && "$CF_STATUS" == "active" ]]; then
    pass "Cloudflare token verified (status: active)"
    info "Token expires: $CF_EXPIRES"
  else
    fail "Cloudflare token invalid (status: $CF_STATUS)"
  fi

  # Check zone access
  ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DNS_ZONE" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" 2>/dev/null \
    | jq -r '.result[0].id // empty' 2>/dev/null || echo "")

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
    REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#' || echo "unknown")
    if [[ "$REPO" != "unknown" && -n "$REPO" ]]; then
      pass "Repository detected from git origin: $REPO"
    else
      warn "Could not detect repository from git origin remote"
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
  if az keyvault show --name "$keyvault" --query name -o tsv &>/dev/null; then
    pass "Key Vault accessible: $keyvault"
  else
    info "Key Vault not found: $keyvault (will be created on first deploy)"
  fi

  # Function App
  if az functionapp show --name "$functionapp" --resource-group "$backend_rg" --query name -o tsv &>/dev/null; then
    FA_STATE=$(az functionapp show --name "$functionapp" --resource-group "$backend_rg" --query state -o tsv 2>/dev/null || echo "unknown")
    pass "Function App accessible: $functionapp (state: $FA_STATE)"
  else
    info "Function App not found: $functionapp (will be created on first deploy)"
  fi

  # Cosmos DB
  if az cosmosdb show --name "$cosmosdb" --resource-group "$backend_rg" --query name -o tsv &>/dev/null; then
    pass "Cosmos DB accessible: $cosmosdb"
  else
    info "Cosmos DB not found: $cosmosdb (will be created on first deploy)"
  fi

  # DNS record (via Cloudflare)
  if [[ -n "${ZONE_ID:-}" ]]; then
    DNS_CHECK=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$dns_record" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" 2>/dev/null \
      | jq '.result | length' 2>/dev/null || echo "0")

    if [[ "$DNS_CHECK" -gt 0 ]]; then
      pass "DNS record exists: $dns_record"
    else
      info "DNS record not found: $dns_record (will be created on first deploy)"
    fi
  fi
}

case "$ENV" in
  --dev)
    load_stack_config "$DEV_WORKFLOW"
    check_env_resources "Development" "$BACKEND_RG" "$FRONTEND_RG" "$KEYVAULT" "$FUNCTIONAPP" "$COSMOSDB" "$DNS_RECORD"
    ;;
  --prod)
    load_stack_config "$PROD_WORKFLOW"
    check_env_resources "Production" "$BACKEND_RG" "$FRONTEND_RG" "$KEYVAULT" "$FUNCTIONAPP" "$COSMOSDB" "$DNS_RECORD"
    ;;
  --all)
    load_stack_config "$DEV_WORKFLOW"
    check_env_resources "Development" "$BACKEND_RG" "$FRONTEND_RG" "$KEYVAULT" "$FUNCTIONAPP" "$COSMOSDB" "$DNS_RECORD"
    load_stack_config "$PROD_WORKFLOW"
    check_env_resources "Production" "$BACKEND_RG" "$FRONTEND_RG" "$KEYVAULT" "$FUNCTIONAPP" "$COSMOSDB" "$DNS_RECORD"
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
