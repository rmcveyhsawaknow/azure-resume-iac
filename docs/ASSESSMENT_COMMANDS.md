# Assessment Commands Reference

This document provides Azure CLI and Cloudflare CLI/API commands to harvest the current state of deployed resources. Run these commands from a GitHub Codespace or local terminal with authenticated Azure CLI and Cloudflare API access.

## Prerequisites

```bash
# Azure CLI login
az login
az account set --subscription "<subscription-name-or-id>"

# Verify correct subscription
az account show --query '{name:name, id:id, tenantId:tenantId}' -o table

# Cloudflare (using curl with API token)
export CF_API_TOKEN="<your-cloudflare-api-token>"
```

## Azure Resource Group Assessment

### List All Resource Groups

```bash
# List all resource groups with tags
az group list --query "[].{Name:name, Location:location, State:properties.provisioningState}" -o table

# Filter to resume-related resource groups
az group list --query "[?contains(name, 'resume') || contains(name, 'ryanmcvey')].{Name:name, Location:location, Tags:tags}" -o table
```

### Resource Group Details

```bash
# Backend resource group
az resource list --resource-group cus1-resume-be-prod-v1-rg \
  --query "[].{Name:name, Type:type, Location:location}" -o table

# Frontend resource group
az resource list --resource-group cus1-resume-fe-prod-v1-rg \
  --query "[].{Name:name, Type:type, Location:location}" -o table

# DNS resource group
az resource list --resource-group glbl-ryanmcveyme-v1-rg \
  --query "[].{Name:name, Type:type, Location:location}" -o table
```

## Function App Assessment

### Function App Status and Configuration

```bash
# Function App state and runtime
az functionapp show --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query '{State:state, DefaultHostName:defaultHostName, HttpsOnly:httpsOnly, Kind:kind, LinuxFxVersion:siteConfig.linuxFxVersion}' -o json

# Function App configuration
az functionapp config show --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg -o json

# App settings (shows runtime version, extension version, etc.)
az functionapp config appsettings list --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query "[].{Name:name, Value:value}" -o table

# CORS settings
az functionapp cors show --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg

# Function list and status
az functionapp function list --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg -o table

# Get function keys (for verifying main.js URL)
az functionapp function keys list --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg \
  --function-name GetResumeCounter -o json

# Test the function directly
curl -v "https://cus1-resumectr-prod-v1-fa.azurewebsites.net/api/GetResumeCounter?code=<function-key>"
```

### App Service Plan

```bash
az appservice plan show --name cus1-resumectr-prod-v1-asp \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query '{Name:name, SKU:sku.name, Tier:sku.tier, Kind:kind, Status:status}' -o json
```

## Cosmos DB Assessment

```bash
# Account details
az cosmosdb show --name cus1-resume-prod-v1-cmsdb \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query '{Name:name, Kind:kind, Capabilities:capabilities[].name, ConsistencyPolicy:consistencyPolicy.defaultConsistencyLevel, DocumentEndpoint:documentEndpoint}' -o json

# List databases
az cosmosdb sql database list --account-name cus1-resume-prod-v1-cmsdb \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query "[].{Name:name, Id:id}" -o table

# List containers
az cosmosdb sql container list --account-name cus1-resume-prod-v1-cmsdb \
  --resource-group cus1-resume-be-prod-v1-rg \
  --database-name azure-resume-click-count \
  --query "[].{Name:name, PartitionKey:resource.partitionKey.paths[0]}" -o table

# Check connection keys (to verify Key Vault values)
az cosmosdb keys list --name cus1-resume-prod-v1-cmsdb \
  --resource-group cus1-resume-be-prod-v1-rg \
  --type connection-strings \
  --query "connectionStrings[0].connectionString" -o tsv
```

## Key Vault Assessment

