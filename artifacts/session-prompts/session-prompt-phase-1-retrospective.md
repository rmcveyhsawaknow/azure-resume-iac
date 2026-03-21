# Codespace Agent Session — Phase 1 Retrospective: Fix Function App

## Setup

Set up this Codespace for executing the Phase 1 retrospective on `develop` branch.

- **Issue:** https://github.com/rmcveyhsawaknow/azure-resume-iac/issues/148
- **Phase:** 1 — Fix Function App
- **Milestone:** Phase 1 - Fix Function App
- **Branch:** `develop`

---

## Phase 1 Rationalization

### Objective

Phase 1 restored the visitor counter Function App, which had been broken since December 2022 when .NET Core 3.1 and Azure Functions v3 reached End of Life. The scope covered runtime upgrades, infrastructure fixes, CI/CD modernization, and security hardening.

### Root Cause (Confirmed)

The Function App (`cus1-resumectr-prod-v1-fa`) was non-functional due to:

| Cause | Status |
|---|---|
| .NET Core 3.1 runtime EOL — Azure removed hosting support | **Primary** |
| Azure Functions v3 runtime EOL — host no longer available | **Primary** |
| CI/CD pipeline broken — expired Azure SP credentials + deprecated GitHub Actions | **Blocking** |
| Function key in `main.js` potentially stale | Contributing |

### Tasks Completed (12 of 13)

| Task | Issue | PR | Title | Copilot | Status |
|---|---|---|---|---|---|
| 1.1 | #83 | #155 | Diagnose root cause | Partial | ✅ Closed |
| 1.2 | #84 | #156 | Upgrade .NET runtime (3.1 → 8) | Yes | ✅ Closed |
| 1.3 | #85 | #157 | Upgrade Functions version (v3 → v4) | Yes | ✅ Closed |
| 1.4 | #86 | #159 | Update NuGet packages (xunit v2 → v3) | Yes | ✅ Closed |
| 1.5 | #87 | #160 | Update test project (expand coverage) | Yes | ✅ Closed |
| 1.6 | #88 | #161 | Verify Cosmos DB data | No | ✅ Closed |
| 1.7 | #89 | #162 | Verify Key Vault access | No | ✅ Closed |
| 1.8 | #90 | #167 | Update CORS settings (single domain) | Yes | ✅ Closed |
| 1.9 | #91 | #168 | Update function key in main.js | Yes | ✅ Closed |
| 1.10 | #92 | #169 | Test function locally (devcontainer + debug) | No | ✅ Closed |
| 1.11 | #93 | #170 | Update workflow dotnet version (8.0.x) | Yes | ✅ Closed |
| 1.12 | #132 | #171 | Set FtpsState to Disabled (gap F12) | Yes | ✅ Closed |
| 1.13 | #148 | — | Phase 1 Retrospective | Partial | 🔲 This session |

### Key Deliverables

- **Backend:** Migrated from .NET Core 3.1 / Functions v3 (in-process) → .NET 8 / Functions v4 (isolated worker model)
- **NuGet:** Deprecated `xunit` v2 replaced with `xunit.v3` 3.2.2; all packages at latest
- **Tests:** 8 unit tests covering counter increment, HTTP response, JSON serialization, model round-trip
- **IaC:** Bicep templates updated — API versions `@2023-12-01`, `ftpsState: 'Disabled'`, `FUNCTIONS_EXTENSION_VERSION: '~4'`
- **CI/CD:** Workflows updated — `actions/checkout@v4`, `actions/setup-dotnet@v4`, `DOTNET_VERSION: '8.0.x'`, added `backend-ci.yml`
- **Frontend:** Hardcoded function key removed from `main.js`, CORS origins scoped to `ryanmcvey.me` only
- **Docs:** Root cause diagnosis, local testing guide, Cosmos DB and Key Vault verification docs
- **Security:** FTP/FTPS access disabled on Function App (gap analysis F12)

### PRs Merged to `develop` (Phase 1)

