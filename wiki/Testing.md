# Testing

> How to run the backend unit tests locally and understand what they cover.

**Source:** [`backend/tests/`](https://github.com/rmcveyhsawaknow/azure-resume-iac/tree/main/backend/tests) · [`docs/LOCAL_TESTING.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/LOCAL_TESTING.md)

---

## Overview

The project uses **xUnit v3** with **Moq** for backend unit tests. Tests live in `backend/tests/` and validate the `GetResumeCounter` Azure Function behavior without connecting to a live Cosmos DB instance.

There are **8 unit tests** covering the function response contract and counter initialization behavior.

## Running Tests

```bash
cd backend/tests
dotnet test
```

All 8 tests should pass. The Backend CI workflow (`backend-ci.yml`) runs these on every push or PR to `main`/`develop` when `backend/**` files change.

You can also use the VS Code task:

1. Open the Command Palette (`Ctrl+Shift+P`)
2. Run **Tasks: Run Task → test (backend)**

## What's Tested

`TestCounter.cs` primarily validates `GetResumeCounter` behavior:

| Test area | What it checks |
|---|---|
| Successful HTTP response | The function returns a successful response when the counter is retrieved |
| Status code | The HTTP status code matches the expected success result |
| Response headers | The response includes the expected headers for the API output |
| JSON response body | The body contains the expected counter payload, including `id` and `count` |
| Counter initialization | The function handles null or uninitialized counter data correctly |
| Mocked data access | Dependencies are mocked so the tests run fully in-memory without a live Cosmos DB instance |

Tests use Moq to isolate the function from external services while still verifying the response contract returned to the frontend.

## Test Project Structure

```
backend/tests/
├── tests.csproj        # xUnit v3, Moq, references api.csproj
└── TestCounter.cs      # All unit tests
```

The test project targets the same .NET 8 framework as the application and references the API project directly.

## CI Integration

The **Backend CI** workflow (`backend-ci.yml`) runs `dotnet test` automatically:

- **Triggers:** Push or PR to `main`/`develop` when `backend/**` files change
- **Runner:** `ubuntu-latest`
- **Steps:** Checkout → Setup .NET 8 → Build → Test

The full-stack workflows (dev and prod) also run tests as part of the `buildDeployBackend` job before deploying.

## Integration Testing

For end-to-end testing against a live Cosmos DB instance:

1. Start the function locally (`func start` in `backend/api/`)
2. Hit the endpoint: `curl http://localhost:7071/api/GetResumeCounter`
3. Verify the response is `{ "id": "1", "count": N }`

See [Getting Started](Getting-Started) for the full local setup, including Cosmos DB Emulator configuration.

---

## See also

- [Backend](Backend) — the Function App code being tested
- [Getting Started](Getting-Started) — setting up the local dev environment
- [CI-CD](CI-CD) — how tests run in the pipeline
