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
- Function auth level should be `Function` (requires function key) for non-public endpoints
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

This repository uses a structured backlog-to-issues workflow:

1. **Backlog planning** lives in `docs/BACKLOG_PLANNING.md` with 6 phases (0–5)
2. **Issue template** at `.github/ISSUE_TEMPLATE/backlog-task.yml` captures task metadata
3. **Retrospective template** at `.github/ISSUE_TEMPLATE/phase-retrospective.yml` captures phase wrap-up data
4. **Backlog issue files** in `scripts/backlog-issues/` contain individual task definitions
5. **Label scripts** at `scripts/setup-github-labels.sh` create required labels
6. **Milestone scripts** at `scripts/setup-github-milestones.sh` create phase milestones for date tracking
7. **Issue creation** at `scripts/create-backlog-issues.sh` creates issues via `gh` CLI
8. **Retrospective generator** at `scripts/generate-phase-retrospective.sh` produces phase reports

### Label Taxonomy for Project Views

| Category | Labels | Purpose |
|---|---|---|
| Phase | `Phase 0 - Assessment` through `Phase 5 - Cleanup & Docs` | Roadmap by phase view |
| Priority | `P1 – Critical`, `P2 – High`, `P3 – Medium`, `P4 – Low` | Priority-based views |
| Size | `S (half-day)`, `M (1–2 days)`, `L (3–5 days)`, `XL (1 week+)` | Sprint planning |
| Copilot | `Copilot: Yes`, `Copilot: Partial`, `Copilot: No` | Copilot queue view |
| Area | `area: infrastructure`, `area: backend`, `area: frontend`, `area: ci-cd`, `area: dns-cdn`, `area: documentation`, `area: credentials` | Domain-based filtering |
| Source | `gap-analysis-finding`, `phase-retrospective` | Origin tracking |
| Status | `backlog`, `ready`, `blocked` | Board view columns |

### Copilot Suitability Guide

When assessing if a task is Copilot-suitable:

- **Yes:** Code generation, file editing, test writing, documentation, scripting, refactoring — fully automatable
- **Partial:** Requires some human judgment, but Copilot can assist with code/docs portions
- **No:** Requires Azure Portal access, credential management, manual verification, or human decision-making

## Agent Workflow for Backlog Build-Out

This repository follows a repeatable agent workflow pattern for building out project backlogs:

1. **Insert instructions** — Add copilot instructions to repo branch (this file)
2. **Assessment session** — Agent assesses source code, architecture, and current state
3. **Backlog research session** — Agent researches each task and generates issue `.md` files
4. **Issue creation session** — Agent builds and runs script to create issues via `gh` CLI with labels
5. **Project setup** — Create GitHub Project, configure custom fields and milestones via script
6. **View configuration** — Manually configure project views (Board, Roadmap by Phase, Copilot Queue, etc.) as this cannot yet be fully scripted

This workflow can be adapted for any repository by:
- Updating the phase definitions and task lists in `docs/BACKLOG_PLANNING.md`
- Adjusting the label taxonomy in `scripts/setup-github-labels.sh`
- Regenerating issue files in `scripts/backlog-issues/`
- Running `scripts/create-backlog-issues.sh` to populate the project

## Phase Retrospective & AgentGitOps

At the conclusion of each phase, a retrospective is generated to capture planned-vs-actual metrics, Human/Copilot AI productivity KPIs, and gap analysis findings.

### Workflow

1. **Milestones** provide date boundaries for each phase — created by `scripts/setup-github-milestones.sh`
2. **Pre-planned retrospective issues** exist for each phase (labeled `phase-retrospective`)
3. At phase end, run `scripts/generate-phase-retrospective.sh <phase_number>` to auto-generate the report
4. Report is committed to `docs/retrospectives/phase-{N}-retrospective.md` and posted as a comment on the retrospective issue
5. Milestone is closed after review

### Human vs Copilot AI Productivity KPI

The retrospective tracks AI leverage at two levels:

- **Task-level:** Issues labeled `Copilot: Yes` that were closed vs total closed issues
- **Commit-level:** Commits with `Co-authored-by` Copilot trailers vs total commits

### Key Scripts

| Script | Purpose |
|---|---|
| `scripts/setup-github-milestones.sh` | Create milestones for each phase |
| `scripts/generate-phase-retrospective.sh` | Generate stats report at phase end |

## Security Reminders

- Never commit secrets, API keys, or connection strings to source
- Use Key Vault references in Bicep for sensitive app settings
- Use GitHub Secrets for CI/CD credentials
- Pin third-party GitHub Actions to commit SHAs to mitigate supply chain attacks
- Prefer managed identity over stored credentials where possible
- Function keys in `main.js` are a known security debt item — see `docs/KNOWN_ISSUES.md`
