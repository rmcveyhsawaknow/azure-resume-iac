# CI CD

> Every GitHub Actions workflow in the repo — what triggers them, what they do, and how they connect.

**Source:** [`.github/workflows/`](https://github.com/rmcveyhsawaknow/azure-resume-iac/tree/main/.github/workflows) · [`docs/CICD_WORKFLOWS.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/CICD_WORKFLOWS.md)

---

## Table of Contents

- [Workflow Summary](#workflow-summary)
- [Active Workflows](#active-workflows)
- [Job Flow](#job-flow)
- [Path-Based Change Detection](#path-based-change-detection)
- [Disabled Workflows](#disabled-workflows)
- [GitHub Environments](#github-environments)
- [Branch Protection](#branch-protection)
- [See also](#see-also)

---

## Workflow Summary

| Workflow | File | Trigger | Status |
|---|---|---|---|
| **Production Cloudflare** | `prod-full-stack-cloudflare.yml` | Push to `main` | Active |
| **Development Cloudflare** | `dev-full-stack-cloudflare.yml` | Push to `develop` | Active |
| **Backend CI** | `backend-ci.yml` | Push/PR to `main`/`develop` (backend changes) | Active |
| **Publish Wiki** | `publish-wiki.yml` | Push to `main` (wiki changes) | Active |
| Production Azure CDN | `prod-full-stack-azureCDN.yml` | — | Disabled |
| Development Azure CDN | `dev-full-stack-azureCDN.yml` | — | Disabled |

Workflows in this repo use a mix of triggers, including `push`, `pull_request`, and `workflow_dispatch`; path filters such as `.iac/**`, `backend/**`, `frontend/**`, and `wiki/**` are used where applicable.

## Active Workflows

### Production Full Stack Cloudflare

**Trigger:** Push to `main` + `workflow_dispatch`  
**Environment:** `production` (requires reviewer approval + 5-minute wait timer)

Deploys the complete production stack: IaC → backend → frontend → DNS → cache purge.

Key env vars:

| Variable | Value |
|---|---|
| `stackVersion` | `v12` |
| `stackEnvironment` | `prod` |
| `stackLocation` | `eastus` |
| `stackLocationCode` | `cus1` |
| `customDomainPrefix` | `resume` |

### Development Full Stack Cloudflare

**Trigger:** Push to `develop`  
**Environment:** `development` (branch-restricted to `develop`)

Identical structure to production with dev-specific variables. Deploys a fully isolated stack.

### Backend CI

**Trigger:** Push/PR to `main` or `develop` when `backend/**` changes  
**Purpose:** Build + test only (no deployment). Runs `dotnet build` then `dotnet test` to validate backend changes before merge.

### Publish Wiki

**Trigger:** Push to `main` when `wiki/**` changes  
**Purpose:** Mirrors the `wiki/` directory to `<repo>.wiki.git` so the GitHub Wiki UI stays in sync with the source repo.

## Job Flow

Each full-stack workflow (dev and prod) runs four sequential jobs:

```
changes → deployIac → buildDeployBackend → buildDeployFrontend
```

### 1. `changes`

Runs `dorny/paths-filter` (pinned to commit SHA) to detect which paths have changed. Outputs three boolean flags: `iac`, `backendApp`, `frontendSite`.

### 2. `deployIac`

**Condition:** IaC files changed or `workflow_dispatch`

1. Azure Login using `Azure/login@v2` with `AZURE_RESUME_GITHUB_SP` secret
2. Deploy `backend.bicep` at subscription scope via `Azure/arm-deploy@v2`
3. Deploy `frontend.bicep` at subscription scope
4. Enable static website on the storage account
5. Create/update Cloudflare CNAME records (proxied + verification)
6. Wait for DNS propagation (dig-based retry loop)
7. Set custom domain on the storage account

### 3. `buildDeployBackend`

**Condition:** Backend or IaC changed, or `workflow_dispatch`

1. Azure Login
2. Setup .NET 8 SDK
3. `dotnet build --configuration Release`
4. `dotnet test` (xUnit)
5. Deploy to Function App via `Azure/functions-action`

### 4. `buildDeployFrontend`

**Condition:** Frontend, backend, or IaC changed, or `workflow_dispatch`

1. Azure Login
2. Generate `config.js` with runtime values (API URL, App Insights, stack metadata)
3. Upload `frontend/` to `$web` container via `az storage blob upload-batch`
4. Purge Cloudflare cache

## Path-Based Change Detection

Jobs use `if:` conditions that combine path filter outputs with `always()` so they run even when upstream jobs are skipped:

```yaml
if: >-
  always() &&
  (needs.deployIac.result == 'success' || needs.deployIac.result == 'skipped') &&
  (needs.changes.outputs.backendApp == 'true' || needs.changes.outputs.iac == 'true' || github.event_name == 'workflow_dispatch')
```

IaC changes trigger all downstream jobs (backend + frontend) to ensure new stack versions get a complete deployment.

## Disabled Workflows

Two legacy workflows used Azure CDN (Front Door) instead of Cloudflare:

- `prod-full-stack-azureCDN.yml` — used `stackLocationCode: zus1`, deployed Azure Front Door profile
- `dev-full-stack-azureCDN.yml` — same structure with dev variables

These are disabled (trigger branch set to `disabled`) and kept for reference. The active architecture uses Cloudflare for CDN/DNS.

## GitHub Environments

| Environment | Used By | Reviewers | Wait Timer | Branch Restriction |
|---|---|---|---|---|
| `production` | prod-full-stack-cloudflare | `rmcveyhsawaknow` | 5 min | `main` only |
| `development` | dev-full-stack-cloudflare | None | None | `develop` only |

## Branch Protection

| Setting | `main` | `develop` |
|---|---|---|
| Require PR (1 approval) | Yes | Yes |
| Require conversation resolution | Yes | Yes |
| Allow force pushes | No | No |
| Admin bypass | Yes (self-authored PRs) | Yes |

---

## See also

- [Deployment](Deployment) — end-to-end deploy procedure and blue/green swap
- [Infrastructure](Infrastructure) — the Bicep templates that these workflows deploy
- [Configuration](Configuration) — secrets and environment variables used by workflows
- [Contributing](Contributing) — branching model and PR flow
