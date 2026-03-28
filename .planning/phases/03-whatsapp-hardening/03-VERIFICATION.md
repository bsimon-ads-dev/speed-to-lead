---
phase: 03-whatsapp-hardening
verified: 2026-03-27T00:00:00Z
status: human_needed
score: 4/4 automated must-haves verified
re_verification: false
human_verification:
  - test: "Activate Core Workflow and send 7 identical webhook calls to the same lead_id within 10 minutes using production /webhook/ URL"
    expected: "Executions 1-5 proceed normally. Execution 6+ is halted at Code: Circuit Breaker with circuit_breaker_tripped: true, and Baptiste's phone receives alert SMS containing the lead_id, cb_count, and client_slug"
    why_human: "staticData does not persist between editor test executions — circuit breaker requires live webhook-triggered production executions. Cannot be verified without running n8n."
  - test: "Set whatsapp_enabled: true in dupont-plomberie entry workflow, set DUPONT_WHATSAPP_SENDER and DUPONT_WHATSAPP_TEMPLATE_SID env vars, send a test lead"
    expected: "Twilio Console shows outbound WhatsApp message with ContentSid (not Body), delivered status with MM-prefixed SID. Prospect receives template message not free-form text."
    why_human: "Requires WABA onboarding completion with real Twilio env vars and live n8n execution. Cannot verify message delivery without real credentials."
  - test: "Set owner_whatsapp_enabled: true in dupont-plomberie entry workflow, set DUPONT_WHATSAPP_OWNER_TEMPLATE_SID env var, send a test lead"
    expected: "Owner receives WhatsApp notification via approved template. Twilio Console shows delivery receipt to owner_phone with ContentSid routing confirmed."
    why_human: "Same WABA onboarding dependency as SC-1. Requires live credentials and running n8n."
  - test: "Configure UptimeRobot HTTP(s) monitor targeting https://{your-n8n-host}/webhook/dupont-plomberie with 5-minute interval, stop n8n"
    expected: "Baptiste receives email alert 'Your monitor [n8n dupont-plomberie webhook] is DOWN' within 5 minutes. Recovery email arrives when n8n restarts."
    why_human: "UptimeRobot is an external service with no CLI. Requires manual web UI setup and stopping the production n8n instance. SC-03-SUMMARY notes this was a checkpoint auto-approved — Baptiste must still complete the setup."
---

# Phase 3: WhatsApp + Hardening — Verification Report

**Phase Goal:** WhatsApp is available as a channel for both prospect messages and owner notifications, and the system is hardened for a growing client base with spend caps, uptime monitoring, and circuit breakers
**Verified:** 2026-03-27
**Status:** HUMAN_NEEDED — all automated code checks pass; live execution and external service setup require human verification
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | A client configured for WhatsApp has a prospect message sent via Twilio WABA using a pre-approved Meta utility template — free-form messages never sent | ? HUMAN NEEDED | Code verified: node-wa-if-prospect gates on whatsapp_enabled, node-wa-prospect uses ContentSid + ContentVariables with no Body param, whatsapp: prefix hardcoded in To/From. Delivery requires live WABA credentials. |
| SC-2 | The owner notification is delivered via WhatsApp when their preferred channel is configured as WhatsApp | ? HUMAN NEEDED | Code verified: node-wa-if-owner gates on owner_whatsapp_enabled, node-wa-owner uses ContentSid + ContentVariables with no Body param. Delivery requires live WABA credentials. |
| SC-3 | UptimeRobot alerts Baptiste within 5 minutes if the n8n instance stops responding | ? HUMAN NEEDED | Test 3-D documented in TESTING.md (lines 224-239). SUMMARY notes the checkpoint was auto-approved — UptimeRobot setup requires manual web UI configuration by Baptiste. No code artifact to verify for an external monitoring service. |
| SC-4 | More than 5 executions for the same lead_id in 10 minutes triggers a halt and alert rather than repeated sends | ✓ VERIFIED | node-circuit-breaker: WINDOW_MS = 10*60*1000, THRESHOLD = 5, condition entry.count > THRESHOLD, staticData.circuitBreaker persistence + 20-min prune. CB Alert node confirmed no outgoing connection. Trigger -> Code: Circuit Breaker wiring confirmed. |

