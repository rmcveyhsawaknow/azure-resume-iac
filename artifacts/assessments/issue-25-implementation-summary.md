# Issue #25 — Implementation Summary: Upgrade .NET Core 3.1 → .NET 8 (Isolated Worker)

**Branch:** `copilot/phase-1-upgrade-net-runtime`
**Depends on:** #24 (root cause diagnosed and closed)
**Status:** Code complete — builds pass, tests pass

---

## Changes Summary (9 files, +97 / -76)

### `backend/api/api.csproj`
- `TargetFramework`: `netcoreapp3.1` → `net8.0`
- `AzureFunctionsVersion`: `v3` → `v4`
- Added `<OutputType>Exe</OutputType>` (required for isolated worker)
- Removed: `Microsoft.NET.Sdk.Functions` 3.0.13, `Microsoft.Azure.WebJobs.Extensions.CosmosDB` 3.0.10
- Added: `Microsoft.Azure.Functions.Worker` 2.51.0, `Microsoft.Azure.Functions.Worker.Sdk` 2.0.7, `Microsoft.Azure.Functions.Worker.Extensions.Http` 3.3.0, `Microsoft.Azure.Functions.Worker.Extensions.CosmosDB` 4.14.0

### `backend/api/Program.cs` (new)
- Added isolated worker `HostBuilder` bootstrap using `ConfigureFunctionsWorkerDefaults()`

### `backend/api/GetResumeCounter.cs`
- Migrated from WebJobs in-process model to isolated worker model
- `[FunctionName]` → `[Function]`
- `HttpRequest` → `HttpRequestData`
- `ILogger` parameter → constructor-injected `ILogger<GetResumeCounter>`
- Cosmos bindings: `[CosmosDB(...)]` → `[CosmosDBInput(...)]` / `[CosmosDBOutput(...)]`
- Introduced `MultiResponse` class for multiple output bindings (HTTP response + Cosmos write)
- Replaced `Newtonsoft.Json` serialization with `System.Text.Json`

### `backend/api/Counter.cs`
- Migrated from `Newtonsoft.Json` `[JsonProperty]` to `System.Text.Json` `[JsonPropertyName]`
- Removed unused `using` statements

### `backend/api/CosmosConstants.cs`
- Removed unused `using` statements (no functional change)

### `backend/api/host.json`
- Added `extensionBundle` with version range `[4.*, 5.0.0)` for Functions v4 isolated worker

### `backend/tests/tests.csproj`
- `TargetFramework`: `netcoreapp3.1` → `net8.0`
- xUnit: 2.4.0 → 2.9.3, xunit.runner.visualstudio → 3.1.5
- Test SDK: 16.5.0 → 18.3.0
- Removed: `Microsoft.AspNetCore.Mvc` 2.2.0
- Added: `Moq` 4.20.72, `coverlet.collector` 8.0.0

### `backend/tests/TestCounter.cs`
- Rewrote test to mock isolated worker types (`FunctionContext`, `HttpRequestData`, `HttpResponseData`)
- Uses `Moq` to create mock request/response pipeline
- Constructor-injects mocked `ILogger<GetResumeCounter>`
- Validates counter increment via `MultiResponse.UpdatedCounter`

### `backend/tests/TestFactory.cs`
- Removed `CreateHttpRequest()` (depended on `Microsoft.AspNetCore.Http.Internal` — not applicable to isolated model)
- Retained `CreateLogger()` utility

---

## Verification Results

| Check | Result |
|-------|--------|
| `dotnet build api.csproj` | ✅ Build succeeded |
| `dotnet build tests.csproj` | ✅ Build succeeded |
| `dotnet test tests.csproj` | ✅ 1 passed, 0 failed |

---

## Acceptance Criteria Status

- [x] `.csproj` updated to target `net8.0`
- [x] All breaking API changes resolved
- [x] Code compiles without errors on .NET 8
- [x] Isolated worker model adopted
- [x] Local build succeeds with `dotnet build`

---

## Notes

- The Codespace has .NET 10 SDK installed, which builds `net8.0` targets via multi-targeting support. The CI runner should use `setup-dotnet@v4` with `dotnet-version: '8.0.x'`.
- `ListLogger.cs`, `LoggerTypes.cs`, and `NullScope.cs` are still in the test project but no longer referenced by tests. They can be cleaned up in a future PR.
- Infrastructure changes (`FUNCTIONS_EXTENSION_VERSION ~3→~4`, `FUNCTIONS_WORKER_RUNTIME dotnet→dotnet-isolated`) are tracked in separate Phase 1 issues.
