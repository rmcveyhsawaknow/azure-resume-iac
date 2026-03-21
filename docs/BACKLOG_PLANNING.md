# Backlog Planning Guide

This document provides a phased planning framework for the resume site content and infrastructure update project. It is designed to support backlog CSV creation and GitHub issue template development.

> **Related docs:**
> - [Agent-Driven Backlog Workflow](backlog_workflow.md) — Detailed session-by-session workflow
> - [AgentGitOps Bootstrap](../bootstrap/agentgitops-instructions.md) — Reusable guide for any project
> - [Retrospectives](retrospectives/README.md) — Phase completion reports

> **Issue types:** Tasks in this plan are either **planned** (part of the original project scope) or **gap-analysis-finding** (discovered during assessment). Gap-analysis tasks are noted in the task tables with "(gap-analysis)" after the description and carry the `gap-analysis-finding` label when created as GitHub issues.

## Project Overview

**Goal:** Update the Azure resume site with content from the [GitHub profile README](https://github.com/rmcveyhsawaknow), fix the broken visitor counter, modernize the technology stack, and deploy through a validated dev → prod pipeline.

**Content Source:** [rmcveyhsawaknow GitHub Profile README](https://github.com/rmcveyhsawaknow)

**Current Site:** <https://resume.ryanmcvey.me/>

## Phase Summary

| Phase | Name | Description | Dependencies |
|---|---|---|---|
| 0 | Assessment | Harvest current Azure and Cloudflare state for ryanmcvey.me, verify credentials, document actuals | None |
| 1 | Fix Function App | Restore the visitor counter (runtime upgrade, connectivity, data verification) | Phase 0 |
| 2 | Content Update | Update resume site HTML/CSS/JS with GitHub profile content | Phase 0 |
| 3 | Dev Deployment | Deploy updated stack to development environment, validate end-to-end | Phases 1, 2 |
| 4 | Prod Deployment | Deploy validated stack to production, verify live site | Phase 3 |
| 5 | Cleanup & Docs | Remove old resources, update documentation, close backlog items | Phase 4 |

---

## Phase 0: Assessment

**Objective:** Understand the current state of all deployed resources, verify credentials, and establish a baseline for planning.

### Workstream: Azure Assessment

| Task ID | Task | Description | CLI Reference |
|---|---|---|---|
| 0.1 | Verify Azure SP credential | Test login, check role assignments and expiry | [ASSESSMENT_COMMANDS.md → Azure SP](ASSESSMENT_COMMANDS.md#azure-service-principal-assessment) |
| 0.2 | Inventory resource groups | List all resume-related resource groups and resources | [ASSESSMENT_COMMANDS.md → Resource Groups](ASSESSMENT_COMMANDS.md#azure-resource-group-assessment) |
| 0.3 | Assess Function App | Check state, runtime, configuration, CORS, function keys | [ASSESSMENT_COMMANDS.md → Function App](ASSESSMENT_COMMANDS.md#function-app-assessment) |
| 0.4 | Assess Cosmos DB | Verify account, database, container, and counter document | [ASSESSMENT_COMMANDS.md → Cosmos DB](ASSESSMENT_COMMANDS.md#cosmos-db-assessment) |
| 0.5 | Assess Key Vault | Check secrets, access policies, expiry | [ASSESSMENT_COMMANDS.md → Key Vault](ASSESSMENT_COMMANDS.md#key-vault-assessment) |
| 0.6 | Assess Storage Accounts | Verify static website config, custom domains, content | [ASSESSMENT_COMMANDS.md → Storage](ASSESSMENT_COMMANDS.md#storage-account-assessment-frontend) |
| 0.7 | Assess App Insights | Verify instrumentation keys, check for recent errors | [ASSESSMENT_COMMANDS.md → App Insights](ASSESSMENT_COMMANDS.md#application-insights-assessment) |

### Workstream: Cloudflare Assessment

| Task ID | Task | Description | CLI Reference |
|---|---|---|---|
| 0.8 | Verify Cloudflare token | Test API token, check permissions | [ASSESSMENT_COMMANDS.md → Cloudflare](ASSESSMENT_COMMANDS.md#cloudflare-assessment) |
| 0.9 | Inventory DNS records | List all DNS records for ryanmcvey.me zone | Same as above |
| 0.10 | Check SSL/TLS settings | Verify encryption mode and certificate status | Same as above |

### Workstream: GitHub Assessment

| Task ID | Task | Description |
|---|---|---|
| 0.11 | Verify GitHub secrets | Confirm all 5 secrets exist in repo settings (values cannot be read) |
| 0.12 | Check workflow run history | Review recent GitHub Actions runs for errors |
| 0.13 | Review GitHub environments | Check if `production` and `development` environments have protection rules |
| 0.14 | Phase 0 Retrospective | Run retrospective generator, commit report, close milestone |

### Phase 0 Deliverable
- Assessment output JSON files saved to `assessment-output/` directory
- Documented list of actual resource names and configurations vs. expected from IaC
- Identified gaps, expired credentials, or misconfigured resources

---

## Phase 1: Fix Function App

**Objective:** Restore the visitor counter to working state.

**Priority:** Complete before content updates to validate the full-stack pipeline.

| Task ID | Task | Description | Depends On |
|---|---|---|---|
| 1.1 | Diagnose root cause | Use Phase 0 assessment data to identify why counter is broken | Phase 0 |
| 1.2 | Upgrade .NET runtime | Migrate from .NET Core 3.1 → .NET 8 in `api.csproj` | 1.1 |
| 1.3 | Upgrade Functions version | Update from v3 → v4 in `api.csproj` and Bicep `FUNCTIONS_EXTENSION_VERSION` | 1.2 |
| 1.4 | Update NuGet packages | Update `Microsoft.Azure.WebJobs.Extensions.CosmosDB` and `Microsoft.NET.Sdk.Functions` | 1.2 |
| 1.5 | Update test project | Migrate `tests.csproj` to match new target framework | 1.4 |
| 1.6 | Verify Cosmos DB data | Ensure counter document `{"id": "1", "count": N}` exists | 1.1 |
| 1.7 | Verify Key Vault access | Confirm Function App managed identity has Key Vault read access | 1.1 |
| 1.8 | Update CORS settings | Verify allowed origins match ryanmcvey.me custom domain | 1.1 |
| 1.9 | Update function key in main.js | Retrieve current function key and update `frontend/main.js` | 1.3 |
| 1.10 | Test function locally | Run Function App locally with `func start` and verify counter | 1.5 |
| 1.11 | Update workflow dotnet version | Change `DOTNET_VERSION` from `3.1` to `8.0` in workflow files | 1.3 |
| 1.12 | Set FtpsState to Disabled on Function App | Function App allows FTP/FTPS — set to `Disabled` in Bicep *(gap-analysis)* | 1.3 |
| 1.13 | Phase 1 Retrospective | Run retrospective generator, commit report, close milestone | — |

---

## Phase 2: Content Update

**Objective:** Update the resume site content to reflect the GitHub profile README.

**Content Mapping from [GitHub Profile](https://github.com/rmcveyhsawaknow):**

| Profile Section | Site Section | Notes |
|---|---|---|
| Title and tagline | Header / Banner | "Innovative Technology Architect \| Cloud, AI, and Hybrid Infrastructure" |
| Certification list | Certifications / Badges | Azure Solutions Architect Expert, AI Engineer, Data Scientist, AI Fundamentals |
| "What I work on" | Skills / Expertise | 6 areas: cloud architecture, AI strategy, agent workflows, SDLC, observability, governance |
| "Current focus" | About / Current Role | 4 focus areas |
| "Featured project work" | Portfolio / Projects | ThisOrThatDesign and this resume project |
| "Background" | Experience summary | Military → Enterprise → Architecture leadership |
| "Philosophy" | About section | Three principles |
| "Outside of work" | Interests / Personal | CAD, CNC, 3D printing, fabrication |

| Task ID | Task | Description | Depends On |
|---|---|---|---|
| 2.1 | Design content layout | Map profile sections to HTML sections in index.html | Phase 0 |
| 2.2 | Update banner text | Update name, title, rotating text items | 2.1 |
| 2.3 | Update About section | Replace with profile background and philosophy | 2.1 |
| 2.4 | Update Resume section | Add skills, certifications, experience summary | 2.1 |
| 2.5 | Add Projects section | Feature ThisOrThatDesign and other project work | 2.1 |
| 2.6 | Update profile photo | Replace `me.png` if needed | 2.1 |
| 2.7 | Update certification badges | Add/update Azure cert badge images | 2.1 |
| 2.8 | Update social links | Verify LinkedIn and GitHub URLs | 2.1 |
| 2.9 | Update page metadata | Title, description, Open Graph tags | 2.1 |
| 2.10 | Review CSS/styling | Adjust styles for new content layout | 2.5 |
| 2.11 | Phase 2 Retrospective | Run retrospective generator, commit report, close milestone | — |

---

## Phase 3: Dev Environment Deployment

**Objective:** Deploy the updated stack to a development environment and validate end-to-end.

| Task ID | Task | Description | Depends On |
|---|---|---|---|
| 3.1 | Update dev workflow variables | Set appropriate `stackVersion`, `AppName` for new dev stack | Phases 1, 2 |
| 3.2 | Update GitHub Actions syntax | Fix deprecated `::set-output`, update action versions | 3.1 |
| 3.3 | Verify/rotate dev credentials | Ensure Azure SP and Cloudflare token are valid | Phase 0 |
| 3.4 | Push to develop branch | Trigger dev workflow deployment | 3.2, 3.3 |
| 3.5 | Verify IaC deployment | Confirm all resources created successfully | 3.4 |
| 3.6 | Verify Function App | Test counter endpoint returns valid response | 3.5 |
| 3.7 | Verify frontend | Access dev URL and confirm content, styling, counter | 3.5 |
| 3.8 | Seed Cosmos DB | Create initial counter document if needed | 3.5 |
| 3.9 | End-to-end validation | Full test of all features on dev environment | 3.6, 3.7 |
| 3.10 | Add production environment protection rules | Configure required reviewers and branch policy on `production` environment *(gap-analysis)* | — |
| 3.11 | Fix development environment branch policy | Add `develop` branch policy to `development` environment *(gap-analysis)* | — |
| 3.12 | Update storage account min TLS to 1.2 | Set `minimumTlsVersion: TLS1_2` on all storage accounts *(gap-analysis)* | 3.1 |
| 3.13 | Migrate backend App Insights to workspace-based | Convert Classic App Insights to workspace-based mode *(gap-analysis)* | 3.1 |
| 3.14 | Enable Key Vault soft delete | Set `enableSoftDelete: true` on Key Vault *(gap-analysis)* | 3.1 |
| 3.15 | Update backend App Insights connection string format | Add `IngestionEndpoint` and `LiveEndpoint` to connection string *(gap-analysis)* | 3.13 |
| 3.16 | Update CLOUDFLARE_TOKEN and CLOUDFLARE_ZONE secrets | Update stale GitHub secrets with current Cloudflare API token *(gap-analysis)* | — |
| 3.17 | Phase 3 Retrospective | Run retrospective generator, commit report, close milestone | — |

---

## Phase 4: Production Deployment

**Objective:** Deploy validated stack to production and verify the live site.

| Task ID | Task | Description | Depends On |
|---|---|---|---|
| 4.1 | Update prod workflow variables | Set appropriate `stackVersion` for new production stack | Phase 3 |
| 4.2 | Verify/rotate prod credentials | Ensure Azure SP and Cloudflare token are valid for prod | Phase 0 |
| 4.3 | Merge to main branch | Trigger production workflow deployment | 4.1, 4.2 |
| 4.4 | Verify IaC deployment | Confirm all resources created successfully | 4.3 |
| 4.5 | Verify Function App | Test counter endpoint on production | 4.4 |
| 4.6 | Verify frontend | Access `resume.ryanmcvey.me` and confirm content | 4.4 |
| 4.7 | Verify DNS resolution | Confirm ryanmcvey.me domain resolves correctly | 4.4 |
| 4.8 | Verify Cloudflare proxy | Confirm proxied CNAME records are active | 4.7 |
| 4.9 | End-to-end production validation | Full test on production URLs | 4.5 through 4.8 |
| 4.10 | Phase 4 Retrospective | Run retrospective generator, commit report, close milestone | — |

---

## Phase 5: Cleanup and Documentation

**Objective:** Remove old resources, update all documentation, close project.

| Task ID | Task | Description | Depends On |
|---|---|---|---|
| 5.1 | Identify old resources | Compare old v1 resources against new deployment | Phase 4 |
| 5.2 | Remove old resource groups | Delete old backend and frontend RGs if replaced | 5.1 |
| 5.3 | Clean up DNS records | Remove stale Cloudflare DNS records for retired .net and .cloud domains | 5.1 |
| 5.4 | Update README.md | Reflect new stack version, configuration, and content | Phase 4 |
| 5.5 | Update docs/ | Refresh architecture, workflow, and assessment docs | Phase 4 |
| 5.6 | Close backlog items | Mark all completed issues as done | 5.4, 5.5 |
| 5.7 | Final cost review | Verify Azure cost impact of new vs. old stack | 5.2 |
| 5.8 | Delete stale GitHub secrets | Remove unused `CLOUDFLARE_ZONE2` and `CLOUDFLARE_ZONE3` secrets *(gap-analysis)* | — |
| 5.9 | Clean up disabled Azure CDN workflows | Delete or archive disabled `azure-static-web-apps-*.yml` workflow files *(gap-analysis)* | — |
| 5.10 | Remove copilot GitHub environment | Delete unused `copilot` environment from repo settings *(gap-analysis)* | — |
| 5.11 | Clean up excess CORS origins | Remove stale Azure CDN CORS origins from Function App Bicep *(gap-analysis)* | — |
| 5.12 | Set Key Vault secret expiration dates | Add expiration dates to all Key Vault secrets *(gap-analysis)* | — |
| 5.13 | Migrate Key Vault to RBAC authorization | Switch from Vault access policy to Azure RBAC model *(gap-analysis)* | — |
| 5.14 | Address frontend iKey hardcoding | Remove hardcoded App Insights instrumentation key from JS *(gap-analysis)* | — |
| 5.15 | Phase 5 Retrospective | Run retrospective generator, commit report, close milestone | — |

---

## Backlog CSV Structure

Use this structure for the backlog CSV file:

```csv
task_id,phase,phase_name,task_title,description,depends_on,priority,status,assignee,copilot_suitable,issue_type,labels
0.1,0,Assessment,Verify Azure SP credential,Test login and check role assignments and expiry,,P1 – Critical,todo,,No,planned,assessment;credentials
0.2,0,Assessment,Inventory resource groups,List all resume-related resource groups and resources,,P2 – High,todo,,Yes,planned,assessment;azure
...
```

**Field Definitions:**

| Field | Description |
|---|---|
| `task_id` | Unique identifier matching phase.sequence (e.g., `0.1`, `1.3`) |
| `phase` | Phase number (0-5) |
| `phase_name` | Human-readable phase name |
| `task_title` | Short task title for issue creation |
| `description` | Detailed description of the work |
| `depends_on` | Comma-separated list of task IDs this depends on |
| `priority` | `P1 – Critical`, `P2 – High`, `P3 – Medium`, `P4 – Low` (must match label names) |
| `status` | `todo`, `in_progress`, `done`, `blocked` |
| `assignee` | GitHub username |
| `copilot_suitable` | `Yes`, `Partial`, `No` — indicates if task is suitable for GitHub Copilot agent |
| `issue_type` | `planned` (original scope) or `gap-analysis-finding` (discovered during assessment) |
| `labels` | Semicolon-separated labels for GitHub issues |

## Issue Template Structure

Recommended GitHub issue template fields:

```yaml
name: Backlog Task
description: Task from the resume site update backlog
title: "[Phase {phase}] {task_title}"
labels: ["backlog"]
body:
  - type: input
    id: task_id
    label: Task ID
  - type: dropdown
    id: phase
    label: Phase
    options: [Assessment, Fix Function App, Content Update, Dev Deployment, Prod Deployment, Cleanup]
  - type: textarea
    id: description
    label: Task Description
  - type: input
    id: depends_on
    label: Dependencies (Task IDs)
  - type: dropdown
    id: priority
    label: Priority
    options: [Critical, High, Medium, Low]
  - type: dropdown
    id: copilot_suitable
    label: Copilot Suitable
    options: [Yes, Partial, No]
  - type: textarea
    id: acceptance_criteria
    label: Acceptance Criteria
  - type: textarea
    id: notes
    label: Assessment Notes (populated from Phase 0)
```