**Score:** 1/4 fully verified programmatically; 3/4 require human execution (code correct, runtime unverifiable)

---

## Required Artifacts

| Artifact | Purpose | Exists | Substantive | Wired | Status |
|----------|---------|--------|-------------|-------|--------|
| `workflows/speed-to-lead-core.json` — Code: Circuit Breaker (node-circuit-breaker) | Halt + alert on >5 same lead_id/10 min | Yes | Yes (49-line jsCode with window/threshold/prune logic) | Yes (first node after trigger) | VERIFIED |
| `workflows/speed-to-lead-core.json` — IF: Circuit Breaker Tripped? (node-cb-if) | Route true to CB Alert, false to Log Raw Payload | Yes | Yes (boolean condition on circuit_breaker_tripped) | Yes (connected after circuit breaker, true->CB Alert, false->Log Raw Payload) | VERIFIED |
| `workflows/speed-to-lead-core.json` — HTTP Request: Twilio SMS (CB Alert) (node-cb-alert) | Alert SMS to BAPTISTE_PHONE | Yes | Yes (full Twilio POST with BAPTISTE_PHONE To, alert Body with lead_id/cb_count/client_slug) | Yes (terminal — no outgoing connection, execution terminates) | VERIFIED |
| `workflows/speed-to-lead-core.json` — IF: whatsapp_enabled? (Prospect) (node-wa-if-prospect) | Gate WhatsApp vs SMS for prospect | Yes | Yes (boolean condition on client_config.whatsapp_enabled) | Yes (phone available? true -> this node; true->WA Prospect, false->SMS Prospect) | VERIFIED |
| `workflows/speed-to-lead-core.json` — HTTP Request: Twilio WhatsApp (Prospect) (node-wa-prospect) | WABA template send to prospect | Yes | Yes (ContentSid + ContentVariables, no Body, whatsapp: prefix on To/From) | Yes (connected from WA IF true branch, converges to Code: Format Owner Notification) | VERIFIED |
| `workflows/speed-to-lead-core.json` — IF: owner_whatsapp_enabled? (node-wa-if-owner) | Gate WhatsApp vs SMS for owner | Yes | Yes (boolean condition on client_config.owner_whatsapp_enabled) | Yes (Code: Format Owner Notification -> this node; true->WA Owner, false->SMS Owner) | VERIFIED |
| `workflows/speed-to-lead-core.json` — HTTP Request: Twilio WhatsApp (Owner) (node-wa-owner) | WABA template send to owner | Yes | Yes (ContentSid + ContentVariables, no Body, whatsapp: prefix on To/From) | Yes (connected from owner WA IF true branch, converges to Wait: Follow-up Delay) | VERIFIED |
| `config/dupont-plomberie.json` — whatsapp_* fields | Config schema with defaults-off | Yes | Yes (5 fields: whatsapp_enabled: false, owner_whatsapp_enabled: false, whatsapp_sender: "", whatsapp_template_sid: "", whatsapp_owner_template_sid: "") | Yes (read by entry workflow jsCode) | VERIFIED |
| `config/cabinet-martin.json` — whatsapp_* fields | Config schema with defaults-off | Yes | Yes (same 5 fields with same safe defaults) | Yes (read by entry workflow jsCode) | VERIFIED |
| `workflows/speed-to-lead-entry-dupont-plomberie.json` — WhatsApp fields in Code: Assemble Client Config | Assemble WhatsApp env vars with || '' fallback | Yes | Yes (whatsapp_enabled: false, owner_whatsapp_enabled: false, DUPONT_WHATSAPP_SENDER/TEMPLATE_SID/OWNER_TEMPLATE_SID with || '' fallback) | Yes (passed to Core Workflow as client_config) | VERIFIED |
| `workflows/speed-to-lead-entry-cabinet-martin.json` — WhatsApp fields in Code: Assemble Client Config | Assemble WhatsApp env vars with || '' fallback | Yes | Yes (same pattern with MARTIN_ prefix) | Yes (passed to Core Workflow as client_config) | VERIFIED |
| `tests/TESTING.md` — Phase 3 section | Tests 3-A through 3-D for SC-1/SC-2/SC-3/SC-4 | Yes | Yes (4 test scenarios, each with prerequisites, steps, expected results, RESTORE warnings) | Yes (referenced from SUMMARY 03-03, line 166 in TESTING.md) | VERIFIED |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Trigger node | Code: Circuit Breaker | connections["When Executed by Another Workflow"].main[0][0] | WIRED | Confirmed: first node is "Code: Circuit Breaker" |
| Code: Circuit Breaker | IF: Circuit Breaker Tripped? | connections chain | WIRED | Confirmed direct connection |
| IF: Circuit Breaker Tripped? (true) | HTTP Request: Twilio SMS (CB Alert) | main[0][0] | WIRED | Confirmed true branch -> CB Alert |
| IF: Circuit Breaker Tripped? (false) | Code: Log Raw Payload | main[1][0] | WIRED | Confirmed false branch -> Log Raw Payload (normal flow) |
| HTTP Request: Twilio SMS (CB Alert) | (terminal) | no outgoing connection | VERIFIED | connections["HTTP Request: Twilio SMS (CB Alert)"] is undefined — execution terminates |
| IF: phone available? (true) | IF: whatsapp_enabled? (Prospect) | main[0][0] | WIRED | Confirmed |
| IF: whatsapp_enabled? (Prospect) (true) | HTTP Request: Twilio WhatsApp (Prospect) | main[0][0] | WIRED | Confirmed |
| IF: whatsapp_enabled? (Prospect) (false) | HTTP Request: Twilio SMS (Prospect) | main[1][0] | WIRED | Confirmed — existing SMS path unaffected |
| HTTP Request: Twilio WhatsApp (Prospect) | Code: Format Owner Notification | main[0][0] | WIRED | Confirmed — converges with SMS path |
| Code: Format Owner Notification | IF: owner_whatsapp_enabled? | main[0][0] | WIRED | Confirmed |
| IF: owner_whatsapp_enabled? (true) | HTTP Request: Twilio WhatsApp (Owner) | main[0][0] | WIRED | Confirmed |
| IF: owner_whatsapp_enabled? (false) | HTTP Request: Twilio SMS (Owner) | main[1][0] | WIRED | Confirmed — existing SMS path unaffected |
| HTTP Request: Twilio WhatsApp (Owner) | Wait: Follow-up Delay | main[0][0] | WIRED | Confirmed — converges with SMS owner path |

