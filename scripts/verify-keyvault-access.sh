#!/usr/bin/env bash
# Key Vault Access Verification Script
# Verifies all acceptance criteria for Phase 1 - Verify Key Vault access
#
# Resource names are sourced dynamically from the workflow YAML files
# (.github/workflows/dev-full-stack-cloudflare.yml or prod-full-stack-cloudflare.yml).
#
# Usage:
#   bash scripts/verify-keyvault-access.sh [--dev | --prod]
#
# Options:
#   --dev   Verify dev environment (default)
#   --prod  Verify production environment
set -euo pipefail

# Prerequisite checks
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command '$1' is not installed or not on PATH." >&2
    echo "Please install '$1' and try again." >&2
    exit 1
  fi
}

require_cmd az
require_cmd jq
require_cmd curl

# =============================================================================
# Dynamic stack configuration from workflow YAML
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_WORKFLOW="${SCRIPT_DIR}/../.github/workflows/dev-full-stack-cloudflare.yml"
PROD_WORKFLOW="${SCRIPT_DIR}/../.github/workflows/prod-full-stack-cloudflare.yml"

# Parse a top-level env var from a workflow YAML file.
parse_workflow_var() {
  local file="$1" var="$2"
  grep -E "^\s+${var}:" "$file" | head -1 | sed -E "s/^\s+${var}:\s*['\"]?([^'\"]+)['\"]?.*$/\1/"
}

ENV_FLAG="${1:---dev}"
case "$ENV_FLAG" in
  --dev)  WF_FILE="$DEV_WORKFLOW" ;;
  --prod) WF_FILE="$PROD_WORKFLOW" ;;
  *)
    echo "Usage: $0 [--dev | --prod]"
    exit 1
    ;;
esac

if [[ ! -f "$WF_FILE" ]]; then
  echo "Error: Workflow file not found: $WF_FILE" >&2
  exit 1
fi

_ver=$(parse_workflow_var "$WF_FILE" stackVersion)
_loc=$(parse_workflow_var "$WF_FILE" stackLocationCode)
_app=$(parse_workflow_var "$WF_FILE" AppName)
_app_be=$(parse_workflow_var "$WF_FILE" AppBackendName)
_env=$(parse_workflow_var "$WF_FILE" stackEnvironment)

KEY_VAULT_NAME="${_loc}-${_app}-${_env}-${_ver}-kv"
RESOURCE_GROUP="${_loc}-${_app}-be-${_env}-${_ver}-rg"
FUNCTION_APP_NAME="${_loc}-${_app_be}-${_env}-${_ver}-fa"
SECRET_NAME_PRIMARY="AzureResumeConnectionStringPrimary"
SECRET_NAME_SECONDARY="AzureResumeConnectionStringSecondary"

echo "============================================="
echo " Key Vault Access Verification"
echo " Key Vault: ${KEY_VAULT_NAME}"
echo " Resource Group: ${RESOURCE_GROUP}"
echo " Function App: ${FUNCTION_APP_NAME}"
echo "============================================="
echo ""

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo "✅ $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "❌ $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo "⚠️  $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

# --- AC1: Function App managed identity confirmed ---
echo "=== AC1: Verify Function App managed identity ==="
echo ""

echo ">> Checking Function App exists..."
FA_STATE=$(az functionapp show --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'state' -o tsv 2>/dev/null || echo "NOT_FOUND")

if [ "$FA_STATE" = "Running" ]; then
  pass "AC1: Function App exists and is Running"
elif [ "$FA_STATE" = "NOT_FOUND" ]; then
  fail "AC1: Function App not found: $FUNCTION_APP_NAME"
  echo "Cannot proceed without Function App. Exiting."
  exit 1
else
  warn "AC1: Function App exists but state is: $FA_STATE"
fi

echo ""
echo ">> Checking managed identity..."
IDENTITY_TYPE=$(az functionapp identity show --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'type' -o tsv 2>/dev/null || echo "NONE")

