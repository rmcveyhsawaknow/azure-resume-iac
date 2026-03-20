# Agent-Driven Backlog Workflow

> **Purpose:** Document the repeatable, agent-assisted workflow used to plan, populate, and manage this project's backlog — from assessment through issue burn-down. Intended as a reference for the `agentgitops.ryanmcvey.me` demonstration site.

## Overview

This repository follows a structured, multi-session agent workflow to build out a project backlog in GitHub. The approach combines AI agent sessions (GitHub Copilot in VS Code) with `gh` CLI automation to produce a fully labeled, project-tracked issue backlog — ready for sprint planning.

```
┌─────────────────────────────────────────────────────────────┐
│  Session 1: Assessment                                      │
│  Agent reads source code, IaC, workflows → produces         │
│  ARCHITECTURE.md, ASSESSMENT_COMMANDS.md, KNOWN_ISSUES.md   │
├─────────────────────────────────────────────────────────────┤
│  Session 2: Backlog Research                                │
│  Agent reads assessment output → produces                   │
│  BACKLOG_PLANNING.md + issue .md files                      │
├─────────────────────────────────────────────────────────────┤
│  Session 3: Issue Population                                │
│  Human + Agent in Codespace → runs scripts to create        │
│  labels, milestones, issues, project, and views via gh CLI  │
├─────────────────────────────────────────────────────────────┤
│  Session 4: Phase 0 Assessment Execution                    │
│  Agent runs assessment commands → produces resource         │
│  inventory, actual-vs-expected, gaps → creates new issues   │
├─────────────────────────────────────────────────────────────┤
│  Session 5+: Backlog Burn-Down                              │
│  Human works issues using feature branches + Codespaces     │
│  Agent assists with Copilot-suitable tasks                  │
│  Technologist runs setup-codespace-auth.sh at session start │
├─────────────────────────────────────────────────────────────┤
│  Phase Boundary: Retrospective                              │
│  PM runs generate-phase-retrospective.sh → commits report   │
│  → posts to issue → closes milestone                        │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

| Requirement | Details |
|---|---|
| GitHub Codespace | Provides consistent dev environment with `gh` CLI pre-installed |
| `gh` CLI authenticated | `gh auth status` — Codespace `GITHUB_TOKEN` works for issues/labels |
| `project` scope token | Required for GitHub Projects API — run `gh auth login --scopes "project,repo"` outside Codespace or use a PAT |
| Issues enabled on repo | Settings → Features → Issues (must be enabled manually if forked) |
| Copilot instructions | `.github/copilot-instructions.md` provides agent context |

## Step-by-Step Workflow

### Step 1: Insert Copilot Instructions

**Session type:** Manual or Agent

Add `.github/copilot-instructions.md` to the repo. This file provides GitHub Copilot with project context: architecture, naming conventions, technology choices, label taxonomy, and security reminders. It ensures all agent sessions produce consistent, aligned output.

**Artifacts:**
- `.github/copilot-instructions.md`

### Step 2: Assessment Session

**Session type:** Agent (Copilot Chat in VS Code)

The agent reads all source files, IaC templates, workflows, and configuration to assess the current state of the project. It produces structured documentation.

**Prompt pattern:**
> "Assess this repository. Read all source files, IaC, workflows, and configuration. Produce architecture docs, assessment CLI commands, and a known-issues list."

**Artifacts:**
- `docs/ARCHITECTURE.md` — system architecture and component inventory
- `docs/ASSESSMENT_COMMANDS.md` — CLI commands to verify Azure/Cloudflare/GitHub state
- `docs/KNOWN_ISSUES.md` — identified gaps, tech debt, and security concerns
- `docs/CICD_WORKFLOWS.md` — CI/CD pipeline documentation

### Step 3: Backlog Research Session

**Session type:** Agent (Copilot Chat in VS Code)

The agent uses assessment output + copilot instructions to plan a phased backlog with individual issue definitions.

**Prompt pattern:**
> "Using the assessment docs and copilot instructions, create a phased backlog plan and generate individual issue .md files with YAML frontmatter for each task."

**Artifacts:**
- `docs/BACKLOG_PLANNING.md` — 6-phase plan with task breakdown
- `scripts/backlog-issues/*.md` — 59 individual issue files with YAML frontmatter
- `.github/ISSUE_TEMPLATE/backlog-task.yml` — issue template for consistency

**Issue file format:**
```yaml
---
task_id: "1.2"
phase: 1
phase_name: "Fix Function App"
title: "Upgrade .NET runtime (.NET Core 3.1 → .NET 8)"
priority: "P1 – Critical"
size: "M (1–2 days)"
copilot_suitable: "Yes"
labels:
  - "Phase 1 - Fix Function App"
  - "P1 – Critical"
  - "M (1–2 days)"
  - "Copilot: Yes"
  - "area: backend"
depends_on: ["1.1"]
---

# [Phase 1] Upgrade .NET runtime

## Description
...

## Acceptance Criteria
- [ ] ...
```

### Step 4: Issue Population Session

**Session type:** Human + Agent in Codespace

This is the execution session. The human opens a Codespace on the `develop` branch and directs the agent to run the automation scripts.

#### 4a: Create Labels

```bash
./scripts/setup-github-labels.sh rmcveyhsawaknow/azure-resume-iac
```

Creates 27 labels across 6 categories:
- **Phase** (6): `Phase 0 - Assessment` through `Phase 5 - Cleanup & Docs`
- **Priority** (4): `P1 – Critical` through `P4 – Low`
- **Size** (4): `S (half-day)` through `XL (1 week+)`
- **Copilot** (3): `Copilot: Yes`, `Copilot: Partial`, `Copilot: No`
- **Area** (7): `area: infrastructure`, `area: backend`, etc.
- **Status** (3): `backlog`, `ready`, `blocked`

#### 4b: Create Issues

```bash
# Dry run first to verify parsing
./scripts/create-backlog-issues.sh --dry-run rmcveyhsawaknow/azure-resume-iac

# Create all issues
./scripts/create-backlog-issues.sh rmcveyhsawaknow/azure-resume-iac
```

Creates 59 GitHub issues with:
- Structured title: `[Phase N] Task title`
- Full markdown body from the `.md` file
- All applicable labels auto-applied

> **Note:** The script includes a `sleep 2` between issues to avoid GitHub API rate limits. A bug fix was applied to use `VAR=$((VAR + 1))` instead of `((VAR++))` to prevent `set -e` from exiting when incrementing from 0.

### Step 5: Project Setup

**Session type:** Human (requires `project` scope)

The Codespace `GITHUB_TOKEN` does not include the `project` scope. Project setup requires either:
- Running locally with `gh auth login --scopes "project,repo"`
- Using a PAT with `project` scope

```bash
# Authenticate with project scope (outside Codespace)
gh auth login --scopes "project,repo,read:org"

# Run project setup
./scripts/setup-github-project.sh rmcveyhsawaknow
```

This script:
1. Creates a GitHub Project (V2) titled "Azure Resume IaC — Backlog"
2. Adds custom fields: Phase, Priority, Size, Copilot Suitable
3. Adds all 59 open issues to the project

### Step 6: Configure Project Views

**Session type:** Manual (GitHub UI)

GitHub Projects V2 views cannot be fully configured via API. After running the project setup script, manually create these views:

| View | Type | Configuration |
|---|---|---|
| **Board** | Board | Group by Status field; columns: Backlog, Ready, In Progress, Done |
| **Roadmap by Phase** | Table | Group by Phase field; sort by Priority |
| **Copilot Queue** | Table | Filter: `Copilot Suitable = Yes`; sort by Phase then Priority |
| **Priority View** | Table | Sort by Priority ascending; group by Phase |
| **Sprint Planning** | Table | Group by Size; filter by Phase for current sprint |

## Label Taxonomy Reference

| Category | Labels | Color | Purpose |
|---|---|---|---|
| Phase | `Phase 0` – `Phase 5` | `#0E8A16` (green) | Roadmap grouping |
| Priority | `P1 – Critical` – `P4 – Low` | Red → Blue gradient | Prioritization |
| Size | `S` – `XL` | `#C2E0C6` (light green) | Sprint planning |
| Copilot | `Yes`, `Partial`, `No` | Purple shades | Agent task queue |
| Area | `infrastructure`, `backend`, etc. | `#1D76DB` (blue) | Domain filtering |
| Source | `gap-analysis-finding`, `phase-retrospective` | `#FEF2C0` (gold) | Origin tracking |
| Status | `backlog`, `ready`, `blocked` | Gray / Green / Red | Board columns |

## Gap Analysis Cycle

After initial assessment (Session 4), a gap analysis cycle may identify additional tasks:

1. **Run assessment commands** — Execute `docs/ASSESSMENT_COMMANDS.md` commands against live infrastructure
2. **Generate artifacts** — Resource inventory, actual-vs-expected comparison, gaps & recommendations
3. **Create new issue files** — Write `.md` files in `scripts/backlog-issues/` with `gap-analysis-finding` label
4. **Update BACKLOG_PLANNING.md** — Add new tasks to the appropriate phase tables
5. **Run issue creation for new files only** — `./scripts/create-backlog-issues.sh scripts/backlog-issues/{new_files}`

This cycle can repeat at any phase boundary when new gaps are discovered.

## Phase Retrospective (AgentGitOps)

Each phase concludes with a retrospective that captures metrics, KPIs, and lessons learned.

### Setup (One-Time)

```bash
# Create milestones for all phases
./scripts/setup-github-milestones.sh

# Assign issues to milestones (via GitHub UI or gh CLI)
```

### At Phase Completion

```bash
# Generate retrospective report
./scripts/generate-phase-retrospective.sh <phase_number>

# The script:
# 1. Collects issue/PR/commit stats from the milestone date range
# 2. Calculates Human vs Copilot AI Productivity KPI
# 3. Writes docs/retrospectives/phase-{N}-retrospective.md
# 4. Posts the report as a comment on the retrospective issue
```

### Human vs Copilot AI Productivity KPI

The retrospective tracks AI leverage at two levels:

- **Task-level:** Closed issues labeled `Copilot: Yes` ÷ total closed issues
- **Commit-level:** Commits with `Co-authored-by` Copilot trailers ÷ total commits

### Artifacts

| Artifact | Location | Purpose |
|---|---|---|
| Committed report | `docs/retrospectives/phase-{N}-retrospective.md` | Persistent git record |
| Issue comment | Retrospective issue for the phase | Full data for Copilot context |
| Milestone | GitHub Milestones | Date boundaries and issue grouping |

## Session 5+: Technologist Bootstrap (Backlog Burn-Down)

When working `Copilot: Partial` issues in a Codespace, the **Technologist role** follows a repeatable bootstrap pattern — parallel to the PM's retrospective prompt.

### Prerequisites (One-Time)

Configure **Codespace Secrets** at [github.com/settings/codespaces](https://github.com/settings/codespaces) so credentials are auto-injected into every new Codespace:

| Secret | Source | Purpose |
|---|---|---|
| `AZURE_SP_APP_ID` | `az ad sp show --id <app-id>` | Azure Service Principal login |
| `AZURE_SP_PASSWORD` | SP client secret value | Azure Service Principal login |
| `AZURE_SP_TENANT` | `az account show --query tenantId` | Azure AD Tenant |
| `AZURE_SUBSCRIPTION_ID` | `az account show --query id` | Azure subscription context |
| `CF_API_TOKEN` | Cloudflare Dashboard → API Tokens | Cloudflare DNS operations |

### Workflow

1. **Human assigns issue** to Copilot via GitHub UI → selects `develop` branch
2. **Copilot creates feature branch** (e.g., `copilot/fix-issue-24`)
3. **Human opens Codespace** on the feature branch
4. **Human pastes the Technologist Session Start prompt** into Copilot Chat
5. Copilot runs auth setup, reads issue context, proposes implementation plan
6. Human reviews plan → Copilot implements → Human validates
7. Copilot creates PR to `develop` when work is complete

### Standard Technologist Session Start Prompt

> Paste this into Copilot Chat at the start of each Codespace session, replacing `{ISSUE_NUMBER}`:

```
Set up this Codespace for working on issue #{ISSUE_NUMBER}:

1. Run `bash scripts/setup-codespace-auth.sh` to authenticate Azure CLI, GitHub CLI, and Cloudflare API
2. Fetch the issue details: `gh issue view {ISSUE_NUMBER} --repo rmcveyhsawaknow/azure-resume-iac`
3. Read the issue acceptance criteria and identify the first actionable step
4. Check current branch and confirm it tracks the correct feature branch
5. Review the relevant source files mentioned in the issue
6. Propose an implementation plan based on the acceptance criteria

Start with step 1 and proceed through each step, pausing after the implementation plan for review.
```

### Role Comparison

| Aspect | PM Role (Retrospective) | Technologist Role (Burn-Down) |
|---|---|---|
| Trigger | Phase boundary | Issue assignment |
| Branch | `develop` | Feature branch (Copilot-created) |
| Auth needs | `gh` CLI only | Azure + GitHub + Cloudflare |
| Script | `generate-phase-retrospective.sh` | `setup-codespace-auth.sh` |
| Prompt location | Retrospective issue body | This section / issue body |
| Output | Report + milestone close | Code changes + PR |

### Codespace Configuration

The `.devcontainer/devcontainer.json` ensures consistent tooling:
- Azure CLI, .NET 8 SDK, Node.js pre-installed
- VS Code extensions: Bicep, Azure Functions, C# Dev Kit, Copilot
- Reminder to run auth script on start

## Scripts Reference

| Script | Purpose | Auth Required |
|---|---|---|
| `scripts/setup-github-labels.sh` | Create/update all labels | `GITHUB_TOKEN` (Codespace) |
| `scripts/create-backlog-issues.sh` | Create issues from `.md` files | `GITHUB_TOKEN` (Codespace) |
| `scripts/setup-github-project.sh` | Create project, fields, add issues | `project` scope token |
| `scripts/setup-github-milestones.sh` | Create milestones for each phase | `GITHUB_TOKEN` (Codespace) |
| `scripts/generate-phase-retrospective.sh` | Generate phase retrospective report | `GITHUB_TOKEN` (Codespace) |
| `scripts/setup-codespace-auth.sh` | Authenticate Azure, GitHub, Cloudflare | Codespace Secrets |

## Adapting This Workflow for Other Repos

This entire workflow is repository-agnostic. To reuse it:

1. **Fork or copy** the `scripts/` directory and `.github/copilot-instructions.md`
2. **Update** `.github/copilot-instructions.md` with your project's context
3. **Run assessment** — agent session to produce architecture docs
4. **Run backlog research** — agent session to produce phase plan + issue files
5. **Customize labels** in `scripts/setup-github-labels.sh` for your taxonomy
6. **Generate issue files** in `scripts/backlog-issues/` with YAML frontmatter
7. **Run scripts** in sequence: labels → milestones → issues → project → views
8. **Set up retrospectives** — create milestone dates, run `generate-phase-retrospective.sh` at each phase end

### Key Design Decisions

- **YAML frontmatter** in issue `.md` files enables scripted label extraction without a separate CSV/JSON mapping
- **Phased structure** (0–5) provides natural ordering and dependency tracking
- **Copilot suitability labels** allow filtering for agent-automatable tasks
- **Dry-run support** in the issue creation script prevents accidental duplicates
- **Idempotent label script** — safe to re-run (creates or updates)

## Future: agentgitops.ryanmcvey.me Integration

This workflow will be demonstrated on the `agentgitops.ryanmcvey.me` site as a reference implementation for:
- Agent-driven project planning and backlog generation
- Scripted GitHub issue and project management via `gh` CLI
- Copilot-assisted backlog burn-down patterns
- Repeatable DevOps workflows with AI agent augmentation

The demonstration will reference this document and the scripts in this repository as the source implementation.
