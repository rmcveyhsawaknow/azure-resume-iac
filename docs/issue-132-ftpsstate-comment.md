# FtpsState Finding from Root Cause Diagnosis (#24)

**Source:** Root cause diagnosis (issue #24, PR #155) — live Azure CLI diagnostics run 2026-03-13

## Diagnosis Confirmation

Live diagnostics confirmed the security finding from Phase 0 gap analysis:

```
az functionapp config show → FtpsState: "AllAllowed"
```

FTP/FTPS is fully enabled on the production Function App. Since all deployments use GitHub Actions zip deploy, FTP access is unnecessary and should be disabled.

### Recommended Fix

Add `ftpsState: 'Disabled'` to the `siteConfig` block in `.iac/modules/functionapp/functionapp.bicep`:

```bicep
resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  // ...
  properties: {
    siteConfig: {
      ftpsState: 'Disabled'    // <-- add this
      cors: { ... }
    }
  }
}
```

### Suggestion: Bundle with Issue #26

This is a small Bicep change that can be included in the same PR as #26 (Upgrade Functions version v3 → v4) to minimize deployment churn. Both changes modify the same Bicep file (`.iac/modules/functionapp/functionapp.bicep`).

### Related Issues

- #24 — Root cause diagnosis (confirmed this finding)
- #26 — Upgrade Functions version (v3 → v4) — same Bicep file, bundle opportunity
