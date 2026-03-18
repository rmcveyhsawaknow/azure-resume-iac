# CI/CD Workflows Reference

This document provides a detailed reference for all GitHub Actions CI/CD workflows, their configuration, required credentials, and operational notes.

## Workflow Summary

| Workflow | File | Trigger Branch | Status | DNS/CDN Provider |
|---|---|---|---|---|
| Production Full Stack Cloudflare | `prod-full-stack-cloudflare.yml` | `main` | **Active** | Cloudflare |
| Development Full Stack Cloudflare | `dev-full-stack-cloudflare.yml` | `develop` | **Active** | Cloudflare |
| Production Full Stack Azure CDN | `prod-full-stack-azureCDN.yml` | `disabled` | **Disabled** | Azure DNS + Front Door |
| Development Full Stack Azure CDN | `dev-full-stack-azureCDN.yml` | `disabled` | **Disabled** | Azure DNS + Front Door |

Active workflows trigger on two events:

1. **`push`** to their configured branch, filtered by paths:
   - `.github/workflows/<workflow-file>`
   - `.iac/**`
   - `backend/**`
   - `frontend/**`
   > **Note:** Changes to `scripts/`, `docs/`, or other non-deployment paths do **not** trigger workflows. This is intentional — operational scripts (e.g., `configure-repo-protection.sh`, `verify-credentials.sh`) are not deployed code and should not cause a stack re-deploy.

2. **`workflow_dispatch`** — manual trigger from the GitHub Actions UI or CLI, bypassing all path filters and running all deploy jobs unconditionally.

## Active Workflow: Production Full Stack Cloudflare

**File:** `.github/workflows/prod-full-stack-cloudflare.yml`  
**Trigger:** Push to `main` branch  
**GitHub Environments Used:** `production`

### Environment Variables

```yaml
env:
  dnsZone: 'ryanmcvey.me'
  stackVersion: 'v1'
  stackEnvironment: 'prod'
  stackLocation: 'eastus'
  stackLocationCode: 'cus1'
  AppName: 'resume'
  AppBackendName: 'resumectr'
  tagCostCenter: 'azCF'
  rgDns: 'glbl-ryanmcveyme-v1-rg'
```

### Jobs Flow

```
changes → deployProductionIac → buildDeployProductionBackend → buildDeployProductionFrontend
```

#### Job 1: `changes`
- **Runner:** `ubuntu-latest`
- **Action:** `dorny/paths-filter@v3` (pinned to commit SHA)
- **Outputs:** `iac`, `backendApp`, `frontendSite` (boolean flags)
- **Note:** These outputs drive active `if:` conditions on downstream jobs. Jobs only run when their relevant paths have changed, or on `workflow_dispatch` events.

#### Job 2: `deployProductionIac`
- **Runner:** `ubuntu-latest`
- **Depends on:** `changes`
- **Condition:** `needs.changes.outputs.iac == 'true' || github.event_name == 'workflow_dispatch'`
- **Steps:**
  1. Azure Login using `Azure/login@v2` with `AZURE_RESUME_GITHUB_SP` secret
  2. Get subscription ID from `az account show`
  3. Deploy `backend.bicep` via `Azure/arm-deploy@v2` at subscription scope
  4. Deploy `frontend.bicep` via `Azure/arm-deploy@v2` at subscription scope
  5. Enable static website on storage account via `az storage blob service-properties update`
  6. Get storage static site endpoints
  7. Create/update Cloudflare CNAME records (proxied) and verification CNAMEs (DNS-only) for ryanmcvey.me zone
  8. Wait 60 seconds for DNS propagation
  9. Set custom domain on storage account

#### Job 3: `buildDeployProductionBackend`
- **Runner:** `windows-latest`
- **Depends on:** `changes`, `deployProductionIac`
- **Condition:** `always() && (deployProductionIac succeeded or skipped) && (backendApp changed || workflow_dispatch)`
- **Steps:**
  1. Azure Login
  2. Setup .NET 8
  3. `dotnet build --configuration Release --output ./output` in `backend/api/`
  4. `dotnet test` in `backend/tests/`
  5. Deploy to Function App via `Azure/functions-action@v1.5.4`