---

## Data-Flow Trace (Level 4)

WhatsApp nodes are HTTP Request nodes (not UI components rendering state). Data flows via n8n expression binding — no useState/useQuery pattern applies. Verification is structural (expression references, not runtime data population).

| Artifact | Data Variable | Source | Expression Verified | Status |
|----------|---------------|--------|---------------------|--------|
| node-wa-prospect To | $json.phone | Code: Extract Lead Fields | =whatsapp:{{ $json.phone }} | FLOWING (structurally) |
| node-wa-prospect From | $json.client_config.whatsapp_sender | Entry workflow jsCode + env var DUPONT/MARTIN_WHATSAPP_SENDER | =whatsapp:{{ $json.client_config.whatsapp_sender }} | FLOWING when env var set; '' fallback prevents runtime error when unset |
| node-wa-prospect ContentSid | $json.client_config.whatsapp_template_sid | Entry workflow jsCode + env var *_WHATSAPP_TEMPLATE_SID | ={{ $json.client_config.whatsapp_template_sid }} | FLOWING when env var set; feature flag whatsapp_enabled: false prevents send when empty |
| node-circuit-breaker staticData | $getWorkflowStaticData('global').circuitBreaker | n8n workflow static data | Direct API call in jsCode | FLOWING (production webhook executions only — does not persist in editor test mode per TESTING.md) |
| node-cb-alert Body | $json.lead_id, $json.cb_count, $json.client_config.client_slug | Carried from circuit breaker Code node output | Inline expression | FLOWING |

---

## Behavioral Spot-Checks

