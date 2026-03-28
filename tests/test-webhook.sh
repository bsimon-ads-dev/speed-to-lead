#!/usr/bin/env bash
# Speed to Lead — Webhook Test Runner
# Usage: GOOGLE_KEY=your_key N8N_URL=http://localhost:5678 ./tests/test-webhook.sh [scenario]
# Scenarios: happy | duplicate | invalid-key | email-only | all (default: all)

set -euo pipefail

N8N_URL="${N8N_URL:-http://localhost:5678}"
GOOGLE_KEY="${GOOGLE_KEY:-REPLACE_WITH_YOUR_GOOGLE_KEY}"
CLIENT_SLUG="${CLIENT_SLUG:-dupont-plomberie}"
SCENARIO="${1:-all}"

WEBHOOK_URL="${N8N_URL}/webhook-test/${CLIENT_SLUG}"
PAYLOADS_DIR="$(dirname "$0")/payloads"

send_payload() {
  local name="$1"
  local file="$2"
  local payload
  payload=$(sed "s/REPLACE_WITH_YOUR_GOOGLE_KEY/${GOOGLE_KEY}/g" "$file")
  echo "--- Sending: $name ---"
  echo "URL: $WEBHOOK_URL"
  HTTP_STATUS=$(echo "$payload" | curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d @-)
  echo "HTTP Status: $HTTP_STATUS"
  if [ "$HTTP_STATUS" = "200" ]; then
    echo "PASS: $name returned 200"
  else
    echo "FAIL: $name returned $HTTP_STATUS (expected 200)"
  fi
  echo ""
  sleep 2
}

case "$SCENARIO" in
  happy)
    send_payload "Happy Path" "${PAYLOADS_DIR}/google-ads-lead.json"
    ;;
  duplicate)
    send_payload "Happy Path (first send)" "${PAYLOADS_DIR}/google-ads-lead.json"
    send_payload "Duplicate (same lead_id)" "${PAYLOADS_DIR}/google-ads-lead-duplicate.json"
    ;;
  invalid-key)
    send_payload "Invalid google_key" "${PAYLOADS_DIR}/google-ads-lead-invalid-key.json"
    ;;
  email-only)
    send_payload "Email Only (no phone)" "${PAYLOADS_DIR}/google-ads-lead-email-only.json"
    ;;
  all)
    send_payload "Happy Path" "${PAYLOADS_DIR}/google-ads-lead.json"
    send_payload "Duplicate lead_id" "${PAYLOADS_DIR}/google-ads-lead-duplicate.json"
    send_payload "Invalid google_key" "${PAYLOADS_DIR}/google-ads-lead-invalid-key.json"
    send_payload "Email Only" "${PAYLOADS_DIR}/google-ads-lead-email-only.json"
    ;;
  *)
    echo "Unknown scenario: $SCENARIO"
    echo "Usage: $0 [happy|duplicate|invalid-key|email-only|all]"
    exit 1
    ;;
esac

echo "Done. Check n8n execution log at: ${N8N_URL}/executions"
