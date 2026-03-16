#!/usr/bin/env bash
# seed-cosmos-db.sh — Check-before-seed a Cosmos DB visitor counter document.
#
# Seeds the Cosmos DB with the initial visitor counter document if it doesn't
# already exist. If the document exists, validates its structure. Uses the
# Cosmos DB REST API with the account master key for data-plane operations.
#
# Required environment variables:
#   COSMOS_ACCOUNT_NAME    Cosmos DB account name
#   COSMOS_RESOURCE_GROUP  Resource group containing the Cosmos DB account
#
# Optional environment variables (with defaults matching the application):
#   COSMOS_DATABASE_NAME   Database name       (default: azure-resume-click-count)
#   COSMOS_CONTAINER_NAME  Container name       (default: Counter)
#   COSMOS_DOCUMENT_ID     Document ID          (default: 1)
#   COSMOS_INITIAL_COUNT   Initial counter value (default: 0)
#
# Prerequisites:
#   - Azure CLI authenticated (az login)
#   - python3 available on PATH (used for auth-token generation)
#   - Contributor or Cosmos DB Account Contributor role on the account
#
# Exit codes:
#   0  Document already exists with valid structure, or was created successfully
#   1  Error (missing prereqs, API error, validation failure)
set -euo pipefail

##############################################################################
# Defaults — match CosmosConstants.cs in the backend application
##############################################################################
DATABASE_NAME="${COSMOS_DATABASE_NAME:-azure-resume-click-count}"
CONTAINER_NAME="${COSMOS_CONTAINER_NAME:-Counter}"
DOCUMENT_ID="${COSMOS_DOCUMENT_ID:-1}"
INITIAL_COUNT="${COSMOS_INITIAL_COUNT:-0}"

##############################################################################
# Validate required inputs
##############################################################################
if [ -z "${COSMOS_ACCOUNT_NAME:-}" ]; then
  echo "::error::COSMOS_ACCOUNT_NAME is required"
  exit 1
fi
if [ -z "${COSMOS_RESOURCE_GROUP:-}" ]; then
  echo "::error::COSMOS_RESOURCE_GROUP is required"
  exit 1
fi

TMPDIR_COSMOS=$(mktemp -d)
trap 'rm -rf -- "$TMPDIR_COSMOS"' EXIT

echo "=== Cosmos DB Seed ==="
echo "  Account:   ${COSMOS_ACCOUNT_NAME}"
echo "  RG:        ${COSMOS_RESOURCE_GROUP}"
echo "  Database:  ${DATABASE_NAME}"
echo "  Container: ${CONTAINER_NAME}"
echo "  Doc ID:    ${DOCUMENT_ID}"

##############################################################################
# Step 1 — Verify the Cosmos DB account exists
##############################################################################
echo ""
echo "Step 1: Verifying Cosmos DB account..."
if ! az cosmosdb show \
      --name "${COSMOS_ACCOUNT_NAME}" \
      --resource-group "${COSMOS_RESOURCE_GROUP}" \
      --query "name" -o tsv > /dev/null 2>&1; then
  echo "::error::Cosmos DB account '${COSMOS_ACCOUNT_NAME}' not found in resource group '${COSMOS_RESOURCE_GROUP}'"
  exit 1
fi
echo "  ✅ Account verified"

##############################################################################
# Step 2 — Retrieve the primary master key
##############################################################################
echo ""
echo "Step 2: Retrieving account key..."
MASTER_KEY=$(az cosmosdb keys list \
  --name "${COSMOS_ACCOUNT_NAME}" \
  --resource-group "${COSMOS_RESOURCE_GROUP}" \
  --type keys \
  --query "primaryMasterKey" -o tsv)

if [ -z "${MASTER_KEY}" ]; then
  echo "::error::Failed to retrieve Cosmos DB master key"
  exit 1
fi
echo "  ✅ Key retrieved"

##############################################################################
# Helper — Generate Cosmos DB REST API authorization token
#
# Uses python3 (stdlib only) to compute the HMAC-SHA256 signature required
# by the Cosmos DB data-plane REST API.
##############################################################################
generate_cosmos_auth_token() {
  local verb="$1"
  local resource_type="$2"
  local resource_link="$3"
  local date_str="$4"
  local key="$5"

  python3 - "$verb" "$resource_type" "$resource_link" "$date_str" "$key" <<'PYEOF'
import hmac, hashlib, base64, urllib.parse, sys

verb, resource_type, resource_link, date_str, key_b64 = sys.argv[1:6]
key   = base64.b64decode(key_b64)
text  = (verb.lower() + '\n' + resource_type.lower() + '\n' +
         resource_link + '\n' + date_str.lower() + '\n\n')
body  = text.encode('utf-8')
digest = hmac.new(key, body, hashlib.sha256).digest()
sig    = base64.b64encode(digest).decode('utf-8')
token  = urllib.parse.quote('type=master&ver=1.0&sig=' + sig)
print(token)
PYEOF
}

