# AgentGitOps

> A human-driven, AI-powered project management workflow — from goals to executing backlog in hours, not days.

**Source:** [`bootstrap/README.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/bootstrap/README.md) · [`bootstrap/agentgitops-instructions.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/bootstrap/agentgitops-instructions.md)

---

## Table of Contents

- [What is AgentGitOps?](#what-is-agentgitops)
- [The Human-AI Loop](#the-human-ai-loop)
- [Session Workflow](#session-workflow)
- [Phase Lifecycle](#phase-lifecycle)
- [Copilot Suitability](#copilot-suitability)
- [Scripts Reference](#scripts-reference)
- [Issue Type Taxonomy](#issue-type-taxonomy)
- [Label Taxonomy](#label-taxonomy)
- [Story Point Capacity Model](#story-point-capacity-model)
- [Getting Started with AgentGitOps](#getting-started-with-agentgitops)
- [See also](#see-also)

---

## What is AgentGitOps?

AgentGitOps is a repeatable workflow that combines **GitHub Copilot agents** with **`gh` CLI automation** to plan, populate, and burn down a project backlog entirely within GitHub. The human provides goals and judgment; the AI handles code generation, documentation, and repetitive tasks.

The entire workflow is portable — copy the `bootstrap/` directory into any repository and follow the sessions below to go from a blank project to a fully tracked, executing backlog.

## The Human-AI Loop

AgentGitOps divides work by **who's best at it**:

| Human does | AI does |
|---|---|
| Defines goals and success criteria | Generates code, tests, and documentation |
| Reviews PRs and approves merges | Creates feature branches and PRs |
| Manages credentials and portal access | Writes Bicep templates, workflows, scripts |
| Makes architectural decisions | Breaks down issues into implementation steps |
| Runs retrospectives and adjusts priorities | Produces metrics and reports |

The key insight: **the human drives direction; the AI handles volume.** Every issue is tagged with a Copilot Suitability field so the system knows which tasks to route to the agent and which require human attention.

```
┌─────────────────────────────────────────────────────────┐
│                   Phase Cycle                           │
│                                                         │
│   PM defines goals                                      │
│       │                                                 │
│       ▼                                                 │
│   Agent creates issues + branches                       │
│       │                                                 │
│       ▼                                                 │
│   Agent implements (Copilot: Yes tasks)                 │
│       │                                                 │
│       ▼                                                 │
│   Human reviews PRs + handles (Copilot: No tasks)       │
│       │                                                 │
│       ▼                                                 │
│   PM runs retrospective (SP velocity + AI KPIs)         │
│       │                                                 │
│       ▼                                                 │
│   Adjust priorities → next phase                        │
└─────────────────────────────────────────────────────────┘
```

## Session Workflow

AgentGitOps operates in **six sessions** (0–5) followed by repeating phase retrospectives:

| Session | Name | Who | What Happens |
|---|---|---|---|
| **0** | Goal-Focused Backlog Planning | PM + Agent | Agent interviews PM for goals, phases, timeline. Produces `BACKLOG_PLANNING.md` + `backlog.csv`. Updates phase labels and milestones in scripts. |
| **1** | Bootstrap — Copilot Instructions | Agent | Agent reads the codebase and generates `.github/copilot-instructions.md` |
| **2** | Backlog Research | Agent | Agent reads codebase + Session 0 CSV, generates issue `.md` files in `artifacts/backlog-issues/`, produces assessment docs |
| **3** | Issue Population | Human + Agent | Run scripts to create labels, milestones, issues, and the GitHub Project |
| **4** | Assessment Execution | Human + Agent | Execute Phase 0 assessment tasks, produce gap analysis findings |
| **5+** | Backlog Burn-Down | Human + Agent | Per-phase cycle: work issues via feature branches + Copilot agents |

### Session 0 in practice

Session 0 is interactive — you paste a prompt into Copilot Chat (Plan mode, Opus 4.6) and the agent asks you questions in groups:

1. **Project Overview** — what is this, what problem does it solve
2. **Business Objectives** — top 3–5 goals, success criteria
3. **Phases and Milestones** — choose a template or describe custom phases
4. **Team and Stack** — team size, technologies, area domains

Once you confirm, the agent populates all scripts and creates initial planning artifacts. No manual script editing required.

### Sessions 1–2: automated discovery

The agent reads your entire codebase — IaC templates, application code, workflows, scripts — and generates architecture docs, known issues, and individual issue markdown files organized by phase.

### Session 3: one-command population

Run the bootstrap scripts in sequence to go from issue files to a fully populated GitHub Project:

```bash
./bootstrap/check-prerequisites.sh
./bootstrap/setup-github-labels.sh
./bootstrap/setup-github-milestones.sh
./bootstrap/create-backlog-issues.sh
./bootstrap/setup-github-project.sh
```

### Sessions 4+: execute and iterate

Work through the backlog phase by phase. The Copilot Queue project view filters for `Copilot Suitable = Yes` tasks, sorted by phase and priority — this is the agent's work queue.

## Phase Lifecycle

Each phase follows a consistent pattern:

1. **Phase Initiation** — PM creates an issue with objectives, dates, and planned SP capacity
2. **Burn-Down** — Technical Tasks, Bugs, and Feature Requests are worked by Technologists and AI Copilot
3. **Retrospective** — PM runs `generate-phase-retrospective.sh`, assesses success criteria
4. **Milestone closed** — Report committed to `docs/retrospectives/phase-N-retrospective.md`
5. **Next phase** — PM creates new Phase Initiation issue and the cycle repeats

Issue status tracks the lifecycle through the board:

`🔲 Backlog` → `✅ Ready` → `🔄 In Progress` → `👀 In Review` → `Done` | `🚫 Blocked` | `📦 Deferred`

## Copilot Suitability

Every issue carries a Copilot Suitability field — this is a **first-class concept** that drives AI task routing and productivity measurement:

| Value | Label | When to use |
|---|---|---|
| **Yes** | `Copilot: Yes` | Code generation, refactoring, test writing, docs, scripting — fully automatable |
| **Partial** | `Copilot: Partial` | Requires human judgment, but agent can assist with code/docs portions |
| **No** | `Copilot: No` | Portal access, credential management, manual verification, human decisions |

The **Human vs AI Productivity KPI** is computed at each retrospective:

- **Task-level:** Closed `Copilot: Yes` issues ÷ total closed issues
- **Story point velocity:** AI-delivered SP ÷ total SP delivered

This metric helps calibrate how much work to delegate to the agent over time.

## Scripts Reference

| Script | Purpose |
|---|---|
| `check-prerequisites.sh` | Verify tools (`gh`, `jq`, `python3`, etc.) and auth before running other scripts |
| `setup-github-labels.sh` | Create/update all labels across 9 categories (idempotent — safe to re-run) |
| `setup-github-milestones.sh` | Create milestones per phase with due dates |
| `create-backlog-issues.sh` | Batch-create GitHub issues from `artifacts/backlog-issues/*.md` files with auto-labels |
| `setup-github-project.sh` | Create GitHub Project V2 with custom fields (Phase, Priority, Size, Copilot Suitable, Status) + add all issues |
| `generate-phase-retrospective.sh` | Generate phase retrospective report with SP velocity, AI ratio, and KPI tracking |

All scripts are idempotent and can be re-run safely.

## Issue Type Taxonomy

| Type | Template | When |
|---|---|---|
| **Phase Initiation** | `phase-initiation.yml` | Phase start — sets objectives and capacity |
| **Technical Task** | `backlog-task.yml` | During burn-down — implementation work |
| **Phase Retrospective** | `phase-retrospective.yml` | Phase end — metrics and assessment |
| **Bug Report** | `bug-report.yml` | As discovered during any phase |
| **Feature Request** | `feature-request.yml` | As discovered — backlogged for future phases |

## Label Taxonomy

Labels are organized into 9 categories:

| Category | Examples | Purpose |
|---|---|---|
| **Phase** | `Phase 0 - Assessment` through `Phase 5` | Roadmap grouping |
| **Priority** | `P1 – Critical` through `P4 – Low` | Triage ordering |
| **Size** | `S (half-day)`, `M (1–2 days)`, `L (3–5 days)`, `XL (1 week+)` | Sprint planning |
| **Copilot** | `Copilot: Yes`, `Copilot: Partial`, `Copilot: No` | AI routing |
| **Area** | `area: infrastructure`, `area: backend`, etc. | Domain filtering |
| **Type** | `type: technical-task`, `type: bug`, etc. | Issue classification |
| **Status** | `🔲 Backlog`, `✅ Ready`, `🔄 In Progress`, `Done` | Board columns |
| **Source** | `gap-analysis-finding`, `phase-retrospective` | Origin tracking |

## Story Point Capacity Model

| Size | Story Points | Hours | Description |
|---|---|---|---|
| **S** (half-day) | 1 SP | 2.5 hrs | Small, well-defined task |
| **M** (1–2 days) | 3 SP | 7.5 hrs | Medium complexity |
| **L** (3–5 days) | 8 SP | 20 hrs | Large, multiple components |
| **XL** (1 week+) | 13 SP | 32.5+ hrs | Extra-large, consider decomposing |

**Capacity constants:** 1 SP = 2.5 hours · 3 SP/dev/day · 15 SP/dev/week

## Getting Started with AgentGitOps

It's genuinely three steps:

```
Step 1 ─── Copy bootstrap/ and .github/ISSUE_TEMPLATE/ into your repo
Step 2 ─── Open in GitHub Codespace · Select Copilot Plan mode · Select Claude Opus 4.6
Step 3 ─── Paste the Session 0 prompt (from bootstrap/README.md) · Answer the questions
```

The agent does the rest — no manual script editing, no CSV wrangling.

For the full reference with Mermaid diagrams, role definitions, and detailed session instructions, see [`bootstrap/agentgitops-instructions.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/bootstrap/agentgitops-instructions.md).

---

## See also

- [Contributing](Contributing) — branching model and PR flow
- [CI-CD](CI-CD) — how code changes flow through the pipeline
- [Glossary](Glossary) — AgentGitOps-specific terms
