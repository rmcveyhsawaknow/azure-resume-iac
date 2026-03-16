#!/usr/bin/env bash
# cloudflare-dns-record.sh — Check-before-create a Cloudflare DNS record.
#
# Required environment variables:
#   CF_TOKEN         Cloudflare API Bearer token
#   CF_ZONE          Cloudflare Zone ID
#   RECORD_TYPE      DNS record type (e.g., CNAME)
#   RECORD_NAME      Fully-qualified record name (e.g., resume.ryanmcvey.me)
#   RECORD_CONTENT   Target value for the record
#   RECORD_PROXIED   "true" or "false" — whether to proxy through Cloudflare
#
# Exit codes:
#   0  Record already exists with correct content, or was created successfully
#   1  API error, HTTP error, or record exists with different content
set -euo pipefail

API_BASE="https://api.cloudflare.com/client/v4/zones/${CF_ZONE}/dns_records"
AUTH_HEADER="Authorization: Bearer ${CF_TOKEN}"
CT_HEADER="Content-Type: application/json"

##############################################################################
# Step 1 — GET existing records
##############################################################################
GET_HTTP=$(curl -sS -o /tmp/cf_dns_get.json -w '%{http_code}' -X GET \
  "${API_BASE}?type=${RECORD_TYPE}&name=${RECORD_NAME}" \
  -H "${AUTH_HEADER}" -H "${CT_HEADER}")

if [ "$GET_HTTP" -lt 200 ] || [ "$GET_HTTP" -ge 300 ]; then
  echo "::error::Cloudflare DNS GET HTTP error ${GET_HTTP}: $(cat /tmp/cf_dns_get.json)"
  exit 1
fi

GET_SUCCESS=$(jq -r '.success' /tmp/cf_dns_get.json)
if [ "$GET_SUCCESS" != "true" ]; then
  echo "::error::Cloudflare DNS GET API failure: $(cat /tmp/cf_dns_get.json)"
  exit 1
fi

##############################################################################
# Step 2 — Decide: skip / warn / create
##############################################################################
COUNT=$(jq '.result | length' /tmp/cf_dns_get.json)

if [ "$COUNT" -gt 0 ]; then
  CURRENT=$(jq -r '.result[0].content' /tmp/cf_dns_get.json)
  if [ "$CURRENT" = "$RECORD_CONTENT" ]; then
    echo "✅ DNS record ${RECORD_NAME} already exists with correct content"
    exit 0
  else
    echo "::warning::DNS record ${RECORD_NAME} exists but content differs (current: ${CURRENT}, expected: ${RECORD_CONTENT})"
    exit 1
  fi
fi

##############################################################################
# Step 3 — POST to create record
##############################################################################
echo "Creating DNS record ${RECORD_NAME} → ${RECORD_CONTENT}"

POST_HTTP=$(curl -sS -o /tmp/cf_dns_post.json -w '%{http_code}' -X POST \
  "${API_BASE}" \
  -H "${AUTH_HEADER}" -H "${CT_HEADER}" \
  --data '{"type":"'"${RECORD_TYPE}"'","name":"'"${RECORD_NAME}"'","content":"'"${RECORD_CONTENT}"'","ttl":1,"proxied":'"${RECORD_PROXIED}"'}')

if [ "$POST_HTTP" -lt 200 ] || [ "$POST_HTTP" -ge 300 ]; then
  echo "::error::Cloudflare DNS POST HTTP error ${POST_HTTP}: $(cat /tmp/cf_dns_post.json)"
  exit 1
fi

POST_SUCCESS=$(jq -r '.success' /tmp/cf_dns_post.json)
if [ "$POST_SUCCESS" != "true" ]; then
  echo "::error::Cloudflare DNS POST API failure: $(cat /tmp/cf_dns_post.json)"
  exit 1
fi

echo "✅ DNS record ${RECORD_NAME} created successfully"
jq . /tmp/cf_dns_post.json
