# Speed to Lead — Testing Guide

## Prerequisites

- n8n running locally: `n8n start` (port 5678 default)
- Main workflow imported and OPEN (not activated) for webhook-test URL
- OR workflow ACTIVATED for production webhook URL
- Environment variables set: `GOOGLE_KEY`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `ANTHROPIC_API_KEY`

## Quick Test Commands

### Send a single happy-path lead
```bash
GOOGLE_KEY=your_key ./tests/test-webhook.sh happy
```

### Test deduplication (send same lead twice, check only one execution proceeds)
```bash
GOOGLE_KEY=your_key ./tests/test-webhook.sh duplicate
```

### Test google_key rejection
```bash
GOOGLE_KEY=your_key ./tests/test-webhook.sh invalid-key
```

### Test email-only path (no phone → Brevo)
```bash
GOOGLE_KEY=your_key ./tests/test-webhook.sh email-only
```

### Run all scenarios
```bash
GOOGLE_KEY=your_key ./tests/test-webhook.sh all
```

## Webhook URL Modes

| Mode | URL | When to use |
|------|-----|-------------|
| Test (workflow open) | http://localhost:5678/webhook-test/{slug} | Development — workflow does not need to be active |
| Production (workflow active) | http://localhost:5678/webhook/{slug} | Deduplication testing — requires active workflow |
| Railway production | https://{hostname}/webhook/{slug} | End-to-end with real Twilio/Claude |

## What to Verify After Each Plan Wave

### After Plan 02 (config + workflow scaffold):
- [ ] Workflow JSON exists in `workflows/`
- [ ] Client config JSON exists in `config/`

### After Plan 03 (ingestion layer):
- [ ] Webhook returns 200: `./tests/test-webhook.sh happy` → HTTP Status: 200
- [ ] Invalid key stops workflow: `./tests/test-webhook.sh invalid-key` → execution stops at IF node (verify in n8n UI)
- [ ] Raw payload visible in execution log (inspect n8n UI > Executions)
- [ ] Duplicate stops at Remove Duplicates node (activate workflow, send twice, verify one execution proceeds)

### After Plan 05 (AI + channel dispatch):
- [ ] Claude node output visible in execution log — inspect `$json.content[0].text`
- [ ] SMS arrives on test phone (requires real Twilio credentials)
- [ ] Email arrives in test inbox (email-only scenario, requires Brevo credentials)

### After Plan 06 (owner notification):
- [ ] Baptiste's test phone receives owner SMS with tel: link
- [ ] End-to-end timing: submit test → SMS on prospect phone in < 2 minutes

## Verifying NOTIF-04 (Error Fallback)

1. Import error handler workflow (created in Plan 04)
2. In main workflow Settings > Error Workflow: select "Speed to Lead — Error Handler"
3. Temporarily break the Claude node (set wrong API key)
4. Send happy-path test lead
5. Baptiste's phone should receive fallback SMS within 30 seconds
6. Restore Claude API key after test

## Test Payload Structure Reference

All test payloads are in `tests/payloads/`. The `google_key` field uses placeholder
`REPLACE_WITH_YOUR_GOOGLE_KEY` — the test script substitutes your actual `$GOOGLE_KEY`
env variable before sending. Never commit a real key into these files.
