---
phase: 01-critical-path
plan: 02
subsystem: infra
tags: [n8n, json, workflow, claude, twilio, brevo, sms, webhook]

# Dependency graph
requires: []
provides:
  - Per-client config JSON schema with env_vars_required documentation (dupont-plomberie test client)
  - Importable n8n workflow skeleton — 12 nodes, all connections wired, ready for Plans 03-06 to fill parameters
  - Importable n8n error handler workflow skeleton — 3 nodes (errorTrigger, code, Twilio Baptiste)
  - Claude system prompt template in French with 160-char constraint and CALLBACK_MINUTES variable
affects: [01-03, 01-04, 01-05, 01-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "n8n workflow JSON skeleton pattern: nodes with TODO comments marking where later plans fill parameters"
    - "Client config JSON schema: env_vars_required field documents which n8n env vars are needed per client"
    - "Prompt template as .txt file: human-readable source of truth for Claude node system prompt"

key-files:
  created:
    - config/dupont-plomberie.json
    - prompts/prospect-sms-fr.txt
    - workflows/speed-to-lead-main.json
    - workflows/speed-to-lead-error-handler.json
  modified: []

key-decisions:
  - "Workflow skeleton approach: nodes present with TODO comments rather than empty JSON — Plans 03-06 build into a pre-existing structure to prevent node connection errors"
  - "env_vars_required field in client config: documents which n8n env vars must be set, serving as setup checklist"
  - "Prompt template stored as .txt file: single source of truth — Plan 05 executor embeds verbatim in Claude HTTP Request node"
  - "n8n expression syntax in prompt ({{ $env.* }}): resolved at runtime by n8n, not pre-processed"

patterns-established:
  - "Pattern: Per-client config JSON lives in config/{client-slug}.json"
  - "Pattern: Prompt templates live in prompts/{use-case}.txt with n8n expression syntax for runtime variables"
  - "Pattern: Workflow skeletons in workflows/{workflow-name}.json importable directly into n8n"

requirements-completed: [RESP-04, INGEST-01]

# Metrics
duration: 2min
completed: 2026-03-28
---

# Phase 01 Plan 02: File Structure Skeleton Summary

**n8n workflow JSON skeletons (12-node main + 3-node error handler), client config schema, and French Claude SMS prompt template — all artifacts Plans 03-06 build against**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-28T13:51:59Z
- **Completed:** 2026-03-28T13:53:39Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Client config JSON for dupont-plomberie test client with all required fields and env_vars_required documentation listing all 7 required n8n environment variables
- Claude system prompt template in French with strict 160-character limit, CALLBACK_MINUTES variable, and example acceptable/forbidden messages
- Main workflow skeleton with 12 nodes (webhook → log → IF validate → dedup → extract → Claude API → truncate → IF route → Twilio prospect → Brevo email → format owner → Twilio owner) all connections wired
- Error handler workflow skeleton with 3 nodes (errorTrigger → format fallback → Twilio Baptiste) ready for Plan 04

## Task Commits

Each task was committed atomically:

1. **Task 1: Create client config and prompt template** - `38b08ef` (feat)
2. **Task 2: Create importable n8n workflow JSON skeletons** - `10ca43c` (feat)

**Plan metadata:** (docs commit — pending)

## Files Created/Modified
- `config/dupont-plomberie.json` - Test client config with all required fields + env_vars_required documentation
- `prompts/prospect-sms-fr.txt` - Claude system prompt template with 160-char constraint, CALLBACK_MINUTES variable, French examples
- `workflows/speed-to-lead-main.json` - 12-node importable n8n workflow skeleton with all connections wired
- `workflows/speed-to-lead-error-handler.json` - 3-node importable n8n error handler skeleton

## Decisions Made
- Workflow skeleton approach adopted: nodes present with TODO comments rather than empty files, so Plans 03-06 build into a pre-existing structure — prevents node connection errors during incremental build
- `env_vars_required` field in client config serves as an installation checklist — executor setting up a new client can see exactly which n8n env vars to configure
- Prompt template stored as `.txt` with n8n expression syntax (`{{ $env.* }}`): single source of truth, Plan 05 executor embeds it verbatim in the Claude HTTP Request node

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## Self-Check: PASSED

- FOUND: config/dupont-plomberie.json
- FOUND: prompts/prospect-sms-fr.txt
- FOUND: workflows/speed-to-lead-main.json
- FOUND: workflows/speed-to-lead-error-handler.json
- FOUND: .planning/phases/01-critical-path/01-02-SUMMARY.md
- FOUND commit: 38b08ef (Task 1)
- FOUND commit: 10ca43c (Task 2)

## User Setup Required
None - no external service configuration required at this stage. Files are inert templates; all secrets remain as documented env var references.

## Next Phase Readiness
- config/dupont-plomberie.json is the contract Plan 03 reads for client context
- workflows/speed-to-lead-main.json is ready to import into n8n — Plans 03-06 fill in node parameters
- workflows/speed-to-lead-error-handler.json is ready to import — Plan 04 fills error handling logic
- prompts/prospect-sms-fr.txt is ready to embed — Plan 05 copies content into Claude HTTP Request node system prompt field
- No blockers for Plans 03-06

---
*Phase: 01-critical-path*
*Completed: 2026-03-28*
