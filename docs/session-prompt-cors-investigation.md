# Codespace Session — CORS Investigation & Dev Endpoint Verification

## Setup

Set up this Codespace for debugging persistent CORS errors preventing the dev site from hitting the visitor counter API, and for verifying the dev environment uses the correct (dev) API endpoint.

- **Issue:** Investigate Persistent CORS Error After Deployment & Enable API Access
- **Parent:** rmcveyhsawaknow/azure-resume-iac#196
- **Branch from:** `develop` (or the feature branch for this investigation)

## Overview

The dev site at `https://resumedevv1.ryanmcvey.me` was calling the **prod** Function App (`cus1-resumectr-prod-v1-fa`) instead of the **dev** Function App (`cus1-resumectr-dev-v1-fa`). PR #197 fixed the hardcoded URL in `main.js` by introducing `config.js` runtime injection. This session verifies the fix is deployed and that CORS rules on the dev Function App allow the dev origin.

> **Root Cause Summary:**
> 1. `frontend/main.js` previously had a hardcoded prod API URL.
> 2. The dev Function App's CORS rules only allow `https://resumedevv1.ryanmcvey.me`, so calling the prod Function App from that origin was blocked.
> 3. Additionally, if the prod Function App was disabled (stopped), it returned a 403 "Site Disabled" instead of a CORS error.

---

## Environment Quick Reference

| Resource | Dev | Prod |
|---|---|---|
| Function App | `cus1-resumectr-dev-v1-fa` | `cus1-resumectr-prod-v1-fa` |
| Backend RG | `cus1-resume-be-dev-v1-rg` | `cus1-resume-be-prod-v1-rg` |
| Frontend RG | `cus1-resume-fe-dev-v1-rg` | `cus1-resume-fe-prod-v1-rg` |
| Storage Account | `cus1resumedevv1sa` | `cus1resumeprodv1sa` |
| Custom Domain | `resumedevv1.ryanmcvey.me` | `resume.ryanmcvey.me` |
| CORS Allowed Origin | `https://resumedevv1.ryanmcvey.me` | `https://resume.ryanmcvey.me` |
| API Endpoint | `https://cus1-resumectr-dev-v1-fa.azurewebsites.net/api/GetResumeCounter` | `https://cus1-resumectr-prod-v1-fa.azurewebsites.net/api/GetResumeCounter` |

---

## Step-by-Step Instructions

### Step 0: Authenticate the Codespace

```bash
bash scripts/setup-codespace-auth.sh
```

If all checks pass (✅), proceed. If any fail, fix the Codespace Secrets at:
https://github.com/settings/codespaces

---

### Step 1: Run the Automated CORS Diagnostic

```bash
bash scripts/diagnose-cors.sh --dev
```

This script checks:
- Function App state (Running/Stopped)
- CORS allowed origins on the Function App
- Whether the correct `config.js` is deployed to the storage account
- Function App HTTP accessibility

For both environments:
```bash
bash scripts/diagnose-cors.sh --all
```

---

### Step 2: Manual CORS Inspection (if needed)

#### 2a. Check Function App CORS settings

```bash
# Dev Function App CORS
az functionapp cors show \
  --name cus1-resumectr-dev-v1-fa \
  --resource-group cus1-resume-be-dev-v1-rg

# Prod Function App CORS (for comparison)
az functionapp cors show \
  --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg
```

**Expected:** Dev CORS should include `https://resumedevv1.ryanmcvey.me`

#### 2b. Check Function App state

```bash
# Dev
az functionapp show \
  --name cus1-resumectr-dev-v1-fa \
  --resource-group cus1-resume-be-dev-v1-rg \
  --query '{Name:name, State:state, Enabled:enabled, DefaultHostName:defaultHostName}' -o table

# Prod
az functionapp show \
  --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query '{Name:name, State:state, Enabled:enabled, DefaultHostName:defaultHostName}' -o table
```

If the Function App state is `Stopped`, start it:
```bash
az functionapp start \
  --name cus1-resumectr-dev-v1-fa \
  --resource-group cus1-resume-be-dev-v1-rg
```

#### 2c. Check deployed config.js in storage

```bash
# Download config.js from dev storage and check the API URL
az storage blob download \
  --account-name cus1resumedevv1sa \
  --container-name '$web' \
  --name config.js \
  --auth-mode login \
  --file /tmp/dev-config.js 2>/dev/null && cat /tmp/dev-config.js
```

**Expected:** Should contain `defined_FUNCTION_API_BASE` pointing to the **dev** Function App:
```
var defined_FUNCTION_API_BASE = 'https://cus1-resumectr-dev-v1-fa.azurewebsites.net/api/GetResumeCounter';
```

