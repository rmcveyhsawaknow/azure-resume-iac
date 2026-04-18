# Backend

> The .NET 8 Azure Function that powers the visitor counter — a single HTTP endpoint that reads, increments, and writes a Cosmos DB document.

**Source:** [`backend/api/`](https://github.com/rmcveyhsawaknow/azure-resume-iac/tree/main/backend/api) · [`backend/tests/`](https://github.com/rmcveyhsawaknow/azure-resume-iac/tree/main/backend/tests)

---

## Table of Contents

- [Overview](#overview)
- [Project Layout](#project-layout)
- [The GetResumeCounter Function](#the-getresumecounter-function)
- [Data Model](#data-model)
- [Cosmos DB Schema](#cosmos-db-schema)
- [Dependencies](#dependencies)
- [Running Locally](#running-locally)
- [See also](#see-also)

---

## Overview

The backend is a single Azure Function App running on **.NET 8 (LTS)** with the **isolated worker model** (Azure Functions v4). It exposes one HTTP-triggered function — `GetResumeCounter` — that serves the visitor counter consumed by the frontend.

The function is intentionally configured with `AuthorizationLevel.Anonymous` so the public frontend can call it without a function key.

## Project Layout

```
backend/
├── api/
│   ├── api.csproj              # .NET 8, Functions v4 isolated worker
│   ├── Program.cs              # Host builder — dependency injection for App Insights
│   ├── GetResumeCounter.cs     # HTTP trigger: reads/increments/writes counter
│   ├── Counter.cs              # Data model (Id, Count)
│   ├── CosmosConstants.cs      # Database, container, and document ID constants
│   ├── host.json               # Functions host config (extension bundle v4)
│   ├── local.settings.json     # Local config (git-ignored)
│   └── local.settings.example.json  # Template for local dev
└── tests/
    ├── tests.csproj            # xUnit v3 test project
    └── TestCounter.cs          # 8 unit tests with Moq
```

## The GetResumeCounter Function

`GetResumeCounter` accepts both **GET** and **POST** requests. On each call it:

1. Reads the current counter document from Cosmos DB (via `CosmosDBInput` binding)
2. Increments the `Count` property
3. Writes the updated document back (via `CosmosDBOutput` binding)
4. Returns the updated counter as JSON

It uses the **MultiResponse** pattern — the function returns an object containing both the HTTP response and the Cosmos DB output binding, so the framework handles both in a single invocation.

```csharp
[Function("GetResumeCounter")]
public MultiResponse Run(
    [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post")] HttpRequestData req,
    [CosmosDBInput(...)] Counter counter)
{
    counter.Count += 1;
    return new MultiResponse { Document = counter, HttpResponse = ... };
}
```

## Data Model

The `Counter` class maps directly to the Cosmos DB document:

```csharp
public class Counter
{
    [JsonPropertyName("id")]
    public string Id { get; set; }

    [JsonPropertyName("count")]
    public int Count { get; set; }
}
```

Property names serialize as lowercase (`id`, `count`) to match the JSON schema and what the frontend expects.

## Cosmos DB Schema

| Setting | Value |
|---|---|
| **Database** | `azure-resume-click-count` |
| **Container** | `Counter` |
| **Partition Key** | `/id` |
| **Consistency** | Eventual |
| **Capacity Mode** | Serverless |

The container holds a single document:

```json
{ "id": "1", "count": 0 }
```

Constants are centralized in `CosmosConstants.cs` so they're shared between the function, tests, and seed scripts.

## Dependencies

Key NuGet packages in `api.csproj`:

| Package | Purpose |
|---|---|
| `Microsoft.Azure.Functions.Worker` | Isolated worker model runtime |
| `Microsoft.Azure.Functions.Worker.Extensions.Http` | HTTP trigger binding |
| `Microsoft.Azure.Functions.Worker.Extensions.CosmosDB` | Cosmos DB input/output bindings |
| `Microsoft.ApplicationInsights.WorkerService` | Application Insights telemetry |

## Running Locally

```bash
cd backend/api
cp local.settings.example.json local.settings.json
# Edit local.settings.json with your Cosmos DB connection string
func start
# → http://localhost:7071/api/GetResumeCounter
```

See [Getting Started](Getting-Started) for the full local development setup, including the Cosmos DB Emulator option.

---

## See also

- [Architecture](Architecture) — where the Function App fits in the overall system
- [Frontend](Frontend) — how `main.js` calls the counter API
- [Testing](Testing) — running the xUnit tests
- [Configuration](Configuration) — app settings and Key Vault references
