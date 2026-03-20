# Phase 4 Retrospective: Prod Deployment

**Generated:** 2026-03-20
**Repository:** rmcveyhsawaknow/azure-resume-iac
**Milestone:** Phase 4 - Prod Deployment
**Milestone State:** open
**Period:** 2026-03-20 → 2026-03-20
**Duration:** 1 day

---

## Phase Summary

**Phase 4 — Prod Deployment** covered the following workstreams:

- **17** issues assigned to milestone
- **10** issues closed, **7** remaining open (this retrospective + deferred gap-analysis duplicates #164/#165)
- **4** issues originated from gap analysis (2 resolved: #163, #166; 2 duplicates deferred: #164, #165)

### Scope

Phase 4 deployed the validated stack to the production environment and verified the live site end-to-end. The deployment completed without issues on the same day as Phase 3 closure, demonstrating the maturity of the CI/CD pipeline and blue/green deployment patterns established in Phase 3. Workstreams included:

1. **Prod Workflow Verification** — Verified prod workflow variables (`dnsZone: 'ryanmcvey.me'`, `stackVersion: 'v1'`, `stackEnvironment: 'prod'`, `customDomainPrefix: 'resume'`) were already correct from prior phase work; no changes needed (#54, #113, PR #222)
2. **Credential Verification** — Verified Azure SP and Cloudflare tokens were valid for production deployment (#114)
3. **Production Deployment** — Merged `develop` to `main` to trigger the production workflow, deploying all infrastructure (Cosmos DB, Key Vault, Function App, Storage Account, App Insights, DNS records) via the blue/green pipeline (#56, #115, PR #223)
4. **IaC Verification** — Confirmed all Azure resources created successfully in production resource groups (#57, #116)
5. **Function App Verification** — Tested counter endpoint on production, confirmed Cosmos DB connectivity and correct HTTP responses (#58, #117)
6. **Frontend Verification** — Accessed `resume.ryanmcvey.me`, confirmed content loads correctly, visitor counter increments, and telemetry (App Insights, Clarity) initializes (#59, #118)
7. **DNS & CDN Verification** — Confirmed `ryanmcvey.me` domain resolves correctly, Cloudflare proxied CNAME records active with SSL/TLS (#60, #61, #119, #120)
8. **End-to-End Validation** — Full production sign-off: site loads, counter API works, CORS configured, no console errors (#62, #121)
9. **Diagnostic Improvements** — Added diagnostic logging for Clarity project ID secret injection in deployment workflows (PR #221)
10. **Bicep API Modernization** — Updated all Key Vault resources from `@2019-09-01` to `@2024-11-01`, Storage Accounts from `@2021-04-01` to `@2024-01-01`, and Web sites/config from `@2021-03-01` to `@2023-12-01` (#163)
11. **Unused Module Cleanup** — Removed unused standalone `kv.bicep` module (Key Vault defined inline in `functionapp.bicep`), updated all documentation references (#166)
12. **Stack Version Bump** — Bumped both dev and prod workflows from `v11` to `v12` for fresh deployments with modernized infrastructure components

### Tech Debt Identified

- **PR #224** — Documents the intentional `AuthorizationLevel.Anonymous` decision for the counter endpoint. `AuthorizationLevel.Function` was evaluated and rejected because the frontend has no secure runtime mechanism to supply the function key without hard-coding it in source. The compensating control is a Cloudflare rate-limiting rule (not yet deployed). This is tracked as a Phase 5 backlog item (`scripts/backlog-issues/5.16.md`).

### Deferred Items

The following gap-analysis duplicate issues remain open (duplicates of #163 and #166 which were resolved):

- #164 — Modernize Bicep API versions (duplicate of #163)
- #165 — Clean up unused Key Vault Bicep module (duplicate of #166)

---

## Planned vs Actual Effort

| Metric | Value |
|---|---|
| Issues planned (milestone) | 17 |
| Issues closed | 12 |
| Issues remaining | 5 |
| Core tasks (4.1–4.9) completed | 9/9 (100%) |
| Gap analysis findings resolved | 2 (#163, #166) |
| Completion rate (overall) | 71% |
| PRs merged | 3 |
| Commits | 9 |
| Gap analysis findings | 0 new |
| Issues from gap analysis (resolved) | 2 |
| Issues from gap analysis (deferred dupes) | 2 |

> **Note:** The overall completion rate reflects 2 deferred gap-analysis duplicates (#164, #165) and this retrospective issue. All core deployment and validation tasks (4.1–4.9) completed at 100%. Gap-analysis items #163 and #166 were resolved during Phase 4.

---

## Capacity & Duration Metrics

| Metric | Value |
|---|---|
| Duration (days) | 1 |
| Remote branches | 3 |
| Unique contributors | 2 |
| Contributors | Ryan Mcvey, copilot-swe-agent[bot] |

---

## PRs by Author

| Author | PRs Merged |
|---|---|
| Copilot | 2 |
| rmcveyhsawaknow | 1 |

## PRs Merged (Phase 4)

| PR | Title | Merged | Author |
|---|---|---|---|
| #221 | Add diagnostic logging for Clarity project ID secret injection | 2026-03-20 | Copilot |
| #222 | [Phase 4] Verify prod workflow variables (single domain) — no changes needed | 2026-03-20 | Copilot |
| #223 | Develop to Main - big push agentGitOps | 2026-03-20 | rmcveyhsawaknow |

### Outlier PR (Tech Debt — Not Merged)

| PR | Title | Status | Author |
|---|---|---|---|
| #224 | Document intentional AuthorizationLevel.Anonymous decision and track Cloudflare rate-limiting mitigation | Open (Draft) | Copilot |

---

## Commits by Author

| Author | Commits |
|---|---|
| Ryan Mcvey | 6 |
| copilot-swe-agent[bot] | 3 |

---

## Human vs Copilot AI Productivity KPI

### Task-Level Attribution (Issue Labels)

| Metric | Count | Percentage |
|---|---|---|
| Issues labeled Copilot: Yes | 2 | — |
| Issues labeled Copilot: Partial | 1 | — |
| Issues labeled Copilot: No | 7 | — |
| Copilot: Yes issues closed | 2 | 20.0% of closed |

### Commit-Level Attribution (Co-authored-by Trailers)

| Metric | Count | Percentage |
|---|---|---|
| Total commits | 9 | 100% |
| Copilot co-authored commits | 6 | 66.7% |
| Human-only commits | 3 | 33.3% |

### AI-Human Productivity Index

> **Definition:** The AI-Human Productivity Index measures the proportion of project work
> that was AI-assisted at both the task level (issues) and code level (commits).
> A higher index indicates greater AI leverage in the development workflow.

| KPI | Value |
|---|---|
| Task-level AI ratio | 20.0% |
| Commit-level AI ratio | 66.7% |

> **Note:** The low task-level AI ratio is expected for Phase 4 — production deployment validation tasks (verifying IaC, Function App, frontend, DNS, Cloudflare proxy) are inherently manual and labeled `Copilot: No`. The commit-level ratio reflects Copilot's contribution to workflow verification and diagnostic improvements.

---

## Gap Analysis Summary

**4 issues in Phase 4 originated from the Phase 0 gap analysis findings — 2 resolved, 2 deferred (duplicates).**

| Issue | Finding | Status |
|---|---|---|
| #163 | Modernize Bicep API versions (Key Vault @2019-09-01 → @2024-11-01, Storage @2021-04-01 → @2024-01-01) | ✅ Closed |
| #164 | Modernize Bicep API versions (duplicate of #163) | ⏳ Deferred |
| #165 | Clean up unused Key Vault Bicep module (duplicate of #166) | ⏳ Deferred |
| #166 | Remove unused `kv.bicep` module, update documentation references | ✅ Closed |

### API Version Changes (#163)

| Resource | Before | After |
|---|---|---|
| `Microsoft.KeyVault/vaults` | `@2019-09-01` | `@2024-11-01` |
| `Microsoft.KeyVault/vaults/secrets` | `@2019-09-01` | `@2024-11-01` |
| `Microsoft.Storage/storageAccounts` | `@2021-04-01` | `@2024-01-01` |
| `Microsoft.Web/sites/config` | `@2021-03-01` | `@2023-12-01` |
| `Microsoft.Insights/components` | `@2020-02-02` | `@2020-02-02` (latest stable) |

---

## Stack Configuration

Phase 4 initially deployed production stack v1, then bumped both dev and prod to v12 for fresh deployments with modernized Bicep API versions:

| Config | Dev | Prod |
|---|---|---|
| Stack version | v12 | v12 |
| Environment | dev | prod |
| DNS zone | ryanmcvey.me | ryanmcvey.me |
| Custom domain prefix | resumedev | resume |
| Public URL | resumedev.ryanmcvey.me | resume.ryanmcvey.me |
| Workflow | `dev-full-stack-cloudflare.yml` | `prod-full-stack-cloudflare.yml` |

### Validation Results

| Check | Result |
|---|---|
| IaC deployment | ✅ All resources created |
| Function App (counter endpoint) | ✅ HTTP 200, Cosmos DB connected |
| Frontend (resume.ryanmcvey.me) | ✅ Content loads, counter increments |
| DNS resolution | ✅ Domain resolves correctly |
| Cloudflare proxy | ✅ Proxied CNAME active, SSL/TLS |
| CORS configuration | ✅ No console errors |
| App Insights telemetry | ✅ Initialized |
| Microsoft Clarity EUM | ✅ Initialized |

---

## Next Phase Readiness

- [x] All core phase tasks (4.1–4.9) closed
- [x] Gap-analysis items #163 and #166 resolved (API modernization, unused module cleanup)
- [x] Deferred duplicates documented (#164, #165)
- [x] Tech debt documented (PR #224 → Phase 5 backlog item 5.16)
- [x] Stack versions bumped to v12 for fresh deployments
- [x] Retrospective committed to `docs/retrospectives/`
- [ ] Retrospective posted as comment on retrospective issue (#151)
- [ ] Phase 4 milestone closed
- [ ] Project board updated — retrospective issue moved to Done
- [ ] No blocking issues for Phase 5

---

*Generated by `scripts/generate-phase-retrospective.sh` — AgentGitOps workflow*
