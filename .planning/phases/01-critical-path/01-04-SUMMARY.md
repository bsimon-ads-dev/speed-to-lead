---
phase: 01-critical-path
plan: 04
subsystem: infra
tags: [n8n, twilio, sms, error-handler, static-data, fallback]

# Dependency graph
requires:
  - phase: 01-critical-path plan 03
    provides: staticData.lastLead written by Code: Log Raw Payload node in main workflow

provides:
  - Error handler workflow end-to-end: Error Trigger -> Code: Format Fallback SMS -> HTTP Request: Twilio SMS (Baptiste)
  - staticData.lastLead recovery with user_column_data parsing for name and phone
  - Graceful no-lead-data fallback SMS (sends error info even without lead payload)

affects:
  - 01-05 (main workflow Claude SMS node — must have error workflow set in Settings)
  - 01-06 (end-to-end validation requires error handler configured and linked)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Error fallback via separate n8n workflow with Error Trigger node"
    - "staticData cross-workflow read: $getWorkflowStaticData('global').lastLead"
    - "SMS 320-char truncation (2 segments) as hard limit for fallback messages"
    - "Twilio REST API via HTTP Request node with genericCredentialType httpBasicAuth"

key-files:
  created: []
  modified:
    - workflows/speed-to-lead-error-handler.json

key-decisions:
  - "genericCredentialType httpBasicAuth chosen for Twilio auth — requires manual credential creation after import (documented in _setup_notes)"
  - "320-char SMS limit (2 segments) chosen for fallback — enough to include error + lead name + phone without wasting budget on a 3-segment failure notification"
  - "user_column_data parsed inline in error handler (not relying on already-extracted fields) — error may fire before Extract Fields node runs"

patterns-established:
  - "Pattern: _setup_notes top-level JSON field documents post-import manual steps for workflows requiring credentials"

requirements-completed: [NOTIF-04]

# Metrics
duration: 2min
completed: 2026-03-28
---

# Phase 01 Plan 04: Error Handler Workflow Summary

**Error fallback workflow (Error Trigger -> staticData recovery -> Twilio SMS Baptiste) fully implemented with user_column_data parsing and no-lead-data graceful degradation**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-28T13:58:55Z
- **Completed:** 2026-03-28T14:00:16Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Code: Format Fallback SMS reads staticData.lastLead from main workflow, parses user_column_data array to extract FULL_NAME and PHONE_NUMBER, formats a 320-char-max fallback SMS for Baptiste
- Fallback SMS handles two cases: lead data present (name + phone + truncated request + lead ID) and no lead data (error message + last node only)
- HTTP Request: Twilio SMS (Baptiste) configured with Twilio REST API, env var references for BAPTISTE_PHONE / TWILIO_SENDER_ID / TWILIO_ACCOUNT_SID, and _setup_notes documenting post-import credential creation steps
- All three nodes remain connected in correct order: Error Trigger -> Code -> Twilio

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement Code: Format Fallback SMS node** - `892ee55` (feat)
2. **Task 2: Implement HTTP Request: Twilio SMS (Baptiste) node** - `04485f9` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `workflows/speed-to-lead-error-handler.json` - Skeleton upgraded to full implementation: jsCode in Code node + parameters in Twilio HTTP Request node + _setup_notes top-level field

## Decisions Made
- Used `genericCredentialType` / `httpBasicAuth` for Twilio auth rather than hardcoding credentials in the URL — cleaner and follows n8n credential pattern. Requires one-time setup step after import, documented in `_setup_notes`.
- Parsed `user_column_data` directly in error handler Code node rather than relying on an earlier Extract Fields node. This is intentional: the error may fire before Extract Fields runs, so the fallback must be self-contained and reconstruct lead fields from raw staticData.
- Set 320-char SMS limit (2 segments): enough room to communicate error context AND lead identity without generating a 3-segment failure notification that wastes Twilio budget.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

After importing this workflow into n8n, three manual steps are required (documented in `_setup_notes` field of the workflow JSON):

1. Create an n8n Basic Auth credential named **"Twilio Basic Auth"** with:
   - Username: value of `TWILIO_ACCOUNT_SID` env var
   - Password: value of `TWILIO_AUTH_TOKEN` env var
2. In the **main workflow Settings > Error Workflow**, select "Speed to Lead — Error Handler"
3. Set the `BAPTISTE_PHONE` environment variable to Baptiste's mobile in E.164 format (`+33XXXXXXXXX`)

## Next Phase Readiness

- Error handler workflow is complete and ready to be linked to the main workflow
- Plan 05 (Claude + prospect SMS) and Plan 06 (owner notification) can proceed — the error fallback is now in place before production SMS sends go live
- One pre-condition before go-live: Twilio credential must be created in n8n UI and linked to the HTTP Request node

---
*Phase: 01-critical-path*
*Completed: 2026-03-28*
