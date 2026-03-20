# Phase 3 Retrospective: Dev Deployment

**Generated:** 2026-03-20
**Repository:** rmcveyhsawaknow/azure-resume-iac
**Milestone:** Phase 3 - Dev Deployment
**Milestone State:** open
**Period:** 2026-03-15 → 2026-03-20
**Duration:** 5 days

---

## Phase Summary

**Phase 3 — Dev Deployment** covered the following workstreams:

- **21** issues assigned to milestone
- **20** issues closed, **1** remaining open (this retrospective)
- **7** issues originated from gap analysis

### Scope

Phase 3 deployed the updated stack to the development environment and validated end-to-end functionality. The phase included CI/CD pipeline hardening, IaC security improvements, blue/green stack deployment with DNS automation, and comprehensive environment protection. Workstreams included:

1. **CI/CD Workflow Updates** — Updated dev workflow variables for single-domain setup, modernized GitHub Actions syntax, added `workflow_dispatch` trigger (#45, #46, #48, #193)
2. **Credential Verification** — Verified/rotated dev credentials, updated Cloudflare tokens and GitHub secrets (#47, #139, #192)
3. **IaC Hardening** — Fixed Bicep `listKeys` reference, CORS config injection, enforced TLS 1.2 on storage accounts, enabled Key Vault soft delete, migrated App Insights to workspace-based mode, removed deprecated instrumentation key (#135, #136, #137, #138, #195, #197, #215, #216, #217, #218)
4. **Deployment Pipeline** — Extracted DNS logic into shared script, automated Cosmos DB seed with check-before-create pattern, blue/green stack deployments (v1→v2→v3→v10→v11), added DNS upsert support for stack swaps (#52, #204, #205, #206, #207, #209, #214)
5. **Security & Environment Protection** — Added production environment protection rules with reviewer gates, fixed development branch policy, created idempotent automation script (#133, #134, #210, #211)
6. **End-to-End Validation** — Verified Function App, frontend, Cosmos DB connectivity, CORS configuration, DNS resolution, and visitor counter (#49, #50, #51, #53, #196, #198, #200)
7. **Documentation** — Dev environment reference architecture with Mermaid diagrams, Cloudflare token permission docs, CI/CD workflow docs (#201, #203)
8. **Frontend Telemetry** — Microsoft Clarity EUM integration, frontend App Insights connection string injection via `config.js` (#215)

---

## Planned vs Actual Effort

| Metric | Value |
|---|---|
| Issues planned (milestone) | 21 |
| Issues closed | 20 |
| Issues remaining | 1 |
| Completion rate | 95% |
| PRs merged | 25 |
| Commits | 103 |
| Gap analysis findings | 0 |
| Issues from gap analysis | 7 |

---

## Capacity & Duration Metrics

| Metric | Value |
|---|---|
| Duration (days) | 5 |
| Remote branches | 3 |
| Unique contributors | 3 |
| Contributors | Copilot, Ryan Mcvey, copilot-swe-agent[bot] |

---

## PRs by Author

| Author | PRs Merged |
|---|---|
| Copilot | 17 |
| rmcveyhsawaknow | 8 |

## PRs Merged (Phase 3)

| PR | Title | Merged | Author |
|---|---|---|---|
| #185 | docs: Phase 2 retrospective and PM Codespace session prompt | 2026-03-15 | Copilot |
| #189 | Update dev workflow variables for single-domain setup (bevis→resume, v66→v1) | 2026-03-15 | Copilot |
| #190 | Update GitHub Actions syntax to current best practices | 2026-03-15 | Copilot |
| #192 | Add credential verification guide and script for Phase 3 dev deployment | 2026-03-15 | rmcveyhsawaknow |
| #193 | Add workflow_dispatch trigger to dev deployment workflow | 2026-03-15 | Copilot |
| #195 | Use resource symbol reference instead of listKeys() in functionapp.bicep | 2026-03-15 | Copilot |
| #197 | Fix CORS: replace hardcoded prod API URL with parameter-driven config injection | 2026-03-15 | Copilot |
| #199 | Add CORS diagnostic tooling for Codespace troubleshooting | 2026-03-15 | Copilot |
| #200 | fix: change GetResumeCounter auth to Anonymous | 2026-03-15 | rmcveyhsawaknow |
| #201 | docs: Dev environment reference architecture, resource inventory & Mermaid diagram | 2026-03-15 | rmcveyhsawaknow |
| #202 | fix: address PR review — null guard, Bicep linuxFxVersion map, workflow hardening | 2026-03-15 | Copilot |
| #203 | fix: make Cloudflare cache purge non-fatal and document required token permissions | 2026-03-16 | rmcveyhsawaknow |
| #204 | fix: replace DNS action with curl check-before-create + bump actions to node24 | 2026-03-16 | rmcveyhsawaknow |
| #205 | refactor: extract DNS logic into shared script with robust error handling | 2026-03-16 | Copilot |
| #206 | Automated Cosmos DB seed with check-before-create pattern and data tier introspection | 2026-03-16 | Copilot |
| #207 | Deploy v2 dev stack for end-to-end validation | 2026-03-16 | Copilot |
| #209 | Fix asverify DNS race on from-scratch deploys; add stack cleanup script; bump dev to v3 | 2026-03-17 | Copilot |
| #210 | Add production environment protection rules — docs and automation script | 2026-03-17 | Copilot |
| #211 | fix: repo detection, idempotent protection config, dynamic stack naming | 2026-03-18 | rmcveyhsawaknow |
| #213 | [Phase 3] Update storage account min TLS to 1.2, bump dev to v11 | 2026-03-18 | rmcveyhsawaknow |
| #214 | fix(dns): Add upsert support to cloudflare-dns-record.sh for blue/green swaps | 2026-03-18 | rmcveyhsawaknow |
| #215 | Migrate App Insights to workspace-based mode, add frontend telemetry injection, and Clarity EUM | 2026-03-19 | Copilot |
| #216 | Enable Key Vault soft delete with 90-day retention | 2026-03-19 | Copilot |
| #217 | fix(kv): Remove immutable softDeleteRetentionInDays to unblock Key Vault redeployment | 2026-03-19 | Copilot |
| #218 | Remove deprecated APPINSIGHTS_INSTRUMENTATIONKEY from backend Function App | 2026-03-20 | Copilot |

## Commits by Author

| Author | Commits |
|---|---|
| Ryan Mcvey | 39 |
| copilot-swe-agent[bot] | 37 |
| Copilot | 27 |

---

## Human vs Copilot AI Productivity KPI

### Task-Level Attribution (Issue Labels)

| Metric | Count | Percentage |
|---|---|---|
| Issues labeled Copilot: Yes | 5 | — |
| Issues labeled Copilot: Partial | 4 | — |
| Issues labeled Copilot: No | 9 | — |
| Copilot: Yes issues closed | 5 | 25.0% of closed |

### Commit-Level Attribution (Co-authored-by Trailers)

| Metric | Count | Percentage |
|---|---|---|
| Total commits | 103 | 100% |
| Copilot co-authored commits | 81 | 78.6% |
| Human-only commits | 22 | 21.4% |

### AI-Human Productivity Index

> **Definition:** The AI-Human Productivity Index measures the proportion of project work
> that was AI-assisted at both the task level (issues) and code level (commits).
> A higher index indicates greater AI leverage in the development workflow.

| KPI | Value |
|---|---|
| Task-level AI ratio | 25.0% |
| Commit-level AI ratio | 78.6% |

---

## Gap Analysis Summary

**7 issues in Phase 3 originated from the Phase 0 gap analysis findings.**

| Issue | Finding | Status |
|---|---|---|
| #133 | Add production environment protection rules | ✅ Closed |
| #134 | Fix development environment branch policy | ✅ Closed |
| #135 | Update storage account min TLS to 1.2 | ✅ Closed |
| #136 | Migrate backend App Insights to workspace-based | ✅ Closed |
| #137 | Enable Key Vault soft delete | ✅ Closed |
| #138 | Update backend App Insights connection string format | ✅ Closed |
| #139 | Update CLOUDFLARE_TOKEN and CLOUDFLARE_ZONE GitHub secrets | ✅ Closed |

All 7 gap analysis findings assigned to Phase 3 were resolved.

---

## Blue/Green Stack Evolution

Phase 3 exercised the blue/green deployment pattern through multiple stack iterations:

| Stack Version | Description | Status |
|---|---|---|
| v1 | Initial dev deployment, single-domain setup | Cleaned up |
| v2 | End-to-end validation stack | Cleaned up |
| v3 | DNS timing fix retest | Cleaned up |
| v10 | Stable stack after cleanup of v1-v3 | Cleaned up |
| v11 | Final dev stack with TLS 1.2, workspace App Insights, KV soft delete | Active |

Stack inventory artifacts committed to `artifacts/`:
- `inventory-dev-v1.json`
- `inventory-dev-v2.json`
- `inventory-dev-v3.json`

---

## Next Phase Readiness

- [x] All phase issues closed or deferred with rationale
- [ ] Milestone closed
- [x] Retrospective committed to `docs/retrospectives/`
- [ ] Retrospective posted as comment on retrospective issue
- [ ] Project board updated — retrospective issue moved to Done
- [ ] No blocking issues for next phase

---

*Generated by `scripts/generate-phase-retrospective.sh` — AgentGitOps workflow*
