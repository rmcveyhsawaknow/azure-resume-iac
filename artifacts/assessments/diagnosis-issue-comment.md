# Root Cause Diagnosis — Live Azure Diagnostics (2026-03-13)

**Issue:** #24 — [Phase 1] Diagnose root cause
**PR:** #155
**Resource:** `cus1-resumectr-prod-v1-fa` (Production Function App)

---

## Diagnostic Summary

Live CLI diagnostics confirm the Function App is **completely non-functional** due to multiple compounding failures. The root cause chain is: .NET Core 3.1 EOL → runtime removed → app stopped → deployment package expired → no CI/CD to redeploy.

---

## Live Diagnostic Results

### 1. Function App State (`az functionapp show`)

| Property | Value | Status |
|---|---|---|
| **State** | `Stopped` | :red_circle: App is not running |
| LinuxFxVersion | `dotnet\|3.1` | :red_circle: .NET Core 3.1 EOL (Dec 2022) |
| Kind | `functionapp,linux` | Linux consumption plan |
| HttpsOnly | `true` | :white_check_mark: OK |
| DefaultHostName | `cus1-resumectr-prod-v1-fa.azurewebsites.net` | Responds with 403 "app is stopped" |

### 2. Function App Configuration (`az functionapp config show`)

| Property | Value | Status |
|---|---|---|
| LinuxFxVersion | `dotnet\|3.1` | :red_circle: EOL runtime |
| AlwaysOn | `false` | Expected for Consumption plan |
| FtpsState | `AllAllowed` | :warning: Should be `FtpsOnly` or `Disabled` |
| HttpLoggingEnabled | `false` | :warning: No application logging |

### 3. App Settings (`az functionapp config appsettings list`)

| Setting | Value | Status |
|---|---|---|
| `FUNCTIONS_EXTENSION_VERSION` | `~3` | :red_circle: Functions v3 EOL |
| `FUNCTIONS_WORKER_RUNTIME` | `dotnet` | In-process model (v3 era) |
| `WEBSITE_RUN_FROM_PACKAGE` | `...Functionapp_202292705659.zip?...se=2023-09-27...` | :red_circle: **SAS token expired Sept 2023** (~2.5 years ago) |
| `AzureWebJobsStorage` | Contains plaintext account key | :warning: Should use managed identity |
| `AzureResumeConnectionStringPrimary` | `@Microsoft.KeyVault(SecretUri=...)` | :white_check_mark: Key Vault reference (good) |
| `AzureResumeConnectionStringSecondary` | `@Microsoft.KeyVault(SecretUri=...)` | :white_check_mark: Key Vault reference (good) |
| `APPINSIGHTS_INSTRUMENTATIONKEY` | `94c2e365-...` | :white_check_mark: Present |

### 4. Deployed Functions (`az functionapp function list`)

| Function | Status |
|---|---|
| `WarmUp` (standby stub) | Only function listed |
| `GetResumeCounter` | :red_circle: **NOT deployed / NOT loaded** |

The actual `GetResumeCounter` function is not loaded. Only the built-in `WarmUp` standby stub exists, confirming the app never successfully loaded the deployment package.

### 5. App Insights Telemetry (`az monitor app-insights events show`)

| Metric | Last 30 Days | Status |
|---|---|---|
| Exceptions | 0 | No telemetry (app is stopped) |
| Requests | 0 | No traffic reaching the function |

No telemetry exists because the app has been stopped — Azure never routes requests to a stopped Function App, so no exceptions or requests are logged.

### 6. Application Logs (`az webapp log download`)

**Result:** `404 Not Found` — SCM site is unavailable for a stopped Linux Consumption app. No logs retrievable.

### 7. Deployment History (`az webapp log deployment list`)

**Result:** Empty array `[]` — No deployment records exist. This may indicate the deployment history was purged, or the original deployment used a mechanism that didn't create Kudu deployment records (e.g., `WEBSITE_RUN_FROM_PACKAGE` with direct blob URL).

### 8. App Service Plan (`az appservice plan show`)

| Property | Value | Status |
|---|---|---|
| SKU | `Y1` (Consumption/Dynamic) | :white_check_mark: OK |
| Kind | `functionapp` | :white_check_mark: OK |

