#!/usr/bin/env bash
# cloudflare-dns-record.sh — Upsert a Cloudflare DNS record (create or update).
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
#   0  Record already exists with correct content, was created, or was updated
#   1  API error or HTTP error
set -euo pipefail

TMPDIR_CF=$(mktemp -d)
trap 'rm -rf -- "$TMPDIR_CF"' EXIT

API_BASE="https://api.cloudflare.com/client/v4/zones/${CF_ZONE}/dns_records"
AUTH_HEADER="Authorization: Bearer ${CF_TOKEN}"
CT_HEADER="Content-Type: application/json"

##############################################################################
# Step 1 — GET existing records
##############################################################################
GET_HTTP=$(curl -sS -o "${TMPDIR_CF}/get.json" -w '%{http_code}' -X GET \
  "${API_BASE}?type=${RECORD_TYPE}&name=${RECORD_NAME}" \
  -H "${AUTH_HEADER}" -H "${CT_HEADER}")

if [ "$GET_HTTP" -lt 200 ] || [ "$GET_HTTP" -ge 300 ]; then
  echo "::error::Cloudflare DNS GET HTTP error ${GET_HTTP}: $(cat "${TMPDIR_CF}/get.json")"
  exit 1
fi

GET_SUCCESS=$(jq -r '.success' "${TMPDIR_CF}/get.json")
if [ "$GET_SUCCESS" != "true" ]; then
  echo "::error::Cloudflare DNS GET API failure: $(cat "${TMPDIR_CF}/get.json")"
  exit 1
fi

##############################################################################
# Step 2 — Decide: skip / update / create
##############################################################################
COUNT=$(jq '.result | length' "${TMPDIR_CF}/get.json")

if [ "$COUNT" -gt 0 ]; then
  CURRENT=$(jq -r '.result[0].content' "${TMPDIR_CF}/get.json")
  CURRENT_PROXIED=$(jq -r '.result[0].proxied' "${TMPDIR_CF}/get.json")
  if [ "$CURRENT" = "$RECORD_CONTENT" ] && [ "$CURRENT_PROXIED" = "$RECORD_PROXIED" ]; then
    echo "✅ DNS record ${RECORD_NAME} already exists with correct content and proxy setting"
    exit 0
  else
    # Record exists with different content — update it (blue/green re-point)
    RECORD_ID=$(jq -r '.result[0].id' "${TMPDIR_CF}/get.json")
    echo "Updating DNS record ${RECORD_NAME} (${RECORD_ID}): ${CURRENT} → ${RECORD_CONTENT}"

    PUT_PAYLOAD=$(jq -n \
      --arg type "$RECORD_TYPE" \
      --arg name "$RECORD_NAME" \
      --arg content "$RECORD_CONTENT" \
      --argjson proxied "$RECORD_PROXIED" \
      '{type: $type, name: $name, content: $content, ttl: 1, proxied: $proxied}')

    PUT_HTTP=$(curl -sS -o "${TMPDIR_CF}/put.json" -w '%{http_code}' -X PUT \
      "${API_BASE}/${RECORD_ID}" \
      -H "${AUTH_HEADER}" -H "${CT_HEADER}" \
      --data "$PUT_PAYLOAD")

    if [ "$PUT_HTTP" -lt 200 ] || [ "$PUT_HTTP" -ge 300 ]; then
      echo "::error::Cloudflare DNS PUT HTTP error ${PUT_HTTP}: $(cat "${TMPDIR_CF}/put.json")"
      exit 1
    fi

    PUT_SUCCESS=$(jq -r '.success' "${TMPDIR_CF}/put.json")
    if [ "$PUT_SUCCESS" != "true" ]; then
      echo "::error::Cloudflare DNS PUT API failure: $(cat "${TMPDIR_CF}/put.json")"
      exit 1
    fi

    echo "✅ DNS record ${RECORD_NAME} updated successfully"
    jq . "${TMPDIR_CF}/put.json"
    exit 0
  fi
fi

##############################################################################
# Step 3 — POST to create record
##############################################################################
echo "Creating DNS record ${RECORD_NAME} → ${RECORD_CONTENT}"

PAYLOAD=$(jq -n \
  --arg type "$RECORD_TYPE" \
  --arg name "$RECORD_NAME" \
  --arg content "$RECORD_CONTENT" \
  --argjson proxied "$RECORD_PROXIED" \
  '{type: $type, name: $name, content: $content, ttl: 1, proxied: $proxied}')

POST_HTTP=$(curl -sS -o "${TMPDIR_CF}/post.json" -w '%{http_code}' -X POST \
  "${API_BASE}" \
  -H "${AUTH_HEADER}" -H "${CT_HEADER}" \
  --data "$PAYLOAD")

if [ "$POST_HTTP" -lt 200 ] || [ "$POST_HTTP" -ge 300 ]; then
  echo "::error::Cloudflare DNS POST HTTP error ${POST_HTTP}: $(cat "${TMPDIR_CF}/post.json")"
  exit 1
fi

POST_SUCCESS=$(jq -r '.success' "${TMPDIR_CF}/post.json")
if [ "$POST_SUCCESS" != "true" ]; then
  echo "::error::Cloudflare DNS POST API failure: $(cat "${TMPDIR_CF}/post.json")"
  exit 1
fi

echo "✅ DNS record ${RECORD_NAME} created successfully"
jq . "${TMPDIR_CF}/post.json"
