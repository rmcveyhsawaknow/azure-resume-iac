# Key Vault Access Verification Commands

This document provides Azure CLI commands to verify the Function App's managed identity has access to the Key Vault secrets it needs (e.g., Cosmos DB connection string). Run these commands from a GitHub Codespace or local terminal with authenticated Azure CLI access.

> **Related Issue:** [Phase 1] Verify Key Vault access
> **Dependencies:** Task 0.5 (Assess Key Vault)

## Prerequisites

```bash
# Azure CLI login
az login
az account set --subscription "<subscription-name-or-id>"

# Verify correct subscription
az account show --query '{Name:name, Id:id, TenantId:tenantId}' -o table
```

## Environment Reference

| Property | Production | Development |
|---|---|---|
| **Key Vault Name** | `cus1-resume-prod-v1-kv` | `cus1-bevis-dev-v66-kv` |
| **Resource Group** | `cus1-resume-be-prod-v1-rg` | `cus1-bevis-be-dev-v66-rg` |
| **Function App Name** | `cus1-resumectr-prod-v1-fa` | `cus1-resumectr-dev-v66-fa` |
| **Key Vault SKU** | `standard` | `standard` |
| **RBAC Authorization** | `false` (uses access policies) | `false` (uses access policies) |
| **Purge Protection** | `true` | `true` |
| **Managed Identity Type** | `SystemAssigned` | `SystemAssigned` |
| **Secret Name (Primary)** | `AzureResumeConnectionStringPrimary` | `AzureResumeConnectionStringPrimary` |
| **Secret Name (Secondary)** | `AzureResumeConnectionStringSecondary` | `AzureResumeConnectionStringSecondary` |
| **Access Policy Permissions** | `get`, `list` (secrets) | `get`, `list` (secrets) |

Set these variables for convenience (use production or development values).
Values are sourced from `.iac/modules/functionapp/functionapp.bicep` and `.github/workflows/`:

```bash
# --- Production ---
KEY_VAULT_NAME="cus1-resume-prod-v1-kv"
RESOURCE_GROUP="cus1-resume-be-prod-v1-rg"
FUNCTION_APP_NAME="cus1-resumectr-prod-v1-fa"

# --- Development (uncomment to use) ---
# KEY_VAULT_NAME="cus1-bevis-dev-v66-kv"
# RESOURCE_GROUP="cus1-bevis-be-dev-v66-rg"
# FUNCTION_APP_NAME="cus1-resumectr-dev-v66-fa"

# Common to both environments
SECRET_NAME_PRIMARY="AzureResumeConnectionStringPrimary"
SECRET_NAME_SECONDARY="AzureResumeConnectionStringSecondary"
```

---

## Acceptance Criteria Verification

### ✅ AC1: Function App managed identity confirmed (system or user-assigned)

Verify the Function App has a System-Assigned Managed Identity enabled (as defined in `.iac/modules/functionapp/functionapp.bicep` lines 152–154).

```bash
# 1a. Verify Function App exists and is accessible
az functionapp show --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query '{Name:name, State:state, DefaultHostName:defaultHostName, Kind:kind}' -o json

# 1b. Verify System-Assigned Managed Identity is enabled
az functionapp identity show --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query '{Type:type, PrincipalId:principalId, TenantId:tenantId}' -o json

# 1c. Capture the principal ID for later use
PRINCIPAL_ID=$(az functionapp identity show --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'principalId' -o tsv)
echo "Function App Managed Identity Principal ID: $PRINCIPAL_ID"
```

**Expected Result:** The Function App has `type: "SystemAssigned"` with a non-empty `principalId` and `tenantId`.

**Validation Checklist:**
- [ ] Function App exists and is in `Running` state
- [ ] Managed identity type is `SystemAssigned`
- [ ] `principalId` is not null/empty
- [ ] `tenantId` matches the subscription tenant

---

### ✅ AC2: Key Vault access policy or RBAC role grants GET permission to the identity

Verify the Key Vault has an access policy granting `get` and `list` secret permissions to the Function App's managed identity (as defined in `.iac/modules/functionapp/functionapp.bicep` lines 51–72).

