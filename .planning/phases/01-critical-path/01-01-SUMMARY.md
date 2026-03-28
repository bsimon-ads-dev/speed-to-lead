---
phase: 01-critical-path
plan: 01
subsystem: testing
tags: [n8n, google-ads, webhook, curl, bash, json, fixtures]

requires: []
provides:
  - Four JSON test payload fixtures covering all webhook scenarios (happy path, dedup, invalid key, email-only)
  - Shell test runner script with per-scenario flags and GOOGLE_KEY substitution
  - End-to-end testing guide with per-plan verification checklists
affects: [01-02, 01-03, 01-04, 01-05, 01-06]

tech-stack:
  added: []
  patterns:
    - "Test fixtures use REPLACE_WITH_YOUR_GOOGLE_KEY placeholder; test script substitutes via sed before curl POST"
    - "All test scenarios driven by single test-webhook.sh with scenario flag: happy|duplicate|invalid-key|email-only|all"

key-files:
  created:
    - tests/payloads/google-ads-lead.json
    - tests/payloads/google-ads-lead-duplicate.json
    - tests/payloads/google-ads-lead-invalid-key.json
    - tests/payloads/google-ads-lead-email-only.json
    - tests/test-webhook.sh
    - tests/TESTING.md
  modified: []

key-decisions:
  - "google_key kept as placeholder in JSON files; substituted at runtime via sed to avoid committing real credentials"
  - "Duplicate fixture is an exact copy of happy-path fixture (same lead_id test-lead-001) — dedup test relies on identical lead_id"
  - "Script defaults to webhook-test URL (workflow open mode) so development testing requires no workflow activation"

patterns-established:
  - "Fixture pattern: static JSON with REPLACE_WITH_YOUR_GOOGLE_KEY sentinel replaced by test script at send time"
  - "Verification pattern: each plan wave has explicit checklist items in TESTING.md"

requirements-completed: [INGEST-01, INGEST-02, INGEST-03, INGEST-04]

duration: 8min
completed: 2026-03-28
---

# Phase 01 Plan 01: Test Fixture Library Summary

**Four Google Ads Lead Form webhook payloads and bash test runner covering happy path, deduplication, auth rejection, and email-only scenarios**

## Performance

- **Duration:** 8 min
- **Started:** 2026-03-28T13:47:44Z
- **Completed:** 2026-03-28T13:55:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created four valid JSON fixtures matching the Google Ads Lead Form webhook payload schema exactly
- Duplicate fixture shares lead_id "test-lead-001" with happy-path fixture for unambiguous deduplication testing
- test-webhook.sh substitutes GOOGLE_KEY via sed at runtime — no real credentials committed to the repo
- TESTING.md provides per-plan verification checklists from Plan 02 through Plan 06, including NOTIF-04 error fallback procedure

## Task Commits

Each task was committed atomically:

1. **Task 1: Create test payload JSON files** - `cef8b35` (feat)
2. **Task 2: Create test runner script and testing guide** - `95d552f` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `tests/payloads/google-ads-lead.json` - Happy-path lead with phone + email (lead_id: test-lead-001)
- `tests/payloads/google-ads-lead-duplicate.json` - Identical to above — same lead_id for dedup test
- `tests/payloads/google-ads-lead-invalid-key.json` - lead_id test-lead-002, google_key WRONG_KEY_INTENTIONALLY_INVALID
- `tests/payloads/google-ads-lead-email-only.json` - lead_id test-lead-003, no PHONE_NUMBER field
- `tests/test-webhook.sh` - Executable bash script, sed-substitutes GOOGLE_KEY, supports 5 scenario flags
- `tests/TESTING.md` - End-to-end testing guide with per-plan checklists and webhook URL mode table

## Decisions Made
- Placeholder `REPLACE_WITH_YOUR_GOOGLE_KEY` used in JSON files rather than leaving field empty — makes substitution point obvious and script logic clean
- Script defaults to `webhook-test/{slug}` (test mode URL) so n8n workflow need not be activated for basic development tests
- `CLIENT_SLUG` defaults to `dupont-plomberie` matching the first client persona used throughout research docs

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required. Test fixtures work locally as soon as n8n is running.

## Next Phase Readiness
- All fixture files ready for use in Plan 02+ verification steps
- TESTING.md provides the exact commands each plan's verify step can reference
- test-webhook.sh is the canonical test command — future plans should add their verification steps to TESTING.md rather than inventing ad-hoc curl commands

---
*Phase: 01-critical-path*
*Completed: 2026-03-28*
