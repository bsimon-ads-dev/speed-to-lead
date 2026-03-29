# Speed to Lead — Testing Guide

## Prerequisites

- n8n running locally: `n8n start` (port 5678 default)
- Main workflow imported and OPEN (not activated) for webhook-test URL
- OR workflow ACTIVATED for production webhook URL
- Environment variables set: `GOOGLE_KEY`, `WA_PHONE_NUMBER_ID`, `WA_ACCESS_TOKEN`, `ANTHROPIC_API_KEY`

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
| Railway production | https://{hostname}/webhook/{slug} | End-to-end with real WhatsApp Cloud API/Claude |

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
- [ ] WhatsApp message arrives on test phone (requires WhatsApp Cloud API credentials)
- [ ] Email arrives in test inbox (email-only scenario, requires Brevo credentials)

### After Plan 06 (owner notification):
- [ ] Dirigeant's test phone receives owner WhatsApp with tel: link
- [ ] End-to-end timing: submit test → WhatsApp message on prospect phone in < 2 minutes

## Verifying NOTIF-04 (Error Fallback)

1. Import error handler workflow (created in Plan 04)
2. In main workflow Settings > Error Workflow: select "Speed to Lead — Error Handler"
3. Temporarily break the Claude node (set wrong API key)
4. Send happy-path test lead
5. Dirigeant's phone should receive fallback WhatsApp message within 30 seconds
6. Restore Claude API key after test

## Test Payload Structure Reference

All test payloads are in `tests/payloads/`. The `google_key` field uses placeholder
`REPLACE_WITH_YOUR_GOOGLE_KEY` — the test script substitutes your actual `$GOOGLE_KEY`
env variable before sending. Never commit a real key into these files.

---

## Phase 2: Follow-up + Multi-tenant

### Multi-client Smoke Test (CONF-03)

Verify both clients have unique webhook URLs and both return 200:

```bash
# Test Dupont Plomberie entry workflow
GOOGLE_KEY=your_dupont_key ./tests/test-webhook.sh happy dupont-plomberie

# Test Cabinet Martin entry workflow
GOOGLE_KEY=your_martin_key ./tests/test-webhook.sh happy cabinet-martin
```

Expected: both return HTTP Status: 200. Verify in n8n Executions view that two separate executions appear, each showing the correct client_slug in the Code: Assemble Client Config node output.

### Core Workflow Multi-tenant Test (CONF-02)

After sending a test lead for each client, verify in the n8n Executions view:
- Both executions show "Speed to Lead — Core" as the workflow name
- The `business_name` field in the Claude API node body matches the correct client (Dupont Plomberie vs Cabinet Martin Avocats)
- The Twilio SMS nodes use different `From` sender IDs for each client

### Follow-up Delay Test (NOTIF-03)

**Important:** This test requires temporarily setting follow_up_delay_minutes to 1 in the entry workflow Code node. Restore to 45 (Dupont) or 120 (Martin) after testing.

Procedure:
1. Open the entry workflow for dupont-plomberie in n8n
2. Edit the "Code: Assemble Client Config" node
3. Change `follow_up_delay_minutes: 45` to `follow_up_delay_minutes: 1`
4. Save the workflow (keep it active or use webhook-test URL)
5. Send a test lead: `GOOGLE_KEY=your_key ./tests/test-webhook.sh happy dupont-plomberie`
6. Wait 1 minute
7. Verify in n8n Executions view: the Core Workflow execution resumes after ~1 minute and reaches "HTTP Request: WhatsApp Cloud API (Follow-up)" (if current time is Mon-Sat 08:00-20:00 Paris)
8. Verify the prospect test phone receives the follow-up WhatsApp message
9. RESTORE: change follow_up_delay_minutes back to 45 and save

### Business Hours Gate Test (NOTIF-03)

To verify the follow-up is suppressed outside business hours:

Option A — Run at off-hours time (after 20:00 or on Sunday):
  Send a test lead during business hours, then run the follow-up test above.
  If the Wait fires outside 08:00-20:00 Mon-Sat, inspect the n8n execution:
  - The "Code: Business Hours Check" node output should show business_hours_ok: false
  - The "IF: Business Hours OK?" node should route to "Code: Log Follow-up Skipped"
  - No Twilio SMS (Follow-up) call should appear in execution

Option B — Verify execution log text:
  After sending a lead when follow-up fires outside hours, check the "Code: Log Follow-up Skipped" node output in n8n Executions. It should log: "Follow-up skipped (outside hours)" with the lead_id and client_slug.

### Credential Isolation Check (CONF-01)

Verify that a misconfigured env var for Client A cannot cause sends on behalf of Client B:

1. In n8n Settings, set WA_PHONE_NUMBER_ID for Client B to an invalid value (e.g. "INVALID")
2. Send a test lead to dupont-plomberie
3. Verify the Dupont Plomberie execution completes normally (uses correct WA credentials)
4. Verify the Cabinet Martin execution (if tested) would fail at WhatsApp nodes — not silently use Dupont's credentials
5. Restore WA_PHONE_NUMBER_ID to its correct value

### Phase 2 Acceptance Checklist

Run these checks before marking Phase 2 complete:

| Requirement | Test | Expected Result |
|-------------|------|-----------------|
| CONF-01 — Per-client config | Send lead to each client, inspect Code: Assemble Client Config output | Each execution shows correct client_slug, business_name, owner_phone |
| CONF-02 — Shared Core Workflow | Both client executions appear under "Speed to Lead — Core" in Executions | Same workflow ID for both clients |
| CONF-03 — Unique webhook slugs | curl to /webhook/dupont-plomberie and /webhook/cabinet-martin both return 200 | Distinct URLs, both active |
| NOTIF-03 — Follow-up fires | 1-minute test (see above), follow-up WhatsApp received on test phone | WhatsApp received within 90 seconds of delay expiry |
| NOTIF-03 — Follow-up gated | Business hours check node output business_hours_ok matches current time | Correctly blocks outside Mon-Sat 08:00-20:00 Paris |

### Webhook URLs for Phase 2

| Client | Test URL (workflow open) | Production URL (workflow active) |
|--------|--------------------------|----------------------------------|
| dupont-plomberie | http://localhost:5678/webhook-test/dupont-plomberie | https://{host}/webhook/dupont-plomberie |
| cabinet-martin | http://localhost:5678/webhook-test/cabinet-martin | https://{host}/webhook/cabinet-martin |

---

## Phase 3: WhatsApp + Hardening

### Test 3-A: Circuit Breaker (SC-4)

**What it tests:** More than 5 executions of the same lead_id within 10 minutes halts execution and sends alert WhatsApp to dirigeant.

**Prerequisite:** n8n running. Core Workflow activated. Dirigeant WhatsApp phone number configured. Circuit breaker nodes present in Core Workflow (Plan 03-01).

**Note on staticData:** $getWorkflowStaticData('global') does NOT persist between manual (editor) test executions. The circuit breaker only fires across production webhook-triggered executions. Use the webhook URL (not webhook-test).

**Steps:**
1. Activate the Core Workflow and dupont-plomberie entry workflow in n8n (not test mode — production activation)
2. Send 7 identical webhook calls using the same lead_id:
   for i in $(seq 1 7); do GOOGLE_KEY=your_key ./tests/test-webhook.sh happy dupont-plomberie; sleep 2; done
   (Replace your_key with DUPONT_GOOGLE_KEY value)
3. Check n8n Executions view — executions 6 and 7 should show "circuit_breaker_tripped: true" in the circuit breaker Code node output
4. Check dirigeant's WhatsApp — should receive alert: "ALERTE circuit breaker: lead_id ... a declenche X executions en 10 min..."

**Expected result:** Executions 1-5 proceed normally (prospect WhatsApp sent). Execution 6+ is halted at circuit breaker with alert WhatsApp to dirigeant.

**RESTORE:** After test, wait for the 10-minute window to expire before running production tests, or manually clear staticData.circuitBreaker in n8n Settings > Workflow static data.

---

### Test 3-B: WhatsApp Prospect Message (SC-1)

**What it tests:** Prospect receives WhatsApp message via approved template when whatsapp_enabled is true.

**Prerequisite:** WABA onboarding complete for the test client (WA_PHONE_NUMBER_ID env var set, WA_TEMPLATE_NAME set to approved template). Entry workflow has whatsapp_enabled: true set in Code: Assemble Client Config.

**Steps:**
1. Temporarily set whatsapp_enabled: true in entry workflow jsCode for dupont-plomberie
2. Send a test lead: GOOGLE_KEY=your_key ./tests/test-webhook.sh happy dupont-plomberie
3. Check Meta Business Manager > WhatsApp > Insights — the outbound WhatsApp message should show status "delivered"
4. Check the prospect's WhatsApp — should receive the template message: "Bonjour [name], votre demande a bien ete recue. Dupont Plomberie vous rappelle sous 30 minutes."

**IMPORTANT:** Verify the message uses the approved template. If the message arrives as free-form text (not a template), the node is misconfigured. Check Meta Business Manager for delivery status — absence of delivery confirmation means silent delivery failure.

**Restore:** Set whatsapp_enabled back to false after testing unless activating for production.

---

### Test 3-C: WhatsApp Owner Notification (SC-2)

**What it tests:** Dirigeant receives WhatsApp notification when owner_whatsapp_enabled is true.

**Prerequisite:** WABA onboarding complete. WA_TEMPLATE_NAME env var set to approved owner template. Entry workflow has owner_whatsapp_enabled: true.

**Steps:**
1. Temporarily set owner_whatsapp_enabled: true in entry workflow jsCode
2. Send a test lead: GOOGLE_KEY=your_key ./tests/test-webhook.sh happy dupont-plomberie
3. Check Meta Business Manager > WhatsApp > Insights — outbound WhatsApp to dirigeant phone should appear with "delivered" status
4. Check dirigeant's WhatsApp — should receive: "Nouveau lead: [name] — Demande: [request] — Tel: [phone]"

**Restore:** Set owner_whatsapp_enabled back to false after testing.

---

### Test 3-D: UptimeRobot Alert (SC-3)

**What it tests:** Baptiste receives alert email within 5 minutes of n8n stopping.

**Prerequisite:** UptimeRobot monitor configured (see checkpoint task in Plan 03-03). n8n running in production.

**Steps:**
1. Stop n8n (Railway: pause deployment or disable the service temporarily)
2. Wait up to 5 minutes (free tier checks every 5 minutes)
3. Check Baptiste's email for UptimeRobot alert: "Your monitor [n8n dupont-plomberie webhook] is DOWN"
4. Restart n8n
5. Wait for UptimeRobot recovery email

**Manual only** — cannot be automated (requires stopping the production service).

**Common mistake:** If the monitor URL uses /webhook-test/ instead of /webhook/, UptimeRobot will fire false-positive alerts constantly (test URL only responds when workflow is open in editor). Verify the monitor URL uses /webhook/ (production path).
