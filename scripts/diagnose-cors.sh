#!/usr/bin/env bash
# diagnose-cors.sh
# Diagnoses CORS configuration, Function App state, and deployed frontend config
# for the Azure Resume IaC project.
#
# Usage:
#   bash scripts/diagnose-cors.sh [--dev | --prod | --all]
#
# Prerequisites:
#   - Authenticated Azure CLI (run scripts/setup-codespace-auth.sh first)

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

ENV="${1:---dev}"

# Dev environment
DEV_BACKEND_RG="cus1-resume-be-dev-v1-rg"
DEV_FUNCTIONAPP="cus1-resumectr-dev-v1-fa"
DEV_STORAGE_ACCOUNT="cus1resumedevv1sa"
DEV_EXPECTED_CORS_ORIGIN="https://resumedevv1.ryanmcvey.me"
DEV_EXPECTED_API_HOST="cus1-resumectr-dev-v1-fa.azurewebsites.net"

# Prod environment
PROD_BACKEND_RG="cus1-resume-be-prod-v1-rg"
PROD_FUNCTIONAPP="cus1-resumectr-prod-v1-fa"
PROD_STORAGE_ACCOUNT="cus1resumeprodv1sa"
PROD_EXPECTED_CORS_ORIGIN="https://resume.ryanmcvey.me"
PROD_EXPECTED_API_HOST="cus1-resumectr-prod-v1-fa.azurewebsites.net"

PASS=0
WARN=0
FAIL=0
INFO=0

pass()   { echo "  ✅ $1"; PASS=$((PASS + 1)); }
warn()   { echo "  ⚠️  $1"; WARN=$((WARN + 1)); }
fail()   { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }
info()   { echo "  ℹ️  $1"; INFO=$((INFO + 1)); }
header() { echo ""; echo "=== $1 ==="; }

# =============================================================================
# Prerequisite check
# =============================================================================

if ! command -v az &>/dev/null; then
  echo "Error: Azure CLI not installed. Run: scripts/setup-codespace-auth.sh" >&2
  exit 1
fi

if ! az account show &>/dev/null; then
  echo "Error: Not authenticated to Azure. Run: scripts/setup-codespace-auth.sh" >&2
  exit 1
fi

# =============================================================================
# Diagnostic function
# =============================================================================

