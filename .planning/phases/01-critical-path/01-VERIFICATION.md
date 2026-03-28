---
phase: 01-critical-path
verified: 2026-03-27T00:00:00Z
status: gaps_found
score: 4/5 must-haves verified
re_verification: false
gaps:
  - truth: "The error handler workflow is linked to the main workflow via Settings > Error Workflow"
    status: failed
    reason: "workflows/speed-to-lead-main.json settings block contains only 'executionOrder: v1' — no errorWorkflow field. The link between main workflow and error handler exists only as a post-import manual instruction in _setup_notes, not encoded in the exported JSON."
    artifacts:
      - path: "workflows/speed-to-lead-main.json"
        issue: "settings object missing errorWorkflow field — only contains {\"executionOrder\": \"v1\"}"
    missing:
      - "Add errorWorkflow field to settings block in speed-to-lead-main.json, referencing the error handler workflow by name or ID, so the link survives workflow import/export without manual re-linking"
human_verification:
  - test: "Import both workflows into a live n8n instance, send a test payload via test-webhook.sh (happy scenario), verify Claude response arrives, Twilio sends prospect SMS, owner SMS arrives with tel: link, all within 2 minutes"
    expected: "Prospect SMS in under 2 minutes with French personalized message under 155 chars; owner SMS with tel:+336XXXXXXXX link arriving within seconds after prospect SMS"
    why_human: "End-to-end timing requires real Twilio and Anthropic credentials; 2-minute SLA cannot be verified statically"
  - test: "Trigger a pipeline error (e.g., temporarily set ANTHROPIC_API_KEY to wrong value), then send a test payload. Confirm Baptiste receives fallback SMS."
    expected: "Baptiste receives SMS with lead name, phone, and error context within 2 minutes of the failed execution"
    why_human: "Requires live n8n instance with error workflow properly linked and real Twilio credentials"
---

# Phase 1: Critical Path Verification Report

**Phase Goal:** A real Google Ads lead triggers a personalized AI response to the prospect and an actionable notification to the owner — in under 2 minutes — for one client
**Verified:** 2026-03-27
**Status:** gaps_found — 1 structural gap (error workflow not linked in JSON), 2 items requiring live environment human verification
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A test lead submitted via Google Ads Lead Form webhook reaches n8n and is logged with its raw payload within seconds | VERIFIED | `responseMode=onReceived` in webhook node; `console.log('RAW_LEAD:', JSON.stringify(lead))` + `staticData.lastLead` write confirmed in Code: Log Raw Payload node |
| 2 | The prospect receives a personalized SMS within 2 minutes that reformulates their stated need and confirms a callback — no prices, no promises, no hallucinated details | VERIFIED (static) / HUMAN for timing | `claude-haiku-4-5` call with French SMS prompt embedded; 155-char truncation; `<prospect_input>` XML wrapping; Twilio SMS (Prospect) node wired to `$json.phone`. Prompt enforces no prices/promises. 2-min SLA needs live test. |
| 3 | The owner receives an SMS with the prospect's name, need, and phone number plus a one-tap `tel:` link to call back immediately | VERIFIED | `tel:${phone}` in Format Owner Notification code node confirmed; `$env.OWNER_PHONE` in Twilio SMS (Owner); both SMS and email branches converge to owner notification |
| 4 | Submitting the same `lead_id` twice results in exactly one message sent (deduplication works) | VERIFIED | `removeItemsSeenInPreviousExecutions` with `deduplicationKey={{ $json.lead_id }}` and `historySize: 10000`; duplicate fixture `test-lead-001` present in payloads |
| 5 | If the Claude or Twilio call fails, Baptiste receives the raw lead data by SMS so no lead is silently dropped | PARTIAL | Error handler workflow is fully implemented with staticData recovery and Twilio fallback SMS. However, the `errorWorkflow` field is absent from `speed-to-lead-main.json` settings — the error handler will not be automatically triggered unless manually linked after import |

