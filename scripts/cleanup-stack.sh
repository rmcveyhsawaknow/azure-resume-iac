#!/usr/bin/env bash
# cleanup-stack.sh — Inventory and optionally purge Azure resource groups and
#                    Cloudflare DNS records for an old/orphaned stack version.
#
# Usage:
#   bash scripts/cleanup-stack.sh --inventory          # List resources only
#   bash scripts/cleanup-stack.sh --purge              # Delete after confirmation
#   bash scripts/cleanup-stack.sh --purge --yes        # Skip confirmation prompt
#
# Required environment variables:
#   STACK_ENVIRONMENT   Stack environment to clean (e.g., dev, prod)
#   STACK_VERSION       Stack version to clean (e.g., v1)
#   STACK_LOCATION_CODE Location code prefix (e.g., cus1)
#   APP_NAME            Application name (e.g., resume)
#
# Optional environment variables (for Cloudflare DNS cleanup):
#   CF_TOKEN            Cloudflare API Bearer token
#   CF_ZONE             Cloudflare Zone ID
#   DNS_ZONE            DNS zone name (e.g., ryanmcvey.me)
#   CUSTOM_DOMAIN_PREFIX  Custom domain prefix (e.g., resumedevv1)
#
# The script discovers resource groups matching the naming convention:
#   {locationCode}-{appName}-*-{environment}-{version}-rg
#
# Exit codes:
#   0  Completed successfully
#   1  Missing required variables or error during cleanup
set -euo pipefail

# Temp file for Cloudflare API calls — cleaned up on exit
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

##############################################################################
# Argument parsing
##############################################################################
ACTION=""
AUTO_CONFIRM=false

for arg in "$@"; do
  case "$arg" in
    --inventory)
      if [ -n "$ACTION" ] && [ "$ACTION" != "inventory" ]; then
        echo "Error: Cannot specify both --inventory and --purge"
        echo "Usage: $0 --inventory | --purge [--yes]"
        exit 1
      fi
      ACTION="inventory"
      ;;
    --purge)
      if [ -n "$ACTION" ] && [ "$ACTION" != "purge" ]; then
        echo "Error: Cannot specify both --inventory and --purge"
        echo "Usage: $0 --inventory | --purge [--yes]"
        exit 1
      fi
      ACTION="purge"
      ;;
    --yes)
      AUTO_CONFIRM=true
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: $0 --inventory | --purge [--yes]"
      exit 1
      ;;
  esac
done

if [ -z "$ACTION" ]; then
  echo "Usage: $0 --inventory | --purge [--yes]"
  exit 1
fi

##############################################################################
# Validate required environment variables
##############################################################################
: "${STACK_ENVIRONMENT:?Set STACK_ENVIRONMENT (e.g., dev)}"
: "${STACK_VERSION:?Set STACK_VERSION (e.g., v1)}"
: "${STACK_LOCATION_CODE:?Set STACK_LOCATION_CODE (e.g., cus1)}"
: "${APP_NAME:?Set APP_NAME (e.g., resume)}"

RG_PATTERN="${STACK_LOCATION_CODE}-${APP_NAME}-*-${STACK_ENVIRONMENT}-${STACK_VERSION}-rg"

echo "============================================================"
echo " Stack Cleanup — ${STACK_ENVIRONMENT} ${STACK_VERSION}"
echo " Action: ${ACTION}"
echo " RG pattern: ${RG_PATTERN}"
echo "============================================================"
echo ""

##############################################################################
# Step 1 — Discover Azure resource groups
##############################################################################
echo "🔍 Discovering Azure resource groups..."

# Use az group list with a JMESPath query that matches our naming convention
# Match resource groups following the convention: {locationCode}-{appName}-*-{environment}-{version}-rg
# Uses a JMESPath query to validate the naming pattern
RESOURCE_GROUPS=$(az group list \
  --query "[?starts_with(name, '${STACK_LOCATION_CODE}-${APP_NAME}-') && ends_with(name, '-${STACK_ENVIRONMENT}-${STACK_VERSION}-rg')].{name:name, location:location, state:properties.provisioningState}" \
  --output json 2>/dev/null || echo "[]")

RG_COUNT=$(echo "$RESOURCE_GROUPS" | jq 'length')

if [ "$RG_COUNT" -eq 0 ]; then
  echo "  ℹ️  No resource groups found matching pattern."
else
  echo "  Found ${RG_COUNT} resource group(s):"
  echo "$RESOURCE_GROUPS" | jq -r '.[] | "  • \(.name) [\(.location)] — \(.state)"'
fi
echo ""

##############################################################################
# Step 2 — Inventory resources within each resource group
##############################################################################
if [ "$RG_COUNT" -gt 0 ]; then
  echo "📦 Resources within matched resource groups:"
  for rg in $(echo "$RESOURCE_GROUPS" | jq -r '.[].name'); do
    echo ""
    echo "  Resource Group: ${rg}"
    RESOURCES=$(az resource list --resource-group "$rg" \
      --query "[].{name:name, type:type, kind:kind}" \
      --output json 2>/dev/null || echo "[]")
    RES_COUNT=$(echo "$RESOURCES" | jq 'length')
    if [ "$RES_COUNT" -eq 0 ]; then
      echo "    (empty)"
    else
      echo "$RESOURCES" | jq -r '.[] | "    • \(.type) / \(.name) (\(.kind // "—"))"'
    fi
  done
  echo ""
fi

##############################################################################
# Step 3 — Discover Cloudflare DNS records (if credentials provided)
##############################################################################
CF_RECORDS="[]"
CF_COUNT=0

