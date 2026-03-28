---
phase: 02-follow-up-multi-tenant
plan: "03"
subsystem: workflow
tags: [n8n, multi-tenant, entry-workflow, webhook, twilio, google-key, fire-and-forget]

# Dependency graph
requires:
  - phase: 02-follow-up-multi-tenant-02
    provides: workflows/speed-to-lead-core.json — shared Core Workflow with executeWorkflowTrigger
  - phase: 02-follow-up-multi-tenant-01
    provides: per-client config JSON files with env var registry (DUPONT_* and MARTIN_* prefixes)
provides:
  - "workflows/speed-to-lead-entry-dupont-plomberie.json — Thin entry workflow for Dupont Plomberie"
  - "workflows/speed-to-lead-entry-cabinet-martin.json — Thin entry workflow for Cabinet Martin"
  - "Per-client webhook URL slugs: /webhook/dupont-plomberie and /webhook/cabinet-martin"
  - "google_key validation gate at entry — Core Workflow is auth-agnostic"
  - "client_config payload assembly from hardcoded non-sensitive values + $env.CLIENTSLUG_* for Twilio"
affects:
  - 02-04-testing

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Thin entry workflow pattern: 4 nodes (Webhook -> IF google_key -> Code assemble config -> Execute Sub-workflow)"
    - "Fire-and-forget Execute Sub-workflow: waitForSubWorkflow=false returns HTTP 200 immediately"
    - "Per-client credential isolation: DUPONT_* env vars in dupont workflow, MARTIN_* in martin workflow"
    - "google_key validation in entry workflow: $json.google_key === $env.CLIENTSLUG_GOOGLE_KEY"
    - "client_config assembled in Code node: non-sensitive hardcoded + sensitive from $env.*"
    - "CORE_WORKFLOW_ID placeholder: replaced post-import by selecting workflow by name in n8n UI"

key-files:
  created:
    - workflows/speed-to-lead-entry-dupont-plomberie.json
    - workflows/speed-to-lead-entry-cabinet-martin.json
  modified: []

key-decisions:
  - "google_key validated in entry workflow (IF node) — stops unauthenticated requests before Core call, Core Workflow trusts authenticated entry payloads"
  - "CORE_WORKFLOW_ID kept as placeholder string — post-import manual step documented in _setup_notes, cannot be determined at authoring time"
  - "IF false branch left empty (no nodes) — invalid requests silently dropped; n8n Webhook returns 200 regardless so Google Ads does not retry"

requirements-completed:
  - CONF-02
  - CONF-03

# Metrics
duration: 2min
completed: "2026-03-28"
---

# Phase 02 Plan 03: Entry Workflows — Per-Client Thin Webhooks Summary

**Two thin entry workflows (4 nodes each) that provide unique webhook URLs per client, validate google_key, assemble client_config from $env.CLIENTSLUG_* vars, and fire-and-forget the Core Workflow — proving that adding a third client requires only a new entry workflow, zero Core changes**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-28T14:56:51Z
- **Completed:** 2026-03-28T14:58:25Z
- **Tasks:** 2
- **Files created:** 2

## Accomplishments

- Created `speed-to-lead-entry-dupont-plomberie.json`: 4-node entry workflow with webhook path `dupont-plomberie`, IF google_key gate (vs $env.DUPONT_GOOGLE_KEY), Code node assembling full client_config with DUPONT_* Twilio env vars, Execute Sub-workflow with waitForSubWorkflow=false
- Created `speed-to-lead-entry-cabinet-martin.json`: structurally identical 4-node entry workflow with webhook path `cabinet-martin`, MARTIN_* env var prefix, Cabinet Martin Avocats config values (avocat/Lyon/60min callback/120min follow-up)
- Enforced credential isolation by construction: each workflow reads only its own CLIENTSLUG_* env vars — no cross-contamination possible
- Confirmed multi-tenant architecture proof: second client (Cabinet Martin) required zero changes to Core Workflow — only new entry workflow + config