```bash
# Key Vault overview
az keyvault show --name cus1-resume-prod-v1-kv \
  --query '{Name:name, VaultUri:properties.vaultUri, SKU:properties.sku.name, SoftDelete:properties.enableSoftDelete, PurgeProtection:properties.enablePurgeProtection}' -o json

# List secrets (names only)
az keyvault secret list --vault-name cus1-resume-prod-v1-kv \
  --query "[].{Name:name, Enabled:attributes.enabled, Expires:attributes.expires}" -o table

# Show specific secret values
az keyvault secret show --vault-name cus1-resume-prod-v1-kv \
  --name AzureResumeConnectionStringPrimary --query value -o tsv

az keyvault secret show --vault-name cus1-resume-prod-v1-kv \
  --name AzureResumeConnectionStringSecondary --query value -o tsv

# Access policies
az keyvault show --name cus1-resume-prod-v1-kv \
  --query 'properties.accessPolicies[].{ObjectId:objectId, Permissions:permissions}' -o json
```

## Storage Account Assessment (Frontend)

```bash
# Storage account
az storage account show --name cus1resumeprodv1sa \
  --resource-group cus1-resume-fe-prod-v1-rg \
  --query '{Name:name, PrimaryEndpoint:primaryEndpoints.web, CustomDomain:customDomain.name, HttpsOnly:enableHttpsTrafficOnly}' -o json

# Static website settings
az storage blob service-properties show --account-name cus1resumeprodv1sa \
  --auth-mode login \
  --query staticWebsite -o json

# List files in $web container
az storage blob list --account-name cus1resumeprodv1sa \
  --container-name '$web' --auth-mode login \
  --query "[].{Name:name, Size:properties.contentLength, Modified:properties.lastModified}" -o table
```

## Application Insights Assessment

```bash
# Backend App Insights
az monitor app-insights component show --app cus1-resumectr-prod-v1-ai \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query '{Name:name, InstrumentationKey:instrumentationKey, ConnectionString:connectionString, AppId:appId}' -o json

# Frontend App Insights
az monitor app-insights component show --app cus1-resume-prod-v1-ai \
  --resource-group cus1-resume-fe-prod-v1-rg \
  --query '{Name:name, InstrumentationKey:instrumentationKey, ConnectionString:connectionString, AppId:appId}' -o json

# Recent exceptions/failures (backend)
az monitor app-insights events show --app cus1-resumectr-prod-v1-ai \
  --resource-group cus1-resume-be-prod-v1-rg \
  --type exceptions --offset 7d
```

## Azure Service Principal Assessment

```bash
# List role assignments for the SP (need the SP's object ID or app ID)
# First, find the SP:
az ad sp list --display-name "github-azure-resume" --query "[].{AppId:appId, ObjectId:id, DisplayName:displayName}" -o table

# Then check its role assignments:
az role assignment list --assignee <appId-or-objectId> \
  --query "[].{Role:roleDefinitionName, Scope:scope}" -o table

# Check credential expiry:
az ad app credential list --id <appId> --query "[].{KeyId:keyId, EndDate:endDateTime}" -o table
```

## Cloudflare Assessment

### Using curl with API Token

```bash
# Verify token
curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq .

# List zones
curl -s -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq '.result[] | {id, name, status}'

# DNS records for ryanmcvey.me (replace ZONE_ID)
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq '.result[] | {type, name, content, proxied, ttl}'

# SSL/TLS settings
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/settings/ssl" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq .result

# Caching settings
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/settings/browser_cache_ttl" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq .result
```

### Using Cloudflare CLI (flarectl) — Optional

```bash
# Install flarectl
go install github.com/cloudflare/cloudflare-go/cmd/flarectl@latest

# Or use npm wrangler
npm install -g wrangler
wrangler login

# List zones
wrangler zones list
```

## Comprehensive Assessment Script

Save this as a script to run in a Codespace session to capture full state:

```bash
#!/bin/bash
# assessment-capture.sh
# Run from a GitHub Codespace with authenticated Azure CLI

OUTPUT_DIR="./assessment-output"
mkdir -p "$OUTPUT_DIR"

echo "=== Azure Resource Groups ==="
az group list --query "[?contains(name, 'resume') || contains(name, 'ryanmcvey')]" -o json > "$OUTPUT_DIR/resource-groups.json"

echo "=== Backend Resources ==="
az resource list --resource-group cus1-resume-be-prod-v1-rg -o json > "$OUTPUT_DIR/backend-resources.json"

echo "=== Frontend Resources ==="
az resource list --resource-group cus1-resume-fe-prod-v1-rg -o json > "$OUTPUT_DIR/frontend-resources.json"

echo "=== Function App ==="
az functionapp show --name cus1-resumectr-prod-v1-fa --resource-group cus1-resume-be-prod-v1-rg -o json > "$OUTPUT_DIR/functionapp.json"
az functionapp config appsettings list --name cus1-resumectr-prod-v1-fa --resource-group cus1-resume-be-prod-v1-rg -o json > "$OUTPUT_DIR/functionapp-settings.json"
az functionapp cors show --name cus1-resumectr-prod-v1-fa --resource-group cus1-resume-be-prod-v1-rg -o json > "$OUTPUT_DIR/functionapp-cors.json"

echo "=== Cosmos DB ==="
az cosmosdb show --name cus1-resume-prod-v1-cmsdb --resource-group cus1-resume-be-prod-v1-rg -o json > "$OUTPUT_DIR/cosmosdb.json"

echo "=== Key Vault ==="
az keyvault show --name cus1-resume-prod-v1-kv -o json > "$OUTPUT_DIR/keyvault.json"
az keyvault secret list --vault-name cus1-resume-prod-v1-kv -o json > "$OUTPUT_DIR/keyvault-secrets.json"

echo "=== Storage Accounts ==="
az storage account show --name cus1resumeprodv1sa --resource-group cus1-resume-fe-prod-v1-rg -o json > "$OUTPUT_DIR/storage-fe.json"

echo "=== App Insights ==="
az monitor app-insights component show --app cus1-resumectr-prod-v1-ai --resource-group cus1-resume-be-prod-v1-rg -o json > "$OUTPUT_DIR/appinsights-backend.json"
az monitor app-insights component show --app cus1-resume-prod-v1-ai --resource-group cus1-resume-fe-prod-v1-rg -o json > "$OUTPUT_DIR/appinsights-frontend.json"

echo "=== Assessment complete. Output in $OUTPUT_DIR ==="
ls -la "$OUTPUT_DIR"
```

## Quick Health Check

Run this to get a fast status overview:

```bash
echo "=== Function App State ==="
az functionapp show --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query '{State:state, LinuxFxVersion:siteConfig.linuxFxVersion}' -o json

echo "=== Function App Runtime Settings ==="
az functionapp config appsettings list --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query "[?name=='FUNCTIONS_EXTENSION_VERSION' || name=='FUNCTIONS_WORKER_RUNTIME'].{Name:name, Value:value}" -o table

echo "=== Function App Functions ==="
az functionapp function list --name cus1-resumectr-prod-v1-fa \
  --resource-group cus1-resume-be-prod-v1-rg -o table

echo "=== Cosmos DB Status ==="
az cosmosdb show --name cus1-resume-prod-v1-cmsdb \
  --resource-group cus1-resume-be-prod-v1-rg \
  --query '{Name:name, DocumentEndpoint:documentEndpoint}' -o json

echo "=== Storage Account Custom Domains ==="
az storage account show --name cus1resumeprodv1sa --resource-group cus1-resume-fe-prod-v1-rg --query '{CustomDomain:customDomain.name}' -o json

echo "=== Test Function Endpoint ==="
curl -s -o /dev/null -w "%{http_code}" "https://cus1-resumectr-prod-v1-fa.azurewebsites.net/api/GetResumeCounter"
echo ""
```