PRINCIPAL_ID=$(az functionapp identity show --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'principalId' -o tsv 2>/dev/null || echo "")

TENANT_ID=$(az functionapp identity show --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'tenantId' -o tsv 2>/dev/null || echo "")

echo "  Identity Type: $IDENTITY_TYPE"
echo "  Principal ID:  $PRINCIPAL_ID"
echo "  Tenant ID:     $TENANT_ID"

if [[ "$IDENTITY_TYPE" == *"SystemAssigned"* ]] && [ -n "$PRINCIPAL_ID" ]; then
  pass "AC1: System-Assigned Managed Identity is enabled (Principal: $PRINCIPAL_ID)"
else
  fail "AC1: System-Assigned Managed Identity not found or not enabled"
fi
echo ""

# --- AC2: Key Vault access policy grants GET permission ---
echo "=== AC2: Verify Key Vault access policy ==="
echo ""

echo ">> Checking Key Vault exists..."
KV_URI=$(az keyvault show --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'properties.vaultUri' -o tsv 2>/dev/null || echo "NOT_FOUND")

if [ "$KV_URI" = "NOT_FOUND" ]; then
  fail "AC2: Key Vault not found: $KEY_VAULT_NAME"
  echo "Cannot proceed without Key Vault. Exiting."
  exit 1
else
  pass "AC2: Key Vault exists at: $KV_URI"
fi

echo ""
echo ">> Checking access model (RBAC vs Access Policies)..."
RBAC_ENABLED=$(az keyvault show --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'properties.enableRbacAuthorization' -o tsv 2>/dev/null || echo "UNKNOWN")
echo "  RBAC Authorization: $RBAC_ENABLED"

if [ "$RBAC_ENABLED" = "false" ]; then
  pass "AC2: Access Policies model is active (RBAC disabled) — matches Bicep config"
elif [ "$RBAC_ENABLED" = "true" ]; then
  warn "AC2: RBAC authorization is enabled — Bicep expects access policies model"
else
  warn "AC2: Could not determine access model"
fi

echo ""
echo ">> Checking purge protection..."
PURGE_PROTECTION=$(az keyvault show --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'properties.enablePurgeProtection' -o tsv 2>/dev/null || echo "UNKNOWN")
echo "  Purge Protection: $PURGE_PROTECTION"

if [ "$PURGE_PROTECTION" = "true" ]; then
  pass "AC2: Purge protection is enabled — matches Bicep config"
else
  warn "AC2: Purge protection is not enabled (expected: true)"
fi

echo ""
echo ">> Checking access policy for Function App identity..."
if [ -n "$PRINCIPAL_ID" ]; then
  ACCESS_POLICY=$(az keyvault show --name "$KEY_VAULT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.accessPolicies[?objectId=='${PRINCIPAL_ID}']" -o json 2>/dev/null || echo "[]")

  POLICY_COUNT=$(echo "$ACCESS_POLICY" | jq 'length')

  if [ "$POLICY_COUNT" -gt 0 ]; then
    SECRET_PERMS=$(echo "$ACCESS_POLICY" | jq -r '.[0].permissions.secrets | join(", ")')
    echo "  Access policy found for principal: $PRINCIPAL_ID"
    echo "  Secret permissions: $SECRET_PERMS"

    HAS_GET=$(echo "$ACCESS_POLICY" | jq '.[0].permissions.secrets | index("get") != null')
    HAS_LIST=$(echo "$ACCESS_POLICY" | jq '.[0].permissions.secrets | index("list") != null')

    if [ "$HAS_GET" = "true" ]; then
      pass "AC2: Access policy grants 'get' permission on secrets"
    else
      fail "AC2: Access policy missing 'get' permission on secrets"
    fi

    if [ "$HAS_LIST" = "true" ]; then
      pass "AC2: Access policy grants 'list' permission on secrets"
    else
      warn "AC2: Access policy missing 'list' permission on secrets (optional but expected)"
    fi
  else
    fail "AC2: No access policy found for Function App identity ($PRINCIPAL_ID)"
  fi
