# Infrastructure

> Deep-dive into the Azure Bicep templates that define every resource in the Azure Resume stack — from subscription-scoped orchestration down to individual modules.

**Source:** [`.iac/`](https://github.com/rmcveyhsawaknow/azure-resume-iac/tree/main/.iac) · [`docs/ARCHITECTURE.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/ARCHITECTURE.md)

---

## Table of Contents

- [IaC Layout](#iac-layout)
- [Orchestration Templates](#orchestration-templates)
- [Module Reference](#module-reference)
- [Resource Groups per Stack](#resource-groups-per-stack)
- [Naming Convention](#naming-convention)
- [Tags](#tags)
- [Key Design Decisions](#key-design-decisions)
- [See also](#see-also)

---

## IaC Layout

All Bicep templates live under `.iac/`:

```
.iac/
├── backend.bicep              # Subscription scope — backend orchestration
├── frontend.bicep             # Subscription scope — frontend orchestration
├── frontendCdn.bicep          # Subscription scope — Azure CDN variant (disabled)
└── modules/
    ├── apm/
    │   └── appinsights.bicep  # Application Insights component
    ├── cdn/
    │   ├── cdn.bicep          # Azure Front Door profile + endpoints
    │   └── cdnClassic.bicep   # Classic CDN (unused)
    ├── cosmos/
    │   └── cosmos.bicep       # Cosmos DB account, database, container
    ├── dns/
    │   └── azuredns.bicep     # Azure DNS records (CDN variant only)
    ├── functionapp/
    │   └── functionapp.bicep  # Function App + ASP + Storage + App Insights + Key Vault
    ├── keyvault/
    │   └── createKeyVaultSecret.bicep  # Helper: single Key Vault secret
    └── storageaccount/
        └── sa_staticsite.bicep  # Storage account for static website hosting
```

## Orchestration Templates

The two main templates deploy at **subscription scope** and create their own resource groups. GitHub Actions calls `az deployment sub create` for each.

### `backend.bicep`

Creates and wires up the entire backend stack:

1. **Resource group** — `{locationCode}-{appName}-be-{env}-{version}-rg`
2. **Cosmos DB** — via `modules/cosmos/cosmos.bicep` — serverless account, SQL database `azure-resume-click-count`, container `Counter` (partition key `/id`)
3. **Function App** — via `modules/functionapp/functionapp.bicep` — complete deployment including:
   - App Service Plan (Y1 consumption)
   - Storage Account (function runtime)
   - Application Insights (backend APM)
   - Key Vault with Cosmos DB connection strings as secrets
   - Function App configured with Key Vault references, managed identity, CORS

Cosmos DB outputs (connection strings) are passed from the cosmos module to the functionapp module so Key Vault secrets are seeded in a single deployment.

### `frontend.bicep`

Creates the frontend hosting layer:

1. **Resource group** — `{locationCode}-{appName}-fe-{env}-{version}-rg`
2. **Storage Account** — via `modules/storageaccount/sa_staticsite.bicep` — StorageV2, HTTPS-only
3. **Application Insights** — via `modules/apm/appinsights.bicep` — frontend monitoring

> **Note:** Static website hosting (`$web` container) is enabled *post-deployment* by the workflow using `az storage blob service-properties update`, not by Bicep (Bicep doesn't support this natively yet).

### `frontendCdn.bicep`

Used only by the disabled Azure CDN workflow variant. Deploys Azure Front Door Standard/Premium with a custom domain and managed TLS certificate. Not used in the active Cloudflare-based architecture.

## Module Reference

Each module is scoped to **resource group** and receives its naming components as parameters.

### `modules/cosmos/cosmos.bicep`

| What it creates | Configuration |
|---|---|
| Cosmos DB Account | Serverless capacity, SQL API, eventual consistency |
| SQL Database | `azure-resume-click-count` |
| SQL Container | `Counter`, partition key `/id` |

**Outputs:** Primary and secondary connection strings (passed to the functionapp module for Key Vault storage).

### `modules/functionapp/functionapp.bicep`

This is the most complex module — it creates five resources in one deployment:

| Resource | Key Settings |
|---|---|
| **App Service Plan** | Y1 (Dynamic/serverless), Linux |
| **Storage Account** | StorageV2, Standard_LRS, function runtime storage |
| **Application Insights** | Web type, backend APM |
| **Key Vault** | Standard SKU, access policies for the Function App managed identity |
| **Function App** | .NET 8 isolated, Functions v4, `httpsOnly: true`, `SystemAssigned` managed identity |

Function App settings reference Key Vault secrets using the `@Microsoft.KeyVault(SecretUri=...)` syntax — connection strings are never in plain text.

CORS allowed origins are parameterized so dev and prod can each specify their custom domain.

### `modules/storageaccount/sa_staticsite.bicep`

| What it creates | Configuration |
|---|---|
| Storage Account | StorageV2, Standard_LRS, HTTPS only, encryption at rest |

This module creates the storage account but not the static website configuration itself (that's a post-deploy CLI step).

### `modules/apm/appinsights.bicep`

| What it creates | Configuration |
|---|---|
| Application Insights | Web type, creates or references a Log Analytics workspace |

### `modules/keyvault/createKeyVaultSecret.bicep`

A small helper that creates a single secret in an existing Key Vault. Used by `functionapp.bicep` to store each Cosmos DB connection string individually.

### `modules/cdn/cdn.bicep` and `cdnClassic.bicep`

Azure Front Door and classic CDN profiles. These are only used by the disabled Azure CDN workflow variant and are not part of the active Cloudflare-based deployment.

### `modules/dns/azuredns.bicep`

Azure DNS CNAME and TXT records for domain validation (Azure CDN variant only). The active architecture uses Cloudflare DNS managed by `scripts/cloudflare-dns-record.sh`.

## Resource Groups per Stack

Each stack version creates two resource groups:

| Resource Group | Pattern | Contains |
|---|---|---|
| Backend | `{loc}-{app}-be-{env}-{ver}-rg` | Cosmos DB, Function App, ASP, Key Vault, Storage, App Insights |
| Frontend | `{loc}-{app}-fe-{env}-{ver}-rg` | Storage Account (static site), App Insights |

A pre-existing shared resource group (`glbl-ryanmcveyme-v1-rg`) holds Azure DNS zones — only used by the disabled CDN variant.

## Naming Convention

```
{locationCode}-{appName}-{environment}-{version}-{resourceType}
```

Storage accounts omit hyphens: `{locationCode}{appName}{environment}{version}sa`

See [Glossary](Glossary) for the full mapping of location codes, resource type suffixes, and other naming tokens.

## Tags

Every resource gets these standard tags (values injected by the workflow):

| Tag | Source |
|---|---|
| `Environment` | `prod` or `dev` |
| `CostCenter` | `azCF` (Cloudflare variant) |
| `GitActionIaCRunId` | `${{ github.run_id }}` |
| `GitActionIaCRunNumber` | `${{ github.run_number }}` |
| `GitActionIaCRunAttempt` | `${{ github.run_attempt }}` |
| `GitActionIacActionsLink` | Link to the workflow run |

Tags are passed as a parameter object to keep templates DRY.

## Key Design Decisions

- **Subscription-scoped orchestration** — orchestration templates create their own resource groups, so a single `az deployment sub create` call provisions everything
- **Managed identity over stored credentials** — the Function App authenticates to Key Vault using its `SystemAssigned` identity, no client secrets
- **Key Vault references** — Cosmos DB connection strings are stored in Key Vault and referenced in app settings using `@Microsoft.KeyVault(...)` syntax
- **Blue/green isolation** — each stack version gets completely separate resource groups, so old and new stacks can run in parallel during validation
- **HTTPS only** — all web-facing resources enforce `httpsOnly: true`
- **Encryption at rest** — enabled on all storage accounts

---

## See also

- [Architecture](Architecture) — high-level system overview and data flow
- [Deployment](Deployment) — how IaC templates are deployed, blue/green swap procedure
- [CI-CD](CI-CD) — workflow jobs that call the Bicep deployments
- [Configuration](Configuration) — environment variables passed to templates
