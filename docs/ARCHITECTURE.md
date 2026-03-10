# Architecture Reference

This document provides a detailed reference of the Azure Resume IaC architecture, resource inventory, and Bicep module structure.

## High-Level Architecture

```
                    ┌──────────────────────────────────────────────────┐
                    │              Cloudflare (Free Plan)              │
                    │  DNS zones: ryanmcvey.me / .net / .cloud        │
                    │  CNAME: resume → storage static site endpoint    │
                    │  Proxy: enabled (orange cloud) for TLS + CDN    │
                    │  asverify CNAME: DNS-only for domain validation  │
                    └──────────────┬───────────────────────────────────┘
                                   │
        ┌──────────────────────────▼───────────────────────────┐
        │              Frontend Resource Group                  │
        │         cus1-resume-fe-prod-v1-rg                    │
        │                                                       │
        │  ┌─────────────────┐  ┌───────────────┐             │
        │  │  Storage Acct 1 │  │ Storage Acct 2│  + Acct 3   │
        │  │  Static Website │  │ Static Website│             │
        │  │  (cus1resume     │  │ (cus1resume2  │             │
        │  │   prodv1sa)      │  │  prodv1sa)    │             │
        │  └─────────────────┘  └───────────────┘             │
        │                                                       │
        │  ┌─────────────────┐                                 │
        │  │  App Insights   │  (frontend monitoring)          │
        │  └─────────────────┘                                 │
        └──────────────────────────────────────────────────────┘
                                   │
                    fetch() call from frontend main.js
                                   │
        ┌──────────────────────────▼───────────────────────────┐
        │              Backend Resource Group                    │
        │         cus1-resume-be-prod-v1-rg                    │
        │                                                       │
        │  ┌─────────────────┐  ┌───────────────┐             │
        │  │  Function App   │  │  App Service  │             │
        │  │  (cus1-resumectr│  │  Plan (Y1     │             │
        │  │   -prod-v1-fa)  │  │  serverless)  │             │
        │  └────────┬────────┘  └───────────────┘             │
        │           │                                           │
        │  ┌────────▼────────┐  ┌───────────────┐             │
        │  │   Cosmos DB     │  │  Key Vault    │             │
        │  │  (serverless)   │  │  (connection  │             │
        │  │  SQL API        │  │   strings)    │             │
        │  └─────────────────┘  └───────────────┘             │
        │                                                       │
        │  ┌─────────────────┐  ┌───────────────┐             │
        │  │  Storage Acct   │  │  App Insights │             │
        │  │  (function app) │  │  (backend APM)│             │
        │  └─────────────────┘  └───────────────┘             │
        └──────────────────────────────────────────────────────┘

        ┌──────────────────────────────────────────────────────┐
        │              DNS Resource Group                       │
        │         glbl-ryanmcveyme-v1-rg                       │
        │  (Pre-existing, managed separately)                  │
        │  Azure DNS zones (used by Azure CDN variant only)    │
        └──────────────────────────────────────────────────────┘
```

## Resource Naming Convention

All resources follow a consistent naming pattern:

```
{locationCode}-{appName}-{environment}-{version}-{resourceType}
```

| Component | Description | Examples |
|---|---|---|
| `locationCode` | Azure region short code | `cus1` (Central US), `zus1` (used in Azure CDN variant) |
| `appName` | Application identifier | `resume` (frontend), `resumectr` (backend) |
| `environment` | Deployment tier | `prod`, `dev` |
| `version` | Stack version | `v1` (production), `v66` (dev) |
| `resourceType` | Azure resource suffix | `rg`, `fa`, `kv`, `sa`, `cmsdb`, `ai`, `asp` |

**Storage account names** omit hyphens (Azure requirement): `{locationCode}{appName}{environment}{version}sa`

## Production Resource Inventory (v1)

### Resource Groups

