# Azure Resume IaC

[![Production Deploy](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/prod-full-stack-cloudflare.yml/badge.svg)](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/prod-full-stack-cloudflare.yml)
[![Dev Deploy](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/dev-full-stack-cloudflare.yml/badge.svg)](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/dev-full-stack-cloudflare.yml)
[![Backend CI](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/backend-ci.yml/badge.svg?branch=develop)](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/backend-ci.yml)

Personal resume website deployed as a static site on Azure PaaS services, fronted by Cloudflare CDN, with a visitor counter powered by Azure Functions and Cosmos DB. All infrastructure is defined as code using Azure Bicep and deployed via GitHub Actions CI/CD.

**Live Site:** <https://resume.ryanmcvey.me/>

> Extended from the [ACG project](https://learn.acloud.guru/series/acg-projects/view/403) by [Drew Davis](https://github.com/davisdre/azure-resume/) with full Infrastructure as Code to deploy all Azure resources.

---

## 🤖 AgentGitOps — AI-Powered Project Management

This repository uses **AgentGitOps**, a repeatable workflow that combines AI coding agents (GitHub Copilot) with `gh` CLI automation to plan, populate, and burn down a project backlog. The entire `bootstrap/` folder is portable — copy it into any repo to go from goals to executing backlog in hours, not days.

**👉 [Full AgentGitOps Guide →](bootstrap/README.md)**

### Key Concepts

**Copilot Suitability** is a first-class field in every issue and project view. It determines how much of each task can be delegated to a GitHub Copilot agent and is the primary driver of AI productivity measurement:

| Field value | Meaning | When to Use |
|---|---|---|
| `Yes` | Fully automatable | Code generation, refactoring, test writing, docs, scripting |
| `Partial` | Agent assists, human guides | Requires judgment — human reviews and directs |
| `No` | Human-only | Portal access, credentials, manual verification |

The corresponding GitHub issue labels are `Copilot: Yes`, `Copilot: Partial`, and `Copilot: No`; these labels should always mirror the `Copilot Suitable` Project field value for each issue.

> The **Copilot Queue** project view (filter: `Copilot Suitable = Yes`, sorted by Phase → Priority) is the primary interface for assigning work to AI agents. Tracking which issues have the **Copilot Suitable** field set to `Yes` (and the corresponding `Copilot: Yes` label) enables the Human vs AI productivity KPI: *AI SP delivered ÷ total SP*.

**Issue Status** tracks the lifecycle of every issue through the board. These values are implemented as options on the single-select **Status** field in the GitHub Project (one board column per value; `bootstrap/setup-github-project.sh` prints a manual checklist, and you must configure these Status options yourself in the Project settings after running it). The full status set is:

`🔲 Backlog` → `✅ Ready` → `🔄 In Progress` → `👀 In Review` → `Done` | `🚫 Blocked` | `📦 Deferred`

### Quick Start

```bash
# 1. Copy bootstrap/ and .github/ISSUE_TEMPLATE/ into your repo
# 2. Check prerequisites
./bootstrap/check-prerequisites.sh

# 3. Follow Sessions 0–5 (each includes a copy-paste agent prompt)
#    See bootstrap/README.md for details
```

### Workflow at a Glance

| Session | Name | Role | Output |
|---|---|---|---|
| 0 | Goal-Focused Backlog Planning | PM / Business Driver | `docs/BACKLOG_PLANNING.md` + `artifacts/backlog.csv` |
| 1 | Bootstrap — Copilot Instructions | Human | `.github/copilot-instructions.md` |
| 2 | Backlog Research | Agent | `artifacts/backlog-issues/*.md` + docs |
| 3 | Issue Population | Human + Agent | GitHub Issues, Labels, Milestones, Project |
| 4 | Assessment Execution | Human + Agent | Gap analysis findings, assessment artifacts |
| 5+ | Backlog Burn-Down | Human + Agent | Code changes, PRs, deployments |

### Key Scripts

| Script | Purpose |
|---|---|
| [`bootstrap/setup-github-labels.sh`](bootstrap/setup-github-labels.sh) | Create/update all labels (9 categories, idempotent) |
| [`bootstrap/setup-github-milestones.sh`](bootstrap/setup-github-milestones.sh) | Create milestones with due dates for Roadmap |
| [`bootstrap/create-backlog-issues.sh`](bootstrap/create-backlog-issues.sh) | Create issues from `.md` files with auto-labels |
| [`bootstrap/setup-github-project.sh`](bootstrap/setup-github-project.sh) | Create GitHub Project V2 + custom fields + add issues |
| [`bootstrap/generate-phase-retrospective.sh`](bootstrap/generate-phase-retrospective.sh) | Generate retrospective report with SP velocity and AI KPIs |

> See [`bootstrap/agentgitops-instructions.md`](bootstrap/agentgitops-instructions.md) for the full workflow guide with Mermaid diagrams, role definitions, label taxonomy, and story point capacity model.

---

## Table of Contents

- [AgentGitOps — AI-Powered Project Management](#-agentgitops--ai-powered-project-management)
- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [CI/CD Workflows](#cicd-workflows)
- [Blue/Green Deployment Strategy](#bluegreen-deployment-strategy)
- [Required Secrets and Credentials](#required-secrets-and-credentials)
- [Development Setup](#development-setup)
- [Known Issues & Technical Debt](#known-issues--technical-debt)
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

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the detailed architecture reference with full resource inventories and Bicep module documentation.

## Tech Stack

| Layer | Technology | Details |
|---|---|---|
| **Frontend** | HTML / CSS / JavaScript | Vanilla static site — no build step or framework |
| **Backend** | C# / .NET 8 (LTS) | Azure Functions v4, isolated worker model |
| **Database** | Azure Cosmos DB | Serverless, SQL API, single `Counter` container |
| **Infrastructure** | Azure Bicep | All resources defined as code in `.iac/` |
| **CI/CD** | GitHub Actions | Automated deploy on push to `main` / `develop` |
| **CDN / DNS** | Cloudflare (Free) | Proxied CNAME for TLS termination and caching |
| **Secrets** | Azure Key Vault | Connection strings stored as Key Vault references |
| **Monitoring** | Application Insights | Frontend + backend telemetry |
| **Testing** | xUnit v3 + Moq | Backend unit tests in `backend/tests/` |
| **Project Mgmt** | AgentGitOps | AI-assisted backlog via [`bootstrap/`](bootstrap/) |

## Repository Structure

```
├── .github/workflows/           # CI/CD pipeline definitions
│   ├── prod-full-stack-cloudflare.yml   # ACTIVE: Production (main branch)
│   ├── dev-full-stack-cloudflare.yml    # ACTIVE: Development (develop branch)
│   ├── backend-ci.yml                   # CI: build + test on backend changes (push & PR)
│   ├── prod-full-stack-azureCDN.yml     # DISABLED: Prod w/ Azure CDN
│   └── dev-full-stack-azureCDN.yml      # DISABLED: Dev w/ Azure CDN
├── .iac/                        # Azure Bicep templates
│   ├── backend.bicep            # Cosmos DB + Function App + Key Vault
│   ├── frontend.bicep           # Storage Accounts + App Insights
│   ├── frontendCdn.bicep        # Azure Front Door (CDN) + DNS
│   └── modules/                 # Reusable Bicep modules
├── backend/                     # Azure Function (visitor counter)
│   ├── api/                     # Function App source (.NET 8, isolated worker)
│   │   ├── GetResumeCounter.cs  # HTTP trigger function
│   │   ├── Counter.cs           # Counter model
│   │   ├── CosmosConstants.cs   # DB/container/document ID constants
│   │   ├── api.csproj           # Project file (net8.0, Functions v4 isolated)
│   │   └── host.json            # Function host configuration
│   └── tests/                   # xUnit v3 tests
│       └── TestCounter.cs       # Counter unit tests
├── frontend/                    # Static resume website
│   ├── index.html               # Single-page resume
│   ├── main.js                  # Visitor counter fetch + text rotation (uses config.js)
│   ├── config.js                # Injected at deploy time with API endpoint and telemetry
│   ├── js/azure_app_insights.js # App Insights SDK bootstrap (reads config.js)
│   ├── css/                     # Stylesheets and font libraries
│   ├── js/                      # jQuery, plugins, and utilities
│   └── images/                  # Profile photo, cert badges, overlays
├── bootstrap/                   # AgentGitOps workflow scripts and guides
│   ├── README.md                # Quick start + session prompts
│   ├── agentgitops-instructions.md  # Full workflow guide
│   └── *.sh                     # Labels, milestones, issues, project, retrospective scripts
├── scripts/                     # Operational scripts
│   └── cleanup-stack.sh         # Blue/green stack inventory and purge
└── docs/                        # Extended documentation
```

## CI/CD Workflows

Two active workflows deploy via Cloudflare DNS; two legacy Azure CDN workflows are disabled:

| Workflow | File | Branch | Status |
|---|---|---|---|
| Production Cloudflare | `prod-full-stack-cloudflare.yml` | `main` | **Active** |
| Development Cloudflare | `dev-full-stack-cloudflare.yml` | `develop` | **Active** |
| Backend CI | `backend-ci.yml` | Push & PRs to `main`/`develop` | **Active** |
| Production Azure CDN | `prod-full-stack-azureCDN.yml` | — | Disabled |
| Development Azure CDN | `dev-full-stack-azureCDN.yml` | — | Disabled |

Each full-stack workflow runs 4 jobs sequentially:

1. **changes** — Detects which paths changed (`.iac/`, `backend/`, `frontend/`) via `dorny/paths-filter`
2. **deployIac** — Deploys Bicep templates for backend and frontend infrastructure
3. **buildDeployBackend** — Builds .NET Function App, runs unit tests, deploys to Azure
4. **buildDeployFrontend** — Generates `config.js` with runtime settings, uploads static files to Azure Storage

See [docs/CICD_WORKFLOWS.md](docs/CICD_WORKFLOWS.md) for the complete workflow reference.

## Blue/Green Deployment Strategy

Both dev and prod tiers use a blue/green pattern where each new major version deploys a **complete, isolated stack** (resource groups, Cosmos DB, Key Vault, Function App, Storage Account, DNS records). Old stacks are replaced and cleaned up.

The `stackVersion` env var in each workflow determines which stack is live:

| Tier | Workflow | `stackVersion` | Public URL |
|---|---|---|---|
| **Prod** | `prod-full-stack-cloudflare.yml` | `v12` | [resume.ryanmcvey.me](https://resume.ryanmcvey.me) |
| **Dev** | `dev-full-stack-cloudflare.yml` | `v12` | [resumedev.ryanmcvey.me](https://resumedev.ryanmcvey.me) |

**Swap procedure:** Bump `stackVersion` → merge to trigger branch → validate new stack → inventory + purge old stack via [`scripts/cleanup-stack.sh`](scripts/cleanup-stack.sh).

**Resource naming:** `{locationCode}-{appName}-{environment}-{version}-{resourceType}` (e.g., `cus1-resume-be-prod-v12-rg`)

## Required Secrets and Credentials

| Secret Name | Purpose |
|---|---|
| `AZURE_RESUME_GITHUB_SP` | Azure Service Principal JSON for `Azure/login` |
| `CLOUDFLARE_TOKEN` | Cloudflare API token for DNS record management |
| `CLOUDFLARE_ZONE` | Zone ID for `ryanmcvey.me` |

See [docs/CICD_WORKFLOWS.md](docs/CICD_WORKFLOWS.md) for the full credentials reference and creation instructions.

## Development Setup

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/) with [recommended extensions](.vscode/extensions.json) (or GitHub Codespaces — devcontainer handles setup automatically)
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (includes Bicep CLI)

### Build & Test

```bash
# Build backend
cd backend/api && dotnet build

# Run unit tests
cd backend/tests && dotnet test

# Run function locally
cd backend/api && func start
# → http://localhost:7071/api/GetResumeCounter
```

See [docs/LOCAL_TESTING.md](docs/LOCAL_TESTING.md) for the full local development guide including Cosmos DB emulator setup and frontend integration testing.

### Deploy Your Own Stack

1. Create an Azure Service Principal and store as GitHub secret `AZURE_RESUME_GITHUB_SP`
2. Configure Cloudflare API token and zone ID as GitHub secrets
3. Update workflow environment variables (`stackVersion`, `AppName`, `dnsZone`, etc.)
4. Push to `main` (prod) or `develop` (dev) — Bicep deploys all infrastructure automatically
5. `config.js` is generated at deploy time with the Function App URL, function key, and App Insights connection string — no manual frontend edits required

> **Note:** The Cosmos DB seed document is created automatically by the deployment workflow via `scripts/seed-cosmos-db.sh`.

## Known Issues & Technical Debt

| Issue | Status | Details |
|---|---|---|
| **jQuery 1.10.2 / Font Awesome 4.x** | ⚠️ Outdated | Frontend libraries are functional but several major versions behind. Low-priority upgrade. |

> **Resolved in recent phases:** .NET 8 migration (from 3.1 EOL), Functions v4 upgrade, deploy-time `config.js` injection (eliminated hardcoded secrets), GitHub Actions modernization (`$GITHUB_OUTPUT`, pinned action versions, `Azure/login@v2`), change detection re-enabled.

See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for the complete history and remediation details.

## Documentation

| Document | Description |
|---|---|
| [bootstrap/README.md](bootstrap/README.md) | **AgentGitOps quick start** — session prompts and workflow overview |
| [bootstrap/agentgitops-instructions.md](bootstrap/agentgitops-instructions.md) | Full AgentGitOps guide with diagrams, roles, labels, and KPIs |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed architecture, resource inventory, and Bicep module reference |
| [docs/CICD_WORKFLOWS.md](docs/CICD_WORKFLOWS.md) | Complete CI/CD workflow reference and credentials guide |
| [docs/LOCAL_TESTING.md](docs/LOCAL_TESTING.md) | Local development, build, test, and debug guide |
| [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) | Known issues, technical debt, and remediation history |
| [docs/BACKLOG_PLANNING.md](docs/BACKLOG_PLANNING.md) | Phased backlog planning guide |
| [docs/ASSESSMENT_COMMANDS.md](docs/ASSESSMENT_COMMANDS.md) | Azure CLI and Cloudflare commands for harvesting deployed state |
| [.github/skills/wiki-generator/README.md](.github/skills/wiki-generator/README.md) | **Wiki Generator skill** — generate the GitHub Wiki from repo content; companion [`publish-wiki.yml`](.github/workflows/publish-wiki.yml) workflow mirrors `wiki/` to the wiki UI |
| [.github/skills/resume-tailoring/SKILL.md](.github/skills/resume-tailoring/SKILL.md) | Resume Tailoring skill — generate a job-specific styled PDF resume and application guide |