diagnose_environment() {
  local env_name="$1"
  local backend_rg="$2"
  local functionapp="$3"
  local storage_account="$4"
  local expected_cors_origin="$5"
  local expected_api_host="$6"

  header "CORS Diagnostic: $env_name"

  # -------------------------------------------------------------------------
  # Check 1: Function App existence and state
  # -------------------------------------------------------------------------
  echo ""
  echo "--- Check 1: Function App State ---"

  if ! az functionapp show --name "$functionapp" --resource-group "$backend_rg" &>/dev/null; then
    fail "Function App '$functionapp' not found in resource group '$backend_rg'"
    echo "       The Function App may not have been deployed yet."
    echo "       Run the $env_name deployment workflow to create it."
    return
  fi

  FA_STATE=$(az functionapp show --name "$functionapp" --resource-group "$backend_rg" \
    --query state -o tsv 2>/dev/null || echo "unknown")
  FA_ENABLED=$(az functionapp show --name "$functionapp" --resource-group "$backend_rg" \
    --query enabled -o tsv 2>/dev/null || echo "unknown")
  FA_HOSTNAME=$(az functionapp show --name "$functionapp" --resource-group "$backend_rg" \
    --query defaultHostName -o tsv 2>/dev/null || echo "unknown")

  if [[ "$FA_STATE" == "Running" ]]; then
    pass "Function App state: $FA_STATE"
  else
    fail "Function App state: $FA_STATE (expected: Running)"
    echo "       Fix: az functionapp start --name $functionapp --resource-group $backend_rg"
  fi

  if [[ "$FA_ENABLED" == "true" ]]; then
    pass "Function App enabled: $FA_ENABLED"
  else
    fail "Function App enabled: $FA_ENABLED (expected: true)"
    echo "       A disabled Function App returns 403 'Site Disabled' for all requests."
  fi

  info "Default hostname: $FA_HOSTNAME"

  # -------------------------------------------------------------------------
  # Check 2: CORS allowed origins
  # -------------------------------------------------------------------------
  echo ""
  echo "--- Check 2: CORS Allowed Origins ---"

  CORS_JSON=$(az functionapp cors show --name "$functionapp" --resource-group "$backend_rg" 2>/dev/null || echo '{"allowedOrigins":[]}')
  CORS_ORIGINS=$(echo "$CORS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
origins = data.get('allowedOrigins', [])
for o in origins:
    print(o)
" 2>/dev/null || echo "")

  if [[ -z "$CORS_ORIGINS" ]]; then
    fail "No CORS origins configured on $functionapp"
    echo "       Fix: az functionapp cors add --name $functionapp --resource-group $backend_rg --allowed-origins \"$expected_cors_origin\""
  else
    info "Configured CORS origins:"
    echo "$CORS_ORIGINS" | while read -r origin; do
      echo "         - $origin"
    done

    if echo "$CORS_ORIGINS" | grep -qF "$expected_cors_origin"; then
      pass "Expected origin present: $expected_cors_origin"
    else
      fail "Expected origin MISSING: $expected_cors_origin"
      echo "       Fix: az functionapp cors add --name $functionapp --resource-group $backend_rg --allowed-origins \"$expected_cors_origin\""
    fi

    # Warn if wildcard is present
    if echo "$CORS_ORIGINS" | grep -q '^\*$'; then
      warn "Wildcard origin '*' is configured — this allows any origin (not recommended for production)"
    fi
  fi

  # -------------------------------------------------------------------------
  # Check 3: Deployed config.js content
  # -------------------------------------------------------------------------
  echo ""
  echo "--- Check 3: Deployed config.js ---"

  TEMP_CONFIG="/tmp/diagnose-cors-config-${env_name,,}.js"

  if az storage blob download \
    --account-name "$storage_account" \
    --container-name '$web' \
    --name config.js \
    --auth-mode login \
    --file "$TEMP_CONFIG" \
    --no-progress &>/dev/null; then

    info "Downloaded config.js from $storage_account:"
    echo "         $(tr -d '\n' < "$TEMP_CONFIG" | head -c 200)"

    # Check if it points to the correct API host
    if grep -q "$expected_api_host" "$TEMP_CONFIG" 2>/dev/null; then
      pass "config.js points to correct API host: $expected_api_host"
    elif grep -q "azurewebsites.net" "$TEMP_CONFIG" 2>/dev/null; then
      ACTUAL_HOST=$(grep -oP 'https://[a-z0-9-]+\.azurewebsites\.net' "$TEMP_CONFIG" 2>/dev/null | head -1)
      fail "config.js points to WRONG API host: ${ACTUAL_HOST:-unknown}"
      echo "       Expected: https://$expected_api_host"
      echo "       This means the $env_name site is calling the wrong Function App."
      echo "       Fix: Redeploy the frontend, or manually upload a corrected config.js."
    elif grep -q "defined_FUNCTION_API_BASE = ''" "$TEMP_CONFIG" 2>/dev/null; then
      warn "config.js has empty defined_FUNCTION_API_BASE (default/uncommitted state)"
      echo "       The CI/CD pipeline should overwrite this during deployment."
      echo "       Run the $env_name deployment workflow to generate the correct config.js."
    else
      warn "config.js does not contain a recognized API URL pattern"
      echo "       Content: $(< "$TEMP_CONFIG")"
    fi

    rm -f "$TEMP_CONFIG"
  else
    warn "Could not download config.js from $storage_account"
    echo "       The storage account may not exist, or auth may be insufficient."
    echo "       Try: az storage blob download --account-name $storage_account --container-name '\$web' --name config.js --auth-mode login --file /tmp/config.js"
  fi

  # -------------------------------------------------------------------------
  # Check 4: HTTP accessibility
  # -------------------------------------------------------------------------
  echo ""
  echo "--- Check 4: API HTTP Accessibility ---"

  API_URL="https://$expected_api_host/api/GetResumeCounter"
  HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$API_URL" 2>/dev/null || echo "000")

  case "$HTTP_CODE" in
    200)
      pass "API endpoint returned HTTP $HTTP_CODE (OK)"
      ;;
    401)
      info "API endpoint returned HTTP $HTTP_CODE (Unauthorized — function key may be required)"
      ;;
    403)
      fail "API endpoint returned HTTP $HTTP_CODE (Forbidden — Function App may be disabled)"
      echo "       Fix: az functionapp start --name $functionapp --resource-group $backend_rg"
      ;;
    404)
      warn "API endpoint returned HTTP $HTTP_CODE (Not Found — function may not be deployed)"
      ;;
    000)
      fail "API endpoint unreachable (connection failed or timed out)"
      echo "       URL: $API_URL"
      ;;
    *)
      warn "API endpoint returned HTTP $HTTP_CODE"
      ;;
  esac

  # -------------------------------------------------------------------------
  # Check 5: CORS preflight simulation
  # -------------------------------------------------------------------------
  echo ""
  echo "--- Check 5: CORS Preflight Simulation ---"

  CORS_HEADERS=$(curl -sS -D - -o /dev/null --max-time 10 \
    -H "Origin: $expected_cors_origin" \
    -H "Access-Control-Request-Method: GET" \
    -X OPTIONS \
    "$API_URL" 2>/dev/null || echo "")

  if echo "$CORS_HEADERS" | grep -qi "access-control-allow-origin"; then
    CORS_ALLOW=$(echo "$CORS_HEADERS" | grep -i "access-control-allow-origin" | tr -d '\r')
    pass "CORS preflight response includes: $CORS_ALLOW"
  elif [[ "$HTTP_CODE" == "403" ]]; then
    fail "CORS preflight failed — Function App is likely disabled (HTTP 403)"
  elif [[ -z "$CORS_HEADERS" ]]; then
    fail "CORS preflight got no response"
  else
    warn "CORS preflight response did not include Access-Control-Allow-Origin header"
    echo "       This may indicate CORS is not configured for $expected_cors_origin"
  fi
}

