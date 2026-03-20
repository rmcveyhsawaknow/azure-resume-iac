# Bicep Remediation Details from Root Cause Diagnosis (#24)

**Source:** Root cause diagnosis (issue #24, PR #155) — live Azure CLI diagnostics run 2026-03-13

## Diagnosis Findings Relevant to This Issue

The live diagnostics against `cus1-resumectr-prod-v1-fa` confirmed the following Bicep template changes are required to complete this issue:

### Current State (from `az functionapp show` + `az functionapp config appsettings list`)

| Setting | Live Value | Bicep Source |
|---|---|---|
| `FUNCTIONS_EXTENSION_VERSION` | `~3` | Hardcoded in `.iac/modules/functionapp/functionapp.bicep` |
| `LinuxFxVersion` | `dotnet|3.1` | Not set in Bicep (set at deploy/platform level) |
| `FUNCTIONS_WORKER_RUNTIME` | `dotnet` | Parameterized via `functionRuntime` |
| `State` | **Stopped** | Function App is not running |

### Required Bicep Changes

| # | File | Change | Notes |
|---|---|---|---|
| 1 | `.iac/modules/functionapp/functionapp.bicep` | `FUNCTIONS_EXTENSION_VERSION: '~3'` → `'~4'` | Direct AC requirement |
| 2 | `.iac/modules/functionapp/functionapp.bicep` | Add `linuxFxVersion` to `siteConfig` in functionApp resource | Currently not in Bicep; should be `'dotnet-isolated|8.0'` or `'dotnet|8.0'` depending on model decision |
| 3 | `.iac/modules/functionapp/functionapp.bicep` | Update `functionRuntime` param usage | If isolated model: pass `'dotnet-isolated'` instead of `'dotnet'` |
| 4 | `.iac/modules/functionapp/functionapp.bicep` | Update API versions: `Microsoft.Web/sites@2020-12-01` → `@2023-12-01` | Outdated but functional; recommended upgrade |
| 5 | `.iac/modules/functionapp/functionapp.bicep` | Update API versions: `Microsoft.Web/serverfarms@2020-12-01` → `@2023-12-01` | Same |
| 6 | `backend/api/host.json` | Update `extensionBundle` version range for v4 | Required for Functions v4 compatibility |

### Decision Dependency: In-Process vs Isolated Worker Model

This issue is blocked on a decision from #25 (Upgrade .NET runtime):
- **In-process** (`dotnet`): `linuxFxVersion: 'dotnet|8.0'`, `FUNCTIONS_WORKER_RUNTIME: 'dotnet'`
- **Isolated** (`dotnet-isolated`): `linuxFxVersion: 'dotnet-isolated|8.0'`, `FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'`

Microsoft recommends isolated model for new development. The existing code uses in-process v3 patterns (WebJobs bindings), so the migration path should be decided before making Bicep changes.

### Additional Finding: WEBSITE_RUN_FROM_PACKAGE SAS Token Expired

The current deployment package URL in `WEBSITE_RUN_FROM_PACKAGE` has an **expired SAS token** (expired Sept 27, 2023). After the Bicep/code upgrade, a fresh deployment via CI/CD will resolve this, but be aware that the current Function App cannot load any code even if the runtime were upgraded in-place.

### Related Issues

- #24 — Diagnose root cause (diagnosis complete)
- #25 — Upgrade .NET runtime (.NET Core 3.1 → .NET 8) — dependency
- #27 — Update NuGet packages — dependency
- #132 — Set FtpsState to Disabled — can be done alongside this issue in the same Bicep PR
