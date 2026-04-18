# Configuration

> Every environment variable, secret, and configuration value the project uses — and where each one comes from.

**Source:** [`docs/CICD_WORKFLOWS.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/CICD_WORKFLOWS.md) · [`docs/ARCHITECTURE.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/ARCHITECTURE.md) · [`frontend/config.js`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/frontend/config.js)

---

## Table of Contents

- [GitHub Secrets](#github-secrets)
- [Workflow Environment Variables](#workflow-environment-variables)
- [Function App Settings](#function-app-settings)
- [Frontend Runtime Config](#frontend-runtime-config)
- [Local Development](#local-development)
- [See also](#see-also)

---

## GitHub Secrets

These secrets must be configured in **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Purpose | How to Create |
|---|---|---|
| `AZURE_RESUME_GITHUB_SP` | Azure Service Principal JSON for `Azure/login@v2` | `az ad sp create-for-rbac --name "github-azure-resume" --role contributor --scopes /subscriptions/<id> --sdk-auth` |
| `CLOUDFLARE_TOKEN` | Cloudflare API token | Dashboard → My Profile → API Tokens → "Edit zone DNS" template (must also include Cache Purge permission) |
| `CLOUDFLARE_ZONE` | Zone ID for `ryanmcvey.me` | Dashboard → select zone → Overview → right sidebar "Zone ID" |

> **OIDC migration:** The `--sdk-auth` format is deprecated. A future improvement will migrate to OpenID Connect federated credentials. See [Troubleshooting](Troubleshooting) for details.

## Workflow Environment Variables

Set in each workflow file under the `env:` block:

| Variable | Production | Development | Purpose |
|---|---|---|---|
| `stackVersion` | `v12` | `v12` | Blue/green stack identifier |
| `stackEnvironment` | `prod` | `dev` | Deployment tier |
| `stackLocation` | `eastus` | `eastus` | Azure region |
| `stackLocationCode` | `cus1` | `cus1` | Short code for naming |
| `AppName` | `resume` | `resume` | Frontend app identifier |
| `AppBackendName` | `resumectr` | `resumectr` | Backend app identifier |
| `customDomainPrefix` | `resume` | `resumedev` | DNS subdomain prefix |
| `dnsZone` | `ryanmcvey.me` | `ryanmcvey.me` | Cloudflare DNS zone |
| `tagCostCenter` | `azCF` | `azCF` | Cost tracking tag |

These compose into resource names following the `{locationCode}-{appName}-{environment}-{version}-{resourceType}` convention.

## Function App Settings

Configured via Bicep (`modules/functionapp/functionapp.bicep`) and stored in the Function App's application settings:

| Setting | Source | Purpose |
|---|---|---|
| `AzureResumeConnectionStringPrimary` | Key Vault reference | Cosmos DB primary connection string |
| `AzureResumeConnectionStringSecondary` | Key Vault reference | Cosmos DB secondary connection string |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights output | Backend telemetry |
| `AzureWebJobsStorage` | Storage account connection | Function runtime storage |
| `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING` | Storage account connection | Content file share |
| `FUNCTIONS_WORKER_RUNTIME` | `dotnet-isolated` | Runtime identifier |
| `FUNCTIONS_EXTENSION_VERSION` | `~4` | Functions host version |

Key Vault references use the `@Microsoft.KeyVault(SecretUri=...)` syntax — Cosmos DB connection strings are never in plain text in app settings.

## Frontend Runtime Config

`frontend/config.js` is **generated at deploy time** by the CI/CD workflow (not committed to source). It provides:

| Variable | Example | Purpose |
|---|---|---|
| `defined_FUNCTION_API_BASE` | `https://cus1-resumectr-prod-v12-fa.azurewebsites.net` | Function App base URL |
| `defined_APPINSIGHTS_CONNECTION_STRING` | `InstrumentationKey=...` | Frontend App Insights |
| `defined_CLARITY_PROJECT_ID` | `abc123` | Microsoft Clarity tracking (optional) |
| `defined_STACK_VERSION` | `v12` | Stack version for footer display |
| `defined_STACK_ENVIRONMENT` | `prod` | Environment for footer display |

The workflow generates this file using a shell heredoc that expands environment variables:

```bash
cat > frontend/config.js <<EOF
const defined_FUNCTION_API_BASE = 'https://${functionAppName}.azurewebsites.net';
const defined_APPINSIGHTS_CONNECTION_STRING = '${appInsightsConnectionString}';
...
EOF
```

## Local Development

For local development, copy `backend/api/local.settings.example.json` to `local.settings.json` and fill in:

| Setting | Source | Notes |
|---|---|---|
| `AzureResumeConnectionStringPrimary` | Azure CLI or Cosmos Emulator | Required for counter to work |
| `AzureWebJobsStorage` | `UseDevelopmentStorage=true` | Uses Azurite or Storage Emulator |
| `FUNCTIONS_WORKER_RUNTIME` | `dotnet-isolated` | Must match production |
| `Host.CORS` | `http://localhost:7071,...` | Add your frontend origin |

`local.settings.json` is git-ignored — never commit it.

---

## See also

- [Getting Started](Getting-Started) — setting up the local environment
- [Security](Security) — how secrets are managed
- [CI-CD](CI-CD) — where these values are consumed in workflows
- [Infrastructure](Infrastructure) — the Bicep templates that set Function App config
