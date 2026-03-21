# Copilot Instructions for Azure Resume IaC

This repository contains the infrastructure-as-code and application source for a personal resume website hosted on Azure PaaS services with Cloudflare CDN. These instructions help GitHub Copilot (and Copilot agents) generate aligned, high-quality code for each component of the stack.

## Project Context

- **Domain:** `ryanmcvey.me` (single domain)
- **Architecture:** Static frontend (Azure Storage) → Azure Functions (.NET) → Cosmos DB, fronted by Cloudflare CDN
- **IaC:** Azure Bicep templates at `.iac/`
- **CI/CD:** GitHub Actions workflows at `.github/workflows/`
- **Backend:** .NET Azure Functions (C#) at `backend/api/`
- **Frontend:** Static HTML/CSS/JS at `frontend/`

## Azure Bicep (Infrastructure as Code)

Reference: [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/) | [Bicep Usage Guide](https://azure.github.io/Azure-Verified-Modules/usage/solution-development/bicep/) | [Bicep Module Index](https://azure.github.io/Azure-Verified-Modules/indexes/bicep/)

When working with Bicep templates (`.iac/` directory):

- Follow [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) patterns for resource definitions
- Use the AVM Bicep module index for standard, well-tested module implementations
- Target subscription scope for orchestration templates (`backend.bicep`, `frontend.bicep`)
- Target resource group scope for individual module templates
- Follow the naming convention: `{locationCode}-{appName}-{environment}-{version}-{resourceType}`
- Storage accounts omit hyphens: `{locationCode}{appName}{environment}{version}sa`
- Use parameter objects for tags to keep templates DRY
- Ensure all resources include standard tags: `Environment`, `CostCenter`, `GitActionIaCRunId`, `GitActionIaCRunNumber`, `GitActionIaCRunAttempt`, `GitActionIacActionsLink`
- Use Key Vault references for secrets (never hardcode connection strings in app settings)
- Prefer managed identity (`SystemAssigned`) for Azure service authentication
- Set `httpsOnly: true` on all web-facing resources
- Enable encryption at rest on storage accounts
- Reference: [awesome-copilot Bicep instructions](https://github.com/github/awesome-copilot/tree/main/instructions)

## .NET / Azure Functions (Backend)

Reference: [awesome-copilot .NET instructions](https://github.com/github/awesome-copilot/tree/main/instructions)

When working with the Function App backend (`backend/` directory):

- Target .NET 8 (LTS) with Azure Functions v4 (migration from .NET Core 3.1/v3 is a backlog item)
- Use the isolated worker model for new function implementations
- Use `Microsoft.Azure.Functions.Worker` packages for the isolated model
- Use `Microsoft.Azure.Cosmos` SDK for Cosmos DB interactions
- Follow C# coding conventions: PascalCase for public members, `_camelCase` for private fields
- Use dependency injection for services
- Use `ILogger<T>` for structured logging
- By default, use `Function` auth level (requires function key) for non-public endpoints.
- Exception: the `GetResumeCounter` HTTP-triggered function is intentionally configured with `AuthorizationLevel.Anonymous` because it serves the public visitor counter consumed by the frontend.
- CORS is configured at the infrastructure level in Bicep, not in application code
- Keep the Cosmos DB schema simple: `{ "id": "1", "count": N }` in the `Counter` container
- Write xUnit tests in `backend/tests/`

## GitHub Actions (CI/CD)

Reference: [awesome-copilot GitHub Actions instructions](https://github.com/github/awesome-copilot/tree/main/instructions)

When working with GitHub Actions workflows (`.github/workflows/`):

- Use `$GITHUB_OUTPUT` for setting outputs (not the deprecated `::set-output`)
- Pin actions to specific versions or commit SHAs (not `@main` or mutable tags)
- Use GitHub environments (`production`, `development`) for deployment protection
- Authenticate to Azure using `Azure/login` (migration to OIDC federated credentials is a backlog item)
- Use path filters to control which jobs run on each push
- Follow the job flow: `changes` → `deployIac` → `buildDeployBackend` → `buildDeployFrontend`
- Store secrets in GitHub Secrets, never in workflow files or committed code
- Use `continue-on-error: true` for DNS record creation (idempotent, may already exist)
- Production deploys from `main` branch, development from `develop` branch

## Blue/Green Deployment Strategy

Both dev and prod tiers use a blue/green deployment pattern where each new major version deploys a **complete, isolated stack** (new resource groups, Cosmos DB, Key Vault, Function App, Storage Account, Cloudflare DNS records). Old stacks are never updated in place — they are replaced and then cleaned up.

### Source of truth

The `stackVersion` env var in each workflow file determines which stack is "live":

| Tier | Workflow | `stackVersion` | `customDomainPrefix` | Public URL |
|---|---|---|---|---|
| Dev | `.github/workflows/dev-full-stack-cloudflare.yml` | e.g. `v10` | `resumedev` | `resumedev.ryanmcvey.me` |
| Prod | `.github/workflows/prod-full-stack-cloudflare.yml` | e.g. `v1` | `resume` | `resume.ryanmcvey.me` |

- `stackVersion` is embedded in all resource names: `{locationCode}-{appName}-{tier}-{environment}-{version}-{resourceType}`
- `customDomainPrefix` controls the public DNS name and stays **stable** across version swaps — the DNS CNAME re-points to the new storage account automatically

### Blue/green swap procedure

1. Bump `stackVersion` in the workflow file to the new version (e.g. `v10` → `v11`)
2. Keep `customDomainPrefix` unchanged — DNS re-points during deploy
3. Merge to the trigger branch (`develop` for dev, `main` for prod) — deploys a new stack from scratch
4. Validate the new stack end-to-end (frontend loads, counter API works, no console errors)
5. Inventory the old stack: `scripts/cleanup-stack.sh --inventory --json-output artifacts/inventory-<env>-<oldVersion>.json`
6. Purge the old stack: `scripts/cleanup-stack.sh --purge`

### Stack cleanup script

`scripts/cleanup-stack.sh` discovers and optionally destroys Azure resource groups and Cloudflare DNS records for a given stack version:

- `--inventory` — list resources only
- `--purge [--yes]` — delete resources (interactive confirmation unless `--yes`)
- `--json-output <path>` — write structured JSON artifact for audit/traceability

Required env vars: `STACK_ENVIRONMENT`, `STACK_VERSION`, `STACK_LOCATION_CODE`, `APP_NAME`
Optional (for DNS cleanup): `CF_TOKEN`, `CF_ZONE`, `DNS_ZONE`, `CUSTOM_DOMAIN_PREFIX`

## Frontend (Static Site)

Reference: [awesome-copilot JavaScript instructions](https://github.com/github/awesome-copilot/tree/main/instructions)

When working with frontend files (`frontend/` directory):

- This is a vanilla HTML/CSS/JS site (no build step, no framework)
- Keep JavaScript simple — no transpilation or bundling is used
- The visitor counter in `main.js` fetches from the Azure Function API
- Do not commit secrets (function keys, instrumentation keys) to source files
- Use semantic HTML5 elements
- Maintain responsive design with existing CSS grid/flex patterns
- Font Awesome icons and jQuery are loaded from local copies (not CDN)

## Backlog and Issue Management

This repository uses a structured AgentGitOps workflow for project management. Full instructions are in `bootstrap/agentgitops-instructions.md` with a dedicated project views guide at `bootstrap/project-views-guide.md`.

### Issue Type Taxonomy

Five issue types support the workflow, each with a dedicated template and aligned to specific roles:

| Issue Type | Template | Label | Role | When |
|---|---|---|---|---|
| Phase Initiation | `phase-initiation.yml` | `type: phase-initiation` | PM / Business Driver | Phase start |
| Technical Task | `backlog-task.yml` | `type: technical-task` | Technologist / AI Copilot | During burn-down |
| Phase Retrospective | `phase-retrospective.yml` | `type: phase-retrospective` | PM | Phase end |
| Bug Report | `bug-report.yml` | `type: bug` | Any role | As discovered |
| Feature Request | `feature-request.yml` | `type: feature-request` | Any role | As discovered |

### Organization Roles

| Role | Responsibilities | Issue Types Owned |
|---|---|---|
| **Project Manager (PM)** | Phase planning, milestones, retrospectives, velocity tracking | Phase Initiation, Phase Retrospective |
| **Technologist** | Technical implementation, code review, PR management | Technical Task, Bug Report |
| **AI Copilot** | Automated code generation, test writing, docs, refactoring | Technical Task (Copilot: Yes) |
| **Business / Functional Driver** | Business objectives, acceptance criteria, feature priorities | Feature Request, Phase Initiation (co-author) |

### Story Point Capacity Model

T-shirt sizing maps to story points for velocity measurement:

| Size | Story Points | Hours | Description |
|---|---|---|---|
| S (half-day) | 1 SP | 2.5 hrs | Small, well-defined task |
| M (1–2 days) | 3 SP | 7.5 hrs | Medium complexity |
| L (3–5 days) | 8 SP | 20 hrs | Large, multiple components |
| XL (1 week+) | 13 SP | 32.5+ hrs | Extra-large, consider breaking down |

**Capacity constants:** 1 SP = 2.5 hours, 3 SP/dev/day, 15 SP/dev/week.

### Label Taxonomy for Project Views

| Category | Labels | Purpose |
|---|---|---|
| Phase | `Phase 0 - Assessment` through `Phase 5 - Cleanup & Docs` | Roadmap by phase view |
| Priority | `P1 – Critical`, `P2 – High`, `P3 – Medium`, `P4 – Low` | Priority-based views |
| Size | `S (half-day)`, `M (1–2 days)`, `L (3–5 days)`, `XL (1 week+)` | Sprint planning + SP mapping |
| Copilot | `Copilot: Yes`, `Copilot: Partial`, `Copilot: No` | Copilot queue view |
| Area | `area: infrastructure`, `area: backend`, `area: frontend`, `area: ci-cd`, `area: dns-cdn`, `area: documentation`, `area: credentials` | Domain-based filtering |
| Issue Type | `type: technical-task`, `type: phase-initiation`, `type: phase-retrospective`, `type: bug`, `type: feature-request` | Issue classification |
| Role | `role: technologist`, `role: ai-copilot`, `role: project-manager`, `role: business-driver` | Role ownership |
| Source | `gap-analysis-finding`, `phase-retrospective` | Origin tracking |
| Status | `backlog`, `ready`, `blocked` | Board view columns |

### Copilot Suitability Guide

When assessing if a task is Copilot-suitable:

- **Yes:** Code generation, file editing, test writing, documentation, scripting, refactoring — fully automatable
- **Partial:** Requires some human judgment, but Copilot can assist with code/docs portions
- **No:** Requires Azure Portal access, credential management, manual verification, or human decision-making

### Project Views (Summary)

10 recommended views ensure nothing falls through the cracks. See `bootstrap/project-views-guide.md` for full setup instructions.

| View | Type | Primary Audience |
|---|---|---|
| Board | Board | All roles (daily) |
| Roadmap | Roadmap | PM, Business Driver (weekly) |
| Current Sprint | Table | Technologist, AI Copilot (daily) |
| Copilot Queue | Table | AI Copilot (primary), Technologist |
| Phase Overview | Table | PM (planning) |
| Priority Triage | Table | PM, Technologist |
| My Work | Table | All roles (daily) |
| Blocked & At Risk | Table | PM (daily) |
| Velocity Dashboard | Table | PM (retrospective) |
| Retrospective Tracker | Table | PM (phase boundary) |

**Required fields in every view:** Title, Assignees, Status, Copilot Suitable, Phase, Priority, Size.

## Agent Workflow for Backlog Build-Out

This repository follows the AgentGitOps repeatable workflow pattern (see `bootstrap/agentgitops-instructions.md`):

1. **Bootstrap** — Add copilot instructions to repo branch (this file)
2. **Assessment session** — Agent assesses source code, architecture, and current state
3. **Backlog research session** — Agent generates issue `.md` files with YAML frontmatter (Technical Tasks, Phase Initiation, Phase Retrospective per phase)
4. **Issue population** — Run scripts to create labels, milestones, issues, project
5. **Backlog burn-down** — Per-phase cycle: Initiation → Technical Tasks → Retrospective

**Key scripts:**

| Script | Purpose |
|---|---|
| `scripts/setup-github-labels.sh` | Create/update all labels (9 categories, idempotent) |
| `scripts/setup-github-milestones.sh` | Create milestones with due dates for Roadmap |
| `scripts/create-backlog-issues.sh` | Create issues from `.md` files with auto-labels |
| `scripts/setup-github-project.sh` | Create project + custom fields + add issues |
| `scripts/generate-phase-retrospective.sh` | Generate phase retrospective report |

## Phase Retrospective & AgentGitOps

At the conclusion of each phase, the PM generates a retrospective to capture planned-vs-actual metrics, Human/Copilot AI productivity KPIs, story point velocity, and gap analysis findings.

### Phase Lifecycle

1. **Phase Initiation** — PM creates `type: phase-initiation` issue with objectives, dates, planned SP capacity
2. **Burn-Down** — Technical Tasks, Bugs, Feature Requests worked by Technologists and AI Copilot
3. **Retrospective** — PM runs `scripts/generate-phase-retrospective.sh <N>`, assesses initiation success criteria
4. **Milestone closed** — Report committed to `docs/retrospectives/phase-{N}-retrospective.md`
5. **Next phase** — PM creates new Phase Initiation issue; cycle repeats

### Human vs Copilot AI Productivity KPI

The retrospective tracks AI leverage at three levels:

- **Task-level:** Closed issues labeled `Copilot: Yes` ÷ total closed issues
- **Commit-level:** Commits with `Co-authored-by` Copilot trailers ÷ total commits
- **Story point velocity:** AI-delivered SP ÷ total SP delivered (requires size labels on issues)

### Stack Inventory Artifacts

Blue/green stack transitions produce inventory JSON artifacts in `artifacts/` that are committed to the repo for traceability:

- `artifacts/inventory-<env>-<version>.json` — Pre-purge snapshot of Azure resource groups, resources, and Cloudflare DNS records for a given stack version
- Generated by `scripts/cleanup-stack.sh --inventory --json-output <path>` during stack cleanup
- These artifacts document environment evolution across phases and milestones, providing a historical record of what infrastructure existed at each version
- Purge artifacts (`purge-*.json`) are excluded from version control (`.gitignore`) since they duplicate inventory data

## Security Reminders

- Never commit secrets, API keys, or connection strings to source
- Use Key Vault references in Bicep for sensitive app settings
- Use GitHub Secrets for CI/CD credentials
- Pin third-party GitHub Actions to commit SHAs to mitigate supply chain attacks
- Prefer managed identity over stored credentials where possible
- Function keys in `main.js` are a known security debt item — see `docs/KNOWN_ISSUES.md`