#### Job 4: `buildDeployProductionFrontend`
- **Runner:** `ubuntu-latest`
- **Depends on:** `changes`, `buildDeployProductionBackend`
- **Condition:** `always() && (buildDeployProductionBackend succeeded or skipped) && (frontendSite changed || workflow_dispatch)`
- **Steps:**
  1. Azure Login
  2. Generate `config.js` with environment-specific API URL
  3. Upload `frontend/` to `$web` container on storage account via `az storage blob upload-batch`
  4. Purge Cloudflare cache (validates API response for success)

## Active Workflow: Development Full Stack Cloudflare

**File:** `.github/workflows/dev-full-stack-cloudflare.yml`  
**Trigger:** Push to `develop` branch (path-filtered) or `workflow_dispatch`  
**GitHub Environments Used:** `development`

### Key Differences from Production

| Setting | Production | Development |
|---|---|---|
| Branch | `main` | `develop` |
| `stackVersion` | `v1` | `v10` |
| `stackEnvironment` | `prod` | `dev` |
| `AppName` | `resume` | `resume` |
| `customDomainPrefix` | `resume` | `resumedev` |
| DNS subdomain | `resume.ryanmcvey.me` | `resumedev.ryanmcvey.me` |
| CORS URIs | `https://resume.ryanmcvey.me` | `https://resumedev.ryanmcvey.me` |
| GitHub environment | `production` | `development` |

The development workflow structure is identical to production but with these variable substitutions. It deploys a fully separate stack.

## Disabled Workflows (Azure CDN Variants)

### Production Azure CDN (`prod-full-stack-azureCDN.yml`)
- **Status:** Disabled (branch trigger set to `disabled`)
- **Key differences:** Uses Azure Front Door as CDN (instead of Cloudflare), Azure DNS for records, single storage account (not 3), `stackLocationCode: 'zus1'`, `tagCostCenter: 'azCDN'`
- **Additional steps:** Deploys `frontendCdn.bicep` for Front Door profile, purges CDN cache after frontend upload

### Development Azure CDN (`dev-full-stack-azureCDN.yml`)
- **Status:** Disabled (branch trigger set to `disabled`)
- **Same structure as production Azure CDN variant with dev environment variables**

## Required GitHub Secrets

### Azure Service Principal

**Secret Name:** `AZURE_RESUME_GITHUB_SP`

**Format:** JSON object from `az ad sp create-for-rbac --sdk-auth`
```json
{
  "clientId": "<application-id>",
  "clientSecret": "<client-secret>",
  "subscriptionId": "<subscription-id>",
  "tenantId": "<tenant-id>"
}
```

**How to Create:**
```bash
az login
az account set --subscription "<subscription-name-or-id>"
az ad sp create-for-rbac \
  --name "github-azure-resume" \
  --role contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth
```

**Required Permissions:**
- `Contributor` role on the Azure subscription (or scoped to relevant resource groups)
- The SP needs permission to create/manage: Resource Groups, Cosmos DB, Function Apps, Storage Accounts, Key Vaults, App Service Plans, Application Insights

**⚠️ Deprecation Warning:** The `--sdk-auth` format is deprecated by both `az ad sp create-for-rbac` and `Azure/login`. For future updates, consider migrating to:
- **Federated identity credentials (OIDC)** — recommended by Microsoft for GitHub Actions
- Or the newer JSON format without `--sdk-auth` flag, used with `Azure/login@v2`

### Cloudflare Credentials

| Secret | Description | How to Find |
|---|---|---|
| `CLOUDFLARE_TOKEN` | API token with DNS edit permissions | Cloudflare Dashboard → My Profile → API Tokens → Create Token → "Edit zone DNS" template |
| `CLOUDFLARE_ZONE` | Zone ID for `ryanmcvey.me` | Cloudflare Dashboard → select zone → Overview page → right sidebar "Zone ID" |

**Cloudflare Token Permissions Required:**
- Zone → DNS → Edit (for CNAME record creation)
- Zone → Cache Purge → Purge (for cache invalidation after frontend deployment)
- Scoped to the `ryanmcvey.me` zone

**Cloudflare DNS Management:** DNS CNAME records are managed via direct `curl` calls to the Cloudflare API v4 using a check-before-create pattern:
1. `GET /zones/{zone}/dns_records?type=CNAME&name={name}` — check if record exists
2. If exists with correct content → skip (no error annotation)
3. If exists with different content → log `::warning::` for operator review
4. If missing → `POST /zones/{zone}/dns_records` to create

Record parameters:
- `type: CNAME`
- `name`: fully-qualified domain name (e.g., `resume.ryanmcvey.me` or `asverify.resume.ryanmcvey.me`)
- `content`: Azure Storage static site endpoint domain
- `proxied: true` for main records (enables Cloudflare CDN/TLS), `false` for `asverify` verification records