COSMOS_ENDPOINT="https://${COSMOS_ACCOUNT_NAME}.documents.azure.com"
API_VERSION="2018-12-31"

##############################################################################
# Step 3 — Try to read the existing document
##############################################################################
echo ""
echo "Step 3: Checking for existing document (id=${DOCUMENT_ID})..."

RESOURCE_LINK="dbs/${DATABASE_NAME}/colls/${CONTAINER_NAME}/docs/${DOCUMENT_ID}"
DATE_STR=$(TZ=GMT date '+%a, %d %b %Y %H:%M:%S GMT')
AUTH_TOKEN=$(generate_cosmos_auth_token "GET" "docs" "${RESOURCE_LINK}" "${DATE_STR}" "${MASTER_KEY}")

GET_HTTP=$(curl -sS -o "${TMPDIR_COSMOS}/get.json" -w '%{http_code}' \
  -X GET "${COSMOS_ENDPOINT}/${RESOURCE_LINK}" \
  -H "Authorization: ${AUTH_TOKEN}" \
  -H "x-ms-date: ${DATE_STR}" \
  -H "x-ms-version: ${API_VERSION}" \
  -H "x-ms-documentdb-partitionkey: [\"${DOCUMENT_ID}\"]" \
  -H "Content-Type: application/json")

##############################################################################
# Step 4 — Decide: validate existing / create new / fail
##############################################################################
if [ "$GET_HTTP" -eq 200 ]; then
  echo "  Document found — validating structure..."

  DOC_ID=$(jq -r '.id // empty' "${TMPDIR_COSMOS}/get.json")
  DOC_COUNT=$(jq -r '.count // empty' "${TMPDIR_COSMOS}/get.json")

  VALID=true
  if [ -z "$DOC_ID" ] || [ "$DOC_ID" != "${DOCUMENT_ID}" ]; then
    echo "::warning::Document 'id' field mismatch: expected '${DOCUMENT_ID}', got '${DOC_ID:-<missing>}'"
    VALID=false
  fi

  if [ -z "$DOC_COUNT" ]; then
    echo "::warning::Document 'count' field is missing"
    VALID=false
  elif ! [[ "$DOC_COUNT" =~ ^[0-9]+$ ]]; then
    echo "::warning::Document 'count' field is not a valid non-negative integer: '${DOC_COUNT}'"
    VALID=false
  fi

  if [ "$VALID" = true ]; then
    echo "  ✅ Document already exists with valid structure (id=${DOC_ID}, count=${DOC_COUNT})"
    exit 0
  else
    echo "::error::Document exists but has invalid structure. Manual intervention required."
    echo "  Document content:"
    jq . "${TMPDIR_COSMOS}/get.json"
    exit 1
  fi

elif [ "$GET_HTTP" -eq 404 ]; then
  echo "  Document not found — will create seed document"

else
  echo "::error::Unexpected HTTP ${GET_HTTP} when reading document:"
  cat "${TMPDIR_COSMOS}/get.json"
  exit 1
fi

##############################################################################
# Step 5 — Create the seed document
##############################################################################
echo ""
echo "Step 5: Creating seed document (id=${DOCUMENT_ID}, count=${INITIAL_COUNT})..."

RESOURCE_LINK_CREATE="dbs/${DATABASE_NAME}/colls/${CONTAINER_NAME}"
DATE_STR=$(TZ=GMT date '+%a, %d %b %Y %H:%M:%S GMT')
AUTH_TOKEN=$(generate_cosmos_auth_token "POST" "docs" "${RESOURCE_LINK_CREATE}" "${DATE_STR}" "${MASTER_KEY}")

PAYLOAD=$(jq -n \
  --arg id "${DOCUMENT_ID}" \
  --argjson count "${INITIAL_COUNT}" \
  '{id: $id, count: $count}')

POST_HTTP=$(curl -sS -o "${TMPDIR_COSMOS}/post.json" -w '%{http_code}' \
  -X POST "${COSMOS_ENDPOINT}/${RESOURCE_LINK_CREATE}/docs" \
  -H "Authorization: ${AUTH_TOKEN}" \
  -H "x-ms-date: ${DATE_STR}" \
  -H "x-ms-version: ${API_VERSION}" \
  -H "x-ms-documentdb-partitionkey: [\"${DOCUMENT_ID}\"]" \
  -H "Content-Type: application/json" \
  --data "${PAYLOAD}")

if [ "$POST_HTTP" -eq 201 ]; then
  echo "  ✅ Seed document created successfully"
  echo "  Document:"
  jq '{id, count}' "${TMPDIR_COSMOS}/post.json"
  exit 0
elif [ "$POST_HTTP" -eq 409 ]; then
  # Race condition: document was created between our GET and POST
  echo "  ✅ Document already exists (created by concurrent process)"
  exit 0
else
  echo "::error::Failed to create seed document (HTTP ${POST_HTTP}):"
  cat "${TMPDIR_COSMOS}/post.json"
  exit 1
fi
