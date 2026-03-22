# AgentGitOps Bootstrap

> **What is AgentGitOps?** A repeatable, multi-session workflow that combines AI coding agents (GitHub Copilot) with `gh` CLI automation to plan, populate, and burn down a project backlog in GitHub. Copy this `bootstrap/` folder into any project and follow the sessions below to go from goals to executing backlog in hours, not days.

For the full workflow guide with Mermaid diagrams, see [`agentgitops-instructions.md`](agentgitops-instructions.md).  
For this repo's implementation reference, see [`backlog_workflow.md`](backlog_workflow.md).

---

## ⚠️ Before You Start — Required Customization

This `bootstrap/` package is designed to be copied into any repository, but **several files contain project-specific values that must be customized** before running scripts:

| File | What to Customize | How |
|---|---|---|
| `setup-github-labels.sh` | Phase label names (lines marked `# CUSTOMIZE:`) | Replace `Phase 1 - Fix Function App` etc. with your phase names |
| `setup-github-milestones.sh` | Phase milestone names and descriptions (`# CUSTOMIZE:`) | Replace the `MILESTONES` array entries with your phases |
| `setup-github-project.sh` | Project title (auto-detected from repo name) | Override `PROJECT_TITLE` if desired |
| `project-fields.json` | **All field and option IDs** (placeholder values) | Run `setup-github-project.sh` first, then refresh IDs per the `_refresh` instructions in the file |
| `backlog-template.csv` | Task definitions | Copy to `artifacts/backlog.csv` and fill in your project's tasks |

> **Phase labels must match across** `setup-github-labels.sh`, `setup-github-milestones.sh`, and the `labels:` field in each issue `.md` file. The agent in Session 2 handles this automatically if given the correct phase names.

---

## What's in This Directory

