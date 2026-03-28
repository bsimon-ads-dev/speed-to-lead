---
phase: 02-follow-up-multi-tenant
plan: "02"
subsystem: workflow
tags: [n8n, twilio, brevo, multi-tenant, follow-up, business-hours, luxon]

# Dependency graph
requires:
  - phase: 01-critical-path
    provides: speed-to-lead-main.json — Phase 1 single-client workflow used as source for transformation
  - phase: 02-follow-up-multi-tenant-01
    provides: per-client config schema with follow_up_delay_minutes and Twilio prefix env var pattern
provides:
  - "workflows/speed-to-lead-core.json — shared parameterized Core Workflow for all clients"
  - "executeWorkflowTrigger entry point accepting lead + client_config payload from entry workflows"
  - "Follow-up chain: Wait -> Business Hours Check (Europe/Paris) -> IF -> SMS or skip log"
  - "Dynamic Twilio credentials via Buffer.from(sid:token).toString('base64') Authorization header"
affects:
  - 02-03-entry-workflows
  - 02-04-testing

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "executeWorkflowTrigger Accept All Data — Core Workflow receives full payload via $json"
    - "Dynamic Twilio auth via HTTP Request Authorization header expression (Buffer.from btoa pattern)"
    - "Business hours gate with Luxon $now.setZone('Europe/Paris').weekday and .hour"
    - "n8n Wait node timeInterval mode with client_config.follow_up_delay_minutes expression"
    - "client_config.* namespace — all per-client values accessed under this key in Core Workflow"
    - "google_key validation delegated to entry workflows — Core Workflow trusts authenticated payloads"

key-files:
  created:
    - workflows/speed-to-lead-core.json
  modified: []

key-decisions:
  - "Removed IF: google_key valid? from Core Workflow — validation moved to entry workflows (Plan 03) so Core Workflow is auth-agnostic and trusts caller"
  - "client_config forwarded explicitly in Code: Extract Lead Fields and Code: Format Owner Notification jsCode — preserves client_config through field-rebuilding code nodes"
  - "Wait node positioned at x=2440 (immediately after owner SMS) — follow-up delay starts from owner notification, not from lead arrival"

patterns-established:
  - "Pattern: Core Workflow is client-agnostic — zero $env.* client-specific refs; all come from $json.client_config.*"
  - "Pattern: $env.ANTHROPIC_API_KEY and $env.BAPTISTE_PHONE are shared env vars — not per-client, left as-is"
  - "Pattern: $env.BREVO_API_KEY uses stored n8n credential — brevo_sender_email is per-client via client_config"

requirements-completed:
  - CONF-02
  - NOTIF-03

# Metrics
duration: 2min
completed: "2026-03-28"
---

# Phase 02 Plan 02: Core Workflow — Multi-tenant Parameterization Summary

**Single shared n8n Core Workflow with executeWorkflowTrigger, zero client-specific $env.* refs, and follow-up chain (Wait -> Business Hours Europe/Paris -> Twilio SMS or skip log) driven entirely by injected client_config payload**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-28T14:52:51Z
- **Completed:** 2026-03-28T14:54:45Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Transformed speed-to-lead-main.json into speed-to-lead-core.json: 8 targeted changes applied (trigger swap, 5 node refactors, 5 new nodes, connection updates, settings update)
- Eliminated all 7 client-specific $env.* references (TWILIO_ACCOUNT_SID, OWNER_PHONE, BUSINESS_NAME, SERVICE_TYPE, CITY, TWILIO_SENDER_ID, BREVO_SENDER_EMAIL) — replaced with $json.client_config.* equivalents
- Appended complete follow-up chain: Wait node (client_config.follow_up_delay_minutes) -> Business Hours Check (Europe/Paris Luxon, Mon-Sat 08:00-20:00) -> IF -> Follow-up Twilio SMS (TRUE) or Log Skipped (FALSE)
- Dynamic Twilio credentials: Authorization header built from Buffer.from(sid:token).toString('base64') expression — works without n8n enterprise license

## Task Commits

1. **Task 1: Replace trigger and refactor $env.* client-specific references** - `2fbe833` (feat)

**Plan metadata:** _(added in final commit below)_

## Files Created/Modified
- `workflows/speed-to-lead-core.json` — Shared parameterized Core Workflow (16 nodes); source of truth for all client executions in Phase 2+

## Decisions Made
- Removed `IF: google_key valid?` node from Core Workflow per plan instructions. Plan specifies this check moves to entry workflows (Plan 03), keeping Core Workflow stateless and auth-agnostic. Core Workflow trusts that any call it receives has already been authenticated by the entry workflow.
- Forwarded `client_config` explicitly in the `jsCode` of `Code: Extract Lead Fields` and `Code: Format Owner Notification` — both nodes rebuild $json from scratch (not pass-through), so client_config must be explicitly carried forward or it would be lost. This is a correctness requirement, not a deviation.
- Wait node placed immediately after `HTTP Request: Twilio SMS (Owner)` — follow-up delay starts from the moment the owner is notified, which is the correct semantic (give the owner N minutes to call before following up with prospect).

## Deviations from Plan

None — plan executed exactly as written.

One implicit addition: `client_config` field explicitly carried forward in two Code nodes that reconstruct `$json` (Extract Lead Fields, Format Owner Notification). This was required for correctness (Rule 2 — missing critical functionality: without it, client_config would be undefined in downstream nodes). Treated as part of Task 1 implementation, not a separate deviation.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required in this plan. Entry workflow wiring (Plan 03) and testing (Plan 04) will require environment variable setup.

## Next Phase Readiness
- `workflows/speed-to-lead-core.json` is ready to be referenced by entry workflows (Plan 03)
- Plan 03 must create per-client entry workflows: Webhook node (client slug) + Code node (assembles client_config from $env.CLIENTSLUG_* vars) + Execute Sub-workflow node (calls Core Workflow, waitForSubWorkflow: false)
- Post-import step required in n8n: note the Core Workflow's assigned ID and update Execute Sub-workflow node references in entry workflows
- Recommend setting `GENERIC_TIMEZONE=Europe/Paris` on the Railway n8n instance to prevent Wait node resume issues (see RESEARCH.md Pitfall 3)

## Self-Check
- [x] `workflows/speed-to-lead-core.json` created at correct path
- [x] Commit `2fbe833` exists: `feat(02-02): add parameterized Core Workflow for multi-tenant speed-to-lead`
- [x] Automated verification script: PASS (all 15 checks green)
- [x] Structural verification: 16 nodes present, 0 forbidden $env.* refs

## Self-Check: PASSED

---
*Phase: 02-follow-up-multi-tenant*
*Completed: 2026-03-28*
