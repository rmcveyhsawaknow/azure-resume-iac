# LinkedIn Post — AgentGitOps: What It Is, What It Did, and How You Can Try It

> **Usage note:** This file contains a ready-to-publish LinkedIn post and a set of supporting talking points. Copy the post text below directly into LinkedIn. The talking points can be used for follow-up comments or a companion article.

---

## The Post

**I used GitHub Copilot agents to plan, build, and deploy an entire Azure project in 13 days. Here's what I learned.**

For the past two weeks, I ran an experiment: Could I take a broken, outdated Azure resume website and modernize the entire thing — infrastructure, backend, frontend, CI/CD, security, documentation — using AI coding agents as managed team members in a structured project workflow?

The answer is yes. And I measured every step.

---

**🔹 The project**

My living resume site ([resume.ryanmcvey.me](https://resume.ryanmcvey.me)) runs on Azure PaaS — Storage Account for static hosting, Azure Functions for a visitor counter, Cosmos DB for data, Cloudflare for CDN/DNS. It was stuck on .NET Core 3.1 (end of life), the counter was broken, and the content was two years stale.

I needed to:
✅ Migrate to .NET 8 and Azure Functions v4
✅ Update all resume content
✅ Harden security (TLS 1.2, Key Vault soft delete, remove hardcoded secrets)
✅ Deploy through an automated CI/CD pipeline with blue/green strategy
✅ Clean up legacy resources
✅ Document everything

**🔹 The approach — AgentGitOps**

I created a workflow I'm calling **AgentGitOps**: a repeatable process that uses GitHub Copilot coding agents alongside standard GitHub project management (Issues, Milestones, Projects, Actions).

The key idea: **every issue gets triaged for Copilot suitability before work begins.**

- **Yes** — fully delegate to the AI agent (code generation, refactoring, docs, tests)
- **Partial** — AI writes the code, human reviews and guides
- **No** — human only (credentials, portal access, deployment verification)

This isn't "vibe coding." It's planned delegation with measurable outcomes.

**🔹 The results — 13 days, 6 phases, 103 issues**

| What | Number |
|---|---|
| Calendar days | 13 |
| Phases completed | 6/6 |
| Issues closed | 91/103 |
| Pull requests merged | 70 |
| PRs authored by AI | 53 (76%) |
| Commits shipped | 235 |
| Commits with AI co-author trailer | 60% (140/235) |
| Gap analysis findings | 28 identified, 10+ resolved |

Phase 2 (content updates) hit **100% AI commit ratio** — every PR and commit was AI-authored with human review. Phase 3 (dev deployment) produced **25 PRs in 5 days** across IaC hardening, CI/CD modernization, and blue/green stack testing.

Production went live on Day 11. All 8 validation checks passed.

**🔹 What made it work**

1. **Structured planning first.** Session 0 produces a backlog CSV and planning doc before any code is written. The AI agent helps generate these, but the human defines the goals.

2. **Suitability triaging.** Labeling every issue as Yes/Partial/No for Copilot sets realistic expectations upfront. You know exactly what the AI will and won't do.

3. **Phase boundary retrospectives.** An automated script (`generate-phase-retrospective.sh`) collects issue counts, PR authors, commit attribution, and AI productivity ratios at every phase boundary. No manual metric tracking.

4. **Standard GitHub platform.** No new tools. GitHub Copilot, GitHub Issues, GitHub Projects, GitHub Actions, `gh` CLI. Everything lives in the repo.

**🔹 How you can try it yourself**

The entire framework is open and portable:

1. Copy the `bootstrap/` folder from my repo into yours
2. Run `bootstrap/check-prerequisites.sh` to verify your setup
3. Follow the Session 0 prompt — paste it into Copilot Plan mode, answer 4 question groups, and the agent generates your backlog

👉 **Repo:** [github.com/rmcveyhsawaknow/azure-resume-iac](https://github.com/rmcveyhsawaknow/azure-resume-iac)
👉 **Quick start:** `bootstrap/README.md`
👉 **Full guide:** `bootstrap/agentgitops-instructions.md`

The repo includes all 6 phase retrospectives with real metrics, the full backlog CSV, issue templates, label scripts, milestone scripts, and project setup automation.

**🔹 Why this matters**

AI coding agents aren't just autocomplete. When you treat them as managed team members — with scoped assignments, review gates, and measurable output — they become a productivity multiplier.

For this project, AI authored 76% of all pull requests. But the human still defined every goal, reviewed every merge, validated every deployment, and managed every credential. That's the balance.

This is what I believe enterprise-grade AI-assisted development looks like: **planned, suitable, and measurable.**

My resume site isn't just a resume. It's a working demonstration of how I think about technology platforms — end-to-end, from architecture to operations.

---

#AgentGitOps #GitHubCopilot #AzureCloud #InfrastructureAsCode #AIProductivity #DevOps #CloudArchitecture #GitHub #LivingResume

---

## Supporting Talking Points (For Comments / Follow-Up)

### For the "how does this compare to just using Copilot in the IDE?" question:

> IDE Copilot is great for line-by-line code completion. AgentGitOps is about delegating entire work items — "here's an issue with acceptance criteria, go write the PR." The coding agent works in a branch, opens a PR, and you review it like any other teammate's code. The difference is the scope of delegation: a line of code vs. an entire task.

### For the "what couldn't the AI do?" question:

> Three things: credentials (creating/rotating Azure service principals and Cloudflare tokens), portal validation (confirming resources exist in the Azure portal), and deployment sign-off (verifying the live site works end-to-end). About one-third of issues (26 of 80 labeled) were tagged Copilot: No for these reasons. On the other end, just over a third (29 issues) were Copilot: Yes — fully delegated to the AI. The framework anticipates this split — it's not about 100% AI, it's about knowing which tasks are fully automatable and which require human judgment.

### For the "is this actually faster?" question:

> 91 issues and 70 PRs in 13 days, solo. The retrospective data shows 7 issues closed per day on average, with 5.4 PRs merged per day. Phase 2 (content updates) closed 20 issues in a single day. Could a person do this without AI? Sure, but not at this throughput. The AI handled the high-volume, well-defined tasks (code gen, docs, refactoring) so I could focus on the judgment-heavy work (architecture decisions, security validation, deployment verification).

### For the "can I use this at work?" question:

> Yes — the `bootstrap/` directory is designed to be portable. Copy it into any GitHub repo. The scripts create labels, milestones, issues, and a project board. The Session 0 prompt works with Copilot Plan mode or any chat agent. You'll need GitHub Copilot (Business or Enterprise) for the coding agent, but the project management scaffolding works without it. Start with a small internal project, measure your AI SP ratio at each retrospective, and scale from there.

### For the "what about code quality?" question:

> Every AI-authored PR went through the same review process as human code: PR description, diff review, CI checks, and manual merge. The backend has 9 xUnit tests that pass on every build. The CI pipeline runs on every push to main and develop. Phase 3 alone went through 5 blue/green stack iterations to validate the deployment pipeline before going to production. This isn't about moving fast and breaking things — it's about moving fast with guardrails.
