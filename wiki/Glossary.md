# Glossary

> Repo-specific terms, acronyms, and naming conventions used throughout this project.

**Source:** [`.github/copilot-instructions.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/.github/copilot-instructions.md) · [`docs/ARCHITECTURE.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/ARCHITECTURE.md)

---

## General Terms

| Term | Definition |
|---|---|
| **AgentGitOps** | The AI-assisted project management workflow used in this repo. Combines GitHub Copilot agents with `gh` CLI scripts to plan and execute a backlog. See [AgentGitOps](AgentGitOps). |
| **Blue/green deployment** | A deployment strategy where each new version creates a complete, isolated stack. The old stack stays running until the new one is validated, enabling zero-downtime swaps and easy rollback. |
| **Copilot Suitability** | A first-class field on every issue indicating whether the task can be delegated to an AI agent (`Yes`, `Partial`, `No`). Drives the Copilot Queue and AI productivity KPIs. |
| **Gap analysis finding** | An issue discovered during Phase 0 assessment that wasn't in the original plan. Tagged with the `gap-analysis-finding` label. |
| **Stack version** | The `stackVersion` env var (e.g., `v12`) that determines which blue/green stack is live. Embedded in all resource names. |
| **Stack** | A complete set of Azure resources (resource groups, Cosmos DB, Function App, Storage, Key Vault, DNS) for one environment at one version. |

## Azure Resource Types

| Suffix | Azure Resource | Example |
|---|---|---|
| `rg` | Resource Group | `cus1-resume-be-prod-v12-rg` |
| `fa` | Function App | `cus1-resumectr-prod-v12-fa` |
| `asp` | App Service Plan | `cus1-resumectr-prod-v12-asp` |
| `sa` | Storage Account | `cus1resumeprodv12sa` (no hyphens) |
| `kv` | Key Vault | `cus1-resume-prod-v12-kv` |
| `cmsdb` | Cosmos DB Account | `cus1-resume-prod-v12-cmsdb` |
| `ai` | Application Insights | `cus1-resume-prod-v12-ai` |

## Naming Convention Segments

| Segment | Description | Current Values |
|---|---|---|
| `locationCode` | Short Azure region code | `cus1` (maps to `eastus`) |
| `appName` | Application identifier | `resume` (frontend), `resumectr` (backend) |
| `environment` | Deployment tier | `prod`, `dev` |
| `version` | Stack version | `v12` |

Full pattern: `{locationCode}-{appName}-{environment}-{version}-{resourceType}`

Storage accounts omit hyphens: `{locationCode}{appName}{environment}{version}sa`

## Acronyms

| Acronym | Full Form |
|---|---|
| **AVM** | Azure Verified Modules — community patterns for Bicep resource definitions |
| **CDN** | Content Delivery Network (Cloudflare in this project) |
| **CORS** | Cross-Origin Resource Sharing |
| **IaC** | Infrastructure as Code (Azure Bicep) |
| **KPI** | Key Performance Indicator (used in retrospectives) |
| **OIDC** | OpenID Connect — planned replacement for SP secret-based auth |
| **SP** | Story Points (project management) or Service Principal (Azure auth) — context-dependent |
| **TLS** | Transport Layer Security (handled by Cloudflare proxy) |

## Branching Terminology

| Term | Definition |
|---|---|
| `main` | Production branch — pushes trigger prod deployment |
| `develop` | Integration branch — pushes trigger dev deployment |
| `feature/` | Feature branches — merge to `develop` |
| `copilot/` | Copilot agent–authored branches — merge to `develop` |
| `hotfix/` | Urgent fixes — branch from `main`, merge to both `main` and `develop` |

## Cloudflare DNS Terms

| Term | Definition |
|---|---|
| **Proxied (orange cloud)** | Traffic routes through Cloudflare CDN for TLS termination and caching |
| **DNS only (grey cloud)** | Record resolves directly without Cloudflare proxy — used for `asverify` validation CNAMEs |
| **Zone ID** | Unique identifier for the `ryanmcvey.me` DNS zone in Cloudflare |

---

## See also

- [Architecture](Architecture) — system components and naming in context
- [Infrastructure](Infrastructure) — Bicep modules and resource details
- [AgentGitOps](AgentGitOps) — project management workflow terminology
