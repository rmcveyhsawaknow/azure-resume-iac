---
name: wiki-generator
description: "Generate a complete, well-structured GitHub Wiki for the current repository by parsing source content (README, docs/, .github/, IaC, code, workflows) and producing markdown pages, sidebar, and footer staged in the repo's wiki/ directory. Use when: bootstrapping a new GitHub Wiki, refreshing wiki content after major changes, standardizing documentation across repositories, preparing wiki for the GitHub UI publishing workflow. Inputs: optional focus areas or excluded sections in tmp/wiki-input.md. Outputs: wiki/Home.md, wiki/_Sidebar.md, wiki/_Footer.md, and one wiki/<Topic>.md page per major area, ready to be mirrored to the <repo>.wiki.git repository by the publish-wiki.yml GitHub Actions workflow."
argument-hint: "(optional) Path to wiki input file (e.g., tmp/wiki-input.md). Omit to use defaults."
---

# Wiki Generator Skill

Generate a complete, idiomatic [GitHub Wiki](https://docs.github.com/en/communities/documenting-your-project-with-wikis/about-wikis) for the current repository by parsing the repo's existing source content (README, `docs/`, `.github/copilot-instructions.md`, IaC templates, application code, workflows, scripts) and producing a coherent set of markdown pages, a custom sidebar, and a footer.

The generated content is staged in the repo's `wiki/` directory. A companion workflow ([`.github/workflows/publish-wiki.yml`](../../workflows/publish-wiki.yml)) mirrors `wiki/` into the separate `<owner>/<repo>.wiki.git` repository that backs the GitHub Wiki UI.

> **Why a workflow?** GitHub Wikis are stored in a separate Git repository (`<owner>/<repo>.wiki.git`) and are **not** auto-mirrored from files in the source repo. The wiki must first be initialized (create one page in the GitHub UI), then any push to the wiki repo updates it. The publish workflow automates this synchronization.

## When to Use

- The repository has no wiki yet and you want to bootstrap a complete one
- Existing wiki content has drifted from the codebase and needs a refresh
- You want consistent wiki structure across multiple repositories
- You are preparing a repo for onboarding new contributors and want first-class navigation
- You want to satisfy GitHub Foundations / 900-level training expectations around documentation

## Prerequisites

1. The repository has a `wiki/` directory at its root (created by this skill if missing). The directory is committed to source control as the **source of truth** for wiki content.
2. The wiki has been initialized once via the GitHub UI (Repository → Wiki → "Create the first page" → Save). This is required before the publish workflow can clone `<repo>.wiki.git`.
3. (Optional) A `tmp/wiki-input.md` file with focus areas, excluded topics, or a target audience override. Copy [`templates/wiki-input-template.md`](./templates/wiki-input-template.md) to `tmp/wiki-input.md` and fill it in. If absent, the skill uses sensible defaults inferred from the repo.

## Procedure

### Step 1 — Prepare Workspace

Ensure the staging directory exists and read any optional input:

```bash
mkdir -p wiki/ tmp/
[ -f tmp/wiki-input.md ] || cp .github/skills/wiki-generator/templates/wiki-input-template.md tmp/wiki-input.md
```

If `tmp/wiki-input.md` exists and has been filled in, read it for:
- **Target audience** (default: contributors + new hires + reviewers)
- **Focus areas** to expand (e.g., "deep-dive on Bicep modules")
- **Excluded sections** to skip (e.g., "skip AgentGitOps section")
- **Tone/voice override** (default: matches existing `docs/` voice)

### Step 2 — Discover Repository Content

Parse the repository to identify content sources. Use the [`references/repo-content-sources.md`](./references/repo-content-sources.md) map as a starting point and adapt to whatever the repo actually contains. Do **not** assume any specific file exists — discover, then read.

Discovery checklist (run these searches/reads in parallel where possible):

1. **Root-level docs**: `README.md`, `CONTRIBUTING.md`, `LICENSE`, `CHANGELOG.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`
2. **`docs/` directory**: every `.md` file (architecture, runbooks, retrospectives, ADRs)
3. **`.github/` directory**: `copilot-instructions.md`, issue templates, PR template, `skills/*/SKILL.md`
4. **CI/CD**: every file in `.github/workflows/` — extract triggers, jobs, deployment targets
5. **Infrastructure as Code**: `.iac/`, `infra/`, `terraform/`, `bicep/`, `cdk/`, `pulumi/` — list resources and modules
6. **Application code**: top-level language directories (`backend/`, `frontend/`, `src/`, `app/`, `api/`) — language, framework, entry points
7. **Scripts**: `scripts/`, `bootstrap/`, `tools/` — operator-facing automation
8. **Tests**: `tests/`, `test/`, `__tests__/` — testing approach and how to run them
9. **Configuration**: `package.json`, `*.csproj`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, etc. — runtimes and dependencies
10. **Project metadata**: `bootstrap/`, `artifacts/backlog.csv`, `docs/BACKLOG_PLANNING.md` — project management workflow if present

For each discovered source, capture: file path, primary topic, and one-sentence summary. This becomes the content map driving page generation.

### Step 3 — Plan the Wiki Structure

Design the page set based on **what the repo actually contains**, following the [wiki structure best practices](./references/wiki-structure-best-practices.md). Aim for **8–14 top-level pages** — enough coverage without sprawl.

Recommended baseline structure (include only the pages whose source content exists):

| Page | Source Content | Purpose |
|---|---|---|
| `Home.md` | `README.md` + project metadata | Landing page: elevator pitch, badges, navigation, quick links |
| `Getting-Started.md` | `README.md` setup section, `CONTRIBUTING.md`, `.devcontainer/` | First-time contributor setup, dev environment, codespace usage |
| `Architecture.md` | `docs/ARCHITECTURE.md`, `.iac/`, code structure | System diagram, components, data flow, key dependencies |
| `Infrastructure.md` | `.iac/`, IaC READMEs | IaC layout, resources deployed, environment topology, blue/green strategy |
| `Backend.md` | `backend/`, API code | Runtime, framework, project layout, endpoints, configuration |
| `Frontend.md` | `frontend/`, `web/` | Framework (or vanilla), build (or absence of), deploy target |
| `CI-CD.md` | `.github/workflows/` | Per-workflow summary: trigger, jobs, environments, secrets used |
| `Deployment.md` | Workflows + IaC + `docs/CICD_WORKFLOWS.md` | End-to-end deploy procedure, rollback, blue/green swap |
| `Configuration.md` | App settings, Key Vault refs, `.env.example` | Required config, secret sources, environment variables |
| `Testing.md` | `tests/`, `docs/LOCAL_TESTING.md` | How to run unit/integration/E2E tests locally and in CI |
| `Troubleshooting.md` | `docs/KNOWN_ISSUES.md`, retrospectives | Common errors, fixes, gotchas |
| `Contributing.md` | `CONTRIBUTING.md`, `.github/copilot-instructions.md` | Branching, conventions, PR flow, code style |
| `Security.md` | `SECURITY.md`, copilot-instructions security section | Secret handling, key vault, vulnerability reporting |
| `Project-Management.md` | `bootstrap/`, `docs/BACKLOG_PLANNING.md` | Project workflow (e.g., AgentGitOps), labels, project board |
| `Skills-and-Agents.md` | `.github/skills/*/SKILL.md` | Available Copilot agent skills and how to invoke them |
| `Glossary.md` | Inferred from copilot-instructions and docs | Repo-specific terms, acronyms, naming conventions |

**Omit any page whose source content is absent.** Do not invent content — if there's no `tests/` directory, skip the Testing page (or add a "Tests not yet implemented" stub only if truly useful).

### Step 4 — Generate Pages

For each planned page, create `wiki/<Page-Name>.md` using [`templates/page-template.md`](./templates/page-template.md) as the structural starting point. Page filename rules:

- Use **hyphens** for spaces (GitHub Wiki converts hyphens to spaces in titles): `Getting-Started.md` → "Getting Started"
- Use **PascalCase or Title-Case** with hyphens: `CI-CD.md`, `Project-Management.md`
- Reserved files (start with underscore): `_Sidebar.md`, `_Footer.md`
- Avoid characters that GitHub Wiki escapes: `:`, `/`, `?`, `#`, `[`, `]`, `\`

For each page:

1. **Lead with a one-sentence purpose statement** so readers know if they're in the right place.
2. **Provide a short Table of Contents** for pages over ~150 lines.
3. **Quote/summarize the source files** (don't copy verbatim — the source files are the source of truth; wiki pages are an index/overview that link back).
4. **Link back to the source path** in the repo at the top of the page (e.g., "Source: [`docs/ARCHITECTURE.md`](https://github.com/<owner>/<repo>/blob/main/docs/ARCHITECTURE.md)") so readers can jump to the canonical content.
5. **Use intra-wiki links** for navigation: `[[Getting Started]]` or `[Getting Started](Getting-Started)` (no `.md` extension in wiki links).
6. **Include a "See also" section** at the bottom with 2–4 related wiki pages.

### Step 5 — Generate `Home.md`

The Home page is the wiki landing. Use [`templates/Home.md`](./templates/Home.md) as the basis. It must contain:

1. **Project name as H1**, one-line tagline immediately below
2. **Status badges** (copy from `README.md` if present)
3. **Live demo / production URL** (if applicable)
4. **"What is this?" paragraph** — 2–4 sentences for someone arriving cold
5. **"Start here" call-out** — a labeled link to `[[Getting Started]]`
6. **Page index** organized by audience: *For Contributors*, *For Operators*, *For Reviewers*
7. **External links** — repo, live site, related docs

### Step 6 — Generate `_Sidebar.md` and `_Footer.md`

`_Sidebar.md` appears on every page and is the primary navigation. Use [`templates/_Sidebar.md`](./templates/_Sidebar.md). Group links by theme (Overview, Build & Deploy, Reference, Project) and **always include a link to `[[Home]]`**.

`_Footer.md` appears at the bottom of every page. Use [`templates/_Footer.md`](./templates/_Footer.md). Include: link back to the source repo, last-updated note, and contact/issue link.

### Step 7 — Validate

Run the following checks before completing:

```bash
# 1. All planned pages exist and are non-empty
ls -la wiki/

# 2. No broken intra-wiki links (any [[X]] or ](X) where wiki/X.md doesn't exist)
#    Build the set of expected page slugs from filenames, then grep for links and verify each.

# 3. No accidental committed secrets
grep -rE '(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[A-Za-z0-9-]+|-----BEGIN [A-Z ]*PRIVATE KEY-----)' wiki/ && echo "SECRET FOUND" || echo "OK"

# 4. Markdown lints cleanly (if markdownlint is available)
command -v markdownlint >/dev/null && markdownlint wiki/ || echo "markdownlint not installed; skipping"
```

Verification checklist:
- [ ] `wiki/Home.md`, `wiki/_Sidebar.md`, `wiki/_Footer.md` all exist
- [ ] Every page in the sidebar has a corresponding `wiki/<Page>.md` file
- [ ] Every `[[Wiki Link]]` and `[text](Page-Name)` resolves to an existing page
- [ ] Each page has a one-line purpose statement at the top
- [ ] Each page links back to its source file(s) in the repo
- [ ] No PII, credentials, or secrets are present in any page
- [ ] No page is purely templated boilerplate — each has real content from the repo

### Step 8 — Hand Off to Publish Workflow

Once validated, commit the `wiki/` directory and push to your branch. Then either:

1. **Manually**: Go to **Actions → Publish Wiki → Run workflow** in the GitHub UI.
2. **Automatically**: Merge to the default branch — the [`publish-wiki.yml`](../../workflows/publish-wiki.yml) workflow runs on push when files under `wiki/**` change and mirrors the contents to `<owner>/<repo>.wiki.git`.

The wiki UI updates within seconds of a successful workflow run.

## Output Files

| File | Description |
|---|---|
| `wiki/Home.md` | Landing page (required) |
| `wiki/_Sidebar.md` | Custom sidebar shown on every page |
| `wiki/_Footer.md` | Custom footer shown on every page |
| `wiki/<Topic>.md` | One page per major topic (8–14 pages typical) |
| `tmp/wiki-input.md` | (Optional) User-supplied focus/exclusion overrides |

## References

- [Wiki structure best practices](./references/wiki-structure-best-practices.md) — page set, naming, navigation, linking
- [Repository content sources](./references/repo-content-sources.md) — where to find content for each wiki page
- [GitHub Docs: About wikis](https://docs.github.com/en/communities/documenting-your-project-with-wikis/about-wikis)
- [GitHub Docs: Adding or editing wiki pages](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages)
- [GitHub Docs: Creating a footer or sidebar for your wiki](https://docs.github.com/en/communities/documenting-your-project-with-wikis/creating-a-footer-or-sidebar-for-your-wiki)
- [GitHub Copilot Docs: Add skills to the cloud agent](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/add-skills)
