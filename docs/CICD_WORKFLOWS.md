# CI/CD Workflows Reference

This document provides a detailed reference for all GitHub Actions CI/CD workflows, their configuration, required credentials, and operational notes.

## Workflow Summary

| Workflow | File | Trigger Branch | Status | DNS/CDN Provider |
|---|---|---|---|---|
| Production Full Stack Cloudflare | `prod-full-stack-cloudflare.yml` | `main` | **Active** | Cloudflare |
| Development Full Stack Cloudflare | `dev-full-stack-cloudflare.yml` | `develop` | **Active** | Cloudflare |
| Production Full Stack Azure CDN | `prod-full-stack-azureCDN.yml` | `disabled` | **Disabled** | Azure DNS + Front Door |
| Development Full Stack Azure CDN | `dev-full-stack-azureCDN.yml` | `disabled` | **Disabled** | Azure DNS + Front Door |

All workflows trigger on `push` events to their configured branch, filtered by paths:
- `.github/workflows/<workflow-file>`
- `.iac/**`
- `backend/**`
- `frontend/**`

## Active Workflow: Production Full Stack Cloudflare

**File:** `.github/workflows/prod-full-stack-cloudflare.yml`  
**Trigger:** Push to `main` branch  
**GitHub Environments Used:** `production`

### Environment Variables

```yaml
env:
  dnsZone: 'ryanmcvey.me'
  dnsZone2: 'ryanmcvey.net'
  dnsZone3: 'ryanmcvey.cloud'
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
- **Action:** `dorny/paths-filter@v2`
- **Outputs:** `iac`, `backendApp`, `frontendSite` (boolean flags)
- **Note:** These outputs are defined but the `if` conditions in downstream jobs are **commented out**, so all jobs always run.

#### Job 2: `deployProductionIac`
- **Runner:** `ubuntu-latest`
- **Depends on:** `changes`
- **Steps:**
  1. Azure Login using `Azure/login@v1.1` with `AZURE_RESUME_GITHUB_SP` secret
  2. Get subscription ID from `az account show`
  3. Deploy `backend.bicep` via `Azure/arm-deploy@v1` at subscription scope
  4. Deploy `frontend.bicep` via `Azure/arm-deploy@v1` at subscription scope
  5. Enable static website on 3 storage accounts via `az storage blob service-properties update`
  6. Get storage static site endpoints
  7. Create/update Cloudflare CNAME records (proxied) and verification CNAMEs (DNS-only) for all 3 zones
  8. Wait 60 seconds for DNS propagation
  9. Set custom domains on all 3 storage accounts

#### Job 3: `buildDeployProductionBackend`
- **Runner:** `windows-latest` (required for .NET Core 3.1)
- **Depends on:** `changes`, `deployProductionIac`
- **Steps:**
  1. Azure Login
  2. Setup .NET Core 3.1
  3. `dotnet build --configuration Release --output ./output` in `backend/api/`
  4. `dotnet test` in `backend/tests/`
  5. Deploy to Function App via `Azure/functions-action@v1.4.4`

#### Job 4: `buildDeployProductionFrontend`
- **Runner:** `ubuntu-latest`
- **Depends on:** `changes`, `buildDeployProductionBackend`
- **Steps:**
  1. Azure Login
  2. Upload `frontend/` to `$web` container on all 3 storage accounts via `az storage blob upload-batch`

## Active Workflow: Development Full Stack Cloudflare

**File:** `.github/workflows/dev-full-stack-cloudflare.yml`  
**Trigger:** Push to `develop` branch  
**GitHub Environments Used:** `development`

### Key Differences from Production

| Setting | Production | Development |
|---|---|---|
| Branch | `main` | `develop` |
| `stackVersion` | `v1` | `v66` |
| `stackEnvironment` | `prod` | `dev` |
| `AppName` | `resume` | `bevis` |
| DNS subdomain | `resume.{zone}` | `bevisdevv66.{zone}` |
| CORS URIs | `https://resume.{zone}` | `https://bevisdevv66.{zone}` |
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
| `CLOUDFLARE_ZONE2` | Zone ID for `ryanmcvey.net` | Same as above for the second zone |
| `CLOUDFLARE_ZONE3` | Zone ID for `ryanmcvey.cloud` | Same as above for the third zone |

**Cloudflare Token Permissions Required:**
- Zone → DNS → Edit
- Scoped to all three zones or the specific zones used

**Cloudflare Action Used:** `rez0n/create-dns-record@v2.2` — creates CNAME records with these parameters:
- `type: CNAME`
- `name`: subdomain (e.g., `resume` or `asverify.resume`)
- `content`: Azure Storage static site endpoint domain
- `proxied: true` for main records (enables Cloudflare CDN/TLS), `false` for `asverify` verification records

> **⚠️ Supply Chain Risk:** This third-party action is pinned to a mutable tag (`v2.2`), not a commit SHA. It runs with `CLOUDFLARE_TOKEN` and has DNS edit access. If the upstream tag is repointed to malicious code, an attacker could exfiltrate the token or hijack DNS records. **Remediation:** Pin the action to a specific commit SHA in all workflow files, or replace it with direct `curl` calls to the Cloudflare API.

## GitHub Environments

The workflows reference two GitHub environments that can be configured with protection rules:

| Environment | Used By | Purpose |
|---|---|---|
| `production` | prod-full-stack-cloudflare, prod-full-stack-azureCDN | Production deployment approval gate |
| `development` | dev-full-stack-cloudflare, dev-full-stack-azureCDN | Development deployment approval gate |

These can be configured in GitHub → Settings → Environments to require reviewers, wait timers, or restrict to specific branches.

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