This approach replaced the third-party `rez0n/create-dns-record` action to eliminate supply chain risk and "record already exists" error annotations. The DNS logic is centralized in `scripts/cloudflare-dns-record.sh` and invoked from both dev and prod workflows.

## Cosmos DB Seed

After the Bicep backend deployment creates the Cosmos DB account, database, and container, the workflow runs `scripts/seed-cosmos-db.sh` to ensure the visitor counter document exists. This follows the same check-before-create pattern as the DNS script:

1. Verify the Cosmos DB account exists via `az cosmosdb show`
2. Retrieve the account primary key via `az cosmosdb keys list`
3. Query the Cosmos DB REST API for document `id=1` in the `Counter` container
4. If the document exists → validate its structure (`id` and `count` fields)
5. If the document is missing → create it with `{ "id": "1", "count": 0 }`
6. Handle race conditions (HTTP 409) gracefully

The script uses environment variables set in the workflow:

| Variable | Description | Default |
|---|---|---|
| `COSMOS_ACCOUNT_NAME` | Cosmos DB account name | *(required)* |
| `COSMOS_RESOURCE_GROUP` | Resource group for the account | *(required)* |
| `COSMOS_DATABASE_NAME` | Database name | `azure-resume-click-count` |
| `COSMOS_CONTAINER_NAME` | Container name | `Counter` |
| `COSMOS_DOCUMENT_ID` | Document ID | `1` |
| `COSMOS_INITIAL_COUNT` | Initial counter value | `0` |

The defaults match `CosmosConstants.cs` in the backend application. For manual use outside of CI/CD:

```bash
az login
export COSMOS_ACCOUNT_NAME=cus1-resume-dev-v1-cmsdb
export COSMOS_RESOURCE_GROUP=cus1-resume-be-dev-v1-rg
bash scripts/seed-cosmos-db.sh
```

## GitHub Environments

The workflows reference two GitHub environments configured with protection rules:

| Environment | Used By | Purpose |
|---|---|---|
| `production` | prod-full-stack-cloudflare, prod-full-stack-azureCDN | Production deployment approval gate |
| `development` | dev-full-stack-cloudflare, dev-full-stack-azureCDN | Development deployment branch restriction |

### Environment Protection Rules

| Setting | Production | Development |
|---|---|---|
| Required reviewers | `rmcveyhsawaknow` (1 reviewer) | None |
| Wait timer | 5 minutes | None |
| Deployment branches | `main` only | `develop` only |

### Branch Protection Rules

| Setting | `main` | `develop` |
|---|---|---|
| Require PR before merging | ✅ (1 approval) | ✅ (1 approval) |
| Require code owner reviews | ❌ (allows admin self-merge) | ❌ (allows admin self-merge) |
| Enforce admins | ❌ (admin bypass enabled) | ❌ (admin bypass enabled) |
| Require conversation resolution | ✅ | ✅ |
| Allow force pushes | ❌ | ❌ |
| Allow deletions | ❌ | ❌ |

> **Note:** "Enforce admins: off" allows the repository owner to bypass the review requirement when needed (self-authored PRs). For Copilot-authored PRs, the owner provides normal review approval.

### Configuration

Protection rules can be configured manually (GitHub → Settings → Environments / Branches) or programmatically:

```bash
# Assess current state (dry run)
bash scripts/configure-repo-protection.sh --dry-run

# Apply all protection rules
bash scripts/configure-repo-protection.sh --reviewer rmcveyhsawaknow
```

See [ENVIRONMENT_BRANCH_PROTECTION.md](ENVIRONMENT_BRANCH_PROTECTION.md) for detailed click-through instructions and script documentation.

## Credential Verification Checklist

Use this checklist when verifying or rotating credentials:

- [ ] **Azure SP:** Run `az login --service-principal -u <clientId> -p <clientSecret> --tenant <tenantId>` to verify
- [ ] **Azure SP Expiry:** Check `az ad app credential list --id <clientId>` for expiration dates
- [ ] **Azure SP Permissions:** Verify `Contributor` role: `az role assignment list --assignee <clientId>`
- [ ] **Cloudflare Token:** Test with `curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" -H "Authorization: Bearer <token>"`
- [ ] **Cloudflare Zone IDs:** Verify with `curl -X GET "https://api.cloudflare.com/client/v4/zones" -H "Authorization: Bearer <token>"`
- [ ] **GitHub Secret Values:** Cannot be read after creation — must be verified by running a test workflow or re-created