else
  fail "AC2: Cannot check access policy — no Principal ID available"
fi
echo ""

# --- AC3: Key Vault reference syntax in app settings ---
echo "=== AC3: Verify Key Vault reference syntax ==="
echo ""

EXPECTED_REF_PRIMARY="@Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/${SECRET_NAME_PRIMARY})"
EXPECTED_REF_SECONDARY="@Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/${SECRET_NAME_SECONDARY})"

echo ">> Checking app settings for Key Vault references..."
APP_SETTINGS=$(az functionapp config appsettings list --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" -o json 2>/dev/null || echo "[]")

ACTUAL_REF_PRIMARY=$(echo "$APP_SETTINGS" | jq -r ".[] | select(.name==\"$SECRET_NAME_PRIMARY\") | .value")
ACTUAL_REF_SECONDARY=$(echo "$APP_SETTINGS" | jq -r ".[] | select(.name==\"$SECRET_NAME_SECONDARY\") | .value")

echo "  Primary setting:   $ACTUAL_REF_PRIMARY"
echo "  Secondary setting: $ACTUAL_REF_SECONDARY"
echo ""
echo "  Expected primary:   $EXPECTED_REF_PRIMARY"
echo "  Expected secondary: $EXPECTED_REF_SECONDARY"
echo ""

if [ "$ACTUAL_REF_PRIMARY" = "$EXPECTED_REF_PRIMARY" ]; then
  pass "AC3: Primary Key Vault reference syntax is correct"
else
  if [[ "$ACTUAL_REF_PRIMARY" == @Microsoft.KeyVault* ]]; then
    warn "AC3: Primary reference uses Key Vault syntax but URI differs from expected"
    echo "     Actual:   $ACTUAL_REF_PRIMARY"
    echo "     Expected: $EXPECTED_REF_PRIMARY"
  else
    fail "AC3: Primary setting does not use Key Vault reference syntax"
  fi
fi

if [ "$ACTUAL_REF_SECONDARY" = "$EXPECTED_REF_SECONDARY" ]; then
  pass "AC3: Secondary Key Vault reference syntax is correct"
else
  if [[ "$ACTUAL_REF_SECONDARY" == @Microsoft.KeyVault* ]]; then
    warn "AC3: Secondary reference uses Key Vault syntax but URI differs from expected"
    echo "     Actual:   $ACTUAL_REF_SECONDARY"
    echo "     Expected: $EXPECTED_REF_SECONDARY"
  else
    fail "AC3: Secondary setting does not use Key Vault reference syntax"
  fi
fi
echo ""

# --- AC4: Secret is retrievable by the Function App identity ---
echo "=== AC4: Verify secrets exist and are retrievable ==="
echo ""

echo ">> Checking secrets in Key Vault..."
SECRET_LIST=$(az keyvault secret list --vault-name "$KEY_VAULT_NAME" \
  --query "[].{Name:name, Enabled:attributes.enabled}" -o json 2>&1 || true)

if echo "$SECRET_LIST" | grep -qi "Forbidden\|AccessDenied"; then
  echo "  NOTE: CLI user does not have Key Vault data plane permissions."
  echo "  Falling back to ARM config references API to verify secret resolution."
  SUBSCRIPTION_ID=${SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}
  KV_CONFIG_REFS=$(az rest --method GET \
    --uri "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}/config/configreferences/appsettings?api-version=2022-03-01" \
    -o json 2>/dev/null || echo '{"value":[]}')

  PRIMARY_STATUS=$(echo "$KV_CONFIG_REFS" | jq -r ".value[]? | select(.name==\"$SECRET_NAME_PRIMARY\") | .properties.status" 2>/dev/null || echo "UNKNOWN")
  SECONDARY_STATUS=$(echo "$KV_CONFIG_REFS" | jq -r ".value[]? | select(.name==\"$SECRET_NAME_SECONDARY\") | .properties.status" 2>/dev/null || echo "UNKNOWN")

  echo "  Primary config ref status:   $PRIMARY_STATUS"
  echo "  Secondary config ref status: $SECONDARY_STATUS"

  if [ "$PRIMARY_STATUS" = "Resolved" ]; then
    pass "AC4: Secret '$SECRET_NAME_PRIMARY' is resolvable by Function App (verified via ARM config references)"
  else
    fail "AC4: Secret '$SECRET_NAME_PRIMARY' config reference status: $PRIMARY_STATUS"
  fi

  if [ "$SECONDARY_STATUS" = "Resolved" ]; then
    pass "AC4: Secret '$SECRET_NAME_SECONDARY' is resolvable by Function App (verified via ARM config references)"
  else
    fail "AC4: Secret '$SECRET_NAME_SECONDARY' config reference status: $SECONDARY_STATUS"
  fi

  warn "AC4: Cannot verify secret value format — CLI user lacks Key Vault data plane access"
else
  echo "$SECRET_LIST" | jq . 2>/dev/null || echo "$SECRET_LIST"

  echo ""
  echo ">> Checking primary secret..."
  PRIMARY_ENABLED=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" \
    --name "$SECRET_NAME_PRIMARY" \
    --query 'attributes.enabled' -o tsv 2>/dev/null || echo "NOT_FOUND")

  if [ "$PRIMARY_ENABLED" = "true" ]; then
    pass "AC4: Secret '$SECRET_NAME_PRIMARY' exists and is enabled"
  elif [ "$PRIMARY_ENABLED" = "NOT_FOUND" ]; then
    fail "AC4: Secret '$SECRET_NAME_PRIMARY' not found in Key Vault"
  else
    warn "AC4: Secret '$SECRET_NAME_PRIMARY' exists but is disabled"
  fi

  echo ""
  echo ">> Checking secondary secret..."
  SECONDARY_ENABLED=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" \
    --name "$SECRET_NAME_SECONDARY" \
    --query 'attributes.enabled' -o tsv 2>/dev/null || echo "NOT_FOUND")

  if [ "$SECONDARY_ENABLED" = "true" ]; then
    pass "AC4: Secret '$SECRET_NAME_SECONDARY' exists and is enabled"
  elif [ "$SECONDARY_ENABLED" = "NOT_FOUND" ]; then
    fail "AC4: Secret '$SECRET_NAME_SECONDARY' not found in Key Vault"
  else
    warn "AC4: Secret '$SECRET_NAME_SECONDARY' exists but is disabled"
  fi

  echo ""
  echo ">> Validating secret value format (primary — first 50 chars)..."
  SECRET_VALUE_PREVIEW=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" \
    --name "$SECRET_NAME_PRIMARY" \
    --query 'value' -o tsv 2>/dev/null | head -c 50 || echo "")
  if [[ "$SECRET_VALUE_PREVIEW" == AccountEndpoint=* ]]; then
    pass "AC4: Primary secret contains a valid Cosmos DB connection string"
  elif [ -n "$SECRET_VALUE_PREVIEW" ]; then
    warn "AC4: Primary secret has a value but may not be a Cosmos DB connection string"
    echo "     Preview: ${SECRET_VALUE_PREVIEW}..."
  else
    fail "AC4: Could not retrieve primary secret value"
  fi
fi

echo ""
echo ">> Testing end-to-end Function App connectivity..."
FUNCTION_KEY=$(az functionapp function keys list \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --function-name GetResumeCounter \
  --query default -o tsv 2>/dev/null || echo "")

if [ -n "$FUNCTION_KEY" ]; then
  FUNCTION_HOST=$(az functionapp show --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query defaultHostName -o tsv)

  echo "  Calling: https://${FUNCTION_HOST}/api/GetResumeCounter"
  RESPONSE=$(curl -s -w "\n%{http_code}" "https://${FUNCTION_HOST}/api/GetResumeCounter?code=${FUNCTION_KEY}" 2>/dev/null || echo "")
  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  echo "  HTTP Status: $HTTP_CODE"
  echo "  Response: $BODY"

  if [ "$HTTP_CODE" = "200" ]; then
    HAS_ID=$(echo "$BODY" | jq -r '.id // empty' 2>/dev/null || echo "")
    HAS_COUNT=$(echo "$BODY" | jq -r '.count // empty' 2>/dev/null || echo "")
    if [ -n "$HAS_ID" ] && [ -n "$HAS_COUNT" ]; then
      pass "AC4: Function App successfully reads from Cosmos DB via Key Vault referenced connection string"
    else
      warn "AC4: Function App returned 200 but response format unexpected: $BODY"
    fi
  else
    fail "AC4: Function App returned HTTP $HTTP_CODE (expected 200)"
  fi
else
  warn "AC4: Could not retrieve function key — skipping end-to-end test"
fi
echo ""

# --- AC5: No access denied errors in Function App logs ---
echo "=== AC5: Check for access denied errors ==="
echo ""

echo ">> Checking Key Vault config reference status..."
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
CONFIG_REFS=$(az rest --method GET \
  --uri "https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}/config/configreferences/appsettings?api-version=2022-03-01" \
  -o json 2>/dev/null || echo '{"value":[]}')

UNRESOLVED=$(echo "$CONFIG_REFS" | jq '[.value[]? | select(.properties.status != null and .properties.status != "Resolved")] | length')

if [ "$UNRESOLVED" = "0" ]; then
  pass "AC5: All Key Vault config references are in Resolved status"
else
  fail "AC5: $UNRESOLVED Key Vault config reference(s) are not resolved"
  echo "$CONFIG_REFS" | jq '.value[]? | select(.properties.status != "Resolved") | {name: .name, status: .properties.status, detail: .properties.details}'
fi

echo ""

# --- Summary ---
echo "============================================="
echo " Verification Summary"
echo "============================================="
echo ""
echo "  ✅ Passed:   $PASS_COUNT"
echo "  ❌ Failed:   $FAIL_COUNT"
echo "  ⚠️  Warnings: $WARN_COUNT"
echo ""
echo "Key Vault Configuration (from .iac/modules/functionapp/functionapp.bicep):"
echo "  Key Vault:          ${KEY_VAULT_NAME}"
echo "  SKU:                standard"
echo "  Access Model:       Access Policies (RBAC disabled)"
echo "  Purge Protection:   true"
echo "  Identity Type:      SystemAssigned"
echo "  Secret Permissions: get, list"
echo ""
echo "Key Vault References (from Bicep app settings):"
echo "  AzureResumeConnectionStringPrimary:   @Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/${SECRET_NAME_PRIMARY})"
echo "  AzureResumeConnectionStringSecondary: @Microsoft.KeyVault(SecretUri=https://${KEY_VAULT_NAME}.vault.azure.net/secrets/${SECRET_NAME_SECONDARY})"
echo ""
echo "Function App binding (from backend/api/GetResumeCounter.cs):"
echo "  Connection setting: AzureResumeConnectionStringPrimary"
echo "  CosmosDBInput:      [CosmosDBInput] with Id=\"1\", PartitionKey=\"1\""
echo "  CosmosDBOutput:     [CosmosDBOutput] to same database/container"
echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "🎉 All checks passed! Key Vault access is correctly configured."
else
  echo "⚠️  Some checks failed. Review the output above and consult"
  echo "   docs/KEY_VAULT_ACCESS_VERIFICATION.md for remediation steps."
fi
echo ""
echo "============================================="
