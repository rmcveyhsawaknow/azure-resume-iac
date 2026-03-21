# Root Cause Diagnosis: Function App Failure

**Date:** 2026-03-10
**Issue:** [Phase 1] Diagnose root cause
**Status:** Diagnosed — Root cause confirmed
**Affected Resource:** `cus1-resumectr-prod-v1-fa` (Production Function App)

---

## Executive Summary

The visitor counter Function App (`cus1-resumectr-prod-v1-fa`) is non-functional due to the end-of-life (EOL) of both .NET Core 3.1 and Azure Functions v3 runtime. The runtime was deprecated on December 13, 2022, and Azure has since removed support for running .NET Core 3.1 workloads on the Functions v3 host. Additionally, the CI/CD pipeline is broken due to expired/invalid Azure service principal credentials and deprecated GitHub Actions versions, preventing any redeployment.

---

## Root Cause Analysis

### Primary Root Cause: .NET Core 3.1 and Azure Functions v3 End of Life

**.NET Core 3.1** reached End of Life on **December 13, 2022**. **Azure Functions v3** runtime also reached EOL on the same date. Microsoft stopped providing security patches, runtime updates, and eventually removed the runtime from Azure App Service hosting environments.

#### Evidence from Codebase

| File | Setting | Current Value | Issue |
|---|---|---|---|
| `backend/api/api.csproj` | `<TargetFramework>` | `netcoreapp3.1` | EOL since Dec 2022 |
| `backend/api/api.csproj` | `<AzureFunctionsVersion>` | `v3` | EOL since Dec 2022 |
| `backend/tests/tests.csproj` | `<TargetFramework>` | `netcoreapp3.1` | EOL since Dec 2022 |
| `.iac/modules/functionapp/functionapp.bicep` | `FUNCTIONS_EXTENSION_VERSION` | `~3` | EOL runtime host |
| `.github/workflows/prod-full-stack-cloudflare.yml` | `DOTNET_VERSION` | `3.1` | Unavailable SDK |

#### Impact

- Azure no longer hosts .NET Core 3.1 workloads on Functions v3 — the function app cannot start
- The `dotnet 3.1` SDK is no longer available in GitHub Actions runner images — builds fail
- NuGet packages `Microsoft.NET.Sdk.Functions` v3.0.13 and `Microsoft.Azure.WebJobs.Extensions.CosmosDB` v3.0.10 are designed for the v3 host and will not work with v4

### Contributing Factor #1: CI/CD Pipeline Broken

The GitHub Actions deployment workflow is also non-functional, preventing any fixes from being deployed.

#### Evidence from CI Logs

**Workflow Run ID:** `22905581884` (Development Full Stack Cloudflare, 2026-03-10)
**Failure:** Azure login step fails immediately:

```
##[error]Az CLI Login failed. Please check the credentials.
##[error]Error: Error: The process '/usr/bin/az' failed with exit code 1
```

#### CI/CD Issues Identified

| Issue | File | Details |
|---|---|---|
| Azure SP credentials invalid/expired | `prod-full-stack-cloudflare.yml:229` | `AZURE_RESUME_GITHUB_SP` secret uses deprecated `--sdk-auth` JSON format |
| `Azure/login@v1.1` deprecated | `prod-full-stack-cloudflare.yml:227` | Should be `@v2` with OIDC or updated credential format |
| `actions/checkout@main` unpinned | `prod-full-stack-cloudflare.yml:224` | Should pin to `@v4` |
| `actions/setup-dotnet@v1` outdated | `prod-full-stack-cloudflare.yml:232` | Should be `@v4` |
| `Azure/functions-action@v1.4.4` outdated | `prod-full-stack-cloudflare.yml:248` | Should be `@v2` |
| `Azure/arm-deploy@v1` outdated | `prod-full-stack-cloudflare.yml:128` | Should be `@v2` |
| `azure/CLI@v1` outdated | `prod-full-stack-cloudflare.yml:149` | Should be `@v2` |
| `::set-output` deprecated syntax | `prod-full-stack-cloudflare.yml:158,167` | Must use `>> $GITHUB_OUTPUT` |
| `DOTNET_VERSION: '3.1'` | `prod-full-stack-cloudflare.yml:218` | SDK no longer available |

### Contributing Factor #2: Hardcoded Function Key in Frontend

The function authorization key is hardcoded in `frontend/main.js`:

