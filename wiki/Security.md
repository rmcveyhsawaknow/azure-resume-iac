# Security

> How this project handles secrets, credentials, and vulnerability reporting.

**Source:** [`.github/copilot-instructions.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/.github/copilot-instructions.md) · [`docs/KNOWN_ISSUES.md`](https://github.com/rmcveyhsawaknow/azure-resume-iac/blob/main/docs/KNOWN_ISSUES.md)

---

## Secret Handling

### Where secrets live

| Secret | Storage | Access Method |
|---|---|---|
| Cosmos DB connection strings | Azure Key Vault | Key Vault reference in Function App settings |
| Azure SP credentials | GitHub Secrets | `Azure/login@v2` in workflows |
| Cloudflare API token | GitHub Secrets | `curl` in workflow scripts |
| Cloudflare Zone ID | GitHub Secrets | Environment variable in workflows |
| Function App keys | Azure (managed) | Retrieved at runtime by Azure |
| App Insights connection string | Generated at deploy | Injected into `config.js` by CI/CD |

### Rules

- **Never commit secrets** to source — `local.settings.json` is git-ignored, `config.js` is generated at deploy time
- **Use Key Vault references** in Bicep for sensitive Function App settings (`@Microsoft.KeyVault(SecretUri=...)`)
- **Use GitHub Secrets** for CI/CD credentials — never in workflow files
- **Prefer managed identity** (`SystemAssigned`) over stored credentials for Azure service-to-service auth
- **Pin GitHub Actions** to specific versions or commit SHAs to mitigate supply chain attacks

### Key Vault Configuration

The Function App's managed identity is granted access to Key Vault via access policies (configured in `modules/functionapp/functionapp.bicep`). This means:

- No client secrets are needed for the Function ↔ Key Vault connection
- Key rotation happens in Key Vault; the Function App automatically picks up new values
- Access is scoped to the specific Function App identity

## Infrastructure Security

| Control | Implementation |
|---|---|
| HTTPS only | `httpsOnly: true` on all web-facing resources |
| Encryption at rest | Enabled on all storage accounts |
| TLS termination | Cloudflare proxy (orange cloud) handles TLS |
| CORS | Configured in Bicep with specific allowed origins |
| Managed identity | Function App uses `SystemAssigned` identity |
| Key Vault | Standard SKU, access policies for Function App only |

## Known Security Debt

| Item | Severity | Status |
|---|---|---|
| `--sdk-auth` SP format deprecated | Medium | OIDC migration planned |
| jQuery 1.10.2 | Low | Functional; upgrade backlogged |

## Vulnerability Reporting

If you discover a security vulnerability in this project, please open an issue (for non-sensitive findings) or contact the repository owner directly for sensitive disclosures. Do not post credential values, exploit details, or reproduction steps publicly.

## CI/CD Security Practices

- All third-party GitHub Actions are pinned to commit SHAs (not mutable tags)
- `dorny/paths-filter` replaced with SHA-pinned version
- Direct `curl` calls replaced the third-party `rez0n/create-dns-record` action to reduce supply chain risk
- Environment protection rules require reviewer approval before production deploys
- Branch protection prevents force pushes and requires PR review

---

## See also

- [Configuration](Configuration) — all secrets and environment variables
- [Infrastructure](Infrastructure) — Bicep security settings (HTTPS, encryption, managed identity)
- [Troubleshooting](Troubleshooting) — credential-related errors and fixes
- [Contributing](Contributing) — how secrets should be handled in PRs
