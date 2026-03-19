# Known Issues and Technical Debt

This document catalogs known issues, broken functionality, and technical debt in the Azure Resume IaC project. Each issue includes impact assessment and remediation guidance.

## Critical Issues

### 1. Visitor Counter Not Working

**Impact:** High — Core interactive feature of the resume site is broken  
**Symptom:** The page counter on `https://resume.ryanmcvey.me/` does not display a visitor count  
**Duration:** Reported as not working for a long time  
**Root Cause:** **CONFIRMED** — See [ROOT_CAUSE_DIAGNOSIS.md](ROOT_CAUSE_DIAGNOSIS.md) for full analysis

**Confirmed Root Cause:** .NET Core 3.1 and Azure Functions v3 reached End of Life on December 13, 2022. Azure has removed runtime support, causing the Function App to fail. The CI/CD pipeline is also broken due to expired Azure SP credentials and deprecated GitHub Actions versions, preventing redeployment.

**Root Cause Evidence:**

| Cause | Status | Details |
|---|---|---|
| .NET Core 3.1 runtime EOL / removed from Azure | ✅ **Confirmed — Primary** | `api.csproj` targets `netcoreapp3.1` + `v3`; Bicep sets `FUNCTIONS_EXTENSION_VERSION: ~3` |
| CI/CD pipeline broken (Azure login fails) | ✅ **Confirmed — Blocking** | Workflow run `22905581884` fails at Azure/login with credential error |
| Function key in main.js may be stale | ⚠️ **Possible — Contributing** | Key was hardcoded and may have been rotated |
| Cosmos DB document missing or inaccessible | ⚠️ **Possible — Contributing** | Key Vault secrets may be stale if keys rotated |
| CORS misconfiguration | ❌ **Unlikely** | CORS is configured in Bicep with correct origins |

**Remediation Plan:**
1. **Upgrade runtime:** .NET 8 (LTS) + Azure Functions v4 — update `api.csproj`, `tests.csproj`, Bicep, and workflows
2. **Fix CI/CD:** Renew Azure SP credentials, upgrade to `Azure/login@v2`, update all deprecated Actions
3. **Verify infrastructure:** Confirm Cosmos DB document exists, Key Vault secrets are current
4. **Update frontend:** Retrieve current function key and update `frontend/main.js`
5. See [ROOT_CAUSE_DIAGNOSIS.md](ROOT_CAUSE_DIAGNOSIS.md) for the detailed remediation action plan

### 2. Hardcoded Secrets in Source Control

**Impact:** Medium — Security concern  
**Files Affected:**
- `frontend/main.js` — Contains Azure Function URL with function authorization code (`?code=M4oh...`)
- ~~`frontend/js/azure_app_insights.js` — Contains Application Insights instrumentation key~~

**Status: PARTIALLY RESOLVED** — The App Insights connection string in `azure_app_insights.js` is now injected at deploy time via `config.js` (no longer hardcoded). The function key in `main.js` remains a known issue.

**Risk:** The function key grants access to call the Function App. While the counter function is low-risk, this is a security anti-pattern.

**Remediation Options:**
- Change function auth level to `Anonymous` (counter is not sensitive)
- Use a backend-for-frontend pattern
- Inject values at build/deploy time instead of committing to source

## Technical Debt

### 1. .NET Core 3.1 and Azure Functions v3 End of Life

**Impact:** High — Blocks future deployments  
**Status:** .NET Core 3.1 reached End of Life on December 13, 2022. Azure Functions v3 reached EOL on December 13, 2022.  
**Diagnosis:** **CONFIRMED** as the primary root cause of the visitor counter failure. See [ROOT_CAUSE_DIAGNOSIS.md](ROOT_CAUSE_DIAGNOSIS.md).

**Current Configuration:**
```xml
<!-- backend/api/api.csproj -->
<TargetFramework>netcoreapp3.1</TargetFramework>
<AzureFunctionsVersion>v3</AzureFunctionsVersion>
```

**Migration Required:**
- Upgrade to .NET 8 (LTS, supported until November 2026)
- Upgrade to Azure Functions v4 (`<AzureFunctionsVersion>v4</AzureFunctionsVersion>`)
- Update `FUNCTIONS_EXTENSION_VERSION` from `~3` to `~4` in Bicep templates
- Update NuGet packages (CosmosDB extension, Functions SDK)
- Update `actions/setup-dotnet` version in workflows
- Update `DOTNET_VERSION` workflow variable from `3.1` to `8.0`
- Test for any Newtonsoft.Json → System.Text.Json migration needs

