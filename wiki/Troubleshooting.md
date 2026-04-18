# Troubleshooting

> Common errors, their root causes, and how to fix them.

**Source:** [`docs/KNOWN_ISSUES.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/KNOWN_ISSUES.md) · [`docs/retrospectives/`](https://github.com/rmcveyhsawaknow/azure-resume-iac/tree/main/docs/retrospectives)

---

## Table of Contents

- [Visitor Counter Not Displaying](#visitor-counter-not-displaying)
- [CORS Errors in Browser Console](#cors-errors-in-browser-console)
- [Azure Login Fails in CI/CD](#azure-login-fails-in-cicd)
- [Cloudflare Cache Purge 401](#cloudflare-cache-purge-401)
- [DNS Record Already Exists](#dns-record-already-exists)
- [Functions Host Won't Start Locally](#functions-host-wont-start-locally)
- [Known Technical Debt](#known-technical-debt)
- [See also](#see-also)

---

## Visitor Counter Not Displaying

**Symptom:** The page counter shows nothing or NaN.

| Possible Cause | How to Check | Fix |
|---|---|---|
| `config.js` not generated | View source → is `defined_FUNCTION_API_BASE` set? | Redeploy frontend (workflow generates `config.js`) |
| Cosmos DB document missing | Check container in Azure Portal | Run `scripts/seed-cosmos-db.sh` |
| Function App down | Hit the API URL directly in browser | Check Function App status in Azure Portal |
| CORS blocked | Browser console → look for CORS errors | See [CORS section](#cors-errors-in-browser-console) |

## CORS Errors in Browser Console

**Symptom:** `Access-Control-Allow-Origin` error when the counter tries to call the Function App.

**Root cause:** The Function App's CORS allowed origins don't include the frontend's domain.

**Fix options:**

1. **Check Bicep CORS config** — verify the `corsUris` parameter in `backend.bicep` includes the correct `https://{customDomainPrefix}.ryanmcvey.me`
2. **Quick fix via CLI:**
   ```bash
   az functionapp cors add \
     --name cus1-resumectr-dev-v12-fa \
     --resource-group cus1-resume-be-dev-v12-rg \
     --allowed-origins "https://resumedev.ryanmcvey.me"
   ```
3. **Diagnose with the helper script:**
   ```bash
   bash scripts/diagnose-cors.sh
   ```

## Azure Login Fails in CI/CD

**Symptom:** Workflow fails at `Azure/login@v2` with credential error.

**Causes:**
- Azure Service Principal secret has expired
- `AZURE_RESUME_GITHUB_SP` secret is malformed or uses the old format

**Fix:**

```bash
# Regenerate the SP credentials
az ad sp create-for-rbac \
  --name "github-azure-resume" \
  --role contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth

# Update the AZURE_RESUME_GITHUB_SP secret in GitHub
gh secret set AZURE_RESUME_GITHUB_SP < sp-output.json
```

> **Future improvement:** Migrate to OIDC federated credentials to eliminate secret rotation entirely.

## Cloudflare Cache Purge 401

**Symptom:** The `buildDeployFrontend` job logs a 401 on the cache purge step.

**Cause:** The `CLOUDFLARE_TOKEN` doesn't have Cache Purge permission — it only has DNS Edit.

**Fix:** Update the API token in Cloudflare Dashboard to include **Zone → Cache Purge → Purge** permission in addition to DNS Edit. Then update the `CLOUDFLARE_TOKEN` GitHub Secret.

The workflow uses `continue-on-error: true` on this step, so it won't block the deployment.

## DNS Record Already Exists

**Symptom:** Workflow logs `::warning::` about a DNS record with different content.

**This is expected during a blue/green swap** — the CNAME previously pointed to the old storage account. The workflow's check-before-create pattern detects the mismatch and logs a warning.

If the record content needs updating, manually delete the old record in Cloudflare Dashboard and rerun the workflow (or use `workflow_dispatch`).

## Functions Host Won't Start Locally

| Symptom | Fix |
|---|---|
| `func: command not found` | Install Azure Functions Core Tools v4: `npm i -g azure-functions-core-tools@4 --unsafe-perm true` |
| `No job functions found` | Make sure you're running `func start` from `backend/api/`, not the repo root |
| `Unable to connect to Cosmos DB` | Check `AzureResumeConnectionStringPrimary` in `local.settings.json` |
| Port 7071 in use | Stop other Functions hosts or use `func start --port 7072` |
| CORS error in browser | Add your frontend origin to `Host.CORS` in `local.settings.json` |

## Known Technical Debt

Items that are tracked but not yet resolved:

| Item | Impact | Status |
|---|---|---|
| jQuery 1.10.2 / Font Awesome 4.x | Low — functional but outdated | Backlogged |
| `--sdk-auth` SP format deprecated | Medium — may break in future `Azure/login` versions | OIDC migration planned |
| Disabled Azure CDN workflows | Low — unused files in `.github/workflows/` | Cleanup planned |

For the full history of resolved and open issues, see [`docs/KNOWN_ISSUES.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/KNOWN_ISSUES.md).

---

## See also

- [Configuration](Configuration) — secrets and environment variables
- [Getting Started](Getting-Started) — local development setup
- [Deployment](Deployment) — blue/green deploy and DNS management
- [CI-CD](CI-CD) — workflow details and debugging