```bash
# 2a. Verify Key Vault exists and check its access model
az keyvault show --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query '{Name:name, VaultUri:properties.vaultUri, Sku:properties.sku.name, EnableRbacAuthorization:properties.enableRbacAuthorization, EnablePurgeProtection:properties.enablePurgeProtection, EnableSoftDelete:properties.enableSoftDelete}' -o json

# 2b. List all access policies on the Key Vault
az keyvault show --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'properties.accessPolicies[].{ObjectId:objectId, TenantId:tenantId, SecretPermissions:permissions.secrets, KeyPermissions:permissions.keys, CertificatePermissions:permissions.certificates}' -o json

# 2c. Check if the Function App's managed identity has an access policy
#     (requires PRINCIPAL_ID from AC1 step 1c)
az keyvault show --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.accessPolicies[?objectId=='${PRINCIPAL_ID}'].{ObjectId:objectId, SecretPermissions:permissions.secrets}" -o json

# 2d. Verify RBAC authorization is disabled (access policies model is used)
RBAC_ENABLED=$(az keyvault show --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query 'properties.enableRbacAuthorization' -o tsv)
echo "RBAC Authorization Enabled: $RBAC_ENABLED"
```

**Expected Result:**
- `enableRbacAuthorization` is `false` (access policies model)
- An access policy exists for the Function App's `principalId`
- The access policy grants `get` and `list` permissions on secrets

**Validation Checklist:**
- [ ] Key Vault exists and is accessible
- [ ] `enableRbacAuthorization` is `false` (Bicep sets this in `functionapp.bicep` line 48)
- [ ] Access policy exists for Function App's managed identity `principalId`
- [ ] Access policy grants `get` permission on secrets
- [ ] Access policy grants `list` permission on secrets
- [ ] `enablePurgeProtection` is `true` (Bicep sets this in `functionapp.bicep` line 47)

---

### ✅ AC3: Key Vault reference syntax in app settings is correct

Verify the Function App app settings use the correct `@Microsoft.KeyVault(SecretUri=...)` reference syntax (as defined in `.iac/modules/functionapp/functionapp.bicep` lines 189–190).

The expected Key Vault reference format:

```
@Microsoft.KeyVault(SecretUri=https://<vault-name>.vault.azure.net/secrets/<secret-name>)
```

```bash
# 3a. List all Function App app settings and check Key Vault references
az functionapp config appsettings list --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?name=='AzureResumeConnectionStringPrimary' || name=='AzureResumeConnectionStringSecondary'].{Name:name, Value:value}" -o json

# 3b. Verify the Key Vault reference format for the primary connection string
az functionapp config appsettings list --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?name=='AzureResumeConnectionStringPrimary'].value" -o tsv

# Expected: @Microsoft.KeyVault(SecretUri=https://cus1-resume-prod-v1-kv.vault.azure.net/secrets/AzureResumeConnectionStringPrimary)

# 3c. Verify the Key Vault reference format for the secondary connection string
az functionapp config appsettings list --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?name=='AzureResumeConnectionStringSecondary'].value" -o tsv

# Expected: @Microsoft.KeyVault(SecretUri=https://cus1-resume-prod-v1-kv.vault.azure.net/secrets/AzureResumeConnectionStringSecondary)

# 3d. Verify the Key Vault reference resolution status
#     A resolved reference will show the secret value, not the @Microsoft.KeyVault(...) syntax
#     Use the REST API to check the reference status
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}/config/configreferences/appsettings?api-version=2022-03-01" \
  --query "properties.{AzureResumeConnectionStringPrimary:AzureResumeConnectionStringPrimary, AzureResumeConnectionStringSecondary:AzureResumeConnectionStringSecondary}" -o json
```

**Expected Key Vault References (from Bicep):**

| App Setting | Expected Value |
|---|---|
| `AzureResumeConnectionStringPrimary` | `@Microsoft.KeyVault(SecretUri=https://{KEY_VAULT_NAME}.vault.azure.net/secrets/AzureResumeConnectionStringPrimary)` |
| `AzureResumeConnectionStringSecondary` | `@Microsoft.KeyVault(SecretUri=https://{KEY_VAULT_NAME}.vault.azure.net/secrets/AzureResumeConnectionStringSecondary)` |

