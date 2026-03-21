# Codespace Agent Session — Issue #26: Upgrade Functions Version (v3 → v4)

## Setup

Set up this Codespace for working on issue #26 "[Phase 1] Upgrade Functions version (v3 → v4)" and resultant PR.

- **Issue:** https://github.com/rmcveyhsawaknow/azure-resume-iac/issues/26
- **PR:** (supply PR link once created by Copilot agent)
- **Depends on:** #25 (merged — .NET 8 isolated worker model adopted)
- **Branch from:** `develop` (after #156 merges)

## Steps

1. Run `bash scripts/setup-codespace-auth.sh` to authenticate Azure CLI, GitHub CLI, and Cloudflare API.

2. Fetch the issue: `gh issue view 26 --repo rmcveyhsawaknow/azure-resume-iac`

3. Read context files:
   - `docs/ROOT_CAUSE_DIAGNOSIS.md` — confirmed root cause and remediation plan
   - `docs/issue-26-bicep-comment.md` — detailed Bicep change requirements from live diagnostics
   - `.github/copilot-instructions.md` — project conventions, especially Azure Bicep and backend sections

4. Read the files requiring changes:
   - `.iac/modules/functionapp/functionapp.bicep` — primary Bicep module
   - `.iac/backend.bicep` — orchestration template (passes `functionRuntime` param)
   - `backend/api/host.json` — already has `extensionBundle` v4 from #25, verify
   - All 4 workflow files in `.github/workflows/` — pass `functionRuntime=dotnet` at deploy time

5. **Upgrade Bicep templates** (`.iac/modules/functionapp/functionapp.bicep`):
   - `FUNCTIONS_EXTENSION_VERSION`: `'~3'` → `'~4'`
   - `FUNCTIONS_WORKER_RUNTIME`: Change the parameter value flow to `'dotnet-isolated'` (decision made in #25 — isolated worker model was adopted)
   - Add `linuxFxVersion: 'dotnet-isolated|8.0'` to `siteConfig` in the `functionApp` resource (Microsoft.Web/sites)
   - Update API versions: `Microsoft.Web/sites@2020-12-01` → `@2023-12-01`, `Microsoft.Web/serverfarms@2020-12-01` → `@2023-12-01`
   - Update `Microsoft.Web/sites/config@2021-03-01` → `@2023-12-01` for appsettings resource

6. **Update orchestration template** (`.iac/backend.bicep`):
   - If `functionRuntime` param has a default, update to `'dotnet-isolated'`; if no default, document that callers must pass `'dotnet-isolated'`

7. **Update workflow files** (all 4 `.github/workflows/*.yml`):
   - Change `functionRuntime` parameter from `dotnet` to `dotnet-isolated` in the Bicep deployment steps
   - Note: `DOTNET_VERSION` update (`3.1` → `8.0`) is tracked in a separate CI/CD issue — do NOT change it here unless it's blocking

8. **Create `backend/api/local.settings.json`** for local development:
   ```json
   {
     "IsEncrypted": false,
     "Values": {
       "AzureWebJobsStorage": "UseDevelopmentStorage=true",
       "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
       "FUNCTIONS_EXTENSION_VERSION": "~4"
     }
   }
   ```
   Ensure `local.settings.json` is listed in `.gitignore` (it should NOT be committed — add to `.gitignore` if missing).

9. **Verify no v3-specific configuration remains:**
   - `grep -r "~3" .iac/ .github/workflows/`
   - `grep -r "FUNCTIONS_WORKER_RUNTIME.*dotnet[^-]" .iac/ .github/workflows/` (should find nothing — all should say `dotnet-isolated`)

10. **Validate Bicep syntax:**
    - `az bicep build --file .iac/modules/functionapp/functionapp.bicep`
    - `az bicep build --file .iac/backend.bicep`

11. Document implementation summary.

12. Pause for review before posting.

13. After approval, post summary comment: `gh issue comment 26 --body-file <summary-file>`
    
Start with step 1 and proceed step-by-step, pausing after implementation summary for review before posting the issue comment.