Step 7b: All behaviors require a running n8n instance. No runnable entry points available in this static codebase — all checks require live webhook-triggered executions.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Circuit breaker halts on >5 same lead_id | Requires live n8n + 7 webhook calls | N/A | ? SKIP (needs running n8n) |
| WhatsApp prospect send via ContentSid | Requires live n8n + WABA env vars | N/A | ? SKIP (needs WABA credentials) |
| WhatsApp owner send via ContentSid | Requires live n8n + WABA env vars | N/A | ? SKIP (needs WABA credentials) |
| UptimeRobot DOWN alert within 5 min | Requires configured UptimeRobot + stopping n8n | N/A | ? SKIP (external service) |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CHAN-01 (v2) | 03-01-SUMMARY.md, 03-03-SUMMARY.md | Envoi WhatsApp au prospect via Twilio WABA (après validation templates Meta) | PARTIALLY SATISFIED | WhatsApp send nodes wired with ContentSid + no Body (WABA-compliant) behind feature flags. Runtime delivery pending WABA onboarding by Baptiste. CHAN-01 is not in REQUIREMENTS.md traceability table (v2 requirement — table covers v1 only). |

**Note on traceability table:** REQUIREMENTS.md traceability table covers only v1 requirements (16 items). CHAN-01 is a v2 requirement listed in the v2 section but not tracked in the traceability table. This is consistent with the current document state — the table was last updated 2026-03-27 after roadmap creation and predates Phase 3 completion. Not flagged as a gap since v2 requirements are explicitly out-of-scope for the traceability coverage statement.

**Spend cap:** The phase goal mentions "spend caps" but the Anthropic spend cap is a console-only setting with no code artifact. It is documented as optional in 03-03-SUMMARY.md (User Setup Required section) and 03-03-PLAN.md. Baptiste must set a $20/month limit at https://console.anthropic.com manually.

---

## Anti-Patterns Found

| File | Pattern | Severity | Assessment |
|------|---------|----------|------------|
| `workflows/speed-to-lead-entry-dupont-plomberie.json` line ~67 | workflowId value: "CORE_WORKFLOW_ID" (placeholder) | INFO | Intentional placeholder — documented in _setup_notes.post_import_step. Must be replaced with actual workflow ID post-import in n8n. Not a code stub — this is the correct import pattern for n8n workflows. |
| `workflows/speed-to-lead-entry-cabinet-martin.json` line ~67 | workflowId value: "CORE_WORKFLOW_ID" (placeholder) | INFO | Same as above. Documented, intentional. |
| Both entry workflows | whatsapp_enabled: false, owner_whatsapp_enabled: false hardcoded | INFO | Intentional feature flags (not stubs). WhatsApp branches are fully wired — the false defaults prevent premature WABA sends before onboarding. Per plan decisions: "Activation is a two-step: configure env vars, then flip flag in jsCode." |
| `config/dupont-plomberie.json`, `config/cabinet-martin.json` | whatsapp_sender: "", whatsapp_template_sid: "", whatsapp_owner_template_sid: "" empty strings | INFO | Config schema ships before WABA onboarding completes — intentional defaults. Values populated via env_vars_required registry entries documented in each config. Not stubs. |

No blockers or warnings. All INFO-level items are intentional patterns documented in plan decisions.

---

## Human Verification Required

### 1. Circuit Breaker Live Execution (SC-4)

**Test:** Activate the Core Workflow and dupont-plomberie entry workflow in n8n (production activation, not editor mode). Send 7 identical webhook calls to the same lead_id within 10 minutes:
```
for i in $(seq 1 7); do GOOGLE_KEY=your_key ./tests/test-webhook.sh happy dupont-plomberie; sleep 2; done
```
**Expected:** Executions 1-5 complete normally (prospect SMS sent). Executions 6 and 7 show circuit_breaker_tripped: true in n8n Executions view and halt. Baptiste's phone receives alert SMS: "ALERTE circuit breaker: lead_id ... a declenche X executions en 10 min..."
**Why human:** $getWorkflowStaticData('global') does NOT persist between editor test executions — circuit breaker only fires across production webhook-triggered executions. Verified in TESTING.md Test 3-A.
**Restore:** Wait 10 minutes or manually clear staticData.circuitBreaker in n8n Settings > Workflow static data.

