# Known Issues and Technical Debt

This document catalogs known issues, broken functionality, and technical debt in the Azure Resume IaC project. Each issue includes impact assessment and remediation guidance.

## Critical Issues

### 1. Visitor Counter Not Working

**Impact:** High — Core interactive feature of the resume site is broken  
**Symptom:** The page counter on `https://resume.ryanmcvey.me/` does not display a visitor count  
**Duration:** Reported as not working for a long time

**Possible Root Causes:**

| Cause | Likelihood | How to Verify |
|---|---|---|
| Function App stopped or in error state | High | `az functionapp show --name cus1-resumectr-prod-v1-fa --resource-group cus1-resume-be-prod-v1-rg --query state` |
| .NET Core 3.1 runtime deprecated/removed from Azure | High | `az functionapp config show --name cus1-resumectr-prod-v1-fa --resource-group cus1-resume-be-prod-v1-rg --query linuxFxVersion` or check Azure Portal |
| Function key changed (URL in main.js is stale) | Medium | Compare `functionApiUrl` in `frontend/main.js` with actual function key in Azure Portal |
| Cosmos DB document missing or inaccessible | Medium | Check Cosmos DB Data Explorer for document `{"id": "1"}` in `Counter` container |
| Key Vault secret expired or inaccessible | Medium | Check Key Vault access policies and secret expiry |
| CORS misconfiguration | Low | Check Function App CORS settings against the custom domain URL |
| Cosmos DB connection string rotated | Low | Compare Key Vault secret with actual Cosmos DB keys |

**Remediation Steps:**
1. Run assessment commands in [ASSESSMENT_COMMANDS.md](ASSESSMENT_COMMANDS.md) to identify exact cause
2. If runtime issue: Upgrade Function App to .NET 8 + Functions v4 (see Technical Debt #1 below)
3. If function key issue: Retrieve current key and update `frontend/main.js`
4. If Cosmos DB issue: Verify document exists and connection strings are valid
5. If CORS issue: Verify allowed origins include the custom domain

### 2. Hardcoded Secrets in Source Control

**Impact:** Medium — Security concern  
**Files Affected:**
- `frontend/main.js` — Contains Azure Function URL with function authorization code (`?code=M4oh...`)
- `frontend/js/azure_app_insights.js` — Contains Application Insights instrumentation key

**Risk:** The function key grants access to call the Function App. While the counter function is low-risk, this is a security anti-pattern.

**Remediation Options:**
- Change function auth level to `Anonymous` (counter is not sensitive)
- Use a backend-for-frontend pattern
- Inject values at build/deploy time instead of committing to source

## Technical Debt

### 1. .NET Core 3.1 and Azure Functions v3 End of Life

**Impact:** High — Blocks future deployments  
**Status:** .NET Core 3.1 reached End of Life on December 13, 2022. Azure Functions v3 reached EOL on December 13, 2022.

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

**Current State:** The `if` conditions using path-filter outputs are commented out in all workflows:
```yaml
# if: ${{ needs.changes.outputs.iac == 'true' }}
```

**Remediation:** Uncomment the `if` conditions after verifying they work correctly, or remove the `changes` job entirely if always-deploy is desired.

### 4. Manual Post-Deployment Steps

**Impact:** Medium — Error-prone deployment process

**Steps that require manual intervention after a new stack deployment:**

1. Retrieve Function App URL and function key → Update `frontend/main.js`
2. Retrieve App Insights connection string → Update `frontend/js/azure_app_insights.js`
3. Create initial Cosmos DB document via Azure Portal Data Explorer

**Remediation Options:**
- Add a workflow step to query the Function App URL and key from Azure, then inject into frontend files before upload
- Add a Bicep deployment script or Azure CLI step to seed the Cosmos DB document
- Use environment-specific configuration files instead of hardcoded values

### 5. jQuery and Frontend Library Versions

**Impact:** Low — Potential security vulnerabilities in outdated libraries

**Current Versions:**
| Library | Version | Latest |
|---|---|---|
| jQuery | 1.10.2 | 3.7.x |
| jQuery Migrate | 1.2.1 | 3.5.x |
| Font Awesome | 4.x | 6.x |
| Modernizr | Unknown (custom build) | 3.x |

### 6. Multi-Storage Account Architecture

**Impact:** Low — Three storage accounts serve identical content for three domains

The Cloudflare workflow deploys the same frontend content to three separate storage accounts, one for each domain. This adds complexity and cost. Consider whether a single storage account with Cloudflare routing to one origin would suffice.

### 7. Azure Service Principal Credential Format

**Impact:** Medium — The `--sdk-auth` flag is deprecated

The current setup uses the legacy `--sdk-auth` JSON format for `Azure/login`. Microsoft recommends migrating to:
- **OpenID Connect (OIDC) federated credentials** — no secrets to rotate, most secure
- **Client ID/Secret** with the newer `Azure/login@v2` format

See: [Configure Azure credentials for GitHub Actions](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