```javascript
const functionApiUrl = 'https://cus1-resumectr-prod-v1-fa.azurewebsites.net/api/GetResumeCounter?code=M4oh...';
```

If the function key was rotated (e.g., during a redeployment or Azure platform update), the frontend would receive `401 Unauthorized` responses even if the Function App were running.

### Contributing Factor #3: Potential Cosmos DB Connectivity Issues

The Function App uses Key Vault references for Cosmos DB connection strings:

```
AzureResumeConnectionStringPrimary: '@Microsoft.KeyVault(SecretUri=https://...)'
```

If the Cosmos DB account keys were rotated since the last deployment, the Key Vault secrets would be stale, causing the function to fail with a `CosmosException` at runtime.

---

## Detailed Technical Assessment

### Backend Code Analysis (`backend/api/`)

| Component | Current | Status |
|---|---|---|
| Target Framework | `netcoreapp3.1` | ❌ EOL — must upgrade to `net8.0` |
| Functions Version | `v3` | ❌ EOL — must upgrade to `v4` |
| Hosting Model | In-process | ⚠️ In-process is supported in v4 for .NET 8, but isolated worker model is recommended |
| `Microsoft.NET.Sdk.Functions` | `3.0.13` | ❌ Must upgrade to `4.x` |
| `Microsoft.Azure.WebJobs.Extensions.CosmosDB` | `3.0.10` | ❌ Must upgrade to `4.x` (for in-process) or migrate to isolated model packages |
| `Newtonsoft.Json` | Implicit via SDK | ⚠️ Consider migrating to `System.Text.Json` |
| Function Auth Level | `Function` | ✅ Acceptable (requires key) |
| Cosmos DB bindings | Input + Output | ✅ Pattern is correct, just needs package update |

### Infrastructure Analysis (`.iac/`)

| Component | Current | Status |
|---|---|---|
| `FUNCTIONS_EXTENSION_VERSION` | `~3` | ❌ Must change to `~4` |
| `FUNCTIONS_WORKER_RUNTIME` | `dotnet` (param) | ⚠️ Keep `dotnet` for in-process, use `dotnet-isolated` for isolated model |
| App Service Plan SKU | `Y1` (Consumption) | ✅ OK |
| Managed Identity | `SystemAssigned` | ✅ OK |
| Key Vault access | Access policies (get, list) | ✅ OK |
| CORS | Two origins configured | ✅ OK |
| App Insights | Classic mode | ⚠️ Consider migrating to workspace-based |
| Bicep API versions | `2020-12-01`, `2021-03-01` | ⚠️ Outdated but functional |

### Test Infrastructure Analysis (`backend/tests/`)

| Component | Current | Status |
|---|---|---|
| Target Framework | `netcoreapp3.1` | ❌ Must upgrade to `net8.0` |
| xUnit | `2.4.0` | ⚠️ Outdated (latest is 2.9.x) |
| Test SDK | `16.5.0` | ⚠️ Outdated (latest is 17.x) |
| `Microsoft.AspNetCore.Mvc` | `2.2.0` | ❌ Must upgrade for .NET 8 compatibility |
| Test coverage | 1 test (counter increment) | ⚠️ Minimal but validates core logic |

### Frontend Analysis (`frontend/`)

| Component | Status |
|---|---|
| Hardcoded function URL + key | ❌ Security concern; key may be stale |
| Hardcoded App Insights key | ⚠️ Low risk but poor practice |
| jQuery 1.10.2 | ⚠️ Very outdated (security patches in 3.x) |
| No build step / no framework | ✅ Simple, low maintenance |

---

## Failure Chain

The following diagram shows the chain of failures that results in the broken visitor counter:

```
.NET Core 3.1 EOL (Dec 2022)
    │
    ├─► Azure removes 3.1 runtime from Functions host
    │       │
    │       └─► Function App cus1-resumectr-prod-v1-fa stops/errors
    │               │
    │               └─► GET /api/GetResumeCounter returns 5xx or timeout
    │                       │
    │                       └─► frontend/main.js fetch() fails
    │                               │
    │                               └─► Visitor counter not displayed
    │
    ├─► GitHub Actions runner images remove dotnet 3.1 SDK
    │       │
    │       └─► dotnet build --configuration Release fails
    │               │
    │               └─► CI/CD pipeline cannot build or deploy new code
    │
    └─► Azure SP credentials expired / --sdk-auth format deprecated
            │
            └─► Azure/login@v1.1 step fails
                    │
                    └─► No Azure deployments possible (IaC or app)
```

