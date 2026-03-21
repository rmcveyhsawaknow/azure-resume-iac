# Codespace Session — Issue #47: Verify/Rotate Dev Credentials

## Setup

Set up this Codespace for working on issue #47 "[Phase 3] Verify/rotate dev credentials."

- **Issue:** https://github.com/rmcveyhsawaknow/azure-resume-iac/issues/47
- **Phase:** 3 — Dev Deployment
- **Depends on:** Task 0.1 (Verify Azure SP), Task 0.8 (Verify Cloudflare token), Task 0.11 (Verify GitHub secrets)
- **Branch from:** `develop`

## Overview

This session verifies that all dev environment credentials (Azure SP, Cloudflare token, GitHub secrets) are valid and ready for the dev deployment pipeline. It also documents credential expiration dates and rotates anything that is expired or close to expiration.

> **⚠️ Security:** This is a public repository. **Never** commit secrets, tokens, or credentials to source code. All secrets are stored in:
> - **Codespace Secrets** — for interactive development/verification (injected as env vars)
> - **GitHub Actions Environment Secrets** — for CI/CD pipeline (`development` and `production` environments)

---

## Secret Architecture

### Two Layers of Secrets (Codespace vs Actions)

| Layer | Purpose | Where to Set | Consumed By |
|---|---|---|---|
| **Codespace Secrets** | Interactive dev/verification in Codespaces | [github.com/settings/codespaces](https://github.com/settings/codespaces) | `scripts/setup-codespace-auth.sh`, manual `az`/`gh`/`curl` commands |
| **Actions Environment Secrets** | CI/CD pipeline deployment | Repo → Settings → Environments → `development` / `production` | `.github/workflows/*.yml` |

### Codespace Secrets (for interactive sessions)

| Secret Name | Source | Purpose |
|---|---|---|
| `AZURE_SP_APP_ID` | Azure AD App Registration → Application (client) ID | Azure CLI service principal login |
| `AZURE_SP_PASSWORD` | Azure AD App Registration → Client secret value | Azure CLI service principal login |
| `AZURE_SP_TENANT` | Azure AD → Tenant ID | Azure CLI service principal login |
| `AZURE_SUBSCRIPTION_ID` | Azure Portal → Subscriptions | Set correct subscription context |
| `CF_API_TOKEN` | Cloudflare Dashboard → My Profile → API Tokens | Cloudflare DNS verification |

### Actions Environment Secrets (for CI/CD)

| Secret Name | Environment(s) | Format | Used By |
|---|---|---|---|
| `AZURE_RESUME_GITHUB_SP` | `development`, `production` | JSON (`{ clientId, clientSecret, subscriptionId, tenantId }`) | `Azure/login@v2` in all deployment jobs |
| `CLOUDFLARE_TOKEN` | `development`, `production` | Bearer token string | `rez0n/create-dns-record@v2.2` |
| `CLOUDFLARE_ZONE` | `development`, `production` | Cloudflare zone ID string | `rez0n/create-dns-record@v2.2` |

### Mapping Between the Two Layers

The Codespace secrets and Actions secrets reference the **same underlying credentials** but in different formats:

```
Codespace Secrets                   Actions Environment Secrets
──────────────────                  ──────────────────────────
AZURE_SP_APP_ID        ─────┐
AZURE_SP_PASSWORD      ─────┼───►  AZURE_RESUME_GITHUB_SP (JSON object)
AZURE_SP_TENANT        ─────┤      { "clientId": APP_ID,
AZURE_SUBSCRIPTION_ID  ─────┘        "clientSecret": PASSWORD,
                                      "subscriptionId": SUB_ID,
                                      "tenantId": TENANT }

CF_API_TOKEN           ─────────►  CLOUDFLARE_TOKEN (same value)

(no codespace equivalent) ──────►  CLOUDFLARE_ZONE (zone ID)
```

When rotating a credential, **both layers must be updated**.

---

## Step-by-Step Instructions

### Step 0: Authenticate the Codespace

```bash
# Run the existing setup script (validates Azure, GitHub, Cloudflare auth)
bash scripts/setup-codespace-auth.sh
```

If all checks pass (✅), proceed. If any fail, fix the Codespace Secrets at:
https://github.com/settings/codespaces

---

### Step 1: Verify Azure Service Principal

#### 1a. Check SP exists and get details

```bash
# Find the Service Principal by display name
az ad sp list --display-name "github-azure-resume" \
  --query "[].{DisplayName:displayName, AppId:appId, ObjectId:id}" -o table
```

If no results, try listing all SPs you own:
```bash
az ad sp list --show-mine --query "[].{DisplayName:displayName, AppId:appId}" -o table
```

#### 1b. Check credential expiration

```bash
# Replace <APP_ID> with the Application (client) ID from step 1a
SP_APP_ID="<APP_ID>"

# List all client secret credentials and their expiry dates
az ad app credential list --id "$SP_APP_ID" \
  --query "[].{KeyId:keyId, DisplayName:displayName, StartDate:startDateTime, EndDate:endDateTime}" -o table
```

**Decision point:**
- If `EndDate` is in the past → credential is **expired**, must rotate (Step 1d)
- If `EndDate` is within 30 days → credential is **expiring soon**, should rotate (Step 1d)
- If `EndDate` is 30+ days out → credential is **valid**, proceed to Step 1c

#### 1c. Verify SP has correct role assignments

```bash
# Check role assignments for the SP
az role assignment list --assignee "$SP_APP_ID" \
  --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

Expected roles (minimum for this project):
- `Contributor` scoped to the subscription or the resume resource groups
- Key Vault access is handled via access policies (not RBAC roles)

#### 1d. Rotate Azure SP credential (if expired or expiring)

```bash
# Generate a new client secret (valid for 1 year by default)
az ad app credential reset --id "$SP_APP_ID" --display-name "github-actions-$(date +%Y%m%d)" --years 1

# Output will include:
# - appId       → AZURE_SP_APP_ID (Codespace Secret)
# - password    → AZURE_SP_PASSWORD (Codespace Secret)
# - tenant      → AZURE_SP_TENANT (Codespace Secret)
```

> **⚠️ IMPORTANT:** The `password` value is shown ONLY ONCE. Copy it immediately.

**After rotation, update BOTH secret layers:**

1. **Codespace Secrets** → https://github.com/settings/codespaces
   - Update `AZURE_SP_PASSWORD` with the new `password` value

2. **Actions Environment Secrets** → Repo Settings → Environments → `development`
   - Update `AZURE_RESUME_GITHUB_SP` with the full JSON (using values from the `az ad app credential reset` output):
     ```json
     {
       "clientId": "<appId from output>",
       "clientSecret": "<password from output>",
       "subscriptionId": "<subscriptionId>",
       "tenantId": "<tenant from output>"
     }
     ```
   - Repeat for the `production` environment if using the same SP

#### 1e. Verify the new credential works

```bash
# Re-login with the new credential
az logout
az login --service-principal \
  -u "$SP_APP_ID" \
  -p "<new-password>" \
  --tenant "<tenant-id>" \
  --output none

# Verify access
az account show --query '{Name:name, Id:id, TenantId:tenantId}' -o table
az group list --query "[?contains(name, 'resume')].Name" -o tsv
```

---

### Step 2: Verify Cloudflare Token

#### 2a. Verify the existing token

```bash
# The token should already be available from Codespace Secrets
if [ -n "${CF_API_TOKEN}" ]; then
  echo "CF_API_TOKEN is set (${#CF_API_TOKEN} chars)"
else
  echo "CF_API_TOKEN is NOT SET"
fi

# Verify token via Cloudflare API
curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | python3 -m json.tool
```

**Expected output:**
```json
{
  "result": { "id": "...", "status": "active" },
  "success": true
}
```

#### 2b. Verify DNS zone access

```bash
# List zones to confirm the token has DNS permissions
curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for z in data.get('result', []):
    print(f\"Zone: {z['name']}  ID: {z['id']}  Status: {z['status']}\")
"
```

You should see `ryanmcvey.me` listed with status `active`.

#### 2c. Check token expiry (if token has an expiry set)

Cloudflare API tokens can be configured with or without an expiration date.
Check the token details at: **Cloudflare Dashboard → My Profile → API Tokens**

#### 2d. Rotate Cloudflare token (if needed)

If the token is expired, revoked, or has insufficient permissions:

1. Go to **Cloudflare Dashboard → My Profile → API Tokens**
2. Click **Create Token**
3. Use the **Edit zone DNS** template, or create a custom token with:
   - **Permissions:** Zone → DNS → Edit
   - **Zone Resources:** Include → Specific Zone → `ryanmcvey.me`
   - **TTL (optional):** Set an expiry date if desired (recommended: 1 year)
4. Copy the token value (shown only once)

**After rotation, update BOTH secret layers:**

1. **Codespace Secrets** → https://github.com/settings/codespaces
   - Update `CF_API_TOKEN` with the new token value

2. **Actions Environment Secrets** → Repo Settings → Environments → `development`
   - Update `CLOUDFLARE_TOKEN` with the new token value
   - Repeat for the `production` environment if using the same token

#### 2e. Verify Cloudflare Zone ID secret

The `CLOUDFLARE_ZONE` secret must match the zone ID from step 2b:

```bash
# Get the zone ID for ryanmcvey.me
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=ryanmcvey.me" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['result'][0]['id'] if data.get('result') else 'NOT FOUND')
")
echo "Zone ID for ryanmcvey.me: $ZONE_ID"
```

Verify this matches the `CLOUDFLARE_ZONE` secret stored in the Actions environments.

---

### Step 3: Verify GitHub Actions Environment Secrets

#### 3a. List environments and their configuration

Go to: **Repo → Settings → Environments**

Verify both environments exist:
- `development` (used by `dev-full-stack-cloudflare.yml`)
- `production` (used by `prod-full-stack-cloudflare.yml`)

#### 3b. Verify all required secrets are present

For **each** environment (`development` and `production`), verify these secrets exist:

| Secret Name | Required | Notes |
|---|---|---|
| `AZURE_RESUME_GITHUB_SP` | ✅ Yes | JSON with clientId, clientSecret, subscriptionId, tenantId |
| `CLOUDFLARE_TOKEN` | ✅ Yes | Cloudflare API token with DNS edit permissions |
| `CLOUDFLARE_ZONE` | ✅ Yes | Cloudflare zone ID for ryanmcvey.me |

> **Note:** GitHub does not expose secret values after they are saved. You can only verify a secret exists (shows last updated date). To verify the value is correct, you must run the workflow or re-set the secret.

#### 3c. Verify using the GitHub CLI

```bash
# List repository environments
gh api repos/{owner}/{repo}/environments --jq '.environments[] | {name, id, created_at, updated_at}'

# Check environment protection rules
gh api repos/{owner}/{repo}/environments/development --jq '{name, protection_rules, deployment_branch_policy}'
gh api repos/{owner}/{repo}/environments/production --jq '{name, protection_rules, deployment_branch_policy}'
```

> **Note:** The GitHub API does not list environment secret names for security reasons. Check manually at Repo Settings → Environments → [environment] → Environment secrets.

---

### Step 4: Automated Credential Verification

Run the comprehensive verification script:

```bash
bash scripts/verify-credentials.sh
```

This script automates Steps 1–3 where possible, checking:
- Azure SP login and credential expiry
- Azure SP role assignments
- Cloudflare token validity and DNS zone access
- GitHub CLI authentication
- Dev environment resource accessibility

---

### Step 5: Document Credential Expiration Dates

After verification, fill in this table and add it as a comment on issue #47:

```markdown
## Credential Status — [DATE]

| Credential | Status | Expiry Date | Action Taken |
|---|---|---|---|
| Azure SP client secret | ✅ Valid / 🔄 Rotated | YYYY-MM-DD | — / Rotated on YYYY-MM-DD |
| Cloudflare API token | ✅ Valid / 🔄 Rotated | YYYY-MM-DD or No expiry | — / Rotated on YYYY-MM-DD |
| GitHub `development` env secrets | ✅ Present | N/A | All 3 secrets verified |
| GitHub `production` env secrets | ✅ Present | N/A | All 3 secrets verified |

### Codespace Secrets
| Secret | Status |
|---|---|
| `AZURE_SP_APP_ID` | ✅ Set |
| `AZURE_SP_PASSWORD` | ✅ Set |
| `AZURE_SP_TENANT` | ✅ Set |
| `AZURE_SUBSCRIPTION_ID` | ✅ Set |
| `CF_API_TOKEN` | ✅ Set |
```

---

### Step 6: End-to-End Validation

After all credentials are verified/rotated, run this final check:

```bash
# 1. Verify Azure can reach dev resources
az group show --name cus1-resume-be-dev-v1-rg --query '{Name:name, State:properties.provisioningState}' -o json 2>/dev/null \
  && echo "✅ Dev backend RG accessible" \
  || echo "⚠️ Dev backend RG not found (will be created on first deploy)"

az group show --name cus1-resume-fe-dev-v1-rg --query '{Name:name, State:properties.provisioningState}' -o json 2>/dev/null \
  && echo "✅ Dev frontend RG accessible" \
  || echo "⚠️ Dev frontend RG not found (will be created on first deploy)"

# 2. Verify Cloudflare DNS for dev subdomain
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$(curl -s -X GET 'https://api.cloudflare.com/client/v4/zones?name=ryanmcvey.me' \
  -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" | python3 -c "import json,sys; print(json.load(sys.stdin)['result'][0]['id'])")/dns_records?name=resumedevv1.ryanmcvey.me" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
records = data.get('result', [])
if records:
    for r in records:
        print(f\"✅ DNS record found: {r['type']} {r['name']} → {r['content']}\")
else:
    print('⚠️ No DNS record for resumedevv1.ryanmcvey.me (will be created on first deploy)')
"

# 3. Run the full auth setup to confirm everything is green
bash scripts/setup-codespace-auth.sh
```

---

## Troubleshooting

### Azure SP login fails

```bash
# Check if the SP exists
az ad sp show --id "$AZURE_SP_APP_ID" --query '{AppId:appId, DisplayName:displayName}' -o json

# If SP doesn't exist, create a new one:
az ad sp create-for-rbac --name "github-azure-resume" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth
# The --sdk-auth output is the exact format needed for AZURE_RESUME_GITHUB_SP
```

### Cloudflare token returns 403

The token may have been revoked or have insufficient permissions. Create a new token at:
**Cloudflare Dashboard → My Profile → API Tokens → Create Token**

Required permissions: `Zone:DNS:Edit` for `ryanmcvey.me`

### GitHub environment secrets missing

Navigate to: **Repo → Settings → Environments → [environment name] → Environment secrets**

If the environment doesn't exist:
1. Go to Repo → Settings → Environments
2. Click **New environment**
3. Name it `development` (must match the `environment: name:` in the workflow YAML)
4. Add the three required secrets

---

## Acceptance Criteria Checklist

- [ ] Azure SP credential verified for dev environment (Step 1)
- [ ] Cloudflare token verified for dev DNS operations (Step 2)
- [ ] All required secrets present in dev GitHub environment (Step 3)
- [ ] Expired credentials rotated and secrets updated (Steps 1d, 2d if needed)
- [ ] Credential expiration dates documented (Step 5)

---

## Next Steps

After all credentials are verified:
1. Close issue #47
2. Proceed with dev deployment tasks (the credential verification unblocks the rest of Phase 3)
3. Consider scheduling credential rotation reminders based on the expiry dates documented