### 2. WhatsApp Prospect Delivery via WABA Template (SC-1)

**Test:** Complete WABA onboarding for dupont-plomberie. Set env vars DUPONT_WHATSAPP_SENDER (E.164), DUPONT_WHATSAPP_TEMPLATE_SID (ContentSid starting HX...). Set whatsapp_enabled: true in entry workflow jsCode. Send a test lead.
**Expected:** Twilio Console > Monitor > Messaging Logs shows outbound WhatsApp message with "delivered" status and MM-prefixed SID. Message uses the approved template (not free-form Body text). Prospect receives template message on WhatsApp.
**Why human:** Requires real Twilio WABA credentials, Meta-approved template, and live n8n execution. Cannot verify actual message delivery without external services.
**Restore:** Set whatsapp_enabled back to false after testing unless activating for production.

### 3. WhatsApp Owner Notification Delivery (SC-2)

**Test:** Set DUPONT_WHATSAPP_OWNER_TEMPLATE_SID env var. Set owner_whatsapp_enabled: true in entry workflow jsCode. Send a test lead.
**Expected:** Owner's phone receives WhatsApp notification via approved template. Twilio Console confirms ContentSid routing (not Body).
**Why human:** Same WABA dependency as SC-1.
**Restore:** Set owner_whatsapp_enabled back to false after testing.

### 4. UptimeRobot Uptime Alert (SC-3)

**Test:** Go to https://uptimerobot.com, create an HTTP(s) monitor:
- Friendly Name: n8n dupont-plomberie webhook
- URL: https://[YOUR-N8N-HOST]/webhook/dupont-plomberie (IMPORTANT: use /webhook/ not /webhook-test/)
- Interval: 5 minutes
- Alert: Baptiste's email

Then stop n8n (pause Railway deployment), wait up to 5 minutes.
**Expected:** Baptiste receives email "Your monitor [n8n dupont-plomberie webhook] is DOWN". Recovery email arrives when n8n restarts.
**Why human:** UptimeRobot has no CLI — requires web UI setup. Requires stopping the production service. The 03-03-SUMMARY checkpoint was auto-approved without Baptiste having completed the UptimeRobot configuration.

### 5. Anthropic Spend Cap (Phase Goal)

**Test:** Go to https://console.anthropic.com > Settings > Limits. Set a monthly spend limit.
**Expected:** Spend limit of approximately $20/month (65x safety margin over current $0.30/month actual spend) is active.
**Why human:** Console-only setting with no code artifact. Cannot be verified programmatically.

---

## Gaps Summary

No code gaps. All automated verifications pass:

- Circuit breaker Code node: present, substantive (10-min window / 5-threshold / 20-min prune), wired as first node after trigger
- Circuit breaker IF node: condition correct, true->CB Alert, false->normal flow
- CB Alert node: terminal (no outgoing connection), sends to BAPTISTE_PHONE
- WhatsApp prospect IF + send node: gates on whatsapp_enabled, uses ContentSid with no Body, whatsapp: prefix hardcoded
- WhatsApp owner IF + send node: gates on owner_whatsapp_enabled, same WABA-compliant pattern
- Both WhatsApp paths converge correctly (prospect->Format Owner Notification, owner->Wait: Follow-up Delay)
- Config schemas: 5 whatsapp_* fields with safe defaults in both client configs
- Entry workflows: whatsapp_* fields assembled with || '' fallback and feature flags defaults-off
- TESTING.md: Phase 3 section with all 4 test scenarios, RESTORE warnings, and /webhook/ vs /webhook-test/ distinction

The remaining items (SC-1, SC-2, SC-3) depend on external service setup and live execution. SC-4 (circuit breaker) is code-complete but requires production webhook execution to verify staticData behavior. The phase goal is substantially achieved at the code level; full goal achievement requires Baptiste to complete: (1) WABA onboarding, (2) UptimeRobot monitor setup, (3) Anthropic spend cap console setting.

---

_Verified: 2026-03-27_
_Verifier: Claude (gsd-verifier)_
