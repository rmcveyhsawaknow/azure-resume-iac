# AgentGitOps Epic Report — Project Management Edition

**Project:** Azure Resume IaC — Full-Stack Modernization & Redeployment
**Repository:** [rmcveyhsawaknow/azure-resume-iac](https://github.com/rmcveyhsawaknow/azure-resume-iac)
**Period:** March 10–22, 2026 (13 calendar days)
**Live Site:** [resume.ryanmcvey.me](https://resume.ryanmcvey.me)
**Methodology:** AgentGitOps — AI-Assisted Project Lifecycle on GitHub

---

## Epic Objective

Refactor, upgrade, and redeploy a living resume website hosted on Azure PaaS services — taking it from a broken, outdated state to a fully operational production deployment — using a structured, AI-assisted project management workflow that produces measurable outcomes at every phase boundary.

### Success Criteria (Defined in Session 0)

| Criterion | Met? | Evidence |
|---|---|---|
| Restore broken visitor counter | ✅ | .NET 8 migration, Functions v4, Cosmos DB validated |
| Update site content from GitHub profile | ✅ | 10 PRs merged in Phase 2 covering all sections |
| Deploy to production via CI/CD | ✅ | `resume.ryanmcvey.me` live, 8/8 validation checks passed |
| Modernize infrastructure (IaC, security) | ✅ | Bicep API versions updated, TLS 1.2, Key Vault soft delete |
| Clean up legacy resources | ✅ | Old resource groups, stale DNS records removed |
| Document everything | ✅ | Architecture, CI/CD, planning, retrospectives, bootstrap guide |
| Demonstrate measurable AI productivity | ✅ | AI KPIs tracked at every phase; 76% of PRs AI-authored |

**Epic status: ✅ All success criteria met.**

---

## Phase Summary

| Phase | Name | Duration | Issues | Closed | Rate | PRs | Commits |
|---|---|---|---|---|---|---|---|
| 0 | Assessment | 0 days | 14 | 13 | 93% | 3 | 0 |
| 1 | Fix Function App | 4 days | 24 | 22 | 92% | 17 | 74 |
| 2 | Content Update | 1 day | 21 | 20 | 95% | 10 | 12 |
| 3 | Dev Deployment | 5 days | 21 | 20 | 95% | 25 | 103 |
| 4 | Prod Deployment | 1 day | 17 | 12 | 71%¹ | 3 | 9 |
| 5 | Cleanup & Docs | 2 days | 6 | 4 | 67%² | 12 | 37 |
| **Totals** | — | **13 days** | **103** | **91** | **88%** | **70** | **235** |

> ¹ Phase 4: All 9 core deployment tasks completed (100%). Remaining = 2 deferred duplicates + retrospective.
> ² Phase 5: All 4 core tasks completed (100%). Remaining = 1 deferred tech debt + retrospective.

---

## Velocity & Throughput

### Issues Per Day

| Phase | Duration | Issues Closed | Issues/Day |
|---|---|---|---|
| 0 — Assessment | <1 day | 13 | 13+ |
| 1 — Fix Function App | 4 days | 22 | 5.5 |
| 2 — Content Update | 1 day | 20 | 20 |
| 3 — Dev Deployment | 5 days | 20 | 4.0 |
| 4 — Prod Deployment | 1 day | 12 | 12 |
| 5 — Cleanup & Docs | 2 days | 4 | 2.0 |
| **Overall** | **13 days** | **91** | **7.0** |

### PRs Per Day

| Phase | PRs Merged | PRs/Day |
|---|---|---|
| 1 — Fix Function App | 17 | 4.3 |
| 2 — Content Update | 10 | 10.0 |
| 3 — Dev Deployment | 25 | 5.0 |
| 4 — Prod Deployment | 3 | 3.0 |
| 5 — Cleanup & Docs | 12 | 6.0 |
| **Overall** | **70** | **5.4** |

---

## Backlog Composition

### Issue Types

| Category | Count | % of Total |
|---|---|---|
| Planned (original scope) | ~85 | 83% |
| Gap analysis findings | ~18 | 17% |
| **Total** | **103** | 100% |

The Phase 0 assessment identified **28 gap analysis findings** — concrete security, configuration, and modernization issues discovered by comparing actual deployed state against expected state. These were triaged, prioritized, and assigned to subsequent phases, with 10+ resolved and 1 deferred (Key Vault RBAC migration).

### Copilot Suitability Distribution

Every issue was triaged for AI delegation fitness before entering a sprint:

| Suitability | Issues | % |
|---|---|---|
| **Yes** — Fully delegable to AI | 29 | 36% |
| **Partial** — AI assists, human guides | 25 | 31% |
| **No** — Human-only | 26 | 33% |

**What "Yes" tasks looked like:** Code generation, NuGet package upgrades, HTML/CSS content updates, Bicep template refactoring, documentation writing, test migration, script creation.

**What "No" tasks looked like:** Azure credential verification/rotation, Cloudflare token management, production deployment sign-off, DNS resolution validation, environment protection configuration.

**What "Partial" tasks looked like:** CI/CD workflow updates (AI writes YAML, human verifies secrets and triggers), IaC hardening (AI writes Bicep, human validates in Azure portal), gap analysis triage.

---

## Human vs AI Productivity — The Core KPI

### Task-Level Attribution

| Phase | Copilot: Yes Closed | Total Closed | AI Task Ratio |
|---|---|---|---|
| 0 — Assessment | 0 | 13 | 0% |
| 1 — Fix Function App | 7 | 22 | 32% |
| 2 — Content Update | 14 | 20 | 70% |
| 3 — Dev Deployment | 5 | 20 | 25% |
| 4 — Prod Deployment | 2 | 12 | 20% (core: verification-heavy) |
| 5 — Cleanup & Docs | 1 | 4 | 25% |
| **Total** | **29** | **91** | **32%** |

### Commit-Level Attribution

| Phase | AI Co-authored | Total | AI Commit Ratio |
|---|---|---|---|
| 0 — Assessment | 0 | 0 | — |
| 1 — Fix Function App | 40 | 74 | 54% |
| 2 — Content Update | 12 | 12 | 100% |
| 3 — Dev Deployment | 81 | 103 | 79% |
| 4 — Prod Deployment | 6 | 9 | 67% |
| 5 — Cleanup & Docs | 24¹ | 37 | 65% |
| **Total** | **163** | **235** | **69%** |

> ¹ Phase 5: `copilot-swe-agent[bot]` authored 24/37 commits directly (counted as AI contribution).

### PR-Level Attribution

| Author Type | PRs | % |
|---|---|---|
| AI (Copilot / copilot-swe-agent) | 53 | 76% |
| Human (rmcveyhsawaknow) | 17 | 24% |

### Productivity Insight

> **32% of tasks** and **69% of commits** were AI-delivered. This delta is expected — AI tasks tend to be code-intensive (generating more commits per issue), while human tasks are often verification or configuration (fewer commits per issue). The PR ratio (76% AI) confirms that AI was the primary code producer, with humans providing oversight, review, and deployment verification.

---

## Phase Delivery Timeline

```
Mar 10  ┃━━ Phase 0: Assessment ━━┃
        ┃                          ┃
Mar 10  ┃━━━━━━━━━━━━━━━━━━━━━━━━━━┃━━━ Phase 1: Fix Function App ━━━┃ Mar 14
        ┃                                                              ┃
Mar 14  ┃━ Phase 2: Content Update ━┃ Mar 15
        ┃                            ┃
Mar 15  ┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃━━━━━ Phase 3: Dev Deployment ━━━━━┃ Mar 20
        ┃                                                                  ┃
Mar 20  ┃━ Phase 4: Prod Deployment ━┃ Mar 20
        ┃                             ┃
Mar 21  ┃━━━ Phase 5: Cleanup & Docs ━━━┃ Mar 22
```

**Critical path:** Phase 0 → Phase 1 (runtime fix) + Phase 2 (content) → Phase 3 (dev deploy) → Phase 4 (prod deploy) → Phase 5 (cleanup)

Phases 1 and 2 ran in parallel on the dependency graph (both depended on Phase 0, not on each other). Phase 3 required both to be complete before deployment validation could begin.

---

## Risk Register (Final State)

| Risk | Likelihood | Impact | Mitigation | Status |
|---|---|---|---|---|
| Expired Azure SP credential | Medium | High | Verified in Phase 0, used in Phases 3–4 | ✅ Mitigated |
| Stale Cloudflare tokens | Medium | High | Rotated in Phase 3 | ✅ Mitigated |
| .NET 3.1 EOL breaking changes | High | High | Full migration to .NET 8 | ✅ Resolved |
| Hardcoded secrets in frontend | High | Critical | Deploy-time `config.js` injection | ✅ Resolved |
| No environment protection | Medium | Medium | Reviewer gates + branch policies | ✅ Resolved |
| Key Vault RBAC migration | Low | Low | Access policies functional, documented | ⏳ Deferred |
| Anonymous function endpoint abuse | Low | Medium | Cloudflare rate-limiting planned | ⏳ Planned |

---

## Retrospective Process

Each phase boundary followed a consistent retrospective process:

1. **Generate:** `bootstrap/generate-phase-retrospective.sh <N>` — collects milestone issues, PR/commit stats, AI KPIs, and gap analysis data
2. **Commit:** Retrospective saved to `docs/retrospectives/phase-N-retrospective.md`
3. **Post:** Report posted as a comment on the phase retrospective GitHub issue
4. **Close:** Milestone closed, project board updated

This produced a **traceable audit trail** — every metric in this epic report can be verified against the individual phase retrospective documents.

### What the Retrospective Script Measures Automatically

- Issues planned vs. closed (completion rate)
- PRs merged by author (human vs. AI attribution)
- Commits by author with co-authored-by trailer analysis
- Copilot suitability label distribution
- Gap analysis findings originated and resolved
- Phase duration and contributor count

---

## Lessons Learned

### What Worked Well

1. **Copilot Suitability triaging** — Pre-classifying every issue as Yes/Partial/No set realistic expectations and enabled the Copilot Queue view for agent assignment.
2. **Phase 0 Assessment** — Investing one session to harvest actual deployed state produced 28 gap findings that would have surfaced as surprises later. Front-loading discovery reduced rework.
3. **Blue/green deployment pattern** — Deploying complete isolated stacks allowed safe iteration. 5 stack versions in dev before going to prod meant production was a single, confident merge.
4. **AI for content and code generation** — Phase 2 achieved 100% AI commit ratio because content updates are well-structured, repeatable tasks that AI excels at.
5. **Automated retrospective generation** — The script eliminated manual metric collection and ensured consistency across all 6 phases.

### What Could Improve

1. **Co-authored-by trailer consistency** — Phase 5 showed a 2.7% co-authored ratio despite 65% AI-authored commits, because `copilot-swe-agent[bot]` commits as primary author without trailers. A consistent attribution model would improve metric accuracy.
2. **Story point estimation** — Issues had T-shirt size labels but SP values were not consistently populated on the Project board, limiting velocity calculations to issue counts rather than weighted SP.
3. **Gap analysis to issue pipeline** — 28 findings were identified but the mapping from finding → issue was manual. An automated finding-to-issue script would reduce the gap.
4. **Phase 4 completion rate** — The 71% rate is misleading due to duplicate gap-analysis issues. Deduplication during backlog population would prevent this.

### Recommendations for Next Project

1. Populate SP values (not just size labels) on every issue at creation time for proper velocity tracking
2. Add a `finding-to-issue.sh` script to `bootstrap/` for automated gap analysis issue creation
3. Standardize commit attribution: use co-authored-by trailers even when AI is the primary author
4. Consider running Phases 1 and 2 explicitly in parallel with separate branches to reduce calendar time

---

## Appendix: Phase Retrospective Index

| Phase | File | Key Metric |
|---|---|---|
| 0 | [`phase-0-retrospective.md`](../retrospectives/phase-0-retrospective.md) | 28 gap findings identified |
| 1 | [`phase-1-retrospective.md`](../retrospectives/phase-1-retrospective.md) | .NET 8 migration, 54% AI commits |
| 2 | [`phase-2-retrospective.md`](../retrospectives/phase-2-retrospective.md) | 100% AI commit ratio |
| 3 | [`phase-3-retrospective.md`](../retrospectives/phase-3-retrospective.md) | 25 PRs, 7 gap findings resolved |
| 4 | [`phase-4-retrospective.md`](../retrospectives/phase-4-retrospective.md) | Production live, 8/8 checks passed |
| 5 | [`phase-5-retrospective.md`](../retrospectives/phase-5-retrospective.md) | Bootstrap framework finalized |

---

*Source data: `docs/retrospectives/phase-{0..5}-retrospective.md` — generated by `bootstrap/generate-phase-retrospective.sh`*