## Task Commits

1. **Task 1: Create entry workflow for Dupont Plomberie** - `1c07080` (feat)
2. **Task 2: Create entry workflow for Cabinet Martin** - `dc7f10a` (feat)

## Files Created/Modified

- `workflows/speed-to-lead-entry-dupont-plomberie.json` — Entry workflow for Dupont Plomberie; webhook slug `dupont-plomberie`, 4 nodes
- `workflows/speed-to-lead-entry-cabinet-martin.json` — Entry workflow for Cabinet Martin; webhook slug `cabinet-martin`, 4 nodes

## Decisions Made

- google_key validation is handled by an IF node in the entry workflow. The false branch is empty — invalid requests are silently dropped. Google Ads Lead Forms do not distinguish between HTTP 200 responses, so silent discard is safe and avoids leaking validation logic to callers.
- `CORE_WORKFLOW_ID` is set to the placeholder string `"CORE_WORKFLOW_ID"` in both files. This value is instance-specific (assigned by n8n at import time) and cannot be determined at authoring time. The `_setup_notes.post_import_step` field in each file documents the manual step: open the Execute Sub-workflow node and select "Speed to Lead — Core" by name.
- `waitForSubWorkflow: false` is hardcoded, not configurable. This is an architectural invariant: the Core Workflow contains a Wait node (45–120 min depending on client). Blocking would cause Google Ads webhook timeout and lead loss.

## Deviations from Plan

None — plan executed exactly as written.

## Overall Verification Results

All three overall checks passed:
- Both entry workflows valid JSON: PASS
- No credential cross-contamination (DUPONT_TWILIO not in martin, MARTIN_TWILIO not in dupont): PASS
- Webhook slugs unique (`dupont-plomberie` vs `cabinet-martin`): PASS

## User Setup Required

Post-import steps for each entry workflow (documented in `_setup_notes` in each file):
1. Open the "Execute: Core Workflow" node, click the workflow selector, choose "Speed to Lead — Core" by name
2. Set env vars per client:
   - Dupont: `DUPONT_GOOGLE_KEY`, `DUPONT_TWILIO_ACCOUNT_SID`, `DUPONT_TWILIO_AUTH_TOKEN`, `DUPONT_TWILIO_SENDER_ID`
   - Martin: `MARTIN_GOOGLE_KEY`, `MARTIN_TWILIO_ACCOUNT_SID`, `MARTIN_TWILIO_AUTH_TOKEN`, `MARTIN_TWILIO_SENDER_ID`
3. Activate each entry workflow
4. Configure Google Ads Lead Form webhook URLs to point to the respective slugs

## Known Stubs

- `CORE_WORKFLOW_ID` placeholder in both Execute Sub-workflow nodes — intentional, replaced post-import by selecting the Core Workflow in the n8n UI. Documented in `_setup_notes.post_import_step` in each file.

## Next Phase Readiness

- Both entry workflows ready to import into n8n alongside `speed-to-lead-core.json`
- Plan 04 (testing) can now write integration test scenarios covering the full entry → core chain
- Third client addition only requires: (a) new entry workflow JSON from the entry template, (b) new `config/[slug].json`, (c) CLIENTSLUG_* env vars in Railway — no Core Workflow changes

## Self-Check

- [x] `workflows/speed-to-lead-entry-dupont-plomberie.json` exists at correct path
- [x] `workflows/speed-to-lead-entry-cabinet-martin.json` exists at correct path
- [x] Commit `1c07080` exists: `feat(02-03): create entry workflow for Dupont Plomberie`
- [x] Commit `dc7f10a` exists: `feat(02-03): create entry workflow for Cabinet Martin`
- [x] Task 1 automated verification: PASS (11/11 checks)
- [x] Task 2 automated verification: PASS (9/9 checks)
- [x] Overall verification: all 3 checks PASS

## Self-Check: PASSED

---
*Phase: 02-follow-up-multi-tenant*
*Completed: 2026-03-28*
