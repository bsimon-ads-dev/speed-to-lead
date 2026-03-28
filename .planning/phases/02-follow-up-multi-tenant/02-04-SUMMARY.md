---
phase: 02-follow-up-multi-tenant
plan: "04"
subsystem: testing
tags: [shell, bash, n8n, multi-tenant, follow-up, smoke-test]

# Dependency graph
requires:
  - phase: 02-follow-up-multi-tenant
    provides: Entry workflows for dupont-plomberie and cabinet-martin with per-client slug routing
provides:
  - Updated test-webhook.sh accepting positional slug argument for multi-client targeting
  - Phase 2 testing procedures in TESTING.md covering CONF-01, CONF-02, CONF-03, NOTIF-03
  - Phase 2 acceptance checklist for pre-launch verification
affects:
  - 03-whatsapp (smoke test procedures apply to future clients)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Positional argument with default for client slug: SLUG="${2:-dupont-plomberie}"
    - RESTORE reminder pattern for temporary test config changes (follow_up_delay_minutes)

key-files:
  created: []
  modified:
    - tests/test-webhook.sh
    - tests/TESTING.md

key-decisions:
  - "Positional argument (not env var) for slug — consistent with existing SCENARIO positional arg, simpler CLI UX"
  - "RESTORE reminder embedded in follow-up delay test procedure — prevents accidental 45-minute production waits"

patterns-established:
  - "Pattern 1: test-webhook.sh [scenario] [slug] — two-arg CLI pattern for targeting per-client entry workflows"
  - "Pattern 2: Phase acceptance checklist in TESTING.md with requirement ID cross-references for traceability"

requirements-completed: [CONF-03, NOTIF-03]

# Metrics
duration: 5min
completed: 2026-03-28
---

# Phase 2 Plan 04: Test Infrastructure Update Summary

**Shell test script extended to target both client slugs; TESTING.md gains Phase 2 procedures with 1-minute follow-up test and CONF-01/CONF-02/CONF-03/NOTIF-03 acceptance checklist**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-28T15:01:00Z
- **Completed:** 2026-03-28T15:01:46Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- test-webhook.sh now accepts `[slug]` as second positional argument defaulting to `dupont-plomberie`, enabling single-command multi-client smoke tests
- TESTING.md Phase 2 section covers all four requirements: multi-client smoke test (CONF-03), Core Workflow multi-tenant verification (CONF-02), 1-minute follow-up delay test with RESTORE reminder (NOTIF-03), business hours gate test (NOTIF-03), and credential isolation check (CONF-01)
- Phase 2 acceptance checklist table maps each requirement ID to its test procedure and expected result

## Task Commits

Each task was committed atomically:

1. **Task 1: Update test-webhook.sh to accept client slug parameter** - `a50d201` (feat)
2. **Task 2: Add Phase 2 testing section to TESTING.md** - `af8b3d5` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `tests/test-webhook.sh` - Added SLUG="${2:-dupont-plomberie}" positional arg, replaced CLIENT_SLUG env var, updated WEBHOOK_URL, added usage comment
- `tests/TESTING.md` - Appended Phase 2 section with 5 test procedures and acceptance checklist

## Decisions Made
- Used positional argument `$2` instead of a new env var for slug — consistent with existing `$1` for scenario, reduces required env var exports for multi-client testing
- Removed `CLIENT_SLUG` env var (was previously set but unused after this change) — callers now use `./test-webhook.sh happy cabinet-martin` style

## Deviations from Plan

The current `test-webhook.sh` already had `CLIENT_SLUG="${CLIENT_SLUG:-dupont-plomberie}"` set from a prior phase, plus `WEBHOOK_URL="${N8N_URL}/webhook-test/${CLIENT_SLUG}"`. The plan specified introducing `SLUG="${2:-dupont-plomberie}"` as a new variable. Applied as: removed `CLIENT_SLUG` env var line, added `SLUG` positional arg line, updated `WEBHOOK_URL` to reference `${SLUG}`. Net behavior: identical default, new second-arg override capability.

None — plan executed exactly as written (minor adaptation to merge with existing CLIENT_SLUG pattern, same outcome).

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 2 test infrastructure complete — all acceptance criteria for CONF-01, CONF-02, CONF-03, NOTIF-03 have documented verification procedures
- Ready for Phase 2 sign-off: run `./tests/test-webhook.sh happy dupont-plomberie` and `./tests/test-webhook.sh happy cabinet-martin`, then follow the Phase 2 Acceptance Checklist in TESTING.md
- Phase 3 (WhatsApp) can reuse the same `[scenario] [slug]` pattern when adding new client entry workflows

---
*Phase: 02-follow-up-multi-tenant*
*Completed: 2026-03-28*
