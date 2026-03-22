# AgentGitOps Bootstrap

> **What is AgentGitOps?** A repeatable, multi-session workflow that combines AI coding agents (GitHub Copilot) with `gh` CLI automation to plan, populate, and burn down a project backlog in GitHub — going from goals to executing backlog in hours, not days.

For the full reference guide with Mermaid diagrams, role definitions, and KPI tracking, see [`agentgitops-instructions.md`](agentgitops-instructions.md).

---

## It's This Simple — 3 Steps to Start

```
Step 1 ─── Copy this bootstrap/ directory into your repository
Step 2 ─── Open in GitHub Codespace · Select Copilot Plan mode · Select Claude Opus 4.6
Step 3 ─── Paste the Session 0 prompt below · Answer the questions · Let the agent fill in everything
```

> **No manual script editing required.** The Session 0 agent reads your answers and populates all phase labels, milestones, and the initial backlog CSV automatically.

---

## What's in This Directory

| File | Purpose |
|---|---|
| **`README.md`** | This file — quick start, session prompts, and workflow overview |
| **`agentgitops-instructions.md`** | Full workflow guide with Mermaid diagrams, role definitions, KPI tracking |
| **`backlog_workflow.md`** | Project-specific workflow reference (this repo's implementation) |
| **`project-views-guide.md`** | GitHub Project V2 views setup guide for all team sizes |
| **`check-prerequisites.sh`** | Verify tools, auth, and permissions before running scripts |
| **`setup-github-labels.sh`** | Create/update all labels across 9 categories (idempotent) |
| **`setup-github-milestones.sh`** | Create GitHub milestones per phase with optional due dates |
| **`create-backlog-issues.sh`** | Create GitHub issues from `artifacts/backlog-issues/*.md` files |
| **`setup-github-project.sh`** | Create GitHub Project V2 with custom fields + add all issues |
| **`generate-phase-retrospective.sh`** | Generate phase retrospective report with SP velocity and AI KPIs |
| **`project-fields.json`** | GitHub Project V2 field and option IDs (refresh after `setup-github-project.sh`) |
| **`backlog-template.csv`** | Session 0 template — agent copies and fills this in automatically |

---

## Step 1: Copy Bootstrap Into Your Repository

```bash
# Copy the bootstrap/ folder and issue templates into your repository
cp -r path/to/azure-resume-iac/bootstrap/ your-repo/bootstrap/
mkdir -p your-repo/.github
cp -r path/to/azure-resume-iac/.github/ISSUE_TEMPLATE/ your-repo/.github/ISSUE_TEMPLATE/

# Commit to your default branch
cd your-repo
git add bootstrap/ .github/ISSUE_TEMPLATE/
git commit -m "bootstrap: add AgentGitOps bootstrap directory"
git push
```

> **Tip:** You can also fork or clone `rmcveyhsawaknow/azure-resume-iac` and use it as a template repository.

---

## Step 2: Open in GitHub Codespace

1. Open your repository on GitHub
2. Click **Code → Codespaces → Create codespace on your default branch** (for example, `main`)
3. Once the Codespace loads, open **GitHub Copilot Chat**
4. Change the model to **Claude Opus 4.6** (or latest Opus model available)
5. Switch Copilot to **Plan mode** (click the mode selector next to the model dropdown)

> **Why Plan mode + Opus 4.6?** Plan mode lets the agent ask clarifying questions and present a complete plan for your review before writing any files. Opus 4.6 provides the highest-quality reasoning for project planning tasks.

---

## Step 3: Paste the Session 0 Prompt

Copy the prompt below and paste it into Copilot Chat. The agent will ask you questions about your project, then — once you confirm the plan — populate all scripts and create your initial backlog.

---

## Session 0 Prompt — Interactive Backlog Planning

> **Copy-paste this entire block into Copilot Chat (Plan mode, Claude Opus 4.6):**

```
You are a Project Manager assistant setting up an AgentGitOps project backlog.
Reference bootstrap/agentgitops-instructions.md for the full workflow guide.
Reference bootstrap/backlog-template.csv for the CSV structure.

=== PLANNING PHASE ===

Before writing any files, ask me the following questions one group at a time.
Wait for my response before moving to the next group.

GROUP 1 — Project Overview:
  a) What is this project? (one sentence describing what it does or will do)
  b) What problem does it solve or what goal does it achieve?
  c) What is the GitHub repository name? (owner/repo format)

GROUP 2 — Business Objectives:
  a) List your top 3–5 goals for this project.
     Examples: "Migrate backend to .NET 8", "Reduce cloud hosting costs by 30%",
               "Pass SOC2 Type II audit", "Launch new feature by Q3", "Refactor monolith to microservices"
  b) How will you know the project is complete? (success criteria)

GROUP 3 — Phases and Milestones:
  Choose one of the standard templates below, or describe custom phases:

  Template A — Security Hardening (3 implementation phases):
    Phase 0: Assessment → Phase 1: Remediation → Phase 2: Validation & Hardening → Phase 3: Cleanup & Docs

  Template B — Cloud or Platform Migration (4 implementation phases):
    Phase 0: Assessment → Phase 1: Refactor → Phase 2: Migrate → Phase 3: Validate & Cutover → Phase 4: Cleanup & Docs

  Template C — Feature Development / Greenfield (3 implementation phases):
    Phase 0: Assessment → Phase 1: Foundation & Scaffolding → Phase 2: Build → Phase 3: Deploy & Validate → Phase 4: Cleanup & Docs

  Template D — Custom: describe your phases (name + one-line objective each)

  Also provide:
  a) Approximate start date (YYYY-MM-DD)
  b) Target completion date (YYYY-MM-DD)

GROUP 4 — Team and Stack:
  a) Team size: Solo (1), Small (2–5), or Larger (6+)?
  b) Technology stack: list languages, frameworks, cloud services involved
  c) Any area domains relevant to your project?
     Standard areas: infrastructure, backend, frontend, ci-cd, dns-cdn, documentation, credentials
     Add custom areas if needed (e.g., "area: data-pipeline", "area: mobile")

=== IMPLEMENTATION PHASE ===

After I confirm my answers, implement the following. Pause for confirmation between each step.

STEP A — Update bootstrap/setup-github-labels.sh:
  Replace the Phase labels in the "# CUSTOMIZE:" section with the confirmed phase names.
  Format: "Phase N - Phase Name" for each phase (0-indexed).
  Preserve all other label categories unchanged.
  If custom area labels were requested, add them to the "=== Domain Area Labels ===" section.

STEP B — Update bootstrap/setup-github-milestones.sh:
  Replace the MILESTONES array entries with the confirmed phase names, descriptions (one line each),
  and keep the PHASE_N_DUE env var pattern for due dates.
  Use the confirmed timeline to suggest reasonable due date spacing.

STEP C — Create docs/BACKLOG_PLANNING.md:
  Include:
  - Project overview and business objectives from GROUP 1 & 2
  - Phase breakdown table: Phase | Objective | Key Tasks | Success Criteria | SP Estimate
  - Story point capacity estimate: team size × 3 SP/day × working days per phase
  - Standard phase structure reminder: Phase 0 = Assessment, last phase = Cleanup & Docs

STEP D — Create artifacts/backlog.csv:
  Copy from bootstrap/backlog-template.csv structure.
  - Phase 0 always includes: Verify credentials, Inventory resources, Assess services,
    Assess CI/CD, Document known issues, Phase 0 Retrospective
  - Middle phases: generate 3–6 tasks per phase based on the business objectives
    (Copilot: Yes for code/docs tasks, Copilot: No for credential/manual tasks)
  - Final phase always includes: Inventory old resources, Remove deprecated resources,
    Update all documentation, Final validation, Project retrospective
  - Each phase ends with a retrospective task (copilot_suitable: Partial, label: phase-retrospective)
  - Label names MUST match exactly: phase labels from STEP A, priority P1–P4, size S/M/L/XL,
    Copilot: Yes/Partial/No, area: X labels

STEP E — Verify consistency:
  Confirm that phase names are identical across:
  - bootstrap/setup-github-labels.sh (Phase labels)
  - bootstrap/setup-github-milestones.sh (MILESTONES array)
  - artifacts/backlog.csv (phase_name column and labels column)
  Report any mismatches and fix them before finishing.

Output a summary of all files created/modified and the phase structure decided.
```

---

## Standard Project Templates — Reference Answers

Use one of these as a starting point when answering Group 3 in the Session 0 prompt. Adapt to your project specifics.

### Template A: Security Hardening

```
Phases (Template A):
  Phase 0: Assessment — Inventory all resources, identify vulnerabilities, document current state
  Phase 1: Remediation — Rotate credentials, patch vulnerabilities, enforce MFA and RBAC
  Phase 2: Validation & Hardening — Run security scans, harden configs, implement monitoring
  Phase 3: Cleanup & Docs — Remove legacy access, update runbooks, close project

Timeline: Start 2025-08-01, Complete 2025-10-31
Team: Solo developer
Stack: Azure (Key Vault, RBAC, Defender), GitHub Actions
Areas: infrastructure, credentials, ci-cd, documentation
```

### Template B: Cloud / Platform Migration

```
Phases (Template B):
  Phase 0: Assessment — Inventory source platform, document dependencies, identify blockers
  Phase 1: Refactor — Update application code and IaC for target platform compatibility
  Phase 2: Migrate — Deploy to target platform, run parallel testing, validate data
  Phase 3: Validate & Cutover — End-to-end validation, DNS cutover, decommission source
  Phase 4: Cleanup & Docs — Remove source resources, update documentation, close project

Timeline: Start 2025-09-01, Complete 2026-01-31
Team: Small (3 developers)
Stack: Source: AWS Lambda / Node.js → Target: Azure Functions / .NET 8, Bicep IaC
Areas: infrastructure, backend, ci-cd, dns-cdn, documentation
```

### Template C: Feature Development / Greenfield

```
Phases (Template C):
  Phase 0: Assessment — Review existing codebase, document architecture, identify gaps
  Phase 1: Foundation & Scaffolding — Set up project structure, CI/CD, base dependencies
  Phase 2: Build — Implement core features per acceptance criteria
  Phase 3: Deploy & Validate — Deploy to staging and production, user acceptance testing
  Phase 4: Cleanup & Docs — Remove scaffolding, finalize documentation, close project

Timeline: Start 2025-07-15, Complete 2025-11-30
Team: Solo developer with AI Copilot
Stack: React, Node.js, Azure App Service, GitHub Actions
Areas: frontend, backend, ci-cd, documentation
```

---

## After Session 0 Completes

When the agent finishes, you will have:

- ✅ `bootstrap/setup-github-labels.sh` — phase labels updated to your project
- ✅ `bootstrap/setup-github-milestones.sh` — milestones updated to your phases
- ✅ `docs/BACKLOG_PLANNING.md` — phased plan with task breakdown and capacity estimates
- ✅ `artifacts/backlog.csv` — initial backlog CSV ready for Sessions 2–3

**Review and commit:**
```bash
git add bootstrap/setup-github-labels.sh bootstrap/setup-github-milestones.sh \
        docs/BACKLOG_PLANNING.md artifacts/backlog.csv
git commit -m "bootstrap(session-0): populate phases, milestones, and initial backlog"
git push
```

---

## Workflow — Sessions 0 Through 5+

```
Session 0 ─── Goal-Focused Backlog Planning (agent-interactive)
    ↓         Output: docs/BACKLOG_PLANNING.md + artifacts/backlog.csv
    ↓         Scripts populated: setup-github-labels.sh, setup-github-milestones.sh
Session 1 ─── Bootstrap — Insert Copilot Instructions (agent)
    ↓         Output: .github/copilot-instructions.md
Session 2 ─── Backlog Research (agent)
    ↓         Output: artifacts/backlog-issues/*.md + assessment docs
Session 3 ─── Issue Population (agent in Codespace)
    ↓         Output: GitHub Issues, Labels, Milestones, Project
Session 4 ─── Assessment Execution (agent + human)
    ↓         Output: Gap analysis findings, assessment artifacts
Session 5+ ── Backlog Burn-Down (per phase, ongoing)
    ↓         Output: Code changes, PRs, deployments
  ┌─────────── Phase Boundary: Retrospective ───────────┐
  │  Output: docs/retrospectives/phase-N-retrospective.md │
  │  → close milestone → plan next phase → repeat         │
  └────────────────────────────────────────────────────────┘
```

---

## Session 1: Bootstrap — Copilot Instructions

**Role:** Agent  
**Time:** 15–30 minutes  
**Output:** `.github/copilot-instructions.md`

### Session 1 Agent Prompt

> Copy-paste into Copilot Chat:

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

**Role:** Agent (Copilot Coding Agent)  
**Time:** 2–4 hours  
**Input:** `artifacts/backlog.csv`, `.github/copilot-instructions.md`, codebase  
**Output:** `artifacts/backlog-issues/*.md`, assessment docs

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
   artifacts/backlog-issues/{task_id}.md with YAML frontmatter:
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

   Body: # Title\n## Description\n## Acceptance Criteria\n- [ ] ...

3. Produce architecture and assessment documentation:
   - docs/ARCHITECTURE.md — system overview, component inventory
   - docs/ASSESSMENT_COMMANDS.md — CLI commands to verify deployed state
   - docs/KNOWN_ISSUES.md — identified gaps, tech debt, security concerns

4. Create one Phase Initiation issue file per phase (type: phase-initiation):
   artifacts/backlog-issues/phase-{N}-initiation.md

5. Create one Phase Retrospective issue file per phase (type: phase-retrospective):
   artifacts/backlog-issues/phase-{N}-retrospective.md

6. If any gaps are discovered during codebase review, create additional issue files
   with issue_type: "gap-analysis-finding" and include the "gap-analysis-finding" label.

7. Ensure all label names match exactly what bootstrap/setup-github-labels.sh creates.
```

---

## Session 3: Issue Population

**Role:** Agent in Codespace  
**Time:** 1–2 hours

### Session 3 Agent Prompt

> Copy-paste into Copilot Chat in a Codespace:

```
You are executing Session 3 (Issue Population) of the AgentGitOps workflow.
Reference bootstrap/agentgitops-instructions.md for full instructions.

Execute these steps in order. Report completion after each step.

Step 1 — Check prerequisites:
  ./bootstrap/check-prerequisites.sh

Step 2 — Create labels:
  ./bootstrap/setup-github-labels.sh [owner/repo]

Step 3 — Create milestones:
  ./bootstrap/setup-github-milestones.sh [owner/repo]

Step 4 — Create issues (dry run first):
  ./bootstrap/create-backlog-issues.sh --dry-run [owner/repo]
  # If dry run output looks correct, proceed:
  ./bootstrap/create-backlog-issues.sh [owner/repo]

Step 5 — Set up GitHub Project:
  # Requires project scope PAT — run: gh auth login --scopes "project,repo,read:org"
  ./bootstrap/setup-github-project.sh [owner]

Step 6 — Refresh project field IDs in bootstrap/project-fields.json:
  gh project field-list <PROJECT_NUMBER> --owner <OWNER> --format json \
    | python3 -c "import json,sys; [print(f['id'], f['name'], \
        [o['id']+' '+o['name'] for o in f.get('options',[])]) \
        for f in json.load(sys.stdin)['fields']]"
  # Update projectId, phaseFieldId, priorityFieldId, sizeFieldId, copilotFieldId
  # and their options maps in bootstrap/project-fields.json

Step 7 — Configure project views:
  # Follow bootstrap/project-views-guide.md for the 10 recommended views.
  # Minimum: Board, Roadmap, Current Sprint, Copilot Queue, Priority Triage
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

**Role:** Agent + Human  
**Time:** 1–4 hours  
**Output:** Assessment artifacts, gap analysis findings

### Session 4 Agent Prompt

> Copy-paste into Copilot Chat in a Codespace:

```
You are executing Session 4 (Assessment Execution) of the AgentGitOps workflow.
Reference bootstrap/agentgitops-instructions.md for full instructions.

Tasks:
1. Fetch the Phase 0 assessment issues from GitHub:
   gh issue list --milestone "Phase 0 - Assessment" --state open --json number,title

2. For each Phase 0 issue:
   a. Read the acceptance criteria
   b. Execute the assessment commands (see docs/ASSESSMENT_COMMANDS.md)
   c. Document findings as comments on the issue
   d. If a gap is found, create a new issue file in artifacts/backlog-issues/
      with issue_type: "gap-analysis-finding" and the gap-analysis-finding label

3. Update docs/KNOWN_ISSUES.md with any new findings

4. Create gap-analysis issues for deviations found:
   ./bootstrap/create-backlog-issues.sh artifacts/backlog-issues/{new_files}.md

5. Close completed Phase 0 assessment issues
```

---

## Session 5+: Backlog Burn-Down

**Role:** Human + Agent (per-phase, ongoing)

### Session 5 Agent Prompt — Assigned Issue

> For issues labeled `Copilot: Yes`, assign to Copilot. For others, paste into Copilot Chat:

```
You are a Copilot Coding Agent assigned to issue #{ISSUE_NUMBER}.
Reference bootstrap/agentgitops-instructions.md and .github/copilot-instructions.md.

Tasks:
1. Fetch the issue: gh issue view {ISSUE_NUMBER}
2. Read the acceptance criteria carefully
3. Check current branch and confirm it tracks the correct feature branch
4. Review the relevant source files mentioned in the issue
5. Propose an implementation plan based on the acceptance criteria
6. Implement the changes, following the conventions in .github/copilot-instructions.md
7. Run existing tests and linters to validate changes
8. Create a PR with a clear title and description referencing the issue
```

### Phase Retrospective Prompt

> Run at the end of each phase:

```
Execute the phase retrospective for Phase {N}:

1. Run: bash bootstrap/generate-phase-retrospective.sh {N}
2. Review docs/retrospectives/phase-{N}-retrospective.md
3. Commit: git add docs/retrospectives/ && git commit -m "docs: Phase {N} retrospective"
4. Post as a comment on the retrospective issue:
   gh issue comment {ISSUE_NUMBER} --body-file docs/retrospectives/phase-{N}-retrospective.md
5. Close the milestone:
   gh api -X PATCH repos/{owner}/{repo}/milestones/{number} -f state=closed
6. Push: git push
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

## Prerequisites

Before Session 3, verify your environment:

| Tool | Check Command |
|---|---|
| `gh` CLI 2.0+ | `gh --version` |
| `git` 2.30+ | `git --version` |
| `python3` 3.8+ | `python3 --version` |
| `jq` 1.6+ | `jq --version` |

```bash
./bootstrap/check-prerequisites.sh
```

> **Note:** The `project` scope is not available in Codespace `GITHUB_TOKEN`. For project setup (Session 3, Step 5), run locally with `gh auth login --scopes "project,repo,read:org"` or use a Personal Access Token.

---

## Reference Implementation

This `bootstrap/` package was developed and demonstrated on the [azure-resume-iac](https://github.com/rmcveyhsawaknow/azure-resume-iac) project — an Azure-hosted living resume site modernized end-to-end using this workflow. The reference implementation includes 6 phases, 80+ issues, complete retrospective data, and the full backlog at `artifacts/backlog.csv`.

See [`backlog_workflow.md`](backlog_workflow.md) for the project-specific implementation reference.

For the full workflow guide, see [`agentgitops-instructions.md`](agentgitops-instructions.md).