| Resource Group | Purpose |
|---|---|
| `cus1-resume-be-prod-v1-rg` | Backend: Cosmos DB, Function App, Key Vault, Storage, App Insights |
| `cus1-resume-fe-prod-v1-rg` | Frontend: 3× Storage Accounts (static sites), App Insights |
| `glbl-ryanmcveyme-v1-rg` | DNS zones (pre-existing, shared) |

### Backend Resources

| Resource | Name | Type | SKU/Tier |
|---|---|---|---|
| Cosmos DB Account | `cus1-resume-prod-v1-cmsdb` | `Microsoft.DocumentDB/databaseAccounts` | Serverless |
| Cosmos DB Database | `azure-resume-click-count` | SQL Database | — |
| Cosmos DB Container | `Counter` | SQL Container | Partition key: `/id` |
| Function App | `cus1-resumectr-prod-v1-fa` | `Microsoft.Web/sites` | Consumption (Y1) |
| App Service Plan | `cus1-resumectr-prod-v1-asp` | `Microsoft.Web/serverfarms` | Y1 (Dynamic) |
| Key Vault | `cus1-resume-prod-v1-kv` | `Microsoft.KeyVault/vaults` | Standard |
| Storage Account | `cus1resumectrprodv1sa` | `Microsoft.Storage/storageAccounts` | StorageV2 |
| App Insights | `cus1-resumectr-prod-v1-ai` | `Microsoft.Insights/components` | Web |

### Frontend Resources

| Resource | Name | Type | Custom Domain |
|---|---|---|---|
| Storage Acct #1 | `cus1resumeprodv1sa` | Static Website | `resume.ryanmcvey.me` |
| Storage Acct #2 | `cus1resume2prodv1sa` | Static Website | `resume.ryanmcvey.net` |
| Storage Acct #3 | `cus1resume3prodv1sa` | Static Website | `resume.ryanmcvey.cloud` |
| App Insights | `cus1-resume-prod-v1-ai` | `Microsoft.Insights/components` | — |

### DNS Configuration (Cloudflare)

| Zone | Record Type | Name | Content | Proxy |
|---|---|---|---|---|
| `ryanmcvey.me` | CNAME | `resume` | `cus1resumeprodv1sa.z13.web.core.windows.net` | Proxied (orange) |
| `ryanmcvey.me` | CNAME | `asverify.resume` | `asverify.cus1resumeprodv1sa...` | DNS only |
| `ryanmcvey.net` | CNAME | `resume` | `cus1resume2prodv1sa...` | Proxied |
| `ryanmcvey.cloud` | CNAME | `resume` | `cus1resume3prodv1sa...` | Proxied |

## Development Stack (v66)

The development environment uses different naming to avoid conflicts:

| Variable | Production | Development |
|---|---|---|
| `stackVersion` | `v1` | `v66` |
| `stackEnvironment` | `prod` | `dev` |
| `AppName` | `resume` | `bevis` |
| Branch trigger | `main` | `develop` |
| DNS subdomain | `resume.{zone}` | `bevisdevv66.{zone}` |

## Bicep Module Reference

### Main Templates

#### `backend.bicep` (Subscription Scope)

Orchestrates all backend resources:
- Creates the backend resource group
- Deploys Cosmos DB via `modules/cosmos/cosmos.bicep`
- Deploys Function App stack via `modules/functionapp/functionapp.bicep`
- Passes Cosmos DB outputs (connection strings) to the function app module

**Key Parameters:**
- Resource group name, Cosmos DB configuration
- Function App naming (storage, App Insights, ASP, function app, Key Vault)
- CORS URIs (up to 3 custom domains + CDN endpoint)
- Tagging (Git Action run metadata, environment, cost center)

#### `frontend.bicep` (Subscription Scope)

Orchestrates frontend resources:
- Creates the frontend resource group
- Deploys 3 storage accounts via `modules/storageaccount/sa_staticsite.bicep`
- Deploys App Insights via `modules/apm/appinsights.bicep`

