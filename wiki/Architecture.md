# Architecture

> How the Azure Resume site fits together — from the user's browser through Cloudflare CDN, Azure Storage, Azure Functions, and Cosmos DB.

**Source:** [`docs/ARCHITECTURE.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/ARCHITECTURE.md) · [`docs/dev-environment-diagram.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/dev-environment-diagram.md)

---

## Table of Contents

- [High-Level Overview](#high-level-overview)
- [Component Map](#component-map)
- [Data Flow](#data-flow)
- [Resource Naming Convention](#resource-naming-convention)
- [Environment Topology](#environment-topology)
- [Tech Stack](#tech-stack)
- [See also](#see-also)

---

## High-Level Overview

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

## Component Map

| Component | Azure Service | Purpose |
|---|---|---|
| **CDN / DNS** | Cloudflare (Free) | TLS termination, caching, proxied CNAME for `ryanmcvey.me` |
| **Frontend** | Azure Storage (Static Website) | Serves the single-page HTML resume from the `$web` container |
| **Backend API** | Azure Functions (.NET 8, isolated v4) | `GetResumeCounter` — increments and returns the visitor count |
| **Database** | Azure Cosmos DB (Serverless, SQL API) | Stores `{ "id": "1", "count": N }` in the `Counter` container |
| **Secrets** | Azure Key Vault | Holds Cosmos DB connection strings as Key Vault references |
| **Monitoring** | Application Insights | Frontend + backend telemetry (separate instances per tier) |
| **Compute Plan** | App Service Plan (Y1) | Serverless consumption plan for the Function App |

## Data Flow

1. **User** visits `https://resume.ryanmcvey.me`
2. **Cloudflare** terminates TLS (orange-cloud proxy), serves cached static assets or forwards the request to the Azure Storage origin
3. **Azure Storage** returns `index.html`, CSS, JS, and images from the `$web` container
4. **`main.js`** in the browser calls `fetch()` to the Function App endpoint (`/api/GetResumeCounter`)
5. **Azure Functions** reads the current counter from Cosmos DB (via Key Vault–referenced connection string), increments it, writes it back, and returns the new count as JSON
6. **`main.js`** displays the count in the page footer

The Function App uses a **managed identity** (`SystemAssigned`) to access Key Vault. Cosmos DB connection strings are never exposed in app settings — they're referenced as `@Microsoft.KeyVault(SecretUri=...)`.

## Resource Naming Convention

All resources follow a consistent pattern:

```
{locationCode}-{appName}-{environment}-{version}-{resourceType}
```

| Segment | Description | Examples |
|---|---|---|
| `locationCode` | Short region code | `cus1` (maps to `eastus`) |
| `appName` | Application identifier | `resume` (frontend), `resumectr` (backend) |
| `environment` | Deployment tier | `prod`, `dev` |
| `version` | Stack version (blue/green) | `v12` |
| `resourceType` | Azure resource suffix | `rg`, `fa`, `kv`, `sa`, `cmsdb`, `ai`, `asp` |

**Storage accounts** omit hyphens (Azure naming rule): `cus1resumeprodv12sa`

**Examples:**
- Resource group: `cus1-resume-be-prod-v12-rg`
- Function App: `cus1-resumectr-prod-v12-fa`
- Cosmos DB: `cus1-resume-prod-v12-cmsdb`
- Key Vault: `cus1-resume-prod-v12-kv`

## Environment Topology

Both dev and prod run identical architectures as fully isolated stacks:

| Setting | Production | Development |
|---|---|---|
| Branch trigger | `main` | `develop` |
| `stackEnvironment` | `prod` | `dev` |
| `stackVersion` | `v12` | `v12` |
| DNS subdomain | `resume.ryanmcvey.me` | `resumedev.ryanmcvey.me` |
| GitHub environment | `production` | `development` |

Each stack version deploys completely separate resource groups, databases, storage accounts, and DNS records. See [Deployment](Deployment) for the blue/green swap procedure.

## Tech Stack

| Layer | Technology | Details |
|---|---|---|
| **Frontend** | HTML / CSS / JavaScript | Vanilla static site — no build step, no framework |
| **Backend** | C# / .NET 8 (LTS) | Azure Functions v4, isolated worker model |
| **Database** | Azure Cosmos DB | Serverless, SQL API, single `Counter` container |
| **Infrastructure** | Azure Bicep | All resources defined as code in `.iac/` |
| **CI/CD** | GitHub Actions | Automated deploy on push to `main` / `develop` |
| **CDN / DNS** | Cloudflare (Free) | Proxied CNAME for TLS termination and caching |
| **Secrets** | Azure Key Vault | Connection strings stored as Key Vault references |
| **Monitoring** | Application Insights | Frontend + backend telemetry |
| **Testing** | xUnit v3 + Moq | Backend unit tests in `backend/tests/` |

> For the full resource inventory with every Azure resource name, SKU, and configuration setting, see [`docs/ARCHITECTURE.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/ARCHITECTURE.md).

---

## See also

- [Infrastructure](Infrastructure) — Bicep module deep-dive and IaC layout
- [Deployment](Deployment) — blue/green strategy and end-to-end deploy procedure
- [Configuration](Configuration) — environment variables and secret sources
- [Glossary](Glossary) — naming conventions and repo-specific terms
