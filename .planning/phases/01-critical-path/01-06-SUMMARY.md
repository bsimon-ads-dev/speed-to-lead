---
phase: 01-critical-path
plan: 06
subsystem: notifications
tags: [n8n, twilio, sms, tel-uri, owner-notification, error-handler]

# Dependency graph
requires:
  - phase: 01-critical-path/01-05
    provides: Twilio SMS (Prospect), Brevo email node, channel routing, Claude-generated message
  - phase: 01-critical-path/01-04
    provides: Error handler workflow with fallback SMS to Baptiste
provides:
  - Owner SMS notification with tel: one-tap callback link for phone leads
  - Owner SMS with email address fallback for email-only leads
  - Brevo branch wired into owner notification (both lead types notify owner)
  - Complete Phase 1 critical path — all 12 nodes fully implemented, no TODO stubs
affects: [02-follow-up, 03-whatsapp]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "tel: URI embedded in SMS body for one-tap dialing on iOS/Android"
    - "Dual-path convergence: both Twilio and Brevo branches connect to a single owner notification node"
    - "320-char SMS limit for owner (2 segments) vs 155-char limit for prospect (1 segment)"

key-files:
  created: []
  modified:
    - workflows/speed-to-lead-main.json

key-decisions:
  - "OWNER_PHONE env var for owner SMS destination — matches pattern used for BAPTISTE_PHONE in error handler"
  - "Brevo branch connection added to Code: Format Owner Notification — ensures email-only leads also generate owner notification"
  - "tel: URI format: tel:${phone} — uses E.164 phone from Google Ads, no reformatting needed"
  - "320-char truncation on owner SMS (2 SMS segments) — sufficient for name + request snippet + tel: link"

patterns-established:
  - "Owner notification: always fires regardless of whether prospect channel was SMS or email"
  - "tel: link pattern: append tel:${phone} directly — E.164 format already in $json.phone from Google Ads"

requirements-completed: [NOTIF-01, NOTIF-02, NOTIF-04, RESP-05]

# Metrics
duration: 3min
completed: 2026-03-28
---

# Phase 01 Plan 06: Owner Notification Summary

**Owner SMS with tel: one-tap callback link, both lead channels converging to owner notification, completing the full Phase 1 critical path with 12/12 nodes implemented**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-28T14:05:00Z
- **Completed:** 2026-03-28T14:07:10Z
- **Tasks:** 1 auto + 1 checkpoint (auto-approved)
- **Files modified:** 1

## Accomplishments
- Replaced TODO stub in "Code: Format Owner Notification" with full implementation: tel: link for phone leads, email address for email-only leads, 320-char truncation
- Implemented "HTTP Request: Twilio SMS (Owner)" with OWNER_PHONE env var, TWILIO_SENDER_ID sender, and owner_sms body field using same httpBasicAuth pattern as prospect node
- Added Brevo branch connection to "Code: Format Owner Notification" so email-only leads also trigger owner notification
- All 13 Phase 1 structural checks pass (onReceived, staticData, GOOGLE_KEY, dedup, user_column_data, claude-haiku-4-5, prompt injection protection, 155-char truncation, TWILIO_SENDER_ID, tel: URI, OWNER_PHONE, error handler staticData, BAPTISTE_PHONE)
- 12/12 nodes fully implemented — zero TODO stubs remain

## Task Commits

1. **Task 1: Implement owner notification nodes and fix Brevo branch connection** - `81c8d88` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `workflows/speed-to-lead-main.json` - Owner notification nodes fully implemented; Brevo branch wired to owner notification

## Decisions Made
- OWNER_PHONE env var for owner SMS destination — consistent with BAPTISTE_PHONE pattern in error handler
- tel: URI appended directly as `tel:${phone}` — Google Ads already provides E.164 format, no reformatting required
- Brevo branch connects to Code: Format Owner Notification — ensures owner always notified regardless of channel
- 320-char truncation on owner SMS (2 segments) vs 155-char prospect limit — owner message includes name + request + tel: link which needs slightly more room

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

**After importing both workflows into n8n, the following manual steps are required:**

1. Create n8n credentials:
   - "Twilio Basic Auth" (HTTP Basic Auth type): Username = TWILIO_ACCOUNT_SID value, Password = TWILIO_AUTH_TOKEN value
   - "Anthropic HTTP Header Auth" (HTTP Header Auth type): Header Name = x-api-key, Value = ANTHROPIC_API_KEY value
   - "Brevo API" (Brevo credential type): API Key = BREVO_API_KEY value

2. Set environment variables in n8n:
   - `GOOGLE_KEY`, `ANTHROPIC_API_KEY`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`
   - `TWILIO_SENDER_ID`, `OWNER_PHONE`, `BAPTISTE_PHONE`
   - `BUSINESS_NAME`, `SERVICE_TYPE`, `CITY`, `CALLBACK_MINUTES`
   - `BREVO_API_KEY`, `BREVO_SENDER_EMAIL`

3. In main workflow Settings > Error Workflow: select "Speed to Lead — Error Handler"

4. Activate the main workflow (toggle to Active)

## Next Phase Readiness

Phase 1 critical path is complete. Full workflow is ready for:
- End-to-end live testing with real Twilio/Anthropic credentials
- First client deployment (Dupont Plomberie or next client)
- Phase 2: Follow-up logic (Wait node, callback tracking)
- Phase 3: WhatsApp channel (Twilio WABA onboarding)

Blockers:
- RGPD: Consent checkbox copy for lead forms should be reviewed against CNIL guidance before first client go-live
- WhatsApp Phase 3: Validate Twilio WABA France onboarding timeline before committing client launch date

---
*Phase: 01-critical-path*
*Completed: 2026-03-28*
