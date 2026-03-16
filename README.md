# Azure Resume IaC

Personal resume website deployed as a static site on Azure PaaS services, fronted by Cloudflare CDN, with a visitor counter powered by Azure Functions and Cosmos DB. All infrastructure is defined as code using Azure Bicep and deployed via GitHub Actions CI/CD.

**Live Site:** <https://resume.ryanmcvey.me/>

> Extended from the [ACG project](https://learn.acloud.guru/series/acg-projects/view/403) by [Drew Davis](https://github.com/davisdre/azure-resume/) with full Infrastructure as Code to deploy all Azure resources.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [CI/CD Workflows](#cicd-workflows)
- [Required Secrets and Credentials](#required-secrets-and-credentials)
- [Current Production Stack (v1)](#current-production-stack-v1)
- [Known Issues](#known-issues)
- [Development Setup](#development-setup)
- [Documentation](#documentation)

## Architecture Overview

```
                    ┌─────────────────────────┐
                    │   Cloudflare CDN/DNS     │
                    │   (ryanmcvey.me zone)    │
                    │   Proxied CNAME records  │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  Azure Storage Account   │
                    │  Static Website Hosting  │
                    │  (index.html, CSS, JS)   │
                    └────────────┬────────────┘
                                 │ fetch() from main.js
                    ┌────────────▼────────────┐
                    │   Azure Function App     │
                    │   GetResumeCounter       │
                    │   (.NET 8, isolated v4)  │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Azure Cosmos DB        │
                    │   (Serverless, SQL API)  │
                    │   Counter document       │
                    └─────────────────────────┘
```

**Supporting Services:** Key Vault (secrets), Application Insights (monitoring), App Service Plan (Y1 serverless)

## Repository Structure

```
├── .github/workflows/           # CI/CD pipeline definitions
│   ├── prod-full-stack-cloudflare.yml   # ACTIVE: Production (main branch)
│   ├── dev-full-stack-cloudflare.yml    # ACTIVE: Development (develop branch)
│   ├── prod-full-stack-azureCDN.yml     # DISABLED: Prod w/ Azure CDN
│   └── dev-full-stack-azureCDN.yml      # DISABLED: Dev w/ Azure CDN
├── .iac/                        # Azure Bicep templates
│   ├── backend.bicep            # Cosmos DB + Function App + Key Vault
│   ├── frontend.bicep           # Storage Accounts + App Insights
│   ├── frontendCdn.bicep        # Azure Front Door (CDN) + DNS
│   └── modules/                 # Reusable Bicep modules
│       ├── apm/appinsights.bicep
│       ├── cdn/cdn.bicep, cdnClassic.bicep
│       ├── cosmos/cosmos.bicep
│       ├── dns/azuredns.bicep
│       ├── functionapp/functionapp.bicep
│       ├── keyvault/kv.bicep, createKeyVaultSecret.bicep
│       └── storageaccount/sa_staticsite.bicep
├── backend/                     # Azure Function (visitor counter)
│   ├── api/                     # Function App source (.NET Core 3.1)
│   │   ├── GetResumeCounter.cs  # HTTP trigger function
│   │   ├── Counter.cs           # Counter model
│   │   ├── CosmosConstants.cs   # DB/container/document ID constants
│   │   ├── api.csproj           # Project file (netcoreapp3.1, Functions v3)
│   │   └── host.json            # Function host configuration
│   └── tests/                   # xUnit tests
│       ├── TestCounter.cs       # Counter increment test
│       └── ...                  # Test helpers
├── frontend/                    # Static resume website
│   ├── index.html               # Single-page resume
│   ├── main.js                  # Counter fetch + text rotation animation
│   ├── js/azure_app_insights.js # Application Insights SDK
│   ├── css/                     # Stylesheets and font libraries
│   ├── js/                      # jQuery, plugins, and utilities
│   ├── images/                  # Profile photo, cert badges, overlays
│   └── fonts/                   # LibreBaskerville, OpenSans web fonts
└── docs/                        # Extended documentation
    ├── ARCHITECTURE.md          # Detailed architecture and resource reference
    ├── CICD_WORKFLOWS.md        # CI/CD pipeline and credentials guide
    ├── KNOWN_ISSUES.md          # Known issues and technical debt
    ├── BACKLOG_PLANNING.md      # Phased backlog planning guide
    └── ASSESSMENT_COMMANDS.md   # CLI commands for harvesting current state
```

## CI/CD Workflows

Four GitHub Actions workflows exist; two are active (Cloudflare DNS), two are disabled (Azure CDN):

| Workflow | File | Branch Trigger | Status | DNS Provider |
|---|---|---|---|---|
| Production Cloudflare | `prod-full-stack-cloudflare.yml` | `main` | **Active** | Cloudflare |
| Development Cloudflare | `dev-full-stack-cloudflare.yml` | `develop` | **Active** | Cloudflare |
| Production Azure CDN | `prod-full-stack-azureCDN.yml` | `disabled` | Disabled | Azure DNS |
| Development Azure CDN | `dev-full-stack-azureCDN.yml` | `disabled` | Disabled | Azure DNS |

Each active workflow contains 4 jobs executed sequentially:

1. **changes** — Detects which paths changed (`.iac/`, `backend/`, `frontend/`)
2. **deployIac** — Deploys Bicep templates for backend and frontend infrastructure
3. **buildDeployBackend** — Builds .NET Function App, runs unit tests, deploys to Azure
4. **buildDeployFrontend** — Uploads static files to Azure Storage blob containers

> **Note:** Change detection (`if` conditions) is currently commented out — all jobs run on every push regardless of which paths changed.

See [docs/CICD_WORKFLOWS.md](docs/CICD_WORKFLOWS.md) for complete workflow details.

## Required Secrets and Credentials

The following GitHub repository secrets must be configured:

| Secret Name | Purpose | How to Create |
|---|---|---|
| `AZURE_RESUME_GITHUB_SP` | Azure Service Principal (JSON) | `az ad sp create-for-rbac --name <name> --role contributor --scopes /subscriptions/<subId> --sdk-auth` |
| `CLOUDFLARE_TOKEN` | Cloudflare API token | Cloudflare Dashboard → My Profile → API Tokens |
| `CLOUDFLARE_ZONE` | Zone ID for `ryanmcvey.me` | Cloudflare Dashboard → Zone Overview (right sidebar) |

> **⚠️ Credential Status:** The Azure SP credential and Cloudflare tokens likely need to be verified or rotated. The SP credential uses the legacy `--sdk-auth` format which has been deprecated by `Azure/login`. See [docs/CICD_WORKFLOWS.md](docs/CICD_WORKFLOWS.md) for migration guidance.

See [docs/CICD_WORKFLOWS.md](docs/CICD_WORKFLOWS.md) for the full secrets and credentials reference.

## Current Production Stack (v1)

**Environment Variables (from `prod-full-stack-cloudflare.yml`):**

| Variable | Value | Description |
|---|---|---|
| `stackVersion` | `v1` | Stack version identifier |
| `stackEnvironment` | `prod` | Environment tier |
| `stackLocation` | `eastus` | Azure region |
| `stackLocationCode` | `cus1` | Location code prefix for resource names |
| `AppName` | `resume` | Application name (used in resource naming) |
| `AppBackendName` | `resumectr` | Backend function app name component |
| `dnsZone` | `ryanmcvey.me` | Custom domain zone |
| `tagCostCenter` | `azCF` | Cost center tag value |
| `rgDns` | `glbl-ryanmcveyme-v1-rg` | Pre-existing DNS resource group |

**Derived Resource Names (production):**

| Resource | Name | Type |
|---|---|---|
| Backend RG | `cus1-resume-be-prod-v1-rg` | Resource Group |
| Frontend RG | `cus1-resume-fe-prod-v1-rg` | Resource Group |
| Cosmos DB | `cus1-resume-prod-v1-cmsdb` | Cosmos DB Account |
| Function App | `cus1-resumectr-prod-v1-fa` | Function App |
| Key Vault | `cus1-resume-prod-v1-kv` | Key Vault |
| Storage (FE) | `cus1resumeprodv1sa` | Storage Account (static site) |

**Resource Naming Convention:** `{locationCode}-{appName}-{environment}-{version}-{resourceType}`

## Known Issues

| Issue | Impact | Details |
|---|---|---|
| **Visitor counter not working** | Page counter shows nothing | Azure Function may be stopped, Cosmos DB may be inaccessible, or function key may have changed. See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) |
| **.NET Core 3.1 end of life** | Build/deploy may fail | Runtime reached EOL Dec 2022. Azure Functions v3 is also deprecated. Needs upgrade to .NET 8+ and Functions v4 |
| **Hardcoded function URL and key in `main.js`** | Security/maintenance concern | Function authorization code is committed to source control |
| **Hardcoded App Insights connection string** | Maintenance concern | Instrumentation key is committed in `azure_app_insights.js` |
| **Deprecated GitHub Actions syntax** | Workflow warnings | Uses `::set-output` (deprecated) instead of `$GITHUB_OUTPUT` |
| **Legacy `Azure/login` format** | May stop working | Uses `--sdk-auth` JSON format which is deprecated |

See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for complete details and remediation guidance.

## Development Setup

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/) with [recommended extensions](.vscode/extensions.json)
- [Azure Functions Core Tools v4](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local)
- [.NET 8 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/8.0) (isolated worker model with System.Text.Json)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (bundled with Azure CLI)

### Initial Deployment Steps

1. Create an Azure Service Principal and store as GitHub secret `AZURE_RESUME_GITHUB_SP`
2. Configure Cloudflare API token and zone IDs as GitHub secrets
3. Update workflow environment variables for your environment
4. Push to trigger the workflow — Bicep deploys all infrastructure
5. **Manual post-deployment steps** (not yet automated):
   - Update `frontend/main.js` with the Function App URL and function key
   - Update `frontend/js/azure_app_insights.js` with the App Insights connection string
   - Cosmos DB seed document is created automatically by the deployment workflow (see `scripts/seed-cosmos-db.sh`)
6. Push again to deploy frontend with updated configuration values

## Documentation

| Document | Description |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed architecture, resource inventory, and Bicep module reference |
| [docs/CICD_WORKFLOWS.md](docs/CICD_WORKFLOWS.md) | Complete CI/CD workflow reference and credentials guide |
| [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) | Known issues, technical debt, and remediation guidance |
| [docs/BACKLOG_PLANNING.md](docs/BACKLOG_PLANNING.md) | Phased backlog planning guide for the content and infrastructure update project |
| [docs/ASSESSMENT_COMMANDS.md](docs/ASSESSMENT_COMMANDS.md) | Azure CLI and Cloudflare CLI commands for harvesting current deployed state |
