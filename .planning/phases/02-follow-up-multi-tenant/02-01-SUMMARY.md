---
phase: 02-follow-up-multi-tenant
plan: 01
subsystem: config
tags: [n8n, twilio, multi-tenant, config-schema, brevo, follow-up]

# Dependency graph
requires:
  - phase: 01-critical-path
    provides: "Initial dupont-plomberie.json with Phase 1 env_vars_required schema"
provides:
  - "Extended per-client config schema with follow-up fields and per-client prefixed env var registry"
  - "config/dupont-plomberie.json with follow_up_delay_minutes, follow_up_enabled, brevo_sender_email, DUPONT_* prefixed env vars"
  - "config/cabinet-martin.json — second client proving multi-tenant schema reusability"
affects:
  - 02-02-core-workflow
  - 02-03-entry-workflows
  - future-client-onboarding

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-client env var naming: SLUG_TWILIO_ACCOUNT_SID, SLUG_TWILIO_AUTH_TOKEN, SLUG_GOOGLE_KEY (uppercase slug prefix)"
    - "Config registry pattern: env_vars_required object stores key names + human descriptions, never values"
    - "follow_up_delay_minutes is per-client config — Core Workflow reads from payload, not hardcoded constants"

key-files:
  created:
    - config/cabinet-martin.json
  modified:
    - config/dupont-plomberie.json

key-decisions:
  - "Per-client Twilio prefix (DUPONT_/MARTIN_) prevents credential collision when multiple clients share one n8n instance"
  - "brevo_sender_email stored in config (non-sensitive); Twilio SID/token/key stored as env vars only"
  - "follow_up_delay_minutes in config lets each client have different delay (plumber=45min, lawyer=120min)"

patterns-established:
  - "Pattern: Per-client env var prefix (SLUG_SERVICE_CREDENTIAL) — all future clients follow CLIENTSLUG_TWILIO_* naming"
  - "Pattern: env_vars_required as installation checklist — key is env var name, value is human-readable description for setup"

requirements-completed: [CONF-01]

# Metrics
duration: 2min
completed: 2026-03-28
---

# Phase 02 Plan 01: Config Schema Extension Summary

**Phase 2 config contract locked — per-client prefixed Twilio credentials (DUPONT_/MARTIN_) and follow-up fields in JSON; second client (cabinet-martin) proves multi-tenant reusability with no plain-text credentials in git.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-28T14:50:02Z
- **Completed:** 2026-03-28T14:51:07Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Extended dupont-plomberie.json with follow_up_delay_minutes=45, follow_up_enabled=true, brevo_sender_email, and DUPONT_ prefixed env var names
- Created cabinet-martin.json as the second client config with MARTIN_ prefixed env vars and lawyer-appropriate delays (60/120min)
- Locked the per-client env var naming convention (SLUG_TWILIO_ACCOUNT_SID) before Plans 02 and 03 write against it

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend dupont-plomberie.json with Phase 2 fields** - `aa3e144` (feat)
2. **Task 2: Create cabinet-martin.json (second client config)** - `ddfb133` (feat)

**Plan metadata:** (docs commit to follow)

## Files Created/Modified

- `config/dupont-plomberie.json` - Extended with follow_up_delay_minutes, follow_up_enabled, brevo_sender_email, DUPONT_-prefixed env var names; removed owner_whatsapp (Phase 3)
- `config/cabinet-martin.json` - New second client config (Cabinet Martin Avocats, Lyon, avocat) with MARTIN_-prefixed env vars and 60/120min delays

## Decisions Made

- Per-client Twilio prefix (DUPONT_/MARTIN_) prevents credential collision when multiple clients share one n8n instance — any workflow Code node must reference `$env.DUPONT_TWILIO_ACCOUNT_SID` not `$env.TWILIO_ACCOUNT_SID`
- brevo_sender_email stored in config file (non-sensitive domain); Twilio SID/token and google_key stored by env var name only
- follow_up_delay_minutes varies per client (45min for plumber, 120min for lawyer) — the Core Workflow reads this from the payload rather than hardcoded constants

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Node.js v24 in TypeScript-strict mode rejected `!!` in `-e` eval string (shell escaping conflict). Switched to `--input-type=module` heredoc for verification scripts. No functional impact.

## User Setup Required

None - no external service configuration required for this plan. Config files contain only env var registries (key names + descriptions), not values. Actual credentials are set separately as n8n environment variables.

## Known Stubs

None - these config files are the ground truth, not stubs. Actual Twilio credentials and Google keys must be populated as n8n env vars during client onboarding (per env_vars_required registry in each file).

## Next Phase Readiness

- Config contract locked — Plans 02-02 (Core Workflow) and 02-03 (Entry Workflows) can now reference `$env.DUPONT_TWILIO_ACCOUNT_SID` and `$env.MARTIN_TWILIO_ACCOUNT_SID` with confidence
- Multi-tenant pattern established: any new client gets a new config file + CLIENTSLUG_ prefixed env vars in n8n
- No blockers

---
*Phase: 02-follow-up-multi-tenant*
*Completed: 2026-03-28*

## Self-Check: PASSED

- config/dupont-plomberie.json: FOUND
- config/cabinet-martin.json: FOUND
- 02-01-SUMMARY.md: FOUND
- Commit aa3e144 (Task 1): FOUND
- Commit ddfb133 (Task 2): FOUND
