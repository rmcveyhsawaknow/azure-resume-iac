# Local Testing Guide

This guide explains how to run and test the Azure Functions backend locally using Azure Functions Core Tools v4.

## Prerequisites

If you're using **GitHub Codespaces**, the devcontainer handles all of this automatically.

For local development, install:

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local#install-the-azure-functions-core-tools)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (optional, for retrieving connection strings)

## Setup

### 1. Create `local.settings.json`

Copy the example settings file and add your Cosmos DB connection string:

```bash
cd backend/api
cp local.settings.example.json local.settings.json
```

Then edit `local.settings.json` and replace the placeholder with your actual Cosmos DB connection string:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "FUNCTIONS_EXTENSION_VERSION": "~4",
    "AzureResumeConnectionStringPrimary": "<your-cosmos-db-connection-string>"
  },
  "Host": {
    "CORS": "http://localhost:7071,http://localhost:4280,https://resume.ryanmcvey.me",
    "CORSCredentials": false
  }
}
```

#### Retrieving the connection string

**From Azure CLI:**

```bash
az cosmosdb keys list \
  --name <cosmos-account-name> \
  --resource-group <resource-group> \
  --type connection-strings \
  --query "connectionStrings[0].connectionString" \
  -o tsv
```

**From Azure Portal:** Navigate to your Cosmos DB account → Keys → Primary Connection String.

#### Using the Cosmos DB Emulator (alternative)

Install the [Azure Cosmos DB Emulator](https://learn.microsoft.com/azure/cosmos-db/emulator) and use its connection string:

```
AccountEndpoint=https://localhost:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==
```

> **Note:** You must create the database `azure-resume-click-count` and container `Counter` (partition key `/id`) with an initial document `{ "id": "1", "count": 0 }` in the emulator before running.

### 2. Build

```bash
cd backend/api
dotnet build
```

### 3. Run unit tests

```bash
cd backend/tests
dotnet test
```

All 8 tests should pass.

## Running the Function App Locally

### Using the command line

```bash
cd backend/api
func start
```

You should see output like:

```
Azure Functions Core Tools
...
Functions:
  GetResumeCounter: [GET,POST] http://localhost:7071/api/GetResumeCounter
```

### Using VS Code (F5)

Press **F5** in VS Code. The launch configuration will:
1. Build the project
2. Start the Functions host via `func host start`
3. Attach the debugger

## Testing the Endpoint

Once the function is running, test it:

### Using curl

```bash
# GET request
curl http://localhost:7071/api/GetResumeCounter

# POST request
curl -X POST http://localhost:7071/api/GetResumeCounter
```

### Expected response

```json
{"id":"1","count":1}
```

Each request increments the `count` value. The response format uses lowercase property names (`id`, `count`) which matches what the frontend expects — see `frontend/main.js` line 23: `data.count`.

### Verifying the frontend integration

Open `frontend/index.html` in a browser. The visitor counter will not connect to the local function by default since it points to the production API. To test locally, temporarily update `frontend/main.js`:

```javascript
const functionApi = 'http://localhost:7071/api/GetResumeCounter';
const functionKey = ''; // No key needed locally
```

## Troubleshooting

| Issue | Fix |
|---|---|
| `func: command not found` | Install Azure Functions Core Tools v4: `npm i -g azure-functions-core-tools@4 --unsafe-perm true` |
| `No job functions found` | Ensure you're running `func start` from the `backend/api/` directory |
| `Unable to connect to Cosmos DB` | Check that `AzureResumeConnectionStringPrimary` is set correctly in `local.settings.json` |
| `CORS error in browser` | Verify the `Host.CORS` setting in `local.settings.json` includes your frontend origin |
| Port 7071 in use | Stop other Functions hosts or use `func start --port 7072` |

## Project Structure

```
backend/
├── api/
│   ├── api.csproj                    # .NET 8, Functions v4 isolated worker
│   ├── Program.cs                    # Host builder entry point
│   ├── GetResumeCounter.cs           # HTTP trigger function + MultiResponse
│   ├── Counter.cs                    # Data model (id, count)
│   ├── CosmosConstants.cs            # DB/container/document constants
│   ├── host.json                     # Functions host config (extension bundle v4)
│   ├── local.settings.json           # Local config (git-ignored)
│   └── local.settings.example.json   # Template for local.settings.json
└── tests/
    ├── tests.csproj                  # xUnit v3 test project
    └── TestCounter.cs                # 8 unit tests
```