if [ -n "${CF_TOKEN:-}" ] && [ -n "${CF_ZONE:-}" ] && [ -n "${CUSTOM_DOMAIN_PREFIX:-}" ] && [ -n "${DNS_ZONE:-}" ]; then
  echo "🌐 Discovering Cloudflare DNS records for ${CUSTOM_DOMAIN_PREFIX}.${DNS_ZONE}..."

  SEARCH_NAME="${CUSTOM_DOMAIN_PREFIX}.${DNS_ZONE}"
  API_BASE="https://api.cloudflare.com/client/v4/zones/${CF_ZONE}/dns_records"
  AUTH_HEADER="Authorization: Bearer ${CF_TOKEN}"

  # Search for main CNAME and asverify CNAME
  HTTP_CODE=$(curl -sS -o "$TMPFILE" -w '%{http_code}' -X GET \
    "${API_BASE}?name=${SEARCH_NAME}" \
    -H "${AUTH_HEADER}" -H "Content-Type: application/json")

  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    MAIN_RECORDS=$(jq '.result' "$TMPFILE")
  else
    MAIN_RECORDS="[]"
    echo "  ⚠️  Failed to query main DNS records (HTTP ${HTTP_CODE})"
  fi

  # Also search for asverify records
  HTTP_CODE=$(curl -sS -o "$TMPFILE" -w '%{http_code}' -X GET \
    "${API_BASE}?name=asverify.${SEARCH_NAME}" \
    -H "${AUTH_HEADER}" -H "Content-Type: application/json")

  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    ASVERIFY_RECORDS=$(jq '.result' "$TMPFILE")
  else
    ASVERIFY_RECORDS="[]"
    echo "  ⚠️  Failed to query asverify DNS records (HTTP ${HTTP_CODE})"
  fi

  CF_RECORDS=$(jq -s 'add' <(echo "$MAIN_RECORDS") <(echo "$ASVERIFY_RECORDS"))
  CF_COUNT=$(echo "$CF_RECORDS" | jq 'length')

  if [ "$CF_COUNT" -eq 0 ]; then
    echo "  ℹ️  No Cloudflare DNS records found."
  else
    echo "  Found ${CF_COUNT} DNS record(s):"
    echo "$CF_RECORDS" | jq -r '.[] | "  • \(.type) \(.name) → \(.content) (proxied: \(.proxied))"'
  fi
  echo ""
else
  echo "ℹ️  Skipping Cloudflare DNS discovery (CF_TOKEN/CF_ZONE/CUSTOM_DOMAIN_PREFIX/DNS_ZONE not all set)."
  echo ""
fi

##############################################################################
# Step 4 — Summary
##############################################################################
echo "============================================================"
echo " Summary"
echo "============================================================"
echo "  Azure Resource Groups: ${RG_COUNT}"
echo "  Cloudflare DNS Records: ${CF_COUNT}"
echo ""

if [ "$ACTION" = "inventory" ]; then
  echo "✅ Inventory complete. Run with --purge to delete these resources."
  exit 0
fi

##############################################################################
# Step 5 — Purge (only if --purge was specified)
##############################################################################
TOTAL_TO_DELETE=$((RG_COUNT + CF_COUNT))

if [ "$TOTAL_TO_DELETE" -eq 0 ]; then
  echo "Nothing to purge."
  exit 0
fi

if [ "$AUTO_CONFIRM" != "true" ]; then
  echo "⚠️  This will PERMANENTLY DELETE the above resources."
  echo ""
  read -r -p "Type 'DELETE' to confirm: " CONFIRM
  if [ "$CONFIRM" != "DELETE" ]; then
    echo "Aborted."
    exit 0
  fi
fi

echo ""
echo "🗑️  Starting purge..."

# Delete Cloudflare DNS records first
if [ "$CF_COUNT" -gt 0 ]; then
  echo ""
  echo "Deleting Cloudflare DNS records..."
  for record_id in $(echo "$CF_RECORDS" | jq -r '.[].id'); do
    RECORD_NAME=$(echo "$CF_RECORDS" | jq -r --arg id "$record_id" '.[] | select(.id == $id) | .name')
    echo "  Deleting DNS record: ${RECORD_NAME} (${record_id})..."
    DEL_HTTP=$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE \
      "${API_BASE}/${record_id}" \
      -H "${AUTH_HEADER}" -H "Content-Type: application/json")
    if [ "$DEL_HTTP" -ge 200 ] && [ "$DEL_HTTP" -lt 300 ]; then
      echo "  ✅ Deleted"
    else
      echo "  ⚠️  Failed to delete (HTTP ${DEL_HTTP})"
    fi
  done
fi

# Delete Azure resource groups (async, then wait)
if [ "$RG_COUNT" -gt 0 ]; then
  echo ""
  echo "Deleting Azure resource groups (this may take several minutes)..."
  for rg in $(echo "$RESOURCE_GROUPS" | jq -r '.[].name'); do
    echo "  Deleting resource group: ${rg} (async)..."
    az group delete --name "$rg" --yes --no-wait 2>/dev/null || \
      echo "  ⚠️  Failed to initiate deletion for ${rg}"
  done

  echo ""
  echo "  Waiting for resource group deletions to complete..."
  for rg in $(echo "$RESOURCE_GROUPS" | jq -r '.[].name'); do
    echo "  Waiting on: ${rg}..."
    if az group wait --name "$rg" --deleted --timeout 600 2>/dev/null; then
      echo "  ✅ ${rg} deleted"
    else
      echo "  ⚠️  Timed out or error waiting for ${rg}"
    fi
  done
fi

echo ""
echo "============================================================"
echo "🧹 Purge complete!"
echo "============================================================"
