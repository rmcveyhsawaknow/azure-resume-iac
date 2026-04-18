# Deployment

> Step-by-step guide to deploying the Azure Resume stack, including the blue/green swap procedure, rollback, and stack cleanup.

**Source:** [`docs/CICD_WORKFLOWS.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/CICD_WORKFLOWS.md) · [`scripts/cleanup-stack.sh`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/scripts/cleanup-stack.sh) · [`scripts/seed-cosmos-db.sh`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/scripts/seed-cosmos-db.sh)

---

## Table of Contents

- [How Deployment Works](#how-deployment-works)
- [Blue/Green Strategy](#bluegreen-strategy)
- [Deploying a New Stack Version](#deploying-a-new-stack-version)
- [Post-Deploy Validation](#post-deploy-validation)
- [Cleaning Up the Old Stack](#cleaning-up-the-old-stack)
- [Rollback](#rollback)
- [Cosmos DB Seeding](#cosmos-db-seeding)
- [DNS Management](#dns-management)
- [See also](#see-also)

---

## How Deployment Works

Pushing code to the trigger branch starts the full-stack workflow:

| Branch | Workflow | Target |
|---|---|---|
| `main` | `prod-full-stack-cloudflare.yml` | Production (`resume.ryanmcvey.me`) |
| `develop` | `dev-full-stack-cloudflare.yml` | Development (`resumedev.ryanmcvey.me`) |

The workflow runs four jobs in sequence:

1. **`changes`** — detects which paths changed (IaC, backend, frontend)
2. **`deployIac`** — runs `az deployment sub create` for `backend.bicep` and `frontend.bicep`
3. **`buildDeployBackend`** — builds .NET 8, runs tests, deploys Function App
4. **`buildDeployFrontend`** — generates `config.js`, uploads to `$web`, purges Cloudflare cache

Only changed components are redeployed (unless you use `workflow_dispatch`, which deploys everything).

## Blue/Green Strategy

Both dev and prod use **blue/green deployment** — each new major version deploys a **complete, isolated stack** with its own resource groups, databases, Key Vault, Function App, Storage Account, and DNS records.

The key mechanism is the `stackVersion` env var in each workflow file:

| Setting | Current (live) |
|---|---|
| **Production** `stackVersion` | `v12` |
| **Development** `stackVersion` | `v12` |

The `customDomainPrefix` stays **stable** across version swaps — DNS simply re-points to the new storage account.

### Why Blue/Green?

- **Zero-downtime swaps** — the new stack is fully provisioned and validated before DNS switches over
- **Easy rollback** — the old stack still exists; just point DNS back
- **No in-place updates** — eliminates configuration drift and partial-deploy risks
- **Clean audit trail** — each stack version is a complete snapshot in resource names and tags

## Deploying a New Stack Version

Here's the step-by-step runbook for a blue/green swap:

### Step 1 — Bump the stack version

Edit the workflow file and change `stackVersion`:

```yaml
# In .github/workflows/dev-full-stack-cloudflare.yml (or prod)
env:
  stackVersion: 'v13'  # was v12
```

**Do not change `customDomainPrefix`** — it stays the same so the public URL doesn't change.

### Step 2 — Commit and push

```bash
git checkout develop          # or main for prod
git add .github/workflows/
git commit -m "bump dev stack to v13"
git push
```

This triggers the workflow, which:
- Creates brand-new resource groups (`cus1-resume-be-dev-v13-rg`, `cus1-resume-fe-dev-v13-rg`)
- Deploys all Azure resources from scratch
- Re-points the Cloudflare CNAME to the new storage account
- Generates and uploads frontend with the new API endpoint

### Step 3 — Validate the new stack

Run through the validation checklist:

- [ ] Frontend loads at the custom domain URL
- [ ] Visitor counter increments (check browser console for errors)
- [ ] No CORS errors in the browser console
- [ ] Function App health check returns 200
- [ ] Cosmos DB counter document exists and increments
- [ ] Cloudflare CDN is serving cached content (check response headers)

### Step 4 — Inventory the old stack

```bash
export STACK_ENVIRONMENT=dev   # or prod
export STACK_VERSION=v12       # the OLD version
export STACK_LOCATION_CODE=cus1
export APP_NAME=resume

bash scripts/cleanup-stack.sh --inventory \
  --json-output artifacts/inventory-dev-v12.json
```

This creates a JSON artifact listing all resource groups and DNS records for the old stack.

### Step 5 — Purge the old stack

```bash
bash scripts/cleanup-stack.sh --purge
# Interactive confirmation by default; add --yes to skip
```

This deletes the old resource groups and (optionally) Cloudflare DNS records.

> **Commit the inventory artifact** to `artifacts/` for traceability before purging.

## Post-Deploy Validation

The workflow automatically handles several validation steps:

- **Cosmos DB seeding** — `scripts/seed-cosmos-db.sh` ensures the counter document exists (check-before-create pattern)
- **DNS propagation** — a `dig`-based retry loop (12 attempts × 10 seconds) waits for the CNAME to resolve before setting the custom domain
- **Cache purge** — Cloudflare cache is purged after frontend upload so users see fresh content immediately

## Cleaning Up the Old Stack

`scripts/cleanup-stack.sh` is the central cleanup tool:

| Flag | What it does |
|---|---|
| `--inventory` | Lists resource groups and DNS records — read-only |
| `--purge` | Deletes resource groups and DNS records (with confirmation) |
| `--purge --yes` | Purge without interactive confirmation |
| `--json-output <path>` | Write inventory to a JSON file for auditing |

Required environment variables:

| Variable | Example | Purpose |
|---|---|---|
| `STACK_ENVIRONMENT` | `dev` | Stack tier |
| `STACK_VERSION` | `v12` | Version to clean up |
| `STACK_LOCATION_CODE` | `cus1` | Location prefix |
| `APP_NAME` | `resume` | Application name |

Optional (for DNS cleanup): `CF_TOKEN`, `CF_ZONE`, `DNS_ZONE`, `CUSTOM_DOMAIN_PREFIX`

## Rollback

Because the old stack still exists (until you purge it), rollback is straightforward:

1. Revert the `stackVersion` change in the workflow file
2. Push — this re-points DNS back to the old storage account
3. Verify the old stack is still serving correctly

If the old stack has already been purged, you'll need to do a full redeployment at the old version.

## Cosmos DB Seeding

`scripts/seed-cosmos-db.sh` runs automatically during IaC deployment. It follows a check-before-create pattern:

1. Verifies the Cosmos DB account exists
2. Queries for the counter document (`id=1`)
3. If missing, creates `{ "id": "1", "count": 0 }`
4. If present, validates structure and reports current count
5. Handles HTTP 409 (conflict/race condition) gracefully

For manual use:

```bash
az login
export COSMOS_ACCOUNT_NAME=cus1-resume-dev-v12-cmsdb
export COSMOS_RESOURCE_GROUP=cus1-resume-be-dev-v12-rg
bash scripts/seed-cosmos-db.sh
```

## DNS Management

Cloudflare DNS records are managed by `scripts/cloudflare-dns-record.sh`, called from the workflow. It uses a check-before-create pattern against the Cloudflare API v4:

1. **GET** existing record → if content matches, skip
2. If content differs → log a warning for operator review
3. If missing → **POST** to create

Two records per stack:
- **Main CNAME** (`resume.ryanmcvey.me`) — proxied (orange cloud) for CDN + TLS
- **Verification CNAME** (`asverify.resume.ryanmcvey.me`) — DNS-only (grey cloud) for Azure domain validation

---

## See also

- [CI-CD](CI-CD) — workflow details, job conditions, and path filtering
- [Infrastructure](Infrastructure) — Bicep templates that create the resources
- [Configuration](Configuration) — secrets needed for deployment
- [Troubleshooting](Troubleshooting) — common deployment errors and fixes
