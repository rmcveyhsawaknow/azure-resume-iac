# Issue Validation: Update Test Project (.NET 8)

**Issue:** [Phase 1] Update test project  
**Date:** 2026-03-14  
**Status:** Complete

## Validation Checklist for Technologist

Use this checklist to verify that the test project update meets all acceptance criteria.

### 1. Target Framework Verification

```bash
# Verify test project targets net8.0
grep '<TargetFramework>' backend/tests/tests.csproj
# Expected: <TargetFramework>net8.0</TargetFramework>
```

### 2. NuGet Package Versions

```bash
# List all package references in the test project
grep 'PackageReference' backend/tests/tests.csproj
```

| Package | Expected Version | Purpose |
|---|---|---|
| `coverlet.collector` | 8.0.0 | Code coverage collection |
| `Microsoft.NET.Test.Sdk` | 18.3.0 | Test SDK for .NET |
| `Moq` | 4.20.72 | Mocking framework |
| `xunit.runner.visualstudio` | 3.1.5 | xUnit test discovery |
| `xunit.v3` | 3.2.2 | xUnit v3 test framework |

### 3. Build Verification

```bash
# Build the API project (dependency)
cd backend/api && dotnet build

# Build the test project
cd backend/tests && dotnet build
```

**Expected:** Both projects build with 0 errors, 0 warnings.

### 4. Test Execution

```bash
cd backend/tests && dotnet test --verbosity normal
```

**Expected:** All 8 tests pass:

| Test Name | Validates |
|---|---|
| `Http_trigger_should_increment_counter` | Counter increments from 2 → 3 |
| `Http_trigger_should_increment_counter_from_zero` | Counter increments from 0 → 1 |
| `Http_trigger_should_return_ok_status` | HTTP 200 OK response |
| `Http_trigger_should_return_json_content_type` | Content-Type header is `application/json; charset=utf-8` |
| `Http_trigger_should_return_updated_counter_as_json` | Response body contains serialized counter JSON |
| `Http_trigger_updated_counter_should_reference_same_object` | UpdatedCounter is same object (for CosmosDB output binding) |
| `Counter_model_should_serialize_with_lowercase_properties` | JSON uses `id`/`count` (not `Id`/`Count`) |
| `Counter_model_should_round_trip_serialize` | Counter survives JSON serialization round-trip |

### 5. Cleanup Verification

Confirm that unused legacy test helpers from the pre-.NET 8 in-process model have been removed:

```bash
# These files should NOT exist
ls backend/tests/ListLogger.cs 2>&1    # Should fail (file not found)
ls backend/tests/NullScope.cs 2>&1     # Should fail (file not found)
ls backend/tests/TestFactory.cs 2>&1   # Should fail (file not found)
ls backend/tests/LoggerTypes.cs 2>&1   # Should fail (file not found)
```

### 6. Project Reference Integrity

```bash
# Verify test project references the API project
grep 'ProjectReference' backend/tests/tests.csproj
# Expected: <ProjectReference Include="..\api\api.csproj" />
```

## Summary of Changes

1. **Test project `.csproj`** — Already targeting `net8.0` with latest packages (no changes needed)
2. **New tests added** — 7 additional unit tests covering HTTP response status, content type, JSON serialization, model round-trip, and counter edge cases
3. **Legacy helpers removed** — `ListLogger.cs`, `NullScope.cs`, `TestFactory.cs`, `LoggerTypes.cs` (unused dead code from pre-.NET 8 in-process model)
4. **Test refactored** — Shared test setup extracted into constructor and helper method for cleaner test code

## Sign-off

- [ ] Technologist has verified all validation steps above
- [ ] `dotnet test` succeeds with 8/8 tests passing
- [ ] No regressions introduced