**Not expected (this was the bug):** URL pointing to `cus1-resumectr-prod-v1-fa`

---

### Step 3: Add CORS Origin (if missing)

If the dev Function App is missing the dev site origin:

```bash
az functionapp cors add \
  --name cus1-resumectr-dev-v1-fa \
  --resource-group cus1-resume-be-dev-v1-rg \
  --allowed-origins "https://resumedevv1.ryanmcvey.me"
```

Verify it was added:
```bash
az functionapp cors show \
  --name cus1-resumectr-dev-v1-fa \
  --resource-group cus1-resume-be-dev-v1-rg
```

> **Note:** This manual fix will be overwritten on the next IaC deployment. The Bicep template sets `corsFriendlyDnsUri` for CORS; ensure the workflow passes the correct origin.

---

### Step 4: Verify API Accessibility

```bash
# Test dev Function App endpoint (expect 200 or function-level auth response)
curl -sS -o /dev/null -w "HTTP %{http_code}\n" \
  "https://cus1-resumectr-dev-v1-fa.azurewebsites.net/api/GetResumeCounter"

# Test with verbose headers to check CORS
curl -sS -D - -o /dev/null \
  -H "Origin: https://resumedevv1.ryanmcvey.me" \
  "https://cus1-resumectr-dev-v1-fa.azurewebsites.net/api/GetResumeCounter" 2>&1 \
  | grep -i 'access-control\|http/'
```

**Expected:** The response should include `Access-Control-Allow-Origin: https://resumedevv1.ryanmcvey.me`

---

### Step 5: Redeploy (if config.js is stale)

If the deployed `config.js` still points to the prod endpoint, trigger a redeployment:

```bash
# Option A: Re-upload config.js manually to dev storage
cat > /tmp/config.js << 'EOF'
var defined_FUNCTION_API_BASE = 'https://cus1-resumectr-dev-v1-fa.azurewebsites.net/api/GetResumeCounter';
EOF

az storage blob upload \
  --account-name cus1resumedevv1sa \
  --container-name '$web' \
  --name config.js \
  --file /tmp/config.js \
  --auth-mode login \
  --overwrite
```

```bash
# Option B: Trigger the dev workflow (merge to develop and push, or use workflow_dispatch)
# The workflow generates config.js with the correct dev endpoint automatically.
```

---

### Step 6: Browser Verification

After fixes are applied:

1. Open `https://resumedevv1.ryanmcvey.me` in a browser
2. Open DevTools → Console
3. Hard refresh (Ctrl+Shift+R) to bypass cache
4. Verify:
   - No CORS errors in console
   - Network tab shows requests to `cus1-resumectr-dev-v1-fa` (NOT `cus1-resumectr-prod-v1-fa`)
   - Visitor counter displays a number (not blank or error)

---

## Troubleshooting

### "403 (Site Disabled)" error

The Function App is stopped. Start it:
```bash
az functionapp start --name cus1-resumectr-dev-v1-fa --resource-group cus1-resume-be-dev-v1-rg
```

### CORS error persists after adding origin

1. Check there's no trailing slash on the origin URL (should be `https://resumedevv1.ryanmcvey.me`, NOT `https://resumedevv1.ryanmcvey.me/`)
2. Clear browser cache or test in incognito mode
3. Check if Cloudflare is caching the old CORS headers — purge cache in Cloudflare Dashboard

### config.js not being generated correctly

Check the workflow's "Generate Frontend Config" step output in the GitHub Actions run log. The heredoc should produce:
```javascript
var defined_FUNCTION_API_BASE = 'https://cus1-resumectr-dev-v1-fa.azurewebsites.net/api/GetResumeCounter';
```

### Function App returns 401 Unauthorized

The Function auth level is `Function` — a function key may be required. Check if the function is configured with anonymous access or if a key needs to be appended:
```bash
az functionapp function keys list \
  --name cus1-resumectr-dev-v1-fa \
  --resource-group cus1-resume-be-dev-v1-rg \
  --function-name GetResumeCounter
```

---

## Acceptance Criteria

- [ ] Dev Function App (`cus1-resumectr-dev-v1-fa`) is in `Running` state
- [ ] Dev Function App CORS includes `https://resumedevv1.ryanmcvey.me`
- [ ] Deployed `config.js` in dev storage points to dev Function App endpoint
- [ ] `https://resumedevv1.ryanmcvey.me` loads without CORS errors
- [ ] Visitor counter API request goes to dev endpoint (not prod)
- [ ] Root cause and remediation documented