**Score:** 4/5 truths fully verified; 1 partial (error handler not linked in JSON)

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tests/payloads/google-ads-lead.json` | Happy-path webhook payload | VERIFIED | Correct schema, FULL_NAME + PHONE_NUMBER + EMAIL + demande, lead_id test-lead-001 |
| `tests/payloads/google-ads-lead-duplicate.json` | Same lead_id for dedup test | VERIFIED | Identical to happy-path, same lead_id test-lead-001 |
| `tests/payloads/google-ads-lead-invalid-key.json` | Bad google_key payload | VERIFIED | `WRONG_KEY_INTENTIONALLY_INVALID` in google_key field, separate lead_id test-lead-002 |
| `tests/payloads/google-ads-lead-email-only.json` | No PHONE_NUMBER for Brevo test | VERIFIED | No PHONE_NUMBER column in user_column_data, lead_id test-lead-003 |
| `tests/test-webhook.sh` | Shell test runner for all scenarios | VERIFIED | Executable; sed-substitutes GOOGLE_KEY at runtime; supports happy/duplicate/invalid-key/email-only/all flags |
| `tests/TESTING.md` | End-to-end testing guide | VERIFIED (existence only) | Present; content not fully read but SUMMARY confirms per-plan checklists |
| `config/dupont-plomberie.json` | Per-client config with all required fields | VERIFIED | client_slug, business_name, service_type, city, owner_phone, callback_promise_minutes, env_vars_required all present |
| `prompts/prospect-sms-fr.txt` | Claude SMS prompt template in French | VERIFIED | 160-char constraint, CALLBACK_MINUTES variable, forbidden-example guidance, no prices/guarantees |
| `workflows/speed-to-lead-main.json` | 12-node main workflow, no TODO stubs | VERIFIED | All 12 nodes present and fully parameterized; connections map complete; zero TODO patterns found |
| `workflows/speed-to-lead-error-handler.json` | 3-node error handler, complete | VERIFIED | Error Trigger -> Code: Format Fallback SMS -> HTTP Request: Twilio SMS (Baptiste); all nodes implemented |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Webhook node | Code: Log Raw Payload | n8n connection + responseMode=onReceived | WIRED | `responseMode: onReceived` in node params; connection confirmed in connections map |
| Code: Log Raw Payload | staticData.lastLead | `$getWorkflowStaticData('global')` | WIRED | jsCode writes `staticData.lastLead = JSON.stringify(lead)` and `staticData.lastLeadTime` |
| IF: google_key valid? | $env.GOOGLE_KEY | n8n environment variable comparison | WIRED | leftValue `$json.google_key` equals rightValue `$env.GOOGLE_KEY`; FALSE branch has no connection (silent 200) |
| Remove Duplicates: lead_id | $json.lead_id | dedup key configuration | WIRED | `deduplicationKey={{ $json.lead_id }}` with `removeItemsSeenInPreviousExecutions` |
| HTTP Request: Claude API | api.anthropic.com/v1/messages | HTTP POST with x-api-key header | WIRED | URL hardcoded; `$env.ANTHROPIC_API_KEY` in header; model `claude-haiku-4-5`; system prompt embedded verbatim from prompts/prospect-sms-fr.txt content |
| Code: Truncate SMS to 155 chars | $json.content[0].text | Claude response parsing | WIRED | `$json.content?.[0]?.text` with 155-char truncation and ellipsis |
| IF: phone available? | $json.phone | isNotEmpty condition | WIRED | `leftValue={{ $json.phone }}` with `isNotEmpty` operator; TRUE->Twilio, FALSE->Brevo |
| HTTP Request: Twilio SMS (Prospect) | $json.phone | Twilio To parameter | WIRED | `To={{ $json.phone }}`; `From={{ $env.TWILIO_SENDER_ID }}`; `Body={{ $json.claude_message }}` |
| Brevo: Send Email (Prospect) | $json.email | Brevo node toEmail | WIRED | `toEmail={{ $json.email }}`; HTML body with `$json.claude_message` |
| Code: Format Owner Notification | $json.phone (tel: URI) | tel: URI construction | WIRED | `` `tel:${phone}` `` in jsCode confirmed; truncated to 320 chars |
| HTTP Request: Twilio SMS (Owner) | $env.OWNER_PHONE | Twilio To parameter | WIRED | `To={{ $env.OWNER_PHONE }}`; same Twilio pattern as prospect node |
| Both Twilio + Brevo branches | Code: Format Owner Notification | dual convergence connection | WIRED | Connections map shows both Twilio Prospect and Brevo Email connect to Code: Format Owner Notification |
| Code: Format Fallback SMS | staticData.lastLead | `$getWorkflowStaticData('global')` read | WIRED | `staticData.lastLead ? JSON.parse(staticData.lastLead) : null` with graceful no-data fallback |
| HTTP Request: Twilio SMS (Baptiste) | $env.BAPTISTE_PHONE | Twilio To parameter | WIRED | `To={{ $env.BAPTISTE_PHONE }}` confirmed |
| **workflows/speed-to-lead-main.json (settings)** | **workflows/speed-to-lead-error-handler.json** | **n8n errorWorkflow setting** | **NOT WIRED** | `settings` block contains only `{"executionOrder": "v1"}` — no `errorWorkflow` field. The error handler workflow is referenced only in `_setup_notes` as a manual post-import step. |

---

## Data-Flow Trace (Level 4)

This project is an n8n workflow (not a web app with components), so data-flow is traced through the node chain rather than React state.

| Node | Data Variable | Source | Produces Real Data | Status |
|------|--------------|--------|-------------------|--------|
| Webhook node | `$json` (full lead payload) | Google Ads webhook POST | Real on live; fixture in tests | FLOWING |
| Code: Extract Lead Fields | `$json.phone`, `$json.name`, `$json.request` | Parsed from `user_column_data` array loop | Parses actual payload fields | FLOWING |
| HTTP Request: Claude API | `content[0].text` | Anthropic API response | Real AI-generated text (needs credentials) | FLOWING (live dependency) |
| Code: Truncate SMS | `$json.claude_message` | Claude response content | Carries full lead fields forward | FLOWING |
| Code: Format Owner Notification | `$json.owner_sms` | Phone/name/request from truncation node | Builds SMS from real lead fields | FLOWING |

---

## Behavioral Spot-Checks

Step 7b: SKIPPED — n8n workflow JSON is not directly executable without a running n8n instance. The test-webhook.sh script requires a live n8n instance and real credentials. Static structure checks serve as the equivalent verification.

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| INGEST-01 | 01-01, 01-02, 01-03 | Receive Google Ads leads via HTTP POST webhook | SATISFIED | Webhook node with `path=dupont-plomberie`, `responseMode=onReceived`; test fixtures send valid POST payloads |
| INGEST-02 | 01-01, 01-03 | Deduplicate leads by lead_id | SATISFIED | `removeItemsSeenInPreviousExecutions` with `deduplicationKey={{ $json.lead_id }}`; duplicate fixture with same lead_id |
| INGEST-03 | 01-01, 01-03 | Log raw payload for audit/debug | SATISFIED | `console.log('RAW_LEAD:', JSON.stringify(lead))` + `staticData.lastLead` write in Code: Log Raw Payload |
| INGEST-04 | 01-01, 01-03 | Validate webhook via google_key | SATISFIED | IF node compares `$json.google_key` to `$env.GOOGLE_KEY`; invalid-key fixture for testing; FALSE branch silent |
| RESP-01 | 01-05 | Generate personalized message via Claude API reformulating prospect request | SATISFIED | `claude-haiku-4-5` call with prospect data in `<prospect_input>` tags; system prompt instructs reformulation |
| RESP-02 | 01-05 | Send message by SMS via Twilio if phone available | SATISFIED | IF routing on `$json.phone` isNotEmpty; Twilio SMS (Prospect) node with `To=$json.phone` |
| RESP-03 | 01-05 | Send message by email via Brevo if only email available | SATISFIED | FALSE branch of phone IF routes to Brevo: Send Email (Prospect) with `toEmail=$json.email` |
| RESP-04 | 01-02, 01-05 | Claude prompt adapted to client's trade/business | SATISFIED | System prompt embeds `$env.BUSINESS_NAME`, `$env.SERVICE_TYPE`, `$env.CITY`; client config defines these; prompt template in prompts/prospect-sms-fr.txt |
| RESP-05 | 01-05, 01-06 | Message sent in under 2 minutes after lead submission | SATISFIED (static) / HUMAN (timing) | Workflow is synchronous; no artificial delays; 2-min SLA requires live test to confirm |
| NOTIF-01 | 01-06 | Owner receives SMS with lead key info (name, request, phone) | SATISFIED | Format Owner Notification code builds SMS with `name`, `request`, and `tel:${phone}` or email fallback |
| NOTIF-02 | 01-06 | Notification contains tel: link for one-tap callback | SATISFIED | `` `tel:${phone}` `` confirmed in jsCode of Code: Format Owner Notification node |
| NOTIF-04 | 01-04, 01-06 | On pipeline error, Baptiste receives raw lead as fallback SMS | PARTIAL | Error handler workflow is fully implemented and self-contained. However, the main workflow does not have `errorWorkflow` set in its settings JSON — the link must be manually established after import. This is a deployment gap, not an implementation gap. |

**Orphaned requirements check:** NOTIF-03 (follow-up after delay) is correctly assigned to Phase 2 and does not appear in Phase 1 plans — not orphaned.

---

## Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `workflows/speed-to-lead-main.json` settings | Missing `errorWorkflow` field | Blocker | Error handler will not fire automatically on pipeline failure unless manually linked after every import. Defeats NOTIF-04 guarantee for anyone importing from the JSON file. |
| `config/dupont-plomberie.json` | `owner_phone: "+33600000000"` (placeholder number) | Warning | This is clearly a placeholder/example number. Must be replaced with real owner phone before any production deployment. Non-blocking for testing. |

No TODO comments, empty implementations, or return null patterns found in any workflow JSON.

---

## Human Verification Required

### 1. End-to-End 2-Minute SLA Test

**Test:** With live n8n instance, real Anthropic API key, real Twilio account, and real Brevo account — import both workflows, set all env vars, activate the main workflow, run `GOOGLE_KEY=<real_key> ./tests/test-webhook.sh happy`. Check the phone number configured as `OWNER_PHONE`.
**Expected:** (1) Prospect phone receives a French SMS under 155 chars reformulating the plumbing request, within 2 minutes. (2) Owner phone receives SMS with name, request snippet, and a `tel:+336...` link immediately after.
**Why human:** Requires real API credentials and live Twilio/Anthropic calls. Cannot verify 2-minute SLA or actual message content statically.

### 2. Error Fallback Activation Test

**Test:** Import both workflows, link error handler in main workflow Settings > Error Workflow. Set `ANTHROPIC_API_KEY` to an invalid value. Send a test payload. Check Baptiste's phone (`BAPTISTE_PHONE`).
**Expected:** Baptiste receives an SMS within 2 minutes containing the lead name, phone number, and an error message indicating Claude API failed.
**Why human:** Requires live n8n instance with error workflow actively linked. The JSON gap (missing `errorWorkflow` in settings) must be resolved first — either by adding it to the JSON or manually linking in n8n UI.

---

## Gaps Summary

**1 blocker gap** preventing full automated confidence in goal achievement:

**Error workflow not encoded in main workflow JSON.** The `workflows/speed-to-lead-main.json` settings block contains only `{"executionOrder": "v1"}`. The `errorWorkflow` field linking to the error handler is absent. This means:
- Anyone importing the workflow JSON into a new n8n instance gets NO error fallback without a manual step that is easy to miss.
- The NOTIF-04 guarantee ("no lead silently dropped") depends on this link existing.
- The `_setup_notes` in the error handler JSON documents this as a manual step, but documentation is not enforcement.

The gap is in deployment wiring, not in implementation logic — both workflows are correctly implemented. The fix is to add the `errorWorkflow` reference to the main workflow's settings block before shipping. Note that n8n error workflow references typically use the workflow's internal n8n ID (assigned at runtime), so this may require a workflow-ID placeholder or documentation approach. If n8n supports referencing by name in the JSON settings, that should be used.

**No other implementation stubs or anti-patterns found.** All 12 main workflow nodes and all 3 error handler nodes are fully parameterized with no TODO comments or empty code blocks.

---

_Verified: 2026-03-27_
_Verifier: Claude (gsd-verifier)_