**Validation Checklist:**
- [ ] `AzureResumeConnectionStringPrimary` app setting uses `@Microsoft.KeyVault(SecretUri=...)` syntax
- [ ] `AzureResumeConnectionStringSecondary` app setting uses `@Microsoft.KeyVault(SecretUri=...)` syntax
- [ ] Secret URI hostname matches the Key Vault name (`{KEY_VAULT_NAME}.vault.azure.net`)
- [ ] Secret name in URI matches `AzureResumeConnectionStringPrimary` / `AzureResumeConnectionStringSecondary`
- [ ] Key Vault references resolve successfully (not stuck in pending/error state)

---

### ✅ AC4: Secret is retrievable by the Function App identity

Verify the secrets exist in the Key Vault and contain valid Cosmos DB connection strings. Then test end-to-end by calling the Function App endpoint.

```bash
# 4a. List secrets in the Key Vault (names only, not values)
az keyvault secret list --vault-name "$KEY_VAULT_NAME" \
  --query "[].{Name:name, Enabled:attributes.enabled, ContentType:contentType, Created:attributes.created, Updated:attributes.updated}" -o json

# 4b. Verify the primary secret exists
az keyvault secret show --vault-name "$KEY_VAULT_NAME" \
  --name "$SECRET_NAME_PRIMARY" \
  --query '{Name:name, Enabled:attributes.enabled, Created:attributes.created, Updated:attributes.updated}' -o json

# 4c. Verify the secondary secret exists
az keyvault secret show --vault-name "$KEY_VAULT_NAME" \
  --name "$SECRET_NAME_SECONDARY" \
  --query '{Name:name, Enabled:attributes.enabled, Created:attributes.created, Updated:attributes.updated}' -o json

# 4d. Verify secret values are valid Cosmos DB connection strings (redacted check)
#     WARNING: This displays the actual secret value — use with caution
az keyvault secret show --vault-name "$KEY_VAULT_NAME" \
  --name "$SECRET_NAME_PRIMARY" \
  --query 'value' -o tsv | head -c 50
echo "... (truncated)"

# 4e. Test the Function App endpoint to confirm end-to-end connectivity
#     This verifies: Function App → Key Vault reference → Cosmos DB connection string → Cosmos DB
FUNCTION_KEY=$(az functionapp function keys list \
  --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --function-name GetResumeCounter \
  --query default -o tsv)

FUNCTION_HOST=$(az functionapp show --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query defaultHostName -o tsv)

# WARNING: This will increment the counter by 1
curl -s "https://${FUNCTION_HOST}/api/GetResumeCounter?code=${FUNCTION_KEY}" | jq .
# Expected response: {"id":"1","count":<current_count>}
```

**Validation Checklist:**
- [ ] Secret `AzureResumeConnectionStringPrimary` exists and is enabled
- [ ] Secret `AzureResumeConnectionStringSecondary` exists and is enabled
- [ ] Secret values are valid Cosmos DB connection strings (start with `AccountEndpoint=`)
- [ ] Function App can call Cosmos DB through the Key Vault referenced connection string
- [ ] Function App returns a valid `{"id":"1","count":<N>}` response

---

### ✅ AC5: No access denied errors in Function App logs

Verify there are no Key Vault access denied or secret resolution errors in the Function App logs.

```bash
# 5a. Check the Function App for Key Vault reference errors in app settings status
az rest --method GET \
  --uri "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}/config/configreferences/appsettings?api-version=2022-03-01" \
  -o json | jq '.value[]? | select(.properties.status != "Resolved") | {name: .name, status: .properties.status, detail: .properties.details}'

# Expected: No output (all Key Vault references are in "Resolved" status)

# 5b. Check recent Function App logs for Key Vault errors
az webapp log tail --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --filter "Error" \
  --timeout 30

# 5c. Query Application Insights for Key Vault related exceptions (last 24 hours)
# Application Insights name follows pattern: cus1-resumectr-{env}-{version}-ai (uses AppBackendName, not AppName)
# Prod: cus1-resumectr-prod-v1-ai | Dev: cus1-resumectr-dev-v66-ai

az monitor app-insights query \
  --app "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --analytics-query "
    exceptions
    | where timestamp > ago(24h)
    | where outerMessage contains 'KeyVault' or outerMessage contains 'Forbidden' or outerMessage contains 'Access denied' or outerMessage contains 'SecretNotFound'
    | project timestamp, outerMessage, outerType
    | order by timestamp desc
    | take 10
  " -o json

# 5d. Check for any failed requests related to the Function App (last 24 hours)
az monitor app-insights query \
  --app "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --analytics-query "
    requests
    | where timestamp > ago(24h)
    | where success == false
    | project timestamp, name, resultCode, duration
    | order by timestamp desc
    | take 10
  " -o json

# 5e. Alternative: Check recent deployment logs for Key Vault reference issues
az webapp log deployment list --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "[].{Time:log_time, Message:message}" -o json
```

