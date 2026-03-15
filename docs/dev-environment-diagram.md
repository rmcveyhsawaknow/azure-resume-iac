# Development Environment Architecture Diagram

Visual reference for the `dev` (v1) stack deployed via the `develop` branch. Resource names are derived from the [`dev-full-stack-cloudflare.yml`](../.github/workflows/dev-full-stack-cloudflare.yml) workflow.

> **Companion doc:** See [ARCHITECTURE.md — Development Resource Inventory](ARCHITECTURE.md#development-resource-inventory-v1) for the full tabular inventory.

```mermaid
flowchart TB
    %% ── Styles ──────────────────────────────────────────────
    classDef cloudflare fill:#F6821F,stroke:#E05D00,color:#fff,stroke-width:2px
    classDef azure fill:#0078D4,stroke:#005A9E,color:#fff,stroke-width:2px
    classDef azureLight fill:#50E6FF,stroke:#0078D4,color:#000,stroke-width:1px
    classDef github fill:#24292E,stroke:#1B1F23,color:#fff,stroke-width:2px
    classDef user fill:#6C6C6C,stroke:#4A4A4A,color:#fff,stroke-width:2px
    classDef keyvault fill:#0078D4,stroke:#FFB900,color:#fff,stroke-width:2px,stroke-dasharray:5 5

    %% ── User ────────────────────────────────────────────────
    USER((("👤 User<br/>Browser"))):::user

    %% ── Cloudflare ──────────────────────────────────────────
    subgraph CF ["☁️ Cloudflare — DNS Zone: ryanmcvey.me"]
        direction TB
        CF_PROXY["CDN Proxy + TLS Termination<br/><i>Proxied (orange cloud)</i>"]:::cloudflare
        CF_CNAME["CNAME: resumedevv1<br/>→ cus1resumedevv1sa.z13.web.core.windows.net"]:::cloudflare
        CF_VERIFY["CNAME: asverify.resumedevv1<br/>→ asverify.cus1resumedevv1sa.z13.web.core.windows.net<br/><i>DNS only (grey cloud)</i>"]:::cloudflare
    end

    %% ── Azure Frontend Resource Group ───────────────────────
    subgraph FE_RG ["Azure — cus1-resume-fe-dev-v1-rg"]
        direction TB
        FE_SA["📦 Storage Account<br/><b>cus1resumedevv1sa</b><br/>Static Website ($web)<br/>StorageV2 · Standard_LRS<br/>HTTPS only"]:::azure
        FE_AI["📊 App Insights<br/><b>cus1-resume-dev-v1-ai</b><br/>Frontend monitoring"]:::azure
    end

    %% ── Azure Backend Resource Group ────────────────────────
    subgraph BE_RG ["Azure — cus1-resume-be-dev-v1-rg"]
        direction TB
        FA["⚡ Function App<br/><b>cus1-resumectr-dev-v1-fa</b><br/>dotnet-isolated · .NET 8 · v4<br/>CORS: https://resumedevv1.ryanmcvey.me<br/>Managed Identity (SystemAssigned)"]:::azure
        ASP["📋 App Service Plan<br/><b>cus1-resumectr-dev-v1-asp</b><br/>Consumption Y1 (serverless)"]:::azure
        KV["🔑 Key Vault<br/><b>cus1-resume-dev-v1-kv</b><br/>Standard SKU<br/>Secrets:<br/>• AzureResumeConnectionStringPrimary<br/>• AzureResumeConnectionStringSecondary"]:::keyvault
        COSMOS["🗄️ Cosmos DB<br/><b>cus1-resume-dev-v1-cmsdb</b><br/>SQL API · Serverless · Eventual<br/>DB: azure-resume-click-count<br/>Container: Counter (pk: /id)"]:::azure
        BE_SA["📦 Storage Account<br/><b>cus1resumectrdevv1sa</b><br/>Function runtime storage<br/>StorageV2 · Standard_LRS"]:::azure
        BE_AI["📊 App Insights<br/><b>cus1-resumectr-dev-v1-ai</b><br/>Backend APM"]:::azure
    end

    %% ── GitHub Actions CI/CD ────────────────────────────────
    subgraph CICD ["GitHub Actions — develop branch"]
        direction LR
        GH_CHANGES["🔍 changes<br/>Path filters"]:::github
        GH_IAC["🏗️ deployDevelopmentIac<br/>Bicep templates"]:::github
        GH_BACKEND["⚙️ buildDeployDevelopment<br/>Backend (.NET 8)"]:::github
        GH_FRONTEND["🌐 buildDeployDevelopment<br/>Frontend (static)"]:::github
    end

    %% ── Data Flow ───────────────────────────────────────────
    USER -->|"https://resumedevv1.ryanmcvey.me"| CF_PROXY
    CF_PROXY --> CF_CNAME
    CF_CNAME -->|"Origin request"| FE_SA
    CF_VERIFY -.->|"Domain validation"| FE_SA
    FE_SA -.-> FE_AI

    FE_SA -->|"fetch() → /api/GetResumeCounter"| FA
    FA --> ASP
    FA -->|"Key Vault reference"| KV
    KV -->|"Connection strings"| COSMOS
    FA -->|"Read/Write counter"| COSMOS
    FA -.-> BE_SA
    FA -.-> BE_AI

    %% ── CI/CD Flow ──────────────────────────────────────────
    GH_CHANGES --> GH_IAC
    GH_IAC --> GH_BACKEND
    GH_BACKEND --> GH_FRONTEND
    GH_IAC -->|"az deployment sub create"| FE_RG
    GH_IAC -->|"az deployment sub create"| BE_RG
    GH_BACKEND -->|"Azure/functions-action"| FA
    GH_FRONTEND -->|"az storage blob upload-batch"| FE_SA
    GH_FRONTEND -->|"Purge cache"| CF_PROXY

    %% ── Subgraph Styling ────────────────────────────────────
    style CF fill:#FFF3E0,stroke:#F6821F,stroke-width:3px,color:#E05D00
    style FE_RG fill:#E3F2FD,stroke:#0078D4,stroke-width:3px,color:#005A9E
    style BE_RG fill:#E3F2FD,stroke:#0078D4,stroke-width:3px,color:#005A9E
    style CICD fill:#F5F5F5,stroke:#24292E,stroke-width:3px,color:#24292E
```

## Legend

| Color | Provider | Hex |
|---|---|---|
| 🟠 Orange nodes / border | Cloudflare | `#F6821F` (fill), `#E05D00` (stroke) |
| 🔵 Blue nodes / border | Microsoft Azure | `#0078D4` (fill), `#005A9E` (stroke) |
| ⚫ Dark nodes | GitHub Actions | `#24292E` (fill) |
| 🔑 Dashed border (blue/gold) | Key Vault (secrets) | `#0078D4` fill, `#FFB900` stroke |

## Notes

- **Solid arrows** represent runtime data flow (user requests, API calls, secret lookups).
- **Dashed arrows** represent telemetry/monitoring or validation flows.
- **CI/CD arrows** show the deployment pipeline from GitHub Actions to Azure and Cloudflare.
- The Cloudflare CDN proxy also terminates TLS — the user never hits the Azure Storage endpoint directly.
- The `asverify` CNAME is DNS-only (grey cloud) and used solely for Azure custom domain validation.
- Cosmos DB connection strings are stored in Key Vault and referenced by the Function App via `@Microsoft.KeyVault(...)` app setting syntax.