| PR | Title | Merged |
|---|---|---|
| #155 | Root cause diagnosis of Function App failure | 2026-03-13 |
| #156 | Upgrade .NET Core 3.1 → .NET 8 with isolated worker model | 2026-03-13 |
| #157 | Upgrade Azure Functions v3 → v4 in IaC and workflows | 2026-03-14 |
| #159 | Migrate deprecated xunit v2 → xunit.v3 in test project | 2026-03-14 |
| #160 | Update test project: expand coverage, remove legacy helpers | 2026-03-14 |
| #161 | Add Cosmos DB data verification commands | 2026-03-14 |
| #162 | Add Key Vault access verification document | 2026-03-14 |
| #167 | Update CORS settings to ryanmcvey.me only | 2026-03-14 |
| #168 | Update main.js: remove hardcoded function key | 2026-03-14 |
| #169 | Add devcontainer, VS Code debug configs, local testing guide | 2026-03-14 |
| #170 | Update workflow .NET SDK to 8.0.x, pin actions, add backend CI | 2026-03-14 |
| #171 | Set ftpsState to Disabled on Function App | 2026-03-14 |

### Copilot AI Leverage (Pre-Retrospective Estimate)

- **Task-level:** 8 of 12 closed issues labeled `Copilot: Yes` (~67%)
- **Commit-level:** All 12 PRs authored by Copilot coding agent, reviewed and merged by PM
- **Phase velocity:** 13 tasks scoped, 12 completed in ~2 days (2026-03-13 to 2026-03-14)

---

## Steps

1. **Authenticate CLI tools:**
   ```bash
   bash scripts/setup-codespace-auth.sh
   ```

2. **Verify you are on `develop` branch with latest changes:**
   ```bash
   git checkout develop && git pull origin develop
   ```

3. **Run the retrospective generator:**
   ```bash
   bash scripts/generate-phase-retrospective.sh 1
   ```
   This generates `docs/retrospectives/phase-1-retrospective.md` with metrics pulled from GitHub API and git history.

4. **Review the generated report:**
   ```bash
   cat docs/retrospectives/phase-1-retrospective.md
   ```
   Verify the metrics look reasonable:
   - Issues planned: 13, closed: 12 (the 13th is this retrospective)
   - PRs merged: ~12 (Phase 1 PRs #155–#171)
   - Copilot task ratio should be ~67% (8 `Copilot: Yes` of 12 closed)
   - Copilot commit ratio should reflect `Co-authored-by` trailers

5. **Commit the retrospective to `develop`:**
   ```bash
   git add docs/retrospectives/phase-1-retrospective.md
   git commit -m "docs: Phase 1 retrospective"
   ```

6. **Post the full retrospective as a comment on issue #148:**
   ```bash
   gh issue comment 148 --repo rmcveyhsawaknow/azure-resume-iac \
     --body-file docs/retrospectives/phase-1-retrospective.md
   ```

7. **Close the Phase 1 milestone:**
   ```bash
   # First, find the milestone number
   gh api repos/rmcveyhsawaknow/azure-resume-iac/milestones?state=all \
     --jq '.[] | select(.title == "Phase 1 - Fix Function App") | .number'

   # Then close it (replace {N} with the milestone number from above)
   gh api -X PATCH repos/rmcveyhsawaknow/azure-resume-iac/milestones/{N} \
     -f state=closed
   ```

8. **Close the retrospective issue #148:**
   ```bash
   gh issue close 148 --repo rmcveyhsawaknow/azure-resume-iac \
     --comment "Phase 1 retrospective completed. Report committed to docs/retrospectives/phase-1-retrospective.md and posted above."
   ```

9. **Push to develop:**
   ```bash
   git push origin develop
   ```

10. **Update the project board:**
    Move issue #148 to **Done** in the GitHub Project board.

## Post-Retrospective: Next Phase Readiness

Before starting Phase 2 (Content Update) or Phase 3 (Dev Deployment), verify:

- [ ] All 12 Phase 1 issues are closed
- [ ] Phase 1 milestone is closed
- [ ] Retrospective committed and posted
- [ ] No blocking issues remain from Phase 1
- [ ] `develop` branch has all Phase 1 changes merged
- [ ] Phase 2/3 dependencies on Phase 1 are satisfied

## Notes

- The retrospective script (`scripts/generate-phase-retrospective.sh`) queries GitHub API for milestone/issue/PR data and git history for commit attribution. It requires `gh` CLI authentication.
- If the script reports `⚠️ Milestone not found`, verify the milestone title exactly matches `Phase 1 - Fix Function App`.
- The script uses the earliest issue activity date (not milestone creation date) as the period start to avoid inflated duration metrics.
- Phase 1 was completed ahead of the 3–5 week estimate, reflecting high Copilot AI leverage on the core upgrade tasks.
