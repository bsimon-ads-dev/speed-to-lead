---
phase: 03-whatsapp-hardening
plan: "01"
subsystem: infra
tags: [n8n, twilio, whatsapp, circuit-breaker, staticdata, config]

# Dependency graph
requires:
  - phase: 02-follow-up-multi-tenant
    provides: per-client config schema (dupont-plomberie.json, cabinet-martin.json) and Core Workflow structure
provides:
  - WhatsApp config fields (whatsapp_enabled, owner_whatsapp_enabled, whatsapp_sender, whatsapp_template_sid, whatsapp_owner_template_sid) in both client configs
  - env_vars_required registry entries for DUPONT_WHATSAPP_* and MARTIN_WHATSAPP_* per client
  - Circuit breaker Code node in Core Workflow halting execution and alerting Baptiste on >5 same lead_id in 10 min
  - IF node routing circuit breaker true/false branches
  - Twilio SMS alert node for circuit breaker (CB Alert) using client Twilio credentials, To: $env.BAPTISTE_PHONE
affects: [03-02-PLAN.md, 03-03-PLAN.md]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Circuit breaker via $getWorkflowStaticData('global').circuitBreaker — same staticData API as lastLead error recovery"
    - "10-minute window / 5-execution threshold / auto-prune entries older than 20 minutes"
    - "WhatsApp sender stored in separate whatsapp_sender field (E.164) — never reuses alphanumeric twilio_sender_id"

key-files:
  created: []
  modified:
    - config/dupont-plomberie.json
    - config/cabinet-martin.json
    - workflows/speed-to-lead-core.json

key-decisions:
  - "WhatsApp fields default to false/empty — activated per client only after WABA onboarding completes"
  - "Separate whatsapp_sender field (E.164) required — alphanumeric sender IDs are SMS-only, rejected by WhatsApp"
  - "Circuit breaker node inserted as very first node in Core Workflow before Log Raw Payload — triggers before any processing"
  - "Circuit breaker alert SMS uses client Twilio credentials (not a dedicated Baptiste account) to avoid additional credential management"
  - "HTTP Request: Twilio SMS (CB Alert) has no outgoing connection — execution terminates after alert fires"

patterns-established:
  - "Pattern: Circuit breaker first — any new hardening gate node belongs before Log Raw Payload"
  - "Pattern: WhatsApp fields off by default — config schema ships before WABA onboarding, activated via flag"

requirements-completed: [CHAN-01]

# Metrics
duration: 2min
completed: 2026-03-28
---

# Phase 03 Plan 01: WhatsApp Config Fields + Circuit Breaker Summary

**WhatsApp config schema added to both client configs and circuit breaker Code node wired as first Core Workflow node, halting and alerting on >5 same lead_id in 10 minutes**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-28T15:26:10Z
- **Completed:** 2026-03-28T15:27:49Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Both client configs now declare all five whatsapp_* fields (false/empty defaults) and three new env var registry entries per client with format-specific descriptions
- Core Workflow gets three new nodes: Code: Circuit Breaker, IF: Circuit Breaker Tripped?, HTTP Request: Twilio SMS (CB Alert)
- Trigger entry point re-wired from direct to Log Raw Payload to the new circuit breaker chain — false branch reconnects to existing Log Raw Payload flow unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Add WhatsApp fields to client configs** - `20e0a8c` (feat)
2. **Task 2: Add circuit breaker node chain to Core Workflow** - `62b2080` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified

- `config/dupont-plomberie.json` — Added 5 whatsapp_* fields + 3 DUPONT_WHATSAPP_* env var registry entries
- `config/cabinet-martin.json` — Added 5 whatsapp_* fields + 3 MARTIN_WHATSAPP_* env var registry entries
- `workflows/speed-to-lead-core.json` — Added circuit breaker Code node, CB IF node, CB Alert SMS node; rewired trigger connection

## Decisions Made

- WhatsApp fields default to `false` / empty string — activated per client only after WABA onboarding completes; Plan 02 reads these fields at runtime
- Separate `whatsapp_sender` field stores E.164 phone number — never reuses `twilio_sender_id` (alphanumeric, SMS-only, rejected by WhatsApp per Pitfall 2 in RESEARCH.md)
- Circuit breaker node inserted before Log Raw Payload (first in chain) — halts before any audit logging, dedup, Claude API, or Twilio sends occur
- CB Alert reuses client Twilio credentials from `client_config` — no dedicated Baptiste Twilio account needed, reduces credential surface
- Alert node has no outgoing connection — execution terminates naturally after alert SMS

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Both verification scripts passed on first run. JSON validity confirmed for all three files.

Pre-flight Body grep returned 4 matches (CB Alert + Prospect + Owner + Follow-up) — all correct Twilio SMS nodes. Zero WhatsApp nodes at this stage as expected.

## User Setup Required

None - no external service configuration required by this plan. WhatsApp onboarding and env var configuration are tracked in env_vars_required fields and will be required before setting whatsapp_enabled to true per client.

## Next Phase Readiness

- Plan 02 can now read `whatsapp_enabled`, `whatsapp_sender`, `whatsapp_template_sid`, `whatsapp_owner_template_sid` from client configs
- Core Workflow circuit breaker is live — all incoming executions pass through the 10-min/5-threshold gate
- Plan 03 (monitoring + Anthropic spend cap) has no blockers from this plan

---
*Phase: 03-whatsapp-hardening*
*Completed: 2026-03-28*