**Reference:** [Azure Functions runtime versions overview](https://learn.microsoft.com/en-us/azure/azure-functions/functions-versions)

### 2. Deprecated GitHub Actions Syntax and Versions

**Impact:** Medium — Workflows may break without warning

**Issues:**

| Item | Current | Required Update |
|---|---|---|
| `::set-output` command | Used throughout | Replace with `>> $GITHUB_OUTPUT` |
| `actions/checkout@main` | Unpinned | Pin to `@v4` |
| `Azure/login@v1` / `@v1.1` | Legacy `--sdk-auth` | Upgrade to `@v2` with OIDC or new format |
| `Azure/arm-deploy@v1` | Old version | Upgrade to `@v2` |
| `Azure/CLI@v1` | Old version | Upgrade to `@v2` |
| `Azure/functions-action@v1.4.4` | Old version | Upgrade to `@v2` |
| `actions/setup-dotnet@v1` | Old version | Upgrade to `@v4` |

### 3. Change Detection Disabled

**Impact:** Low — All jobs run on every push, increasing build time and Azure costs

**Current State:** ~~The `if` conditions using path-filter outputs are commented out in all workflows.~~

**Status: PARTIALLY RESOLVED** — The `if` conditions have been uncommented in both `dev-full-stack-cloudflare.yml` and `prod-full-stack-cloudflare.yml` (branch `copilot/investigate-cors-error-and-fix`). Each conditional uses `always()` to run even when upstream jobs are skipped, checks upstream job result, and falls back to full deploy on `workflow_dispatch`. The disabled Azure CDN workflows still have commented-out conditionals.

**Remediation:** Merge the branch to `develop`/`main` and verify the conditionals work correctly in a real workflow run.

### 4. Manual Post-Deployment Steps

**Impact:** Medium — Error-prone deployment process

**Steps that require manual intervention after a new stack deployment:**

1. Retrieve Function App URL and function key → Update `frontend/main.js`
2. ~~Retrieve App Insights connection string → Update `frontend/js/azure_app_insights.js`~~ — **RESOLVED:** Now auto-injected via `config.js` at deploy time
3. ~~Create initial Cosmos DB document via Azure Portal Data Explorer~~ — **RESOLVED:** Auto-seeded via `scripts/seed-cosmos-db.sh`

**Remediation Options:**
- Add a workflow step to query the Function App URL and key from Azure, then inject into frontend files before upload
- ~~Add a Bicep deployment script or Azure CLI step to seed the Cosmos DB document~~
- ~~Use environment-specific configuration files instead of hardcoded values~~ — **DONE:** `config.js` pattern implemented

### 5. jQuery and Frontend Library Versions

**Impact:** Low — Potential security vulnerabilities in outdated libraries

**Current Versions:**
| Library | Version | Latest |
|---|---|---|
| jQuery | 1.10.2 | 3.7.x |
| jQuery Migrate | 1.2.1 | 3.5.x |
| Font Awesome | 4.x | 6.x |
| Modernizr | Unknown (custom build) | 3.x |

### 6. Multi-Storage Account Architecture (Resolved)

**Impact:** Resolved — Previously, three storage accounts served identical content for three domains

The Cloudflare workflow previously deployed the same frontend content to three separate storage accounts, one for each domain (`ryanmcvey.me`, `ryanmcvey.net`, `ryanmcvey.cloud`). The architecture has been consolidated to use a single storage account and single domain (`ryanmcvey.me`).

### 7. Azure Service Principal Credential Format

**Impact:** Medium — The `--sdk-auth` flag is deprecated

The current setup uses the legacy `--sdk-auth` JSON format for `Azure/login`. Microsoft recommends migrating to:
- **OpenID Connect (OIDC) federated credentials** — no secrets to rotate, most secure
- **Client ID/Secret** with the newer `Azure/login@v2` format

See: [Configure Azure credentials for GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)

---

## Resolved Issues

### CORS Investigation — Dev Site Visitor Counter (Issue #196)

**Date Resolved:** June 2025 (branch `copilot/investigate-cors-error-and-fix`)

**Symptoms:** Dev site at `https://resumedevv1.ryanmcvey.me` showed CORS errors in browser console. Visitor counter did not display.

**Root Causes Found:**

| # | Cause | Status | Fix Applied |
|---|---|---|---|
| 1 | `main.js` hardcoded prod API URL | ✅ Fixed in PR #197 | `config.js` runtime injection |
| 2 | Dev Function App CORS origins were empty | ✅ Fixed | `az functionapp cors add --allowed-origins "https://resumedevv1.ryanmcvey.me"` |
| 3 | Cosmos DB seed document missing | ✅ Fixed | Created `{id: "1", count: 0}` in `Counter` container via REST API upsert |
| 4 | Function key not passed in API calls | ⚠️ Open | `functionKey` in `main.js` is empty; API requires `?code=<key>` (AuthorizationLevel.Function) |

**Additional Workflow Improvements Applied:**

- Uncommented path-filter `if:` conditionals on deployment jobs (both dev and prod workflows)
- Added `customDomainPrefix` env var for consistent domain/CORS construction
- Pinned `dorny/paths-filter` to commit SHA; replaced `rez0n/create-dns-record` with direct `curl` calls to Cloudflare API (check-before-create pattern)
- Replaced `sleep 60s` DNS wait with `dig`-based retry loop (12 attempts × 10s)
- Switched blob upload from `--auth-mode key` to `--auth-mode login`
- Added Cloudflare cache purge step after frontend deployment
- Added `workflow_dispatch` trigger to prod workflow
- Removed single-quoted heredoc delimiter on `config.js` generation (allows shell expansion)

**Prerequisites for Workflow Changes:**

- GitHub Actions SP needs `Storage Blob Data Contributor` role on frontend storage accounts for `--auth-mode login`
- `CLOUDFLARE_ZONE` secret must be configured in GitHub Secrets for cache purge step
- `CLOUDFLARE_TOKEN` must include **Zone → Cache Purge → Purge** permission (in addition to Zone → DNS → Edit). A 401 authentication error was observed in [workflow run #58](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/runs/23121086640) when the token only had DNS Edit scope. The step now uses `continue-on-error: true` so cache purge failures do not block deployments.