# =============================================================================
# Main
# =============================================================================

echo "========================================"
echo "  CORS & Endpoint Diagnostic"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "========================================"

case "$ENV" in
  --dev)
    diagnose_environment "Development" "$DEV_BACKEND_RG" "$DEV_FUNCTIONAPP" "$DEV_STORAGE_ACCOUNT" "$DEV_EXPECTED_CORS_ORIGIN" "$DEV_EXPECTED_API_HOST"
    ;;
  --prod)
    diagnose_environment "Production" "$PROD_BACKEND_RG" "$PROD_FUNCTIONAPP" "$PROD_STORAGE_ACCOUNT" "$PROD_EXPECTED_CORS_ORIGIN" "$PROD_EXPECTED_API_HOST"
    ;;
  --all)
    diagnose_environment "Development" "$DEV_BACKEND_RG" "$DEV_FUNCTIONAPP" "$DEV_STORAGE_ACCOUNT" "$DEV_EXPECTED_CORS_ORIGIN" "$DEV_EXPECTED_API_HOST"
    diagnose_environment "Production" "$PROD_BACKEND_RG" "$PROD_FUNCTIONAPP" "$PROD_STORAGE_ACCOUNT" "$PROD_EXPECTED_CORS_ORIGIN" "$PROD_EXPECTED_API_HOST"
    ;;
  *)
    echo "Usage: $0 [--dev | --prod | --all]"
    exit 1
    ;;
esac

# =============================================================================
# Summary
# =============================================================================
header "Diagnostic Summary"
echo ""
echo "  ✅ Passed:   $PASS"
echo "  ⚠️  Warnings: $WARN"
echo "  ❌ Failed:   $FAIL"
echo "  ℹ️  Info:     $INFO"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "❌ RESULT: $FAIL issue(s) found. Review the failures above and apply the suggested fixes."
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo "⚠️  RESULT: All critical checks passed but $WARN warning(s) found."
  exit 0
else
  echo "✅ RESULT: All CORS and endpoint checks passed."
  exit 0
fi
