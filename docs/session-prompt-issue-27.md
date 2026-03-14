# Codespace Validation Session — Issue #27: Update NuGet Packages

## Setup

Set up this Codespace for validating issue #27 "[Phase 1] Update NuGet packages" and resultant PR.

- **Issue:** https://github.com/rmcveyhsawaknow/azure-resume-iac/issues/27
- **PR:** (supply PR link once created by Copilot agent)
- **Depends on:** #25 (.NET 8 runtime upgrade), #26 (Functions v3 → v4 upgrade)
- **Branch from:** `develop`

## Context

This PR updates all NuGet package references to the latest .NET 8 and Azure Functions v4 compatible versions. The key change is migrating the deprecated `xunit` v2 test library to `xunit.v3`.

### Package Summary

**API project (`backend/api/api.csproj`) — no changes needed (already at latest):**

| Package | Version | Status |
|---------|---------|--------|
| Microsoft.Azure.Functions.Worker | 2.51.0 | ✅ Latest, .NET 8 compatible |
| Microsoft.Azure.Functions.Worker.Extensions.CosmosDB | 4.14.0 | ✅ Latest, v4 CosmosDB extension |
| Microsoft.Azure.Functions.Worker.Extensions.Http | 3.3.0 | ✅ Latest |
| Microsoft.Azure.Functions.Worker.Sdk | 2.0.7 | ✅ Latest |

**Test project (`backend/tests/tests.csproj`) — xunit v2 → xunit.v3:**

| Package | Before | After | Notes |
|---------|--------|-------|-------|
| xunit | 2.9.3 | _(removed)_ | Deprecated by NuGet |
| xunit.v3 | _(new)_ | 3.2.2 | Replacement for deprecated xunit |
| xunit.runner.visualstudio | 3.1.5 | 3.1.5 | No change (already v3 compatible) |
| Microsoft.NET.Test.Sdk | 18.3.0 | 18.3.0 | No change (already latest) |
| Moq | 4.20.72 | 4.20.72 | No change (already latest) |
| coverlet.collector | 8.0.0 | 8.0.0 | No change (already latest) |

## Validation Steps

1. **Checkout the PR branch:**
   ```bash
   gh pr checkout <PR_NUMBER>
   ```

2. **Verify `dotnet restore` succeeds without warnings:**
   ```bash
   dotnet restore backend/api/api.csproj
   dotnet restore backend/tests/tests.csproj
   ```

3. **Verify `dotnet build` succeeds for both projects:**
   ```bash
   dotnet build backend/api/api.csproj
   dotnet build backend/tests/tests.csproj
   ```

4. **Verify all tests pass:**
   ```bash
   dotnet test backend/tests/tests.csproj --verbosity normal
   ```

5. **Verify no deprecated packages remain:**
   ```bash
   dotnet list backend/api/api.csproj package --deprecated
   dotnet list backend/tests/tests.csproj package --deprecated
   ```
   Both should report "no deprecated packages."

6. **Verify no vulnerable packages remain:**
   ```bash
   dotnet list backend/api/api.csproj package --vulnerable
   dotnet list backend/tests/tests.csproj package --vulnerable
   ```
   Both should report "no vulnerable packages."

7. **Verify no outdated packages remain:**
   ```bash
   dotnet list backend/api/api.csproj package --outdated
   dotnet list backend/tests/tests.csproj package --outdated
   ```
   Both should report "no updates given the current sources."

8. **Verify xunit.v3 test discovery works correctly:**
   ```bash
   dotnet test backend/tests/tests.csproj --list-tests
   ```
   Should list `tests.TestCounter.Http_trigger_should_increment_counter`.

9. **Review the `.csproj` files for correctness:**
   ```bash
   cat backend/api/api.csproj
   cat backend/tests/tests.csproj
   ```
   - `api.csproj` should target `net8.0` with `AzureFunctionsVersion` v4
   - `tests.csproj` should reference `xunit.v3` (not `xunit`)

## Expected Results

- All restore/build/test commands succeed with zero warnings and zero errors
- No deprecated, vulnerable, or outdated packages
- The single existing test (`Http_trigger_should_increment_counter`) passes
- xunit.v3 3.2.2 is the test framework (replacing deprecated xunit 2.9.3)

## Rollback

If issues are found, revert the test project change:
```bash
cd backend/tests
dotnet remove tests.csproj package xunit.v3
dotnet add tests.csproj package xunit --version 2.9.3
dotnet test tests.csproj
```
