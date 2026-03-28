---
phase: 01-critical-path
plan: 03
subsystem: ingestion
tags: [n8n, webhook, validation, dedup, field-extraction, google-ads, security]

# Dependency graph
requires:
  - 01-02 (workflow skeleton with pre-wired nodes)
provides:
  - Complete ingestion layer: webhook (200 immediate) + raw log (staticData + console.log) + google_key validation + lead_id dedup + field extraction
  - INGEST-01, INGEST-02, INGEST-03, INGEST-04 requirements all satisfied
affects: [01-04, 01-05, 01-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "n8n Webhook responseMode=onReceived: returns HTTP 200 before any processing node runs"
    - "getWorkflowStaticData('global') for cross-execution data persistence: error handler can read lastLead even if pipeline fails"
    - "IF node typeVersion 2 condition format: leftValue/rightValue/operator object with id field"
    - "Remove Duplicates removeItemsSeenInPreviousExecutions: cross-execution dedup stored in n8n DB (Postgres)"
    - "user_column_data parsing: loop over array, map column_name to value, produce flat output object"

key-files:
  created: []
  modified:
    - workflows/speed-to-lead-main.json

key-decisions:
  - "Webhook node responseMode=onReceived already correct in skeleton — no change needed, confirmed pattern works"
  - "staticData.lastLead stores full JSON.stringify(lead) not object — safe for error handler which does JSON.parse"
  - "is_test handled in Extract node not IF node — dedup still runs for test leads (intentional, avoids test-lead flood)"
  - "fields['MESSAGE'] fallback added to extract node — defensive against case variation in custom question column names"

requirements-completed: [INGEST-01, INGEST-02, INGEST-03, INGEST-04]

# Metrics
duration: 1min
completed: 2026-03-28
---

# Phase 01 Plan 03: Ingestion Layer Summary

**Complete n8n ingestion layer: webhook returns 200 immediately, raw payload logged to staticData + execution log, google_key validated against env var, lead_id cross-execution dedup, user_column_data parsed to flat fields**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-28T13:55:41Z
- **Completed:** 2026-03-28T13:56:51Z
- **Tasks:** 2 auto + 1 checkpoint (auto-approved)
- **Files modified:** 1

## Accomplishments

- Webhook node: confirmed `responseMode=onReceived` and `path=dupont-plomberie` (skeleton was already correct)
- Code: Log Raw Payload: implements `console.log('RAW_LEAD:', JSON.stringify(lead))` for execution log visibility + `getWorkflowStaticData('global')` write of `lastLead` and `lastLeadTime` for error handler recovery
- IF: google_key valid?: typeVersion 2 condition comparing `{{ $json.google_key }}` to `{{ $env.GOOGLE_KEY }}` via string equals — FALSE branch has no connection (silent 200, no retry signal to Google)
- Remove Duplicates: lead_id: `removeItemsSeenInPreviousExecutions` operation with `{{ $json.lead_id }}` dedup key and `historySize: 10000` — cross-execution persistence via n8n DB
- Code: Extract Lead Fields: loops over `user_column_data` array, maps `column_name` → `string_value`, outputs flat object with `lead_id`, `is_test`, `phone`, `email`, `name`, `request`, `submit_time`, `raw`

## Task Commits

1. **Task 1: Webhook node + Code: Log Raw Payload** - `8012234` (feat)
2. **Task 2: google_key validation + dedup + field extraction** - `ba93b9e` (feat)
3. **Task 3: checkpoint:human-verify** - auto-approved (auto_advance=true)

**Plan metadata:** (docs commit — pending)

## Files Created/Modified

- `workflows/speed-to-lead-main.json` — 5 ingestion nodes fully configured (3 were TODO stubs, 2 confirmed correct)

## Decisions Made

- staticData stores `lastLead` as `JSON.stringify(lead)` (string, not object) — the error handler workflow does `JSON.parse(staticData.lastLead)` so the type contract is string→string
- `is_test` flag handled in Extract node (sets `isTest: lead.is_test === true`) not in a separate IF — dedup still runs for test leads intentionally to avoid test-lead ID exhaustion
- Fields `['MESSAGE']` added as third fallback for the `request` field in Extract node — defensive against custom question label case variation

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all 5 ingestion nodes are fully configured. Remaining workflow nodes (HTTP Request: Claude API, Code: Truncate SMS, IF: phone available?, Twilio nodes, Brevo node) remain as Plan 02 skeletons, but these are out of scope for Plan 03.

## Self-Check: PASSED

- FOUND: workflows/speed-to-lead-main.json
- FOUND commit: 8012234 (Task 1)
- FOUND commit: ba93b9e (Task 2)
- All 5 ingestion verification checks passed (see overall verification output above)

## Verification Results

```
PASS: webhook responseMode
PASS: log has staticData
PASS: IF reads body
PASS: dedup cross-execution
PASS: extract parses array
All ingestion checks passed
```

## Next Phase Readiness

- Plan 04 (error handler) can now read `staticData.lastLead` from the raw log node — the data contract is established
- Plan 05 (Claude API call) receives flat fields from Extract node: `$json.name`, `$json.request`, `$json.is_test` — no further parsing needed
- Plan 06 (owner notification) receives `$json.phone` and `$json.email` from Extract node for tel: link formatting
- No blockers for Plans 04-06

---
*Phase: 01-critical-path*
*Completed: 2026-03-28*
