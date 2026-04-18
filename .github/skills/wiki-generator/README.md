# wiki-generator (Copilot Agent Skill)

A reusable [GitHub Copilot agent skill](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/add-skills) that generates a complete, well-structured GitHub Wiki for **any** repository by parsing its source content, plus a companion GitHub Actions workflow that publishes the generated content to the GitHub Wiki UI.

> **TL;DR**: Run the skill in a Codespace → it writes markdown pages into `wiki/` → commit & push → the `publish-wiki.yml` workflow mirrors `wiki/` to the `<owner>/<repo>.wiki.git` repo, and the GitHub Wiki UI updates automatically.

---

## How it solves the problem

GitHub Wikis are stored in a **separate Git repository** (`<owner>/<repo>.wiki.git`) and are **not** auto-mirrored from files in your source repo. So even if you put `.md` files in the repo, they will never appear in the wiki UI by themselves.

This skill addresses the gap with two pieces:

| Piece | Role |
|---|---|
| **`SKILL.md`** (this skill) | Tells the Copilot agent how to *generate* idiomatic wiki pages from your repo's existing content (README, `docs/`, IaC, code, workflows). Output is staged in `wiki/` so it lives under version control. |
| **`.github/workflows/publish-wiki.yml`** | A GitHub Actions workflow that *mirrors* the contents of `wiki/` into `<owner>/<repo>.wiki.git`. Triggered on push to the default branch (when `wiki/**` changes) or manually via `workflow_dispatch`. |

Together they form a **docs-as-code** pipeline for the wiki: you author/regenerate wiki content as part of normal PRs, and the workflow handles the mechanical sync to the wiki UI.

---

## Quick start (in a Codespace)

### 1. Initialize the wiki **once** in the GitHub UI

The wiki repo (`<owner>/<repo>.wiki.git`) does not exist until the wiki has at least one page. Create it once:

1. Go to your repository on GitHub → **Wiki** tab
2. Click **Create the first page**
3. Title: `Home`, content: anything (it will be overwritten by the workflow), click **Save Page**

### 2. Open a Codespace on your branch

Use the green **Code → Codespaces → Create codespace** button on your working branch.

### 3. (Optional) Provide focus/exclusion overrides

Copy the input template and edit it if you want to steer the agent:

```bash
mkdir -p tmp
cp .github/skills/wiki-generator/templates/wiki-input-template.md tmp/wiki-input.md
# Open tmp/wiki-input.md and fill in target audience, focus areas, excluded sections
```

If you skip this, the skill uses sensible defaults.

### 4. Invoke the skill from Copilot Chat

In the Codespace, open the Copilot Chat panel and run the skill. Either method works:

- **Slash command (when registered as a project skill):**
  ```text
  /wiki-generator
  ```
- **Or prompt the agent directly:**
  ```text
  Run the wiki-generator skill in .github/skills/wiki-generator/SKILL.md to generate
  the GitHub Wiki content for this repository under the wiki/ directory.
  ```

The agent will:
1. Discover repo content (README, `docs/`, `.github/`, IaC, code, workflows, scripts)
2. Plan a page set (8–14 pages) tailored to what your repo actually contains
3. Write `wiki/Home.md`, `wiki/_Sidebar.md`, `wiki/_Footer.md`, and one `wiki/<Topic>.md` per major area
4. Validate links, secrets, and structure before completing

### 5. Review, commit, push

```bash
ls wiki/                          # Inspect the generated pages
git checkout -b wiki/refresh
git add wiki/
git commit -m "docs(wiki): regenerate via wiki-generator skill"
git push -u origin wiki/refresh
```

Open a PR. Review pages just like any other code change.

### 6. Publish to the wiki UI

When the PR merges to the default branch, the `publish-wiki.yml` workflow runs automatically and mirrors `wiki/` to the wiki repo. You can also run it manually from **Actions → Publish Wiki → Run workflow** at any time.

The wiki UI shows the new content within seconds.

---

## What the skill produces

A typical output for a mid-sized full-stack repo:

```
wiki/
├── Home.md                  # Landing page with badges, navigation, "what is this"
├── _Sidebar.md              # Persistent left navigation
├── _Footer.md               # Persistent footer (link back to repo, last-updated)
├── Getting-Started.md       # Codespace + local dev setup
├── Architecture.md          # System diagram, components, data flow
├── Infrastructure.md        # IaC layout (Bicep/Terraform/etc.), resources
├── Backend.md               # Runtime, framework, endpoints, configuration
├── Frontend.md              # Static site / SPA layout and deploy target
├── CI-CD.md                 # Per-workflow summary
├── Deployment.md            # End-to-end deploy procedure, rollback
├── Configuration.md         # Required env vars, secret sources
├── Testing.md               # How to run tests locally and in CI
├── Troubleshooting.md       # Known issues, common errors
├── Contributing.md          # Branching, PR conventions, code style
├── Security.md              # Secret handling, vulnerability reporting
├── Project-Management.md    # Project board, labels, workflow
├── Skills-and-Agents.md     # Available Copilot agent skills
└── Glossary.md              # Repo-specific terms and acronyms
```

Pages whose source content does not exist in your repo are **omitted** rather than stubbed.

---

## Re-running the skill

The skill is idempotent — re-running it overwrites the staged pages in `wiki/` based on the **current state** of the repo. Use it whenever:

- Documentation has drifted from code
- You've added a new major component (new IaC module, new service)
- A new contributor onboarding session reveals gaps
- After a phase retrospective surfaces missing/outdated docs

The publish workflow always pushes the latest `wiki/` snapshot, so the wiki UI stays in lock-step with the repo.

---

## Reusing the skill in other repositories

The skill is **fully portable**. To use it in another repo:

1. Copy these files into the target repo (preserving paths):
   - `.github/skills/wiki-generator/` (entire directory)
   - `.github/workflows/publish-wiki.yml`
2. Initialize the wiki once in the GitHub UI (see Quick Start step 1)
3. Open a Codespace and invoke the skill (see Quick Start step 4)

No editing of the skill files is required — the skill discovers content based on what's in the repo, and the workflow auto-detects `<owner>/<repo>` from the runner context.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Workflow fails: `remote: Repository not found` when pushing to wiki | Wiki not initialized in the GitHub UI | Create the first wiki page in the UI (Quick Start step 1), then re-run the workflow |
| Workflow fails: `Permission to <repo>.wiki.git denied` | `GITHUB_TOKEN` lacks wiki write permission | Confirm `permissions: contents: write` is set in the workflow (it is by default in `publish-wiki.yml`); for org repos, check **Settings → Actions → General → Workflow permissions** is set to "Read and write" |
| Pages appear in wiki UI but sidebar is missing | `_Sidebar.md` not generated, or filename is wrong | Re-run the skill; ensure exact name `_Sidebar.md` (capital S, leading underscore) |
| Intra-wiki links broken (`[[Page]]` shows as text) | Target page filename uses spaces or wrong casing | Wiki link `[[Getting Started]]` resolves to file `Getting-Started.md` (spaces → hyphens). Re-run skill validation step. |
| Skill creates too many / too few pages | Defaults didn't match repo shape | Provide `tmp/wiki-input.md` with explicit focus areas / excluded sections |
| Wiki content goes stale between regenerations | Manual edits in the wiki UI overwritten on next publish | Treat the wiki UI as **read-only**. Author all changes in `wiki/` and let the workflow publish them. |

---

## Files in this skill

| File | Purpose |
|---|---|
| [`SKILL.md`](./SKILL.md) | The skill definition (frontmatter + procedure) consumed by the Copilot agent |
| [`README.md`](./README.md) | This file — human-facing usage documentation |
| [`templates/Home.md`](./templates/Home.md) | Starting structure for the wiki landing page |
| [`templates/_Sidebar.md`](./templates/_Sidebar.md) | Starting structure for the persistent sidebar |
| [`templates/_Footer.md`](./templates/_Footer.md) | Starting structure for the persistent footer |
| [`templates/page-template.md`](./templates/page-template.md) | Starting structure for a generic content page |
| [`templates/wiki-input-template.md`](./templates/wiki-input-template.md) | Optional user input file (focus areas, exclusions) |
| [`references/wiki-structure-best-practices.md`](./references/wiki-structure-best-practices.md) | Best-practices guide: page set, naming, navigation, linking |
| [`references/repo-content-sources.md`](./references/repo-content-sources.md) | Map of where wiki content is sourced from in a typical repo |

## Related

- Companion workflow: [`.github/workflows/publish-wiki.yml`](../../workflows/publish-wiki.yml)
- GitHub Docs: [About wikis](https://docs.github.com/en/communities/documenting-your-project-with-wikis/about-wikis)
- GitHub Docs: [Adding skills to the Copilot cloud agent](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/add-skills)