> **Note:** Static website hosting is enabled post-deployment by the GitHub Actions workflow using `az storage blob service-properties update`, not by Bicep.

#### `frontendCdn.bicep` (Subscription Scope)

Used only by the Azure CDN workflow variant (currently disabled):
- Deploys Azure Front Door Standard/Premium profile
- Configures custom domain with managed TLS certificate
- Creates Azure DNS records for domain validation

### Modules

| Module | Path | Purpose |
|---|---|---|
| `appinsights.bicep` | `modules/apm/` | Creates Application Insights component |
| `cdn.bicep` | `modules/cdn/` | Azure Front Door profile, endpoint, origin group, custom domain, route |
| `cdnClassic.bicep` | `modules/cdn/` | Classic CDN profile (not currently used) |
| `cosmos.bicep` | `modules/cosmos/` | Cosmos DB account (serverless), SQL database, container |
| `azuredns.bicep` | `modules/dns/` | Azure DNS CNAME and TXT records (for Azure CDN variant) |
| `functionapp.bicep` | `modules/functionapp/` | Function App, ASP, Storage, App Insights, Key Vault with secrets |
| `kv.bicep` | `modules/keyvault/` | Standalone Key Vault creation (not currently used in main flow) |
| `createKeyVaultSecret.bicep` | `modules/keyvault/` | Helper to create a single Key Vault secret |
| `sa_staticsite.bicep` | `modules/storageaccount/` | Storage account for static website hosting |

## Function App Details

### Runtime Configuration

| Setting | Value |
|---|---|
| Runtime | .NET Core 3.1 (netcoreapp3.1) |
| Functions Version | v3 (`FUNCTIONS_EXTENSION_VERSION: ~3`) |
| Worker Runtime | `dotnet` |
| Hosting Plan | Consumption (Y1, serverless) |
| Auth Level | Function (requires function key) |

### App Settings (via Bicep/Key Vault)

| Setting | Source | Purpose |
|---|---|---|
| `AzureResumeConnectionStringPrimary` | Key Vault reference | Cosmos DB primary connection string |
| `AzureResumeConnectionStringSecondary` | Key Vault reference | Cosmos DB secondary connection string |
| `APPINSIGHTS_INSTRUMENTATIONKEY` | App Insights output | APM instrumentation |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights output | APM connection |
| `AzureWebJobsStorage` | Storage account | Function runtime storage |
| `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING` | Storage account | Content share |
| `FUNCTIONS_WORKER_RUNTIME` | `dotnet` | Runtime identifier |
| `FUNCTIONS_EXTENSION_VERSION` | `~3` | Functions host version |

### Cosmos DB Schema

```json
{
  "id": "1",
  "count": 0
}
```

- **Database:** `azure-resume-click-count`
- **Container:** `Counter`
- **Partition Key:** `/id`
- **Consistency:** Eventual
- **Capacity Mode:** Serverless

## Frontend Details

### Static Site Content

The frontend is a single-page resume website served from Azure Storage static website hosting. Key files:

| File | Purpose |
|---|---|
| `index.html` | Main resume page with sections: Header, About, Resume, Counter |
| `main.js` | Visitor counter fetch logic + text rotation animation |
| `js/azure_app_insights.js` | Application Insights SDK initialization |
| `css/` | Core styles, Font Awesome 4.x, Fontello icons |
| `js/` | jQuery 1.10.2, FitText, FlexSlider, Magnific Popup, Modernizr, Waypoints |

### Hardcoded Configuration Values

These values in the frontend source must be updated manually after each new stack deployment:

| File | Value | Current Content |
|---|---|---|
| `main.js` | `functionApiUrl` | `https://cus1-resumectr-prod-v1-fa.azurewebsites.net/api/GetResumeCounter?code=...` |
| `js/azure_app_insights.js` | Connection string | `InstrumentationKey=9bdff2b7-...` |