## Action Versions and Dependencies

| Action | Version Used | Current Status |
|---|---|---|
| `actions/checkout` | `@main` | ⚠️ Should pin to specific version (e.g., `@v4`) |
| `Azure/login` | `@v1` / `@v1.1` | ⚠️ Deprecated format; current is `@v2` |
| `Azure/arm-deploy` | `@v1` | ⚠️ Current is `@v2` |
| `Azure/CLI` | `@v1` | ⚠️ Current is `@v2` |
| `Azure/functions-action` | `@v1.4.4` | ⚠️ Current is `@v2` |
| `actions/setup-dotnet` | `@v1` | ⚠️ Current is `@v4` |
| `dorny/paths-filter` | `@v2` | Current version |
| `rez0n/create-dns-record` | `@v2.2` | ⚠️ Third-party action pinned to mutable tag; pin to commit SHA or replace with direct API calls (supply chain risk — runs with `CLOUDFLARE_TOKEN`) |

## Deprecated Syntax

The workflows use the deprecated `::set-output` command:
```yaml
# Deprecated (currently used):
echo "::set-output name=SUBID::${SUBID}"

# Replacement (GitHub recommended):
echo "SUBID=${SUBID}" >> $GITHUB_OUTPUT
```

This will need to be updated across all workflows as GitHub may remove support for the old syntax.

## Workflow Trigger FAQ

### Why didn't the workflow trigger after my last merge?

The most common reason is the **path filter**. A push to `develop` (or `main`) only triggers a workflow when at least one changed file matches the configured paths:

```
.github/workflows/dev-full-stack-cloudflare.yml
.iac/**
backend/**
frontend/**
```

**If your PR changed only `scripts/`, `docs/`, `.github/copilot-instructions.md`, or other non-deployment files, the workflow will correctly skip.** This is expected behavior — those changes don't modify deployed infrastructure, application code, or frontend assets.

| PR changes only… | Workflow triggers? | Reason |
|---|---|---|
| `.iac/**` | ✅ Yes | IaC path matched |
| `backend/**` | ✅ Yes | Backend path matched |
| `frontend/**` | ✅ Yes | Frontend path matched |
| `.github/workflows/dev-full-stack-cloudflare.yml` | ✅ Yes | Workflow file itself matched |
| `scripts/**` | ❌ No | Not in path filter (by design) |
| `docs/**` | ❌ No | Not in path filter (by design) |
| `.github/copilot-instructions.md` | ❌ No | Not in path filter (by design) |

### Does using admin bypass affect workflow triggering?

**No.** When the repository owner merges a pull request using the admin bypass (merging without meeting branch protection requirements such as reviewer approval), GitHub still fires the normal `push` event on the target branch. Workflow triggers are unaffected by how the merge was performed.

The branch protection rule in this repo uses `enforce_admins: false`, which allows the owner to self-merge PRs without a separate reviewer. This does **not** suppress push events or prevent workflow runs.

If a workflow did not trigger after an admin-bypass merge, the cause is always the path filter — not the bypass mechanism.

### How do I manually trigger a workflow?

Use `workflow_dispatch` via the GitHub UI or CLI:

**GitHub UI:**
1. Go to **Actions** → select the workflow (e.g., "Development Full Stack Cloudflare")
2. Click **Run workflow** → select branch `develop` → click **Run workflow**

**GitHub CLI:**
```bash
# Trigger dev workflow on develop branch
gh workflow run dev-full-stack-cloudflare.yml --ref develop

# Trigger prod workflow on main branch
gh workflow run prod-full-stack-cloudflare.yml --ref main
```

When triggered via `workflow_dispatch`, **all deploy jobs run unconditionally** — the path-filter `if:` conditions are bypassed. This is useful when you need to force a full re-deploy after a scripts-only or docs-only merge.

### Why would I want to manually re-trigger the workflow?

Common scenarios:
- A scripts-only PR (e.g., `configure-repo-protection.sh`, `verify-credentials.sh`) was merged and you want to verify the deployment is still healthy
- An Azure credential rotation requires redeployment to pick up the new secrets
- Infrastructure drift was detected and you want to re-apply the desired state
- A previous workflow run failed for a transient reason (network timeout, rate limit, etc.)