| File | Purpose |
|---|---|
| **`README.md`** | This file — quick start, session prompts, and workflow overview |
| **`agentgitops-instructions.md`** | Full workflow guide with Mermaid diagrams, role definitions, KPI tracking |
| **`backlog_workflow.md`** | Project-specific workflow reference (this repo's implementation) |
| **`project-views-guide.md`** | GitHub Project V2 views setup guide for all team sizes |
| **`check-prerequisites.sh`** | Verify tools, auth, and permissions before running scripts |
| **`setup-github-labels.sh`** | Create/update all 27+ labels across 9 categories (idempotent) |
| **`setup-github-milestones.sh`** | Create GitHub milestones per phase with optional due dates |
| **`create-backlog-issues.sh`** | Create GitHub issues from `artifacts/backlog-issues/*.md` files |
| **`setup-github-project.sh`** | Create GitHub Project V2 with custom fields + add all issues |
| **`generate-phase-retrospective.sh`** | Generate phase retrospective report with SP velocity and AI KPIs |
| **`project-fields.json`** | GitHub Project V2 field and option IDs (refresh after `setup-github-project.sh`) |
| **`backlog-template.csv`** | Session 0 template — copy to `artifacts/backlog.csv` and fill in your tasks |

---

## Quick Start (Any Project)

```bash
# 1. Copy this bootstrap/ folder into your repository
# 2. Copy .github/ISSUE_TEMPLATE/ templates (5 files)
# 3. Check prerequisites
./bootstrap/check-prerequisites.sh

# 4. Follow Sessions 0–5 below — each includes a copy-paste agent prompt
```

---

## Workflow — Sessions 0 Through 5

```
Session 0 ─── Goal-Focused Backlog Planning (PM/BD, human-driven)
    ↓         Output: docs/BACKLOG_PLANNING.md + artifacts/backlog.csv
Session 1 ─── Bootstrap — Insert Copilot Instructions (human)
    ↓         Output: .github/copilot-instructions.md
Session 2 ─── Backlog Research (agent-driven)
    ↓         Output: artifacts/backlog-issues/*.md + assessment docs
Session 3 ─── Issue Population (human + agent scripts)
    ↓         Output: GitHub Issues, Labels, Milestones, Project
Session 4 ─── Assessment Execution (human + agent)
    ↓         Output: Gap analysis findings, assessment artifacts
Session 5+ ── Backlog Burn-Down (per phase, ongoing)
    ↓         Output: Code changes, PRs, deployments
  ┌─────────── Phase Boundary: Retrospective ───────────┐
  │  Output: docs/retrospectives/phase-N-retrospective.md │
  │  → close milestone → plan next phase → repeat         │
  └────────────────────────────────────────────────────────┘
```

---

## Session 0: Goal-Focused Backlog Planning

**Role:** PM / Business Driver  
**Time:** 1–4 hours  
**Output:** `docs/BACKLOG_PLANNING.md`, `artifacts/backlog.csv`

Before involving any agent, the PM and Business Driver define the project goals and produce the planning artifacts that drive all subsequent sessions.

**Steps:**
1. Define project goals, scope, and success criteria
2. Identify phases (0-indexed, typically 3–6 phases)
3. Create `docs/BACKLOG_PLANNING.md` with phased task breakdown and phase objectives
4. Copy `bootstrap/backlog-template.csv` → `artifacts/backlog.csv` and fill in all tasks

### Session 0 Agent Prompt

> Copy-paste into Copilot Chat for assistance with planning:

```
You are a Project Manager helping plan a software project backlog using the AgentGitOps
methodology. Reference bootstrap/agentgitops-instructions.md for the full workflow guide.

Project: [DESCRIBE YOUR PROJECT]
Goals: [LIST YOUR GOALS]
Technology stack: [LIST YOUR STACK]

Tasks:
1. Create docs/BACKLOG_PLANNING.md with:
   - Project overview and goals
   - Phase breakdown (Phase 0 = Assessment, then implementation phases, final phase = Cleanup & Docs)
   - For each phase: objectives, task table (task_id, title, priority, size, copilot_suitable), success criteria
   - Story point capacity model (S=1SP, M=3SP, L=8SP, XL=13SP; 3 SP/dev/day)

2. Create artifacts/backlog.csv using the structure from bootstrap/backlog-template.csv with:
   - One row per task, all fields populated
   - depends_on as semicolon-separated task IDs (e.g., "1.1;1.2")
   - labels as semicolon-separated label names matching bootstrap/setup-github-labels.sh
   - Phase 0 should be Assessment tasks (verify credentials, inventory resources, etc.)
   - Final phase should be Cleanup & Documentation
   - Each phase ends with a retrospective task (copilot_suitable: Partial)

3. Ensure consistency: labels in CSV must match label names in setup-github-labels.sh,
   phase names must match milestone names in setup-github-milestones.sh.

4. Update the phase names in bootstrap/setup-github-labels.sh (# CUSTOMIZE: section)
   and bootstrap/setup-github-milestones.sh (MILESTONES array) to match your phases.
```

---

## Session 1: Bootstrap — Copilot Instructions

**Role:** Human  
**Time:** 15–30 minutes  
**Output:** `.github/copilot-instructions.md`

Create `.github/copilot-instructions.md` with your project's context: architecture, naming conventions, technology stack, label taxonomy, and security reminders. This provides persistent context to every Copilot agent session.

### Session 1 Agent Prompt

> Copy-paste into Copilot Chat to generate copilot instructions:

```
Read the entire codebase of this repository — source files, IaC templates, CI/CD workflows,
configuration, and documentation. Reference bootstrap/agentgitops-instructions.md for the
AgentGitOps workflow structure and label taxonomy.

Generate .github/copilot-instructions.md that includes:
1. Project context — what this project does, its architecture
2. Technology stack — languages, frameworks, cloud services
3. Naming conventions — variables, files, resources
4. Directory structure — what lives where and why
5. CI/CD — how workflows are structured, deployment strategy
6. Security reminders — no secrets in code, use Key Vault references, pin actions to SHAs
7. Label taxonomy — copy the full label table from bootstrap/agentgitops-instructions.md
8. AgentGitOps workflow summary — reference bootstrap/ scripts and their purposes
9. Backlog and issue management — issue type taxonomy, story point model
10. Testing and linting — how to build, test, and validate changes

This file will be read by every Copilot agent session to ensure consistent, aligned output.
```

---

## Session 2: Backlog Research

**Role:** Agent (Copilot Chat / Coding Agent)  
**Time:** 2–4 hours  
**Input:** `artifacts/backlog.csv`, `.github/copilot-instructions.md`, codebase  
**Output:** `artifacts/backlog-issues/*.md`, assessment docs

The agent reads the Session 0 CSV and codebase to produce individual issue files with YAML frontmatter, plus architecture and assessment documentation.

### Session 2 Agent Prompt

> Copy-paste into Copilot Chat or use as a Copilot Coding Agent issue body:

```
You are a Backlog Research agent following the AgentGitOps workflow.
Reference bootstrap/agentgitops-instructions.md for full instructions.

Inputs:
- artifacts/backlog.csv (Session 0 planning CSV)
- .github/copilot-instructions.md (project context)
- The full codebase of this repository

Tasks:
1. Read the entire codebase — source files, IaC, workflows, config, documentation.

2. For each task row in artifacts/backlog.csv, create an issue file at
   artifacts/backlog-issues/{task_id}.md with this YAML frontmatter format:
   ---
   task_id: "1.2"
   phase: 1
   phase_name: "Phase Name"
   title: "Task title from CSV"
   issue_type: "planned"
   priority: "P2 – High"
   size: "M (1–2 days)"
   copilot_suitable: "Yes"
   labels:
     - "Phase 1 - Phase Name"
     - "P2 – High"
     - "M (1–2 days)"
     - "Copilot: Yes"
     - "area: backend"
   depends_on: ["1.1"]
   ---
   # [Phase 1] Task Title
   ## Description
   [Detailed description based on codebase analysis]
   ## Acceptance Criteria
   - [ ] [Specific, testable criteria]

3. For each phase, also create:
   - A Phase Initiation issue (task_id: N.0) with type: phase-initiation label
   - A Phase Retrospective issue (last task in phase) with type: phase-retrospective label

4. Produce assessment documentation:
   - docs/ARCHITECTURE.md — system architecture and component inventory
   - docs/ASSESSMENT_COMMANDS.md — CLI commands to verify deployed state
   - docs/KNOWN_ISSUES.md — identified gaps, tech debt, security concerns
   - docs/LOCAL_TESTING.md — local development and testing guide

5. If you discover issues not in the original CSV (gaps, tech debt, security findings),
   create additional issue files with issue_type: "gap-analysis-finding" and include the
   "gap-analysis-finding" label.

6. Ensure all label names match exactly what bootstrap/setup-github-labels.sh creates.

7. Update bootstrap/setup-github-labels.sh and bootstrap/setup-github-milestones.sh
   phase names if they don't match the phases in the CSV.
```

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

### Session 3 Agent Prompt

> Copy-paste into Copilot Chat in a Codespace for guided execution:

```
You are executing Session 3 (Issue Population) of the AgentGitOps workflow.
Reference bootstrap/agentgitops-instructions.md for full instructions.

Execute these steps in order. Pause after each step for confirmation.

Step 1 — Check prerequisites:
  ./bootstrap/check-prerequisites.sh

Step 2 — Create labels:
  ./bootstrap/setup-github-labels.sh [owner/repo]

Step 3 — Create milestones:
  ./bootstrap/setup-github-milestones.sh [owner/repo]
  # Optionally set due dates:
  # PHASE_0_DUE=2025-07-01 PHASE_1_DUE=2025-07-15 ./bootstrap/setup-github-milestones.sh

Step 4 — Create issues (dry run first):
  ./bootstrap/create-backlog-issues.sh --dry-run [owner/repo]
  # If dry run looks correct:
  ./bootstrap/create-backlog-issues.sh [owner/repo]

Step 5 — Set up GitHub Project:
  # Requires project scope — may need: gh auth login --scopes "project,repo,read:org"
  ./bootstrap/setup-github-project.sh [owner]

Step 6 — Refresh project field IDs:
  # After setup-github-project.sh creates the project, update project-fields.json:
  gh project field-list <PROJECT_NUMBER> --owner <OWNER> --format json
  # Map the field and option IDs into bootstrap/project-fields.json
  # Example: find the "Phase" field ID and its option IDs:
  #   gh project field-list 1 --owner myuser --format json \
  #     | python3 -c "import json,sys; [print(f['id'], f['name'], [o['id']+' '+o['name'] for o in f.get('options',[])]) for f in json.load(sys.stdin)['fields']]"
  # Then update project-fields.json phaseFieldId, priorityFieldId, etc. with the IDs

Step 7 — Configure project views:
  # Follow bootstrap/project-views-guide.md for the 10 recommended views:
  # Board, Roadmap, Current Sprint, Copilot Queue, Phase Overview,
  # Priority Triage, My Work, Blocked & At Risk, Velocity Dashboard,
  # Retrospective Tracker
  # Required fields in every view: Title, Assignees, Status, Copilot Suitable,
  # Phase, Priority, Size
```

### Manual Script Reference

| Step | Script | Command |
|---|---|---|
| 1 | Check prerequisites | `./bootstrap/check-prerequisites.sh` |
| 2 | Create labels | `./bootstrap/setup-github-labels.sh [owner/repo]` |
| 3 | Create milestones | `./bootstrap/setup-github-milestones.sh [owner/repo]` |
| 4 | Create issues | `./bootstrap/create-backlog-issues.sh [owner/repo]` |
| 5 | Set up project | `./bootstrap/setup-github-project.sh [owner]` |
| 6 | Refresh field IDs | Edit `bootstrap/project-fields.json` with actual IDs |
| 7 | Configure views | Follow [`project-views-guide.md`](project-views-guide.md) |

---

## Session 4: Assessment Execution

**Role:** Human + Agent  
**Time:** 1–4 hours  
**Input:** Phase 0 assessment issues from backlog  
**Output:** Assessment artifacts, gap analysis findings

### Session 4 Agent Prompt

> Copy-paste into Copilot Chat in a Codespace:

```
You are executing Session 4 (Assessment Execution) of the AgentGitOps workflow.
Reference bootstrap/agentgitops-instructions.md for full instructions.

Tasks:
1. Authenticate to required services (Azure, GitHub, Cloudflare, etc.)
2. Fetch the Phase 0 assessment issues from the GitHub project:
   gh issue list --milestone "Phase 0 - Assessment" --state open --json number,title
3. For each Phase 0 issue:
   a. Read the acceptance criteria
   b. Execute the assessment commands (see docs/ASSESSMENT_COMMANDS.md if available)
   c. Document findings in the issue comments
   d. If a gap is found, create a new issue file in artifacts/backlog-issues/ with
      issue_type: "gap-analysis-finding" and the gap-analysis-finding label
4. Update docs/KNOWN_ISSUES.md with any new findings
5. Create gap-analysis issues for any deviations found:
   ./bootstrap/create-backlog-issues.sh artifacts/backlog-issues/{new_files}.md
6. Close completed Phase 0 issues
```

---

## Session 5+: Backlog Burn-Down

**Role:** Human + Agent (per-phase, ongoing)  
**Time:** Per phase (days to weeks)

### Session 5 Agent Prompt — Phase Start

> The PM creates a Phase Initiation issue at the start of each phase. For agent-assigned issues:

```
You are a Copilot Coding Agent assigned to issue #{ISSUE_NUMBER}.
Reference bootstrap/agentgitops-instructions.md and .github/copilot-instructions.md.

Tasks:
1. Fetch the issue details: gh issue view {ISSUE_NUMBER}
2. Read the acceptance criteria carefully
3. Check current branch and confirm it tracks the correct feature branch
4. Review the relevant source files mentioned in the issue
5. Propose an implementation plan based on the acceptance criteria
6. Implement the changes, following the conventions in copilot-instructions.md
7. Run existing tests and linters to validate changes
8. Create a PR with a clear title and description referencing the issue
```

### Phase Retrospective Prompt

> Run at the end of each phase:

```
Execute the phase retrospective for Phase {N}:

1. Run: bash bootstrap/generate-phase-retrospective.sh {N}
2. Review the generated docs/retrospectives/phase-{N}-retrospective.md
3. Stage and commit: git add docs/retrospectives/ && git commit -m "docs: Phase {N} retrospective"
4. Post the full retrospective as a comment on the retrospective issue:
   gh issue comment {ISSUE_NUMBER} --body-file docs/retrospectives/phase-{N}-retrospective.md
5. Close the milestone:
   gh api -X PATCH repos/{owner}/{repo}/milestones/{milestone_number} -f state=closed
6. Update project board: move the retrospective issue to Done
7. Push changes: git push
```

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

| Script | Purpose | Auth Required | When |
|---|---|---|---|
| `check-prerequisites.sh` | Verify tools, auth, and permissions | None (checks auth) | Before Session 3 |
| `setup-github-labels.sh` | Create/update all labels (idempotent) | `GITHUB_TOKEN` | Session 3, Step 2 |
| `setup-github-milestones.sh` | Create milestones for each phase | `GITHUB_TOKEN` | Session 3, Step 3 |
| `create-backlog-issues.sh` | Create issues from `.md` files in `artifacts/backlog-issues/` | `GITHUB_TOKEN` | Session 3, Step 4 |
| `setup-github-project.sh` | Create project + custom fields + add issues | `project` scope PAT | Session 3, Step 5 |
| `generate-phase-retrospective.sh` | Generate phase retrospective report | `GITHUB_TOKEN` | Each phase boundary |
| `project-fields.json` | GitHub Project V2 field/option IDs | N/A | Refresh after Step 5 |

---

## Role-Scoped GitHub Project Views

The project views drive collaboration and AI assignment. Each view is designed for specific roles:

| View | Type | Primary Audience | Key Config |
|---|---|---|---|
| **Board** | Board | All roles | Group by Status; columns: Backlog → Ready → In Progress → Done |
| **Roadmap** | Roadmap | PM, Business Driver | Date: Start/End Date; Group by Phase |
| **Current Sprint** | Table | Technologist, AI Copilot | Filter: current phase; Status ≠ Done |
| **Copilot Queue** | Table | AI Copilot (primary) | Filter: Copilot Suitable = Yes; Sort by Phase → Priority |
| **Phase Overview** | Table | PM | Group by Phase; sort by Priority |
| **Priority Triage** | Table | PM, Technologist | Sort by Priority ascending |
| **My Work** | Table | All roles | Filter: Assignee = @me |
| **Blocked & At Risk** | Table | PM | Filter: Status = blocked |
| **Velocity Dashboard** | Table | PM | Group by Phase; Story Points field visible |
| **Retrospective Tracker** | Table | PM | Filter: type: phase-retrospective |

**Required fields in every view:** Title, Assignees, Status, Copilot Suitable, Phase, Priority, Size.

> The **Copilot Queue** view is key for AI productivity — it shows all issues labeled `Copilot: Yes` sorted by phase and priority, making it easy to assign to Copilot agents. The **Velocity Dashboard** tracks SP delivery per phase, enabling planned-vs-actual KPI reporting.

See [`project-views-guide.md`](project-views-guide.md) for complete setup instructions.

---

## Human vs AI Productivity KPIs

Phase retrospectives (generated by `generate-phase-retrospective.sh`) track:

| Metric | Formula | Purpose |
|---|---|---|
| **Task-level AI ratio** | Copilot: Yes closed ÷ total closed | How many tasks did AI handle? |
| **Commit-level AI ratio** | Co-authored commits ÷ total commits | How much code did AI write? |
| **SP velocity** | Total SP delivered ÷ working days | Overall team throughput |
| **AI SP velocity** | AI SP delivered ÷ total SP | AI contribution to velocity |
| **Planned vs actual** | Delivered SP ÷ planned SP | Estimation accuracy |

**Goal:** Show velocity increasing over time as humans focus on high-judgment work and AI agents handle well-defined, consistent tasks — demonstrating real progress at a good value and cost point.

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
4. **Customize** the files listed in the [Required Customization](#️-before-you-start--required-customization) section above
5. **Follow Sessions 0–5** using the copy-paste prompts above

---

## Reference Implementation

This `bootstrap/` package was developed and demonstrated on the [azure-resume-iac](https://github.com/rmcveyhsawaknow/azure-resume-iac) project — a multi-phase infrastructure-as-code update for an Azure-hosted resume site. The reference implementation includes 6 phases, 80+ issues, complete retrospective data, and the full backlog CSV at `artifacts/backlog.csv`.

See [`backlog_workflow.md`](backlog_workflow.md) for this project's implementation details.
