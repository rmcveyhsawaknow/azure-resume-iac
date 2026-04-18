# Getting Started

> Everything you need to go from zero to running the Azure Resume project locally or in a Codespace.

**Source:** [`README.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/README.md) · [`docs/LOCAL_TESTING.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/LOCAL_TESTING.md) · [`.devcontainer/devcontainer.json`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/.devcontainer/devcontainer.json)

---

## Table of Contents

- [Quickest Path: GitHub Codespace](#quickest-path-github-codespace)
- [Local Development Setup](#local-development-setup)
- [Build and Test](#build-and-test)
- [Run the Function App Locally](#run-the-function-app-locally)
- [Frontend Integration](#frontend-integration)
- [Deploy Your Own Stack](#deploy-your-own-stack)
- [See also](#see-also)

---

## Quickest Path: GitHub Codespace

The fastest way to get started is a GitHub Codespace — the devcontainer handles all tool installation automatically.

1. Open the repo on GitHub
2. Click **Code → Codespaces → Create codespace on `develop`**
3. Wait for the container to build (first time takes a couple of minutes)
4. You're ready — .NET 8, Azure Functions Core Tools v4, Azure CLI, Node.js, and `gh` are all pre-installed

The devcontainer is based on `mcr.microsoft.com/devcontainers/dotnet:8.0` and includes:

| Tool | Version | Purpose |
|---|---|---|
| .NET SDK | 8.0 | Backend build and test |
| Azure Functions Core Tools | v4 | Local function host |
| Azure CLI | Latest | Infrastructure commands, Bicep deployments |
| Node.js | LTS | Frontend tooling, npm scripts |
| GitHub CLI (`gh`) | Latest | Issue and project management |

Port **7071** is auto-forwarded for the local Functions host.

## Local Development Setup

If you prefer working on your own machine, install these prerequisites:

- [Visual Studio Code](https://code.visualstudio.com/) with [recommended extensions](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/.vscode/extensions.json) (C#, Azure Functions, Bicep, GitHub Actions)
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (optional, for deploying infrastructure)

## Build and Test

```bash
# Build the backend
cd backend/api && dotnet build

# Run unit tests (8 xUnit tests)
cd backend/tests && dotnet test
```

All tests use xUnit v3 with Moq for mocking. They validate the counter increment logic without requiring a live Cosmos DB connection.

## Run the Function App Locally

### 1. Create `local.settings.json`

```bash
cd backend/api
cp local.settings.example.json local.settings.json
```

Edit the file and add your Cosmos DB connection string (or use the [Cosmos DB Emulator](https://learn.microsoft.com/azure/cosmos-db/emulator)):

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "FUNCTIONS_EXTENSION_VERSION": "~4",
    "AzureResumeConnectionStringPrimary": "<your-connection-string>"
  },
  "Host": {
    "CORS": "http://localhost:7071,http://localhost:4280,https://resume.ryanmcvey.me",
    "CORSCredentials": false
  }
}
```

> **Tip:** Retrieve the connection string from Azure CLI:  
> `az cosmosdb keys list --name <account> --resource-group <rg> --type connection-strings --query "connectionStrings[0].connectionString" -o tsv`

### 2. Start the function host

```bash
cd backend/api
func start
# → http://localhost:7071/api/GetResumeCounter
```

Or press **F5** in VS Code — the launch configuration builds, starts the host, and attaches the debugger.

### 3. Test the endpoint

```bash
curl http://localhost:7071/api/GetResumeCounter
# → {"id":"1","count":1}
```

Each request increments the counter. The response uses lowercase property names (`id`, `count`) matching what the frontend expects.

## Frontend Integration

The frontend at `frontend/index.html` is a plain HTML file — just open it in a browser. By default it reads the API endpoint from `frontend/config.js`, which is generated at deploy time by CI/CD.

To test against your local function, temporarily update `config.js`:

```javascript
const defined_FUNCTION_API_BASE = 'http://localhost:7071';
```

## Deploy Your Own Stack

1. Create an Azure Service Principal → store as GitHub secret `AZURE_RESUME_GITHUB_SP`
2. Configure Cloudflare API token and zone ID as GitHub secrets
3. Update workflow environment variables (`stackVersion`, `AppName`, `dnsZone`, etc.)
4. Push to `main` (production) or `develop` (development)
5. Bicep deploys all infrastructure; `config.js` is generated automatically — no manual frontend edits needed
6. The Cosmos DB counter document is auto-seeded by `scripts/seed-cosmos-db.sh`

For the full deployment walkthrough, see [Deployment](Deployment).

---

## See also

- [Architecture](Architecture) — system overview and component map
- [Testing](Testing) — running tests locally and in CI
- [Configuration](Configuration) — required environment variables and secrets
- [Deployment](Deployment) — end-to-end deploy and blue/green swap procedure
