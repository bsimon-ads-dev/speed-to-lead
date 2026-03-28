#!/bin/bash
# Speed to Lead — Test Script
# Usage: bash tests/test-webhook.sh <n8n-url> <webhook-secret>
#
# Examples:
#   bash tests/test-webhook.sh https://n8n.example.com mysecret123
#   bash tests/test-webhook.sh http://localhost:5678 mysecret123

N8N_URL="${1:?Usage: bash tests/test-webhook.sh <n8n-url> <webhook-secret>}"
SECRET="${2:?Usage: bash tests/test-webhook.sh <n8n-url> <webhook-secret>}"
WEBHOOK_URL="${N8N_URL}/webhook-test/speed-to-lead"

echo "=== Speed to Lead — Test ==="
echo "URL: ${WEBHOOK_URL}"
echo ""

echo "--- Test 1: Lead complet (nom + tel + email + message) ---"
curl -s -w "\nHTTP %{http_code}\n" \
  -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Secret: ${SECRET}" \
  -d @tests/payloads/wordpress-lead.json
echo ""

echo "--- Test 2: Lead email uniquement (pas de telephone) ---"
curl -s -w "\nHTTP %{http_code}\n" \
  -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Secret: ${SECRET}" \
  -d @tests/payloads/wordpress-lead-email-only.json
echo ""

echo "--- Test 3: Lead sans secret (doit etre rejete) ---"
curl -s -w "\nHTTP %{http_code}\n" \
  -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d @tests/payloads/wordpress-lead.json
echo ""

echo "--- Test 4: Deduplication (meme lead envoye 2x) ---"
curl -s -w "\nHTTP %{http_code}\n" \
  -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Secret: ${SECRET}" \
  -d @tests/payloads/wordpress-lead.json
echo "(Le prospect ne doit PAS recevoir un 2e SMS)"
echo ""

echo "=== Tests termines ==="
