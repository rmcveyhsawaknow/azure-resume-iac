# Repository Content Sources

This reference is the **content map** the [`wiki-generator`](../SKILL.md) skill uses to decide what to read in the source repository when planning each wiki page. It is intentionally generic — the skill discovers what actually exists in the target repo and adapts.

## How to use this map

For each candidate wiki page (left column), the skill reads the listed sources (middle column) **only if they exist** and synthesizes them into the page. If none of the sources for a page exist, the page is **omitted** rather than stubbed with placeholder content.

| Wiki Page | Source files / directories to read | Synthesis notes |
|---|---|---|
| `Home.md` | `README.md`, project metadata (badges, live URL, license) | Elevator pitch + navigation hub. 2–4 sentence "what is this". |
| `Getting-Started.md` | `README.md` (Quick Start / Setup section), `CONTRIBUTING.md`, `.devcontainer/devcontainer.json`, `.codespaces/`, `Makefile`, `package.json` scripts, `pyproject.toml`, `bootstrap/` setup scripts | Codespace path first (zero local install), then local fallback. List exact commands, not prose. |
| `Architecture.md` | `docs/ARCHITECTURE.md`, `docs/dev-environment-diagram.md`, top-level directory layout, `.iac/` orchestration templates | Lead with a diagram or ASCII layout. List components and data flow. |
| `Infrastructure.md` | `.iac/`, `infra/`, `terraform/`, `bicep/`, `cdk/`, `pulumi/`; any IaC `README.md`; module/template files | Tabulate resources by environment. Note IaC tool, scopes, and naming convention. |
| `Backend.md` | `backend/`, `src/`, `api/`, `app/`; `*.csproj`, `package.json`, `pyproject.toml`, `go.mod`; entry-point files (`Program.cs`, `main.go`, `app.py`, `index.js`) | Runtime + framework + project layout + endpoint inventory. |
| `Frontend.md` | `frontend/`, `web/`, `client/`, `ui/`; `package.json`, `vite.config.*`, `next.config.*`; entry HTML | Framework (or vanilla), build (or absence), deploy target. |
| `CI-CD.md` | `.github/workflows/*.yml`, `.gitlab-ci.yml`, `azure-pipelines.yml`, `Jenkinsfile` | One row per workflow: name, trigger, jobs, environments, secrets used. |
| `Deployment.md` | Workflows + IaC + `docs/CICD_WORKFLOWS.md`, `docs/DEPLOYMENT.md` | End-to-end deploy procedure. Include rollback. Call out blue/green or canary if present. |
| `Configuration.md` | `.env.example`, `appsettings*.json`, `config/`, `secrets/` references in code, Key Vault references in IaC | Tabulate required env vars: name, source (env / secret store), purpose. **Never include actual values.** |
| `Testing.md` | `tests/`, `test/`, `__tests__/`, `*.test.*`, `docs/LOCAL_TESTING.md`, CI test job | Commands to run unit/integration/E2E. Coverage target if defined. |
| `Troubleshooting.md` | `docs/KNOWN_ISSUES.md`, `docs/TROUBLESHOOTING.md`, `docs/retrospectives/`, common error sections in READMEs | Symptom → cause → fix tables. Link to issues for in-flight problems. |
| `Contributing.md` | `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `.github/copilot-instructions.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/` | Branching model, PR flow, code style, AI-agent conventions. |
| `Security.md` | `SECURITY.md`, `.github/dependabot.yml`, security sections in copilot-instructions, secret-scanning config | How to report vulns, secret handling rules, supported versions, dependency-update cadence. |
| `Project-Management.md` | `bootstrap/`, `docs/BACKLOG_PLANNING.md`, `artifacts/backlog.csv`, `docs/retrospectives/`, project board metadata | Project workflow, label taxonomy, roles, capacity model, view conventions. |
| `Skills-and-Agents.md` | `.github/skills/*/SKILL.md`, `.github/copilot-instructions.md` | Per-skill row: name, when to use, inputs, outputs, link to SKILL.md. |
| `Glossary.md` | Terms used repeatedly across docs, copilot-instructions, code comments | Repo-specific terms only — not a general dictionary. |

## Discovery patterns

When invoked, the skill should perform these searches **in parallel** to build its content inventory:

```bash
# Top-level docs
ls -1 *.md 2>/dev/null

# docs/ tree
find docs -type f -name '*.md' 2>/dev/null

# .github tree
find .github -type f \( -name '*.md' -o -name '*.yml' -o -name '*.yaml' \) 2>/dev/null

# IaC trees
find .iac infra terraform bicep cdk pulumi -type f 2>/dev/null

# Application code roots
ls -1d backend frontend src api app web client ui 2>/dev/null

# Test trees
find . -maxdepth 3 -type d \( -name tests -o -name test -o -name __tests__ \) 2>/dev/null

# Configuration files
ls -1 package.json *.csproj pyproject.toml go.mod Cargo.toml Gemfile *.sln 2>/dev/null

# Project metadata
ls -1d bootstrap scripts artifacts 2>/dev/null
```

The result of these probes determines which pages get generated and what content fills them.

## Filling gaps

If the skill finds **no source content** for a page in the recommended set, it has two options:

1. **Omit the page** (preferred). Don't fabricate.
2. **Generate a one-paragraph stub** *only* if the topic is critical to the repo type (e.g., a code repo with no `Testing.md` is a notable gap that should be flagged) — and the stub should explicitly say "Tests are not yet documented; see [issue #N] or contribute via PR."

Stubs are a smell; treat them as a backlog signal, not a finished product.

## Cross-cutting content

Some content appears across multiple pages — keep it in one place and link:

| Content | Canonical home | Linked from |
|---|---|---|
| Architecture diagram | `Architecture.md` | `Home.md`, `Infrastructure.md`, `Deployment.md` |
| Required env vars | `Configuration.md` | `Getting-Started.md`, `Backend.md`, `Frontend.md` |
| Branching model | `Contributing.md` | `CI-CD.md`, `Deployment.md` |
| Project board view setup | `Project-Management.md` | `Contributing.md` |

This avoids duplication and keeps the wiki maintainable on regeneration.