**Validation Checklist:**
- [ ] All Key Vault config references show `Resolved` status (step 5a shows no output)
- [ ] No `Forbidden` or `Access denied` errors in Function App logs
- [ ] No Key Vault related exceptions in Application Insights
- [ ] No failed requests caused by connection string issues

---

## Full Verification Script

Save as `scripts/verify-keyvault-access.sh` and run from a Codespace:

```bash
#!/bin/bash
# Key Vault Access Verification Script
# Verifies all acceptance criteria for Phase 1 - Verify Key Vault access
set -euo pipefail

# Configuration (edit for your environment)
KEY_VAULT_NAME="${1:-cus1-resume-prod-v1-kv}"
RESOURCE_GROUP="${2:-cus1-resume-be-prod-v1-rg}"
FUNCTION_APP_NAME="${3:-cus1-resumectr-prod-v1-fa}"
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
```

---

## Troubleshooting

### Common Issues

| Issue | Symptom | Resolution |
|---|---|---|
| **No managed identity** | `principalId` is null | Enable System-Assigned identity on the Function App |
| **Missing access policy** | No policy for the principal ID | Redeploy Bicep or manually add access policy |
| **Wrong permissions** | Policy exists but missing `get` | Update access policy to include `get` and `list` |
| **Secret not found** | Secret name doesn't match | Verify secret names match `AzureResumeConnectionStringPrimary`/`Secondary` |
| **Key Vault reference stuck** | Config reference status is not `Resolved` | Restart the Function App: `az functionapp restart --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP` |
| **RBAC vs Access Policies** | `enableRbacAuthorization` is `true` | Bicep expects access policies model; redeploy or switch access model |
| **Purge protection disabled** | `enablePurgeProtection` is `false` or `null` | Redeploy Bicep to enable purge protection |
| **Connection string invalid** | Secret value doesn't start with `AccountEndpoint=` | Redeploy Bicep (secrets are auto-populated from Cosmos DB `listConnectionStrings()`) |

### Manual Remediation Commands

```bash
# Re-enable managed identity (if missing)
az functionapp identity assign --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP"

# Add access policy manually (if missing)
az keyvault set-policy --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --object-id "$PRINCIPAL_ID" \
  --secret-permissions get list

# Restart Function App (to resolve stuck Key Vault references)
az functionapp restart --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP"

# Check Function App health after restart
az functionapp show --name "$FUNCTION_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query '{Name:name, State:state}' -o json
```

---

## Source Code Reference

The following source files define the Key Vault and Function App managed identity configuration:

| File | Purpose |
|---|---|
| `.iac/modules/functionapp/functionapp.bicep` | Key Vault resource, access policies, managed identity, app settings with Key Vault references, secret creation |
| `.iac/modules/keyvault/kv.bicep` | Standalone Key Vault module (empty access policies — not actively used) |
| `.iac/modules/keyvault/createKeyVaultSecret.bicep` | Creates a secret in Key Vault |
| `.iac/backend.bicep` | Orchestration — passes Key Vault params to Function App module |
| `backend/api/GetResumeCounter.cs` | Function App code using `Connection = "AzureResumeConnectionStringPrimary"` |
| `backend/api/local.settings.example.json` | Local dev settings showing expected app setting name |
| `.github/workflows/prod-full-stack-cloudflare.yml` | Production deployment — Key Vault name and secret name parameters |
| `.github/workflows/dev-full-stack-cloudflare.yml` | Development deployment — Key Vault name and secret name parameters |

### Architecture Flow

```
Function App (SystemAssigned Identity)
  └── App Setting: AzureResumeConnectionStringPrimary
        └── @Microsoft.KeyVault(SecretUri=https://<kv>.vault.azure.net/secrets/AzureResumeConnectionStringPrimary)
              └── Key Vault Secret: AzureResumeConnectionStringPrimary
                    └── Value: Cosmos DB Primary Connection String (from listConnectionStrings())
                          └── Cosmos DB Account
```