### 9. CORS Configuration (`az functionapp cors show`)

```json
{
  "allowedOrigins": [
    "https://resume.ryanmcvey.me",
    "https://resume.ryanmcvey.net",
    "https://resume.ryanmcvey.cloud",
    "https://cus1-resume-prod-v1-cdn.azureedge.net"
  ]
}
```
:white_check_mark: CORS origins are configured (will need verification once app is running).

### 10. Direct Endpoint Test (`curl`)

```
HTTP 403 — "Error 403 - This web app is stopped."
```

---

## Root Cause Chain

```
.NET Core 3.1 EOL (Dec 13, 2022)
    │
    ├─► Azure stops supporting dotnet|3.1 on Functions v3 host
    │       │
    │       └─► Function App enters "Stopped" state
    │               │
    │               └─► GetResumeCounter function never loads
    │                       │
    │                       └─► All API calls return HTTP 403
    │
    ├─► WEBSITE_RUN_FROM_PACKAGE SAS token expired (Sept 27, 2023)
    │       │
    │       └─► Even if runtime were available, deployment package is inaccessible
    │
    ├─► Backend code targets netcoreapp3.1 + Functions v3 packages
    │       │
    │       └─► Cannot build with modern .NET SDK (3.1 SDK removed from runners)
    │
    └─► CI/CD pipeline broken (expired SP credentials + deprecated Actions)
            │
            └─► No mechanism to deploy fixes
```

**Five independent blockers must ALL be resolved before the Function App can work:**

1. **Runtime**: Upgrade from `dotnet|3.1` → `dotnet-isolated|8.0` (or `dotnet|8.0` for in-process)
2. **Functions host**: Upgrade from `~3` → `~4`
3. **Backend code**: Upgrade `netcoreapp3.1` → `net8.0`, update NuGet packages
4. **Deployment package**: Redeploy (current SAS token expired 2.5 years ago)
5. **CI/CD pipeline**: Fix credentials, update Actions versions, update .NET SDK version

---

## Remediation Action Plan

### Phase 1A: Backend Code Upgrade (Copilot-suitable)

| # | Task | File(s) | Change |
|---|---|---|---|
| 1 | Upgrade target framework | `backend/api/api.csproj` | `netcoreapp3.1` → `net8.0` |
| 2 | Upgrade Functions version | `backend/api/api.csproj` | `v3` → `v4` |
| 3 | Update NuGet packages | `backend/api/api.csproj` | `Microsoft.NET.Sdk.Functions` → `4.x`, `CosmosDB` → `4.x` |
| 4 | Upgrade test project | `backend/tests/tests.csproj` | `netcoreapp3.1` → `net8.0`, update test SDKs |
| 5 | Verify code compiles | Terminal | `dotnet build`, `dotnet test` |

### Phase 1B: Infrastructure Update (Copilot-suitable)

| # | Task | File(s) | Change |
|---|---|---|---|
| 6 | Update Functions extension version | `.iac/modules/functionapp/functionapp.bicep` | `~3` → `~4` |
| 7 | Update Linux FX version | `.iac/modules/functionapp/functionapp.bicep` | `dotnet\|3.1` → `dotnet-isolated\|8.0` |

### Phase 1C: CI/CD Pipeline Fix (Copilot-suitable)

| # | Task | File(s) | Change |
|---|---|---|---|
| 8 | Update .NET SDK version | Workflow YAML | `3.1` → `8.0` |
| 9 | Upgrade GitHub Actions | Workflow YAML | Pin to latest stable versions |
| 10 | Fix deprecated `::set-output` | Workflow YAML | Use `>> $GITHUB_OUTPUT` |

### Phase 1D: Manual Steps (Human required)

| # | Task | Owner | Notes |
|---|---|---|---|
| 11 | Renew/recreate Azure SP credentials | Human | Requires Azure Portal or `az ad sp` |
| 12 | Start Function App after deployment | Human | `az functionapp start` |
| 13 | Verify Cosmos DB data integrity | Human | Check `Counter` collection has `{"id":"1"}` |
| 14 | Verify Key Vault secrets are current | Human | Compare to actual Cosmos DB keys |
| 15 | Update function key in `frontend/main.js` if rotated | Human | Check after Functions restart |
| 16 | End-to-end test | Human | Visit `https://resume.ryanmcvey.me` and verify counter |

