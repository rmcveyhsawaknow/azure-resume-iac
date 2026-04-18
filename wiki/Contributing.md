# Contributing

> Branching strategy, PR flow, coding conventions, and how to work with Copilot agents in this repository.

**Source:** [`.github/copilot-instructions.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/.github/copilot-instructions.md)

---

## Table of Contents

- [Branching Model: Git Flow (Simplified)](#branching-model-git-flow-simplified)
- [PR Workflow](#pr-workflow)
- [Coding Conventions](#coding-conventions)
- [Working with Copilot Agents](#working-with-copilot-agents)
- [Commit Messages](#commit-messages)
- [See also](#see-also)

---

## Branching Model: Git Flow (Simplified)

This project uses a simplified [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/) — similar to the standard model but **without release branches**. Compared to [GitHub Flow](https://docs.github.com/en/get-started/using-git/github-flow) (which uses a single `main` branch with feature branches), Git Flow separates development and production with a long-lived `develop` branch:

```
main (production)
 │
 ├── hotfix/urgent-fix ──────────────────→ merge to main AND develop
 │
 └── develop (integration)
      │
      ├── feature/my-feature ────────────→ merge to develop
      ├── copilot/issue-42 ──────────────→ merge to develop
      └── bugfix/fix-cors ───────────────→ merge to develop
```

### How it maps to deployments

| Branch | Deploys to | Workflow |
|---|---|---|
| `main` | Production (`resume.ryanmcvey.me`) | `prod-full-stack-cloudflare.yml` |
| `develop` | Development (`resumedev.ryanmcvey.me`) | `dev-full-stack-cloudflare.yml` |
| Feature/bugfix branches | Nothing (CI only via `backend-ci.yml`) | — |

### Key differences from GitHub Flow

| Aspect | GitHub Flow | This Project (Git Flow, no release branch) |
|---|---|---|
| Long-lived branches | `main` only | `main` + `develop` |
| Feature merge target | `main` | `develop` |
| Production deploy | Merge to `main` | Merge `develop` → `main` |
| Release branch | N/A | Not used — `develop` is promoted directly |
| Hotfixes | Branch from `main` | Branch from `main`, merge to both `main` and `develop` |

### Branch naming

| Prefix | Use |
|---|---|
| `feature/` | New functionality |
| `bugfix/` | Bug fixes |
| `hotfix/` | Urgent production fixes (branch from `main`) |
| `copilot/` | Copilot agent–authored branches |

## PR Workflow

1. Create a feature branch from `develop` (or `main` for hotfixes)
2. Make changes, commit with descriptive messages
3. Push and open a PR targeting `develop`
4. CI runs (`backend-ci.yml` tests, linting)
5. At least one approval required (admin can self-merge for solo work)
6. All conversations must be resolved before merge
7. Merge — CI/CD deploys to dev automatically

To promote to production:
1. Open a PR from `develop` → `main`
2. Review + approve (production environment requires reviewer + 5-min wait timer)
3. Merge — CI/CD deploys to production

## Coding Conventions

### C# / .NET (Backend)

- **PascalCase** for public members, **_camelCase** for private fields
- Use dependency injection for services
- Use `ILogger<T>` for structured logging
- Follow isolated worker model patterns (`Microsoft.Azure.Functions.Worker`)
- `Function` auth level by default; `Anonymous` only where justified (the counter endpoint)
- CORS configured in Bicep, not in application code

### Bicep (Infrastructure)

- Follow [Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/) patterns
- Subscription scope for orchestration, resource group scope for modules
- Naming convention: `{locationCode}-{appName}-{environment}-{version}-{resourceType}`
- Always include standard tags (Environment, CostCenter, Git Action metadata)
- Use Key Vault references for secrets — never hardcode connection strings
- Prefer managed identity (`SystemAssigned`)

### JavaScript (Frontend)

- Vanilla JS — no transpilation, no bundling
- Keep it simple — the frontend is a static site
- Don't commit secrets or keys to source files
- Use semantic HTML5 and responsive CSS grid/flex patterns

### GitHub Actions (Workflows)

- Pin actions to specific versions or commit SHAs
- Use `$GITHUB_OUTPUT` (not deprecated `::set-output`)
- Use path filters for change detection
- Store secrets in GitHub Secrets, never in workflow files

## Working with Copilot Agents

Copilot agents use branches prefixed with `copilot/` and follow the same PR workflow. Every issue in the project has a **Copilot Suitability** field:

| Value | Meaning |
|---|---|
| `Yes` | Fully automatable — code gen, refactoring, tests, docs |
| `Partial` | Human guides, agent assists with code portions |
| `No` | Requires Portal access, credentials, or human judgment |

When reviewing Copilot-authored PRs, check that:
- Tests pass and cover the change
- No secrets or PII are introduced
- Code follows the conventions above
- The change matches the issue requirements

## Commit Messages

Use descriptive messages with a conventional prefix when applicable:

```
feat: add visitor counter endpoint
fix: resolve CORS error on dev site
docs: update architecture diagram
chore: bump stack version to v13
ci: pin dorny/paths-filter to commit SHA
```

---

## See also

- [Getting Started](Getting-Started) — setting up the dev environment
- [CI-CD](CI-CD) — how branches trigger workflows
- [AgentGitOps](AgentGitOps) — the AI-assisted project workflow
- [Security](Security) — secret handling and responsible disclosure
