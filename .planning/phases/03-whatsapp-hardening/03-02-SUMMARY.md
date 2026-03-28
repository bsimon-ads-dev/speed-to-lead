---
phase: 03-whatsapp-hardening
plan: "02"
subsystem: messaging
tags: [n8n, twilio, whatsapp, waba, content-template, if-node, feature-flag]

# Dependency graph
requires:
  - phase: 03-whatsapp-hardening
    plan: "01"
    provides: Core Workflow with circuit breaker; WhatsApp config fields in client configs
provides:
  - WhatsApp prospect branch in Core Workflow (IF: whatsapp_enabled? gates ContentSid send)
  - WhatsApp owner branch in Core Workflow (IF: owner_whatsapp_enabled? gates ContentSid send)
  - Entry workflows assemble whatsapp_* fields from env vars with || '' fallback
affects: [03-03-PLAN.md]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "WhatsApp nodes use ContentSid + ContentVariables only — no Body field to prevent WABA flagging"
    - "whatsapp: prefix hardcoded in expression (=whatsapp:{{ $json.phone }}) — never stored in client_config"
    - "ContentVariables as JSON string literal in n8n expression (not JSON.stringify) — avoids double-encoding"
    - "whatsapp_enabled: false and owner_whatsapp_enabled: false default — SMS clients unaffected until WABA onboarding"
    - "|| '' fallback on env var reads — prevents runtime errors before WABA env vars are configured"

key-files:
  created: []
  modified:
    - workflows/speed-to-lead-core.json
    - workflows/speed-to-lead-entry-dupont-plomberie.json
    - workflows/speed-to-lead-entry-cabinet-martin.json

# Decisions
decisions:
  - "whatsapp: prefix hardcoded in expression rather than stored in client_config — eliminates one class of misconfiguration"
  - "ContentVariables as JSON string literal not JSON.stringify() — n8n expression engine double-encodes stringify output"
  - "No Body parameter on WhatsApp nodes — Body silently ignored for new contacts and can cause WABA flagging"
  - "Both WhatsApp flags default false in entry workflows — safe to deploy before any client completes WABA onboarding"

# Metrics
metrics:
  duration: "2 minutes"
  completed_date: "2026-03-28"
  tasks_completed: 2
  files_modified: 3
---

# Phase 3 Plan 02: WhatsApp Branches — Core Workflow and Entry Config Assemblers

WhatsApp prospect and owner notification branches wired into Core Workflow behind feature flags, with entry workflows assembling WhatsApp env vars into client_config defaults-off.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Add WhatsApp branches to Core Workflow | c14b1a3 | workflows/speed-to-lead-core.json |
| 2 | Add WhatsApp fields to entry workflow config assemblers | bfa83ff | workflows/speed-to-lead-entry-dupont-plomberie.json, workflows/speed-to-lead-entry-cabinet-martin.json |

## What Was Built

### Task 1 — Core Workflow WhatsApp Branches

Four new nodes added to `speed-to-lead-core.json`:

**Prospect path:** `IF: phone available?` true branch now routes to `IF: whatsapp_enabled? (Prospect)` (id: node-wa-if-prospect) which fans out to:
- true branch: `HTTP Request: Twilio WhatsApp (Prospect)` (id: node-wa-prospect) — ContentSid + ContentVariables, no Body
- false branch: `HTTP Request: Twilio SMS (Prospect)` (existing node, unchanged)

Both branches converge at `Code: Format Owner Notification` as before.

**Owner path:** `Code: Format Owner Notification` now routes to `IF: owner_whatsapp_enabled?` (id: node-wa-if-owner) which fans out to:
- true branch: `HTTP Request: Twilio WhatsApp (Owner)` (id: node-wa-owner) — ContentSid + ContentVariables, no Body
- false branch: `HTTP Request: Twilio SMS (Owner)` (existing node, unchanged)

Both branches converge at `Wait: Follow-up Delay` as before.

WhatsApp node body parameters (both prospect and owner):
- `To`: `=whatsapp:{{ $json.phone }}` / `=whatsapp:{{ $json.client_config.owner_phone }}`
- `From`: `=whatsapp:{{ $json.client_config.whatsapp_sender }}`
- `ContentSid`: `={{ $json.client_config.whatsapp_template_sid }}` / `whatsapp_owner_template_sid`
- `ContentVariables`: JSON string literal with prospect name, business name, callback minutes (prospect) or name, request, phone (owner)

### Task 2 — Entry Workflow Config Assemblers

Both entry workflows updated to append five WhatsApp fields after the existing Twilio fields:

```js
whatsapp_enabled: false,
owner_whatsapp_enabled: false,
whatsapp_sender: $env.DUPONT_WHATSAPP_SENDER || '',  // MARTIN_ prefix for cabinet-martin
whatsapp_template_sid: $env.DUPONT_WHATSAPP_TEMPLATE_SID || '',
whatsapp_owner_template_sid: $env.DUPONT_WHATSAPP_OWNER_TEMPLATE_SID || ''
```

`_setup_notes.post_import_step` updated in both files to document the three optional WhatsApp env vars and when to enable the flags.

## Decisions Made

1. **whatsapp: prefix hardcoded in expression** — `=whatsapp:{{ $json.phone }}` rather than expecting client_config to include the prefix. Prevents one entire class of misconfiguration where the prefix gets omitted from env var or config.

2. **No JSON.stringify() for ContentVariables** — n8n expression engine would double-encode it. The expression `={"1":"{{ $json.name }}"}` already evaluates to a valid JSON string that Twilio accepts.

3. **No Body parameter on WhatsApp nodes** — Body is silently ignored by Twilio WABA for new contacts and can trigger WABA compliance flags. ContentSid alone routes correctly to the approved template.

4. **Both flags default false** — `whatsapp_enabled: false` and `owner_whatsapp_enabled: false` hardcoded in entry workflow jsCode. Safe to deploy to n8n before any client has completed WABA onboarding. Activation is a two-step: configure env vars, then flip flag in jsCode.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. WhatsApp branches are fully wired. The `whatsapp_enabled: false` default is intentional feature-flag behavior, not a stub — the plan documents that flags are activated per client post-WABA-onboarding.

## Self-Check: PASSED

Files confirmed present:
- workflows/speed-to-lead-core.json — contains node-wa-prospect, node-wa-owner, updated connections
- workflows/speed-to-lead-entry-dupont-plomberie.json — contains DUPONT_WHATSAPP_SENDER, whatsapp_enabled: false
- workflows/speed-to-lead-entry-cabinet-martin.json — contains MARTIN_WHATSAPP_SENDER, whatsapp_enabled: false

Commits confirmed:
- c14b1a3 — feat(03-02): add WhatsApp branches to Core Workflow
- bfa83ff — feat(03-02): add WhatsApp config fields to entry workflow assemblers