### Security Findings (Address During Remediation)

| Finding | Severity | Recommendation |
|---|---|---|
| `FtpsState: AllAllowed` | Medium | Set to `Disabled` (use zip deploy, not FTP) |
| `AzureWebJobsStorage` has plaintext key | Medium | Migrate to managed identity-based storage |
| `HttpLoggingEnabled: false` | Low | Enable for observability |
| Hardcoded function key in `frontend/main.js` | Medium | Known issue; address in Phase 3 |

---

## Cross-Reference: Related Phase 1 Issues

The remediation action plan maps directly to the following existing Phase 1 issues:

| Action Plan Item | GitHub Issue | Bicep Impact? |
|---|---|---|
| Upgrade `netcoreapp3.1` → `net8.0` | #25 — Upgrade .NET runtime | No |
| Upgrade Functions v3 → v4, update Bicep templates | **#26 — Upgrade Functions version (v3 → v4)** | **Yes** |
| Update NuGet packages | #27 — Update NuGet packages | No |
| Update test project | #28 — Update test project | No |
| Verify Cosmos DB data | #29 — Verify Cosmos DB data | No |
| Verify Key Vault access | #30 — Verify Key Vault access | No |
| Update CORS (single domain) | #31 — Update CORS settings | **Yes** (Bicep CORS config) |
| Update function key in main.js | #32 — Update function key in main.js | No |
| Test function locally | #33 — Test function locally | No |
| Update workflow dotnet version | #34 — Update workflow dotnet version | No |
| Set FtpsState to Disabled | **#132 — Set FtpsState to Disabled** | **Yes** |

### Issue #26 — Bicep-Specific Remediation Details

The live diagnostics confirm the following Bicep changes are required for issue #26:

| File | Current | Required | Line |
|---|---|---|---|
| `.iac/modules/functionapp/functionapp.bicep` | `FUNCTIONS_EXTENSION_VERSION: '~3'` | `'~4'` | appsettings resource |
| `.iac/modules/functionapp/functionapp.bicep` | No `linuxFxVersion` in `siteConfig` | Add `linuxFxVersion: 'dotnet-isolated\|8.0'` (or `'dotnet\|8.0'` for in-process) | functionApp resource |
| `.iac/modules/functionapp/functionapp.bicep` | No `ftpsState` in `siteConfig` | Add `ftpsState: 'Disabled'` (maps to #132) | functionApp resource |
| `.iac/modules/functionapp/functionapp.bicep` | `Microsoft.Web/sites@2020-12-01` | Update to `@2023-12-01` or latest stable | API version |
| `.iac/modules/functionapp/functionapp.bicep` | `Microsoft.Web/serverfarms@2020-12-01` | Update to `@2023-12-01` or latest stable | API version |
| `backend/api/host.json` | Needs review for v4 extensionBundle | Update `extensionBundle` version range | host.json |

### Decision Required: In-Process vs Isolated Worker Model

The `functionRuntime` parameter currently passes `'dotnet'` (in-process model). For .NET 8:
- **In-process** (`dotnet`): Simpler migration, fewer code changes, but limited to Functions v4 LTS
- **Isolated** (`dotnet-isolated`): Recommended by Microsoft, decoupled from host, broader .NET version support

This decision affects both the Bicep template (`FUNCTIONS_WORKER_RUNTIME` value) and the backend code (different NuGet packages and hosting patterns). It should be resolved as part of #25/#26.

---

## Acceptance Criteria Status

- [x] Root cause identified and documented
- [x] Application logs reviewed from last 30 days (no logs available — app stopped; SCM returns 404)
- [x] App Insights exceptions and failures analyzed (0 exceptions/requests — app stopped)
- [x] Runtime compatibility issues identified (.NET Core 3.1 EOL, Functions v3 EOL, expired SAS token)
- [x] Clear action plan for remediation defined (see above)
