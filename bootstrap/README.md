# AgentGitOps Bootstrap

> **What is AgentGitOps?** A repeatable, multi-session workflow that combines AI coding agents (GitHub Copilot) with `gh` CLI automation to plan, populate, and burn down a project backlog in GitHub. Copy this `bootstrap/` folder into any project and follow the sessions below to go from goal to executing backlog in hours, not days.

For complete workflow documentation, see [`agentgitops-instructions.md`](agentgitops-instructions.md).  
For the project-specific implementation reference, see [`backlog_workflow.md`](backlog_workflow.md).

---

## What's in This Directory

| File | Purpose |
|---|---|
| **`README.md`** | This file — quick start and workflow overview |
| **`agentgitops-instructions.md`** | Full workflow guide with Mermaid diagrams, role definitions, KPI tracking |
| **`backlog_workflow.md`** | Project-specific workflow reference (this repo's implementation) |
| **`project-views-guide.md`** | GitHub Project V2 views setup guide for all team sizes |
| **`check-prerequisites.sh`** | Verify tools, auth, and permissions before running scripts |
| **`setup-github-labels.sh`** | Create/update all 27+ labels across 9 categories (idempotent) |
| **`setup-github-milestones.sh`** | Create GitHub milestones per phase with optional due dates |
| **`create-backlog-issues.sh`** | Create GitHub issues from `artifacts/backlog-issues/*.md` files |
| **`setup-github-project.sh`** | Create GitHub Project V2 with custom fields + add all issues |
| **`generate-phase-retrospective.sh`** | Generate phase retrospective report with SP velocity and AI KPIs |
| **`project-fields.json`** | GitHub Project V2 field and option IDs (project-specific, refresh after setup) |
| **`backlog-template.csv`** | Session 0 template — copy to `artifacts/backlog.csv` and fill in your tasks |

---

## Quick Start (Any Project)

```bash
# 1. Copy this bootstrap/ folder into your repository
# 2. Copy .github/ISSUE_TEMPLATE/ templates (5 files)
# 3. Check prerequisites
./bootstrap/check-prerequisites.sh

# 4. Follow Sessions 0–5 below
```

---

## Workflow — Sessions 0 Through 5

```
┌─────────────────────────────────────────────────────────────────────┐
│  Session 0: Goal-Focused Backlog Planning                           │
│  PM/Business Driver defines goals, phases, produces:               │
│  docs/BACKLOG_PLANNING.md + artifacts/backlog.csv                  │
├─────────────────────────────────────────────────────────────────────┤
│  Session 1: Bootstrap                                               │
│  Human adds .github/copilot-instructions.md to provide             │
│  persistent agent context for all subsequent sessions              │
├─────────────────────────────────────────────────────────────────────┤
│  Session 2: Backlog Research                                        │
│  Agent reads codebase + Session 0 CSV → generates                  │
│  artifacts/backlog-issues/*.md + assessment docs                   │
├─────────────────────────────────────────────────────────────────────┤
│  Session 3: Issue Population                                        │
│  Human + Agent run scripts to create labels, milestones,           │
│  issues, and GitHub Project via gh CLI                             │
├─────────────────────────────────────────────────────────────────────┤
│  Session 4: Assessment Execution                                    │
│  Human + Agent execute Phase 0 assessment tasks from              │
│  backlog — verify infrastructure, document actuals, find gaps      │
├─────────────────────────────────────────────────────────────────────┤
│  Session 5+: Backlog Burn-Down (per phase)                         │
│  PM creates Phase Initiation issue → issues assigned →             │
│  Copilot implements → PRs reviewed → merged → repeat              │
├─────────────────────────────────────────────────────────────────────┤
│  Phase Boundary: Retrospective                                     │
│  PM runs generate-phase-retrospective.sh → commits report         │
│  → posts to issue → closes milestone → plans next phase            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Session 0: Goal-Focused Backlog Planning

**Role:** PM / Business Driver  
**Time:** 1–4 hours  
**Output:** `docs/BACKLOG_PLANNING.md`, `artifacts/backlog.csv`

This is the first step. Before involving any agent, the PM and Business Driver define the project goals and structure. The output feeds directly into Sessions 2 and 3.

**Steps:**
1. Define project goals, scope, and success criteria
2. Identify phases (0-indexed, typically 3–6 phases)
3. Create `docs/BACKLOG_PLANNING.md` with phased task breakdown and objectives
4. Copy `bootstrap/backlog-template.csv` → `artifacts/backlog.csv` and fill in all tasks

**Agent assist prompt:**
> "Help me create a phased backlog plan for [project description]. Goals: [goals]. Create a BACKLOG_PLANNING.md with phases and an artifacts/backlog.csv using the template structure."

---

## Session 1: Bootstrap — Copilot Instructions

**Role:** Human  
**Time:** 15–30 minutes  
**Output:** `.github/copilot-instructions.md`

Create `.github/copilot-instructions.md` with your project's context: architecture, naming conventions, technology stack, label taxonomy, and security reminders. This provides persistent context to every Copilot agent session.

---

## Session 2: Backlog Research

**Role:** Agent (Copilot Chat / Coding Agent)  
**Time:** 2–4 hours  
**Input:** `artifacts/backlog.csv`, `.github/copilot-instructions.md`, codebase  
**Output:** `artifacts/backlog-issues/*.md`, `docs/ARCHITECTURE.md`, `docs/KNOWN_ISSUES.md`

**Prompt pattern:**
> "Using the Session 0 backlog CSV (`artifacts/backlog.csv`) and copilot instructions, generate individual issue .md files in `artifacts/backlog-issues/` with YAML frontmatter for each task. Mark each as `planned` or `gap-analysis-finding`. Also create Phase Initiation and Phase Retrospective issues per phase. Produce architecture and known issues docs."

**Issue file format:**
```yaml
---
task_id: "1.2"
phase: 1
phase_name: "My Phase"
title: "Task title"
issue_type: "planned"
priority: "P2 – High"
size: "M (1–2 days)"
copilot_suitable: "Yes"
labels:
  - "Phase 1 - My Phase"
  - "P2 – High"
  - "M (1–2 days)"
  - "Copilot: Yes"
  - "area: backend"
depends_on: ["1.1"]
---

# Task Title

## Description
...

## Acceptance Criteria
- [ ] ...
```

---

## Session 3: Issue Population

**Role:** Human + Agent (Codespace)  
**Time:** 1–2 hours

### Step 1: Check Prerequisites

```bash
./bootstrap/check-prerequisites.sh
```

### Step 2: Create Labels

```bash
./bootstrap/setup-github-labels.sh [owner/repo]
```

Creates 27+ labels across 9 categories: Phase, Priority, Size, Copilot Suitability, Domain Area, Source, Status, Issue Type, Role.

### Step 3: Create Milestones

```bash
./bootstrap/setup-github-milestones.sh [owner/repo]

# Set due dates for Roadmap view (optional):
PHASE_0_DUE=2025-06-15 PHASE_1_DUE=2025-06-30 ./bootstrap/setup-github-milestones.sh
```

### Step 4: Create Issues

```bash
# Dry run first (verify parsing):
./bootstrap/create-backlog-issues.sh --dry-run [owner/repo]

# Create all issues:
./bootstrap/create-backlog-issues.sh [owner/repo]
```

### Step 5: Set Up GitHub Project

> **Requires `project` scope** — run locally or with a PAT, not in Codespace.

```bash
gh auth login --scopes "project,repo,read:org"
./bootstrap/setup-github-project.sh [owner]
```

Creates a GitHub Project V2 with Phase, Priority, Size, Copilot Suitable fields.

> After first run, refresh `bootstrap/project-fields.json` with the actual project field IDs:
> ```bash
> gh project field-list <number> --owner <owner> --format json
> ```

### Step 6: Configure Project Views

GitHub Projects V2 views require manual setup. Follow [`project-views-guide.md`](project-views-guide.md) for complete instructions.

**Minimum views to create:**

| View | Type | Key Config |
|---|---|---|
| **Board** | Board | Group by Status |
| **Roadmap** | Roadmap | Date: Start/End Date; Group by Phase |
| **Current Sprint** | Table | Filter: current phase; Status ≠ Done |
| **Copilot Queue** | Table | Filter: Copilot Suitable = Yes |
| **Priority Triage** | Table | Sort by Priority ascending |

**Required fields in every view:** Title, Assignees, Status, Copilot Suitable, Phase, Priority, Size.

---

## Phase Retrospective (Runs at Each Phase Boundary)

```bash
# Generate retrospective and post to issue:
./bootstrap/generate-phase-retrospective.sh <phase_number>

# Dry run (preview only):
./bootstrap/generate-phase-retrospective.sh <phase_number> --dry-run
```

**Output:** `docs/retrospectives/phase-{N}-retrospective.md`

**Metrics collected:**
- Issues planned vs. closed (completion rate)
- PRs merged and commits in phase date range
- Story point velocity (SP/day)
- Task-level AI ratio: Copilot: Yes closed ÷ total closed
- Commit-level AI ratio: Copilot co-authored commits ÷ total commits

---

## Gap Analysis Cycle

During or after assessment, new tasks may be discovered that weren't in the original plan:

1. Create new issue files in `artifacts/backlog-issues/` with `issue_type: "gap-analysis-finding"`
2. Include `gap-analysis-finding` in the `labels:` list
3. Update `docs/BACKLOG_PLANNING.md` phase tables
4. Run issue creation for the new files only:
   ```bash
   ./bootstrap/create-backlog-issues.sh artifacts/backlog-issues/{new_files}.md
   ```

---

## Scripts Reference

| Script | Purpose | Auth Required | Scope |
|---|---|---|---|
| `check-prerequisites.sh` | Verify tools, auth, and permissions | None (checks auth) | Before Session 3 |
| `setup-github-labels.sh` | Create/update all labels (idempotent) | `GITHUB_TOKEN` | Session 3, Step 2 |
| `setup-github-milestones.sh` | Create milestones for each phase | `GITHUB_TOKEN` | Session 3, Step 3 |
| `create-backlog-issues.sh` | Create issues from `.md` files in `artifacts/backlog-issues/` | `GITHUB_TOKEN` | Session 3, Step 4 |
| `setup-github-project.sh` | Create project + custom fields + add issues | `project` scope PAT | Session 3, Step 5 |
| `generate-phase-retrospective.sh` | Generate phase retrospective report | `GITHUB_TOKEN` | Each phase boundary |

**Project-specific scripts** (not in bootstrap — live in `scripts/`):

| Script | Purpose |
|---|---|
| `scripts/setup-codespace-auth.sh` | Authenticate Azure, GitHub, Cloudflare in Codespace |
| `scripts/cleanup-stack.sh` | Inventory/purge old blue/green stack resources |

---

## Label Taxonomy Reference

| Category | Labels | Color |
|---|---|---|
| **Phase** | `Phase 0 - Assessment` through `Phase N` | Green `#0E8A16` |
| **Priority** | `P1 – Critical`, `P2 – High`, `P3 – Medium`, `P4 – Low` | Red → Blue gradient |
| **Size** | `S (half-day)`, `M (1–2 days)`, `L (3–5 days)`, `XL (1 week+)` | Light green `#C2E0C6` |
| **Copilot** | `Copilot: Yes`, `Copilot: Partial`, `Copilot: No` | Purple shades |
| **Area** | `area: infrastructure`, `area: backend`, `area: frontend`, `area: ci-cd`, `area: dns-cdn`, `area: documentation`, `area: credentials` | Blue `#1D76DB` |
| **Source** | `gap-analysis-finding`, `phase-retrospective` | Gold `#FEF2C0` |
| **Issue Type** | `type: technical-task`, `type: phase-initiation`, `type: phase-retrospective`, `type: bug`, `type: feature-request` | Purple / Blue |
| **Role** | `role: technologist`, `role: ai-copilot`, `role: project-manager`, `role: business-driver` | Varied |
| **Status** | `backlog`, `ready`, `blocked` | Gray / Green / Red |

---

## Story Point Capacity Model

| Size | Story Points | Hours | Description |
|---|---|---|---|
| S (half-day) | 1 SP | 2.5 hrs | Small, well-defined task |
| M (1–2 days) | 3 SP | 7.5 hrs | Medium complexity |
| L (3–5 days) | 8 SP | 20 hrs | Large, multiple components |
| XL (1 week+) | 13 SP | 32.5+ hrs | Extra-large, consider breaking down |

**Capacity constants:** 3 SP/dev/day · 15 SP/dev/week · 1 SP = 2.5 hours

---

## Adapting for Any Project

1. **Copy `bootstrap/`** into your repository — all scripts and guides are self-contained
2. **Copy `.github/ISSUE_TEMPLATE/`** (5 templates: backlog-task, phase-initiation, phase-retrospective, bug-report, feature-request)
3. **Run `./bootstrap/check-prerequisites.sh`** to verify your setup
4. **Customize** `setup-github-labels.sh` phase labels and `setup-github-milestones.sh` phase definitions for your project
5. **Follow Sessions 0–5** above

### Customization Points

| What to Customize | File | How |
|---|---|---|
| Phase names | `setup-github-labels.sh`, `setup-github-milestones.sh` | Edit phase arrays |
| Label taxonomy | `setup-github-labels.sh` | Add/remove labels |
| Project name | `setup-github-project.sh` | Change `PROJECT_TITLE` |
| Project field IDs | `project-fields.json` | Refresh after project creation |
| Copilot instructions | `.github/copilot-instructions.md` | Rewrite for your stack |

---

## Reference Implementation

This `bootstrap/` package was developed and demonstrated on the [azure-resume-iac](https://github.com/rmcveyhsawaknow/azure-resume-iac) project — a multi-phase infrastructure-as-code update for an Azure-hosted resume site. The reference implementation includes 6 phases, 80+ issues, complete retrospective data, and the full backlog CSV at `artifacts/backlog.csv`.

See [`backlog_workflow.md`](backlog_workflow.md) for this project's implementation details.