---

## Remediation Action Plan

### Phase 1A: Fix Function App (Code Changes)

| # | Task | Priority | Effort |
|---|---|---|---|
| 1 | Upgrade `backend/api/api.csproj` to `net8.0` + Functions v4 | P1 | M |
| 2 | Update NuGet packages to v4-compatible versions | P1 | S |
| 3 | Update `backend/tests/tests.csproj` to `net8.0` + new package versions | P1 | S |
| 4 | Decide: in-process vs isolated worker model | P1 | S |
| 5 | Update `host.json` if needed for v4 | P2 | S |
| 6 | Verify function code compiles and tests pass locally | P1 | S |

### Phase 1B: Fix Infrastructure (Bicep Changes)

| # | Task | Priority | Effort |
|---|---|---|---|
| 7 | Update `FUNCTIONS_EXTENSION_VERSION` from `~3` to `~4` in `functionapp.bicep` | P1 | S |
| 8 | Update `FUNCTIONS_WORKER_RUNTIME` if switching to isolated model | P1 | S |
| 9 | Update Bicep API versions to latest stable | P3 | S |

### Phase 1C: Fix CI/CD Pipeline (Workflow Changes)

| # | Task | Priority | Effort |
|---|---|---|---|
| 10 | Update `DOTNET_VERSION` from `3.1` to `8.0` in workflows | P1 | S |
| 11 | Upgrade `Azure/login` to `@v2` | P1 | S |
| 12 | Renew or recreate Azure SP credentials (manual) | P1 | S |
| 13 | Replace `::set-output` with `>> $GITHUB_OUTPUT` | P2 | S |
| 14 | Pin `actions/checkout` to `@v4` | P2 | S |
| 15 | Upgrade remaining Actions to latest versions | P2 | S |

### Phase 1D: Verify and Validate (Post-Deployment)

| # | Task | Priority | Effort |
|---|---|---|---|
| 16 | Verify Cosmos DB document `{"id": "1"}` exists | P1 | S |
| 17 | Verify Key Vault secrets are current | P1 | S |
| 18 | Verify function key and update `frontend/main.js` if needed | P1 | S |
| 19 | Test visitor counter end-to-end | P1 | S |

---

## Appendix: Assessment Commands

The following commands can verify the current state of Azure resources. See also [ASSESSMENT_COMMANDS.md](ASSESSMENT_COMMANDS.md).

### Function App State

```bash
# Check if function app is running
az functionapp show \
  --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query "{state:state, runtime:siteConfig.linuxFxVersion, enabled:enabled}"

# Check function extension version
az functionapp config appsettings list \
  --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query "[?name=='FUNCTIONS_EXTENSION_VERSION']"
```

### Cosmos DB State

```bash
# Verify database and container exist
az cosmosdb sql database list \
  --account-name cus1-resume-prod-v1-cosmos \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query "[].name"

az cosmosdb sql container list \
  --account-name cus1-resume-prod-v1-cosmos \
  --resource-group cus1-resume-be-prod-v1-rg \
  --database-name azure-resume-click-count \
  --query "[].name"
```

### Key Vault State

```bash
# Check Key Vault secret versions
az keyvault secret list \
  --vault-name cus1-resume-prod-v1-kv \
  --query "[].{name:name, enabled:attributes.enabled, expires:attributes.expires}"
```

---

## References

- [Azure Functions runtime versions overview](https://learn.microsoft.com/en-us/azure/azure-functions/functions-versions)
- [.NET Core 3.1 EOL announcement](https://devblogs.microsoft.com/dotnet/net-core-3-1-will-reach-end-of-support-on-december-13-2022/)
- [Migrate Azure Functions v3 to v4](https://learn.microsoft.com/en-us/azure/azure-functions/migrate-version-3-version-4)
- [Azure Functions .NET isolated worker model](https://learn.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide)
- [Configure Azure credentials for GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- Project documentation: [KNOWN_ISSUES.md](KNOWN_ISSUES.md), [ARCHITECTURE.md](ARCHITECTURE.md), [ASSESSMENT_COMMANDS.md](ASSESSMENT_COMMANDS.md)
