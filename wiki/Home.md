# Azure Resume IaC

> Personal resume website on Azure PaaS — static frontend, serverless API, Cosmos DB visitor counter — all deployed as code via Bicep and GitHub Actions, fronted by Cloudflare CDN.

[![Production Deploy](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/prod-full-stack-cloudflare.yml/badge.svg)](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/prod-full-stack-cloudflare.yml)
[![Dev Deploy](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/dev-full-stack-cloudflare.yml/badge.svg)](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/dev-full-stack-cloudflare.yml)
[![Backend CI](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/backend-ci.yml/badge.svg?branch=develop)](https://github.com/rmcveyhsawaknow/azure-resume-iac/actions/workflows/backend-ci.yml)

**Live:** [resume.ryanmcvey.me](https://resume.ryanmcvey.me/) · **Source:** [github.com/rmcveyhsawaknow/azure-resume-iac](https://github.com/rmcveyhsawaknow/azure-resume-iac)

---

## What is this?

A personal resume website hosted entirely on Azure PaaS services. The static HTML/CSS/JS frontend is served from Azure Storage, a .NET 8 Azure Function powers the visitor counter backed by Cosmos DB, and Cloudflare provides CDN and TLS. Every Azure resource is defined as code in Bicep templates and deployed automatically via GitHub Actions CI/CD. The project also uses **AgentGitOps** — an AI-powered workflow that combines GitHub Copilot agents with `gh` CLI automation to manage the project backlog.

> **New here?** Start with **[Getting Started](Getting-Started)** to set up a Codespace and run the project end-to-end in minutes.

---

## Page Index

### For Contributors

- [Getting Started](Getting-Started) — Codespace + local setup, build and test
- [Architecture](Architecture) — system overview, components, data flow
- [Backend](Backend) — .NET 8 Function App, counter API, Cosmos DB schema
- [Frontend](Frontend) — static site layout, config injection, counter integration
- [Testing](Testing) — running xUnit tests locally and in CI
- [Contributing](Contributing) — Git Flow branching, conventions, PR workflow

### For Operators

- [Infrastructure](Infrastructure) — Bicep module deep-dive, IaC layout, resource naming
- [CI-CD](CI-CD) — workflows, triggers, environments, path-based change detection
- [Deployment](Deployment) — blue/green strategy, step-by-step runbook, stack cleanup
- [Configuration](Configuration) — environment variables, secrets, Key Vault references
- [Troubleshooting](Troubleshooting) — common errors, root causes, and fixes

### For Reviewers

- [Security](Security) — secret handling, managed identity, vulnerability reporting
- [AgentGitOps](AgentGitOps) — AI-powered project workflow, Copilot Suitability, phase lifecycle
- [Glossary](Glossary) — repo-specific terms, naming conventions, acronyms

---

## External Links

- **Live site:** [resume.ryanmcvey.me](https://resume.ryanmcvey.me/)
- **Repository:** [github.com/rmcveyhsawaknow/azure-resume-iac](https://github.com/rmcveyhsawaknow/azure-resume-iac)
- **Report an issue:** [Open an issue](https://github.com/rmcveyhsawaknow/azure-resume-iac/issues/new/choose)
- **AgentGitOps guide:** [`bootstrap/README.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/bootstrap/README.md)

---

> This wiki is generated from repository content by the [`wiki-generator`](https://github.com/rmcveyhsawaknow/azure-resume-iac/tree/main/.github/skills/wiki-generator) Copilot agent skill and published by the [`publish-wiki.yml`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/.github/workflows/publish-wiki.yml) workflow. Direct edits in the wiki UI will be overwritten on the next publish — author changes in the `wiki/` directory of the source repo.
