# AgentGitOps Epic Report — Technical Staff Edition

**Project:** Azure Resume IaC — Full-Stack Modernization & Redeployment
**Repository:** [rmcveyhsawaknow/azure-resume-iac](https://github.com/rmcveyhsawaknow/azure-resume-iac)
**Period:** March 10–22, 2026 (13 calendar days)
**Live Site:** [resume.ryanmcvey.me](https://resume.ryanmcvey.me)
**Methodology:** AgentGitOps — AI-Assisted Project Lifecycle on GitHub

---

## What This Report Covers

This is the epic-level technical summary for the complete AgentGitOps lifecycle — 6 phases, 103 issues, 70 PRs, and 235 commits — that took a broken, outdated Azure resume site and delivered a modernized, production-deployed application with full infrastructure-as-code, CI/CD, and monitoring. Every phase has a detailed retrospective in `docs/retrospectives/`.

---

## Architecture: Before and After

### Before (Pre-Project State)

- .NET Core 3.1 (EOL) with Azure Functions v3
- Broken visitor counter (runtime mismatch, expired connections)
- Hardcoded secrets in frontend JavaScript
- Classic Application Insights (deprecated)
- No environment protection rules
- Stale DNS records across multiple domains (`.net`, `.cloud`, `.me`)
- Manual deployments, no blue/green strategy
- Outdated Bicep API versions (`@2019-09-01` Key Vault)

### After (Production v12)

```
                    ┌─────────────────────────┐
                    │   Cloudflare CDN/DNS     │
                    │   Proxied CNAME + TLS    │
                    │   ryanmcvey.me zone      │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  Azure Storage Account   │
                    │  Static Website + TLS1.2 │
                    │  Stack v12, config.js    │
                    │  injected at deploy time │
                    └────────────┬────────────┘
                                 │ fetch()
                    ┌────────────▼────────────┐
                    │   Azure Function App     │
                    │   .NET 8 Isolated v4     │
                    │   GetResumeCounter       │
                    │   (Anonymous auth)       │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Azure Cosmos DB        │
                    │   Serverless SQL API     │
                    │   Auto-seeded counter    │
                    └─────────────────────────┘

Supporting: Key Vault (soft delete, 90d retention) │ App Insights (workspace-based)
            │ Microsoft Clarity (EUM) │ App Service Plan (Y1 serverless)
```

---

## Phase-by-Phase Technical Breakdown

### Phase 0 — Assessment (Day 0)

**Goal:** Harvest current state, identify gaps, establish baseline.

- Inventoried all Azure resource groups, Cosmos DB, Key Vault, Function App, Storage, App Insights
- Inventoried Cloudflare DNS records, SSL/TLS config, API token permissions
- Verified GitHub secrets, workflow history, environment protection rules
- **Output:** 28 gap analysis findings that seeded Phases 1–5 backlogs

| Metric | Value |
|---|---|
| Issues | 14 planned → 13 closed (93%) |
| PRs merged | 3 |
| Gap findings | 28 |

### Phase 1 — Fix Function App (Days 1–4)

**Goal:** Restore the broken visitor counter — runtime upgrade, connectivity, data verification.

Key technical changes:
- **Runtime migration:** .NET Core 3.1 → .NET 8, Azure Functions v3 → v4 (isolated worker model)
- **NuGet upgrades:** `Microsoft.Azure.Functions.Worker`, `Microsoft.Azure.Cosmos` SDK
- **Test project:** Migrated to xUnit v3, all 9 tests passing
- **Cosmos DB:** Verified counter document schema `{"id": "1", "count": N}`
- **Key Vault:** Confirmed managed identity access for Function App
- **Bicep:** Set FtpsState to Disabled (gap analysis finding)
- **Workflows:** Updated `DOTNET_VERSION` from `3.1` to `8.0`

| Metric | Value |
|---|---|
| Issues | 24 planned → 22 closed (92%) |
| PRs merged | 17 |
| Commits | 74 |
| AI PRs | 15 / 17 (88%) |
| AI commits | 54% co-authored |

### Phase 2 — Content Update (Day 5)

**Goal:** Update all resume site content from GitHub profile README.

Key technical changes:
- Restructured HTML sections: banner, about, resume, projects, AgentGitOps
- Updated profile photo (optimized WebP/JPEG), certification badges with verification links
- Added 9 portfolio project entries with descriptions and external links
- Updated OG tags and SEO metadata for social sharing
- Fixed CSS: banner text visibility, responsive `h4` rules, resume list styling
- Enforced `target="_blank" rel="noopener noreferrer"` on all external links

| Metric | Value |
|---|---|
| Issues | 21 planned → 20 closed (95%) |
| PRs merged | 10 |
| Commits | 12 |
| AI PRs | 10 / 10 (100%) |
| AI commits | 100% co-authored |

> Phase 2 was the highest AI-leverage phase — all PRs and commits were AI-authored, with human review on every merge.

### Phase 3 — Dev Deployment (Days 5–10)

**Goal:** Deploy updated stack to dev, validate end-to-end, harden infrastructure.

Key technical changes:
- **CI/CD modernization:** `$GITHUB_OUTPUT` syntax, pinned action versions, `workflow_dispatch` trigger, `node24` actions
- **Bicep hardening:** Fixed `listKeys` reference, CORS parameter injection, TLS 1.2 enforcement on storage, Key Vault soft delete with 90-day retention, workspace-based App Insights
- **DNS automation:** Extracted Cloudflare DNS logic into reusable `cloudflare-dns-record.sh` with upsert support for blue/green swaps
- **Cosmos DB seeding:** Automated `seed-cosmos-db.sh` with check-before-create pattern
- **Blue/green deployment:** Exercised 5 stack iterations (v1→v2→v3→v10→v11) with full inventory/purge cycle
- **Environment protection:** Added production reviewer gates, fixed development branch policy
- **Frontend telemetry:** Microsoft Clarity EUM integration, App Insights connection string injection via `config.js`
- **Removed deprecated:** `APPINSIGHTS_INSTRUMENTATIONKEY` from backend Function App

| Metric | Value |
|---|---|
| Issues | 21 planned → 20 closed (95%) |
| PRs merged | 25 |
| Commits | 103 |
| AI PRs | 17 / 25 (68%) |
| AI commits | 79% co-authored |
| Gap findings resolved | 7 |
| Stack iterations | 5 (v1→v2→v3→v10→v11) |

### Phase 4 — Prod Deployment (Day 11)

**Goal:** Deploy validated stack to production, verify live site.

Key technical changes:
- **Deployment:** Merged `develop` → `main` triggering full production pipeline
- **Bicep API modernization:** Key Vault `@2019-09-01` → `@2024-11-01`, Storage `@2021-04-01` → `@2024-01-01`, Web sites `@2021-03-01` → `@2023-12-01`
- **Unused module cleanup:** Removed standalone `kv.bicep` (Key Vault defined inline in `functionapp.bicep`)
- **Stack version bump:** Both dev and prod bumped to v12 for fresh deployments
- **Full validation:** IaC, Function App, frontend, DNS, Cloudflare proxy, CORS, App Insights, Clarity — all 8 checks passed

| Metric | Value |
|---|---|
| Issues | 17 planned → 12 closed (71% overall, 100% core tasks) |
| PRs merged | 3 |
| Commits | 9 |
| Gap findings resolved | 2 (+ 2 deferred duplicates) |
| Validation checks | 8/8 passed |

### Phase 5 — Cleanup & Docs (Days 12–13)

**Goal:** Remove old resources, finalize documentation, enhance bootstrap framework.

Key technical changes:
- **Resource cleanup:** Removed old Azure resource groups from superseded stack versions
- **DNS cleanup:** Removed stale `.net` and `.cloud` DNS records after domain consolidation
- **Stack version injection:** Added `defined_STACK_VERSION` / `defined_STACK_ENVIRONMENT` display in site footer via `config.js` + `main.js`
- **AgentGitOps bootstrap:** Issue type taxonomy, role-based templates, project views guide, story point model, Session 0 interactive prompt, 7-state status taxonomy, Copilot Suitability as first-class field
- **Backend CI:** Fixed badge URL, confirmed all 9 xUnit tests pass

| Metric | Value |
|---|---|
| Issues | 6 planned → 4 closed (67% overall, 100% core tasks) |
| PRs merged | 12 |
| Commits | 37 |
| AI PRs | 7 / 12 (58%) |
| AI direct commits | 24 / 37 (65%) |

---

## Aggregate Engineering Metrics

### Code Volume

| Metric | Total |
|---|---|
| Pull requests merged | 70 |
| Commits shipped | 235 |
| Phases completed | 6 / 6 |
| Issues closed | 91 / 103 (88%) |
| Gap analysis findings | 28 identified, 10+ resolved |

### Contributor Breakdown (Commits)

| Author | Commits | % |
|---|---|---|
| copilot-swe-agent[bot] | 106 | 45% |
| Ryan McVey | 78 | 33% |
| Copilot | 51 | 22% |

> `copilot-swe-agent[bot]` and `Copilot` are both AI actors — combined **67% of all commits** were AI-authored.

### PR Authorship

| Author | PRs Merged | % |
|---|---|---|
| AI (Copilot + copilot-swe-agent) | 53 | 76% |
| Human (rmcveyhsawaknow) | 17 | 24% |

### AI Productivity Index by Phase

| Phase | Task AI % | Commit AI % | Notes |
|---|---|---|---|
| 0 — Assessment | 0% | 0% | Baseline collection, no code changes |
| 1 — Fix Function App | 32% | 54% | Runtime migration, NuGet upgrades |
| 2 — Content Update | 70% | 100% | Highest AI leverage — all content PRs AI-authored |
| 3 — Dev Deployment | 25% | 79% | Mixed — IaC hardening + manual validation |
| 4 — Prod Deployment | 20% | 67% | Deployment verification is human-heavy |
| 5 — Cleanup & Docs | 25% | 3%¹ | Bootstrap framework + cleanup |
| **Weighted Average** | **~29%** | **~60%** | — |

> ¹ Phase 5 co-authored-by trailer ratio was 2.7% (1/37). However, `copilot-swe-agent[bot]` directly authored 24/37 (65%) of commits as primary author without adding trailers. The weighted average uses trailer-based ratios for consistency with the retrospective methodology.

---

## Security Improvements Delivered

| Finding | Phase | Change |
|---|---|---|
| FtpsState set to Disabled | 1 | Bicep `siteConfig.ftpsState: 'Disabled'` |
| TLS 1.2 enforced on Storage | 3 | `minimumTlsVersion: 'TLS1_2'` |
| Key Vault soft delete enabled | 3 | `enableSoftDelete: true`, 90-day retention |
| App Insights workspace-based | 3 | Migrated from Classic to workspace-based mode |
| Deprecated instrumentation key removed | 3 | Removed `APPINSIGHTS_INSTRUMENTATIONKEY` |
| Environment protection rules | 3 | Production reviewer gates, development branch policy |
| Credential rotation | 3 | Updated Cloudflare tokens, verified Azure SP |
| Bicep API versions modernized | 4 | Key Vault, Storage, Web — all to latest stable |
| Unused module removed | 4 | Standalone `kv.bicep` cleaned up |
| Hardcoded secrets eliminated | 3 | `config.js` injected at deploy time |
| Stale DNS records removed | 5 | Consolidated to `ryanmcvey.me` single domain |

### Remaining Tech Debt

| Item | Issue | Status |
|---|---|---|
| Key Vault RBAC migration | #145 | Deferred — access policies functional |
| jQuery 1.10.2 / Font Awesome 4.x | — | Low priority, functional |
| Anonymous function endpoint rate limiting | — | Cloudflare rule planned |

---

## Blue/Green Deployment Evolution

The project exercised the blue/green pattern through 6 stack versions in dev and 2 in prod:

```
Dev:  v1 → v2 → v3 → v10 → v11 → v12 (active)
Prod: v1 → v12 (active)
```

Each stack version deployed a complete, isolated set of Azure resources (resource groups, Cosmos DB, Key Vault, Function App, Storage Account). Old stacks were inventoried (JSON artifacts in `artifacts/`) and purged via `scripts/cleanup-stack.sh`.

**Stack naming convention:** `{locationCode}-{appName}-{tier}-{environment}-{version}-{resourceType}`
Example: `cus1-resume-be-prod-v12-rg`

---

## Repository Deliverables

| Artifact | Path | Description |
|---|---|---|
| Infrastructure as Code | `.iac/` | Azure Bicep templates (backend + frontend modules) |
| Backend | `backend/api/` | .NET 8 Function App (isolated worker) |
| Tests | `backend/tests/` | 9 xUnit v3 tests |
| Frontend | `frontend/` | Static HTML/CSS/JS resume site |
| CI/CD | `.github/workflows/` | 3 active workflows (prod, dev, backend CI) |
| AgentGitOps Bootstrap | `bootstrap/` | Portable scripts, guides, templates |
| Documentation | `docs/` | Architecture, CI/CD, local testing, known issues, planning |
| Phase Retrospectives | `docs/retrospectives/` | 6 phase retrospectives with KPIs |
| Stack Inventories | `artifacts/` | JSON snapshots of Azure/Cloudflare resources per version |
| Operational Scripts | `scripts/` | Cleanup, DNS, Cosmos seed, environment protection |

---

## How the AgentGitOps Workflow Operated

```
Session 0: PM defines goals → Agent generates backlog CSV + planning doc
Session 1: Agent reads codebase → generates copilot-instructions.md
Session 2: Agent produces issue .md files from CSV + codebase analysis
Session 3: Scripts create GitHub labels, milestones, issues, project
Session 4: Phase 0 assessment tasks → gap analysis → feeds backlog
Session 5+: Phase-by-phase burn-down with AI + human collaboration
            Each phase ends with a retrospective (generate-phase-retrospective.sh)
```

**What made it work technically:**
- `Copilot Suitable` as a first-class field on every issue — enables the Copilot Queue view
- Co-authored-by trailers on commits — enables commit-level AI attribution
- Phase milestones + retrospective script — automates metrics collection
- `bootstrap/` directory is self-contained and portable to any repo

---

*Source data: `docs/retrospectives/phase-{0..5}-retrospective.md` — generated by `bootstrap/generate-phase-retrospective.sh`*
