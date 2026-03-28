---
phase: 02-follow-up-multi-tenant
verified: 2026-03-28T00:00:00Z
status: passed
score: 4/4 must-haves verified
re_verification: false
---

# Phase 2: Follow-up + Multi-tenant Verification Report

**Phase Goal:** The system automatically follows up with prospects the owner hasn't called back, and the same Core Workflow serves multiple clients without credential cross-contamination
**Verified:** 2026-03-28
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A second prospect message fires automatically after the configured delay if the owner has not called back — and does not fire outside 08:00-20:00 Mon-Sat | VERIFIED | Wait node uses `$json.client_config.follow_up_delay_minutes`; Business Hours Check node gates on `weekday >= 1 && weekday <= 6 && hour >= 8 && hour < 20` (Europe/Paris); follow-up SMS wired to TRUE branch of IF: Business Hours OK? |
| 2 | Adding a second client requires only creating a new per-client JSON config and thin entry workflow — no changes to the Core Workflow | VERIFIED | cabinet-martin entry workflow is structurally identical to dupont-plomberie; Core Workflow contains zero `$env.CLIENTSLUG_*` refs; adding a third client requires only a new entry workflow JSON and config file |
| 3 | Each client's Twilio credentials and Claude prompts are isolated; a misconfiguration for client A cannot cause a message to be sent on behalf of client B | VERIFIED | No `DUPONT_*` refs in cabinet-martin entry workflow; no `MARTIN_*` refs in dupont-plomberie entry workflow; each entry workflow reads only its own `CLIENTSLUG_*` env vars; Core Workflow uses only `$json.client_config.*` (injected at entry, not shared) |
| 4 | Each client has a unique webhook URL slug and Baptiste can identify which client triggered each execution at a glance | VERIFIED | Dupont webhook path: `dupont-plomberie`; Martin webhook path: `cabinet-martin`; paths are unique; `client_slug` is carried in `client_config` through all Core nodes |

**Score: 4/4 truths verified**

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `workflows/speed-to-lead-core.json` | Shared parameterized Core Workflow with executeWorkflowTrigger | VERIFIED | 16 nodes; trigger is `n8n-nodes-base.executeWorkflowTrigger`; zero forbidden `$env.CLIENTSLUG_*` refs; error workflow linked |
| `workflows/speed-to-lead-entry-dupont-plomberie.json` | Thin entry workflow, 4 nodes, webhook slug `dupont-plomberie` | VERIFIED | 4 nodes; webhook path `dupont-plomberie`; IF google_key gate vs `$env.DUPONT_GOOGLE_KEY`; Code assembles `client_config` with `DUPONT_*` env vars; Execute Core with `waitForSubWorkflow: false` |
| `workflows/speed-to-lead-entry-cabinet-martin.json` | Thin entry workflow, 4 nodes, webhook slug `cabinet-martin` | VERIFIED | 4 nodes; webhook path `cabinet-martin`; IF google_key gate vs `$env.MARTIN_GOOGLE_KEY`; Code assembles `client_config` with `MARTIN_*` env vars; Execute Core with `waitForSubWorkflow: false` |
| `config/dupont-plomberie.json` | Extended with follow-up fields and `DUPONT_*` prefixed env var registry | VERIFIED | `follow_up_delay_minutes: 45`, `follow_up_enabled: true`, `brevo_sender_email`, `DUPONT_TWILIO_ACCOUNT_SID/AUTH_TOKEN/SENDER_ID` in `env_vars_required` |
| `config/cabinet-martin.json` | Second client config with `MARTIN_*` prefixed env vars | VERIFIED | `follow_up_delay_minutes: 120`, `callback_promise_minutes: 60`, `MARTIN_*` prefixed env vars; business_name: `Cabinet Martin Avocats`, city: `Lyon` |
| `tests/test-webhook.sh` | Accepts `[slug]` as second positional argument | VERIFIED | `SLUG="${2:-dupont-plomberie}"` on line 16; `WEBHOOK_URL` uses `${SLUG}`; examples in header comment show two-arg usage |
| `tests/TESTING.md` | Phase 2 section with procedures for CONF-01, CONF-02, CONF-03, NOTIF-03 | VERIFIED | Phase 2 section appended; covers multi-client smoke test, Core multi-tenant test, follow-up delay test with RESTORE reminder, business hours gate test, credential isolation check, and acceptance checklist table |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Entry workflow (Dupont) | Core Workflow | Execute Sub-workflow node, `waitForSubWorkflow: false` | WIRED | `CORE_WORKFLOW_ID` placeholder present — intentional, replaced post-import in n8n UI |
| Entry workflow (Martin) | Core Workflow | Execute Sub-workflow node, `waitForSubWorkflow: false` | WIRED | Same pattern; `CORE_WORKFLOW_ID` placeholder; `waitForSubWorkflow: false` confirmed |
| Entry Code node | Core Workflow `client_config` | `client_config` key in merged payload `{ ...lead, client_config: clientConfig }` | WIRED | Both entry Code nodes assemble `clientConfig` and merge it into the payload before Execute node |
| Core `client_config` | Wait node | `$json.client_config.follow_up_delay_minutes` expression | WIRED | Wait node `amount` field uses the expression; `client_config` is explicitly carried forward in Extract Lead Fields and Format Owner Notification Code nodes |
| Wait node | Business Hours gate | Direct connection: Wait -> Code: Business Hours Check -> IF: Business Hours OK? | WIRED | Connections confirmed: `Wait: Follow-up Delay` -> `Code: Business Hours Check` -> `IF: Business Hours OK?` |
| IF: Business Hours OK? TRUE branch | Follow-up Twilio SMS | Direct connection | WIRED | TRUE output routes to `HTTP Request: Twilio SMS (Follow-up)` |
| IF: Business Hours OK? FALSE branch | Log Skipped node | Direct connection | WIRED | FALSE output routes to `Code: Log Follow-up Skipped` |
| Follow-up SMS body | `client_config.business_name` | Expression in Body parameter | WIRED | Body: `=Toujours disponible pour votre demande ? {{ $json.client_config.business_name }} peut vous rappeler maintenant.` |
| Twilio auth (Core) | `client_config.twilio_account_sid/twilio_auth_token` | `Buffer.from(sid + ':' + token).toString('base64')` in Authorization header | WIRED | All three Twilio SMS nodes (Prospect, Owner, Follow-up) use this dynamic auth pattern; no hardcoded credentials |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| Core Workflow — Twilio SMS nodes | `twilio_account_sid`, `twilio_auth_token` | `$json.client_config.*` injected by entry Code node from `$env.DUPONT_*` / `$env.MARTIN_*` | Yes — reads live env vars at execution time | FLOWING |
| Core Workflow — Wait node | `follow_up_delay_minutes` | `$json.client_config.follow_up_delay_minutes` from entry Code node | Yes — 45 (Dupont) / 120 (Martin) hardcoded in entry Code from config | FLOWING |
| Core Workflow — Claude API | `business_name`, `service_type`, `city`, `callback_promise_minutes` | `$json.client_config.*` from entry Code node | Yes — non-sensitive values hardcoded in entry Code node | FLOWING |
| Entry workflows — google_key gate | `$json.google_key` vs `$env.CLIENTSLUG_GOOGLE_KEY` | Incoming webhook payload vs n8n env var | Yes — runtime env var comparison | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| Core Workflow has no client-specific `$env.*` refs | `grep '\$env\.' core.json` excluding shared keys | Zero matches for TWILIO_*, OWNER_*, BUSINESS_*, SERVICE_*, CITY_*, SENDER_ID | PASS |
| No credential cross-contamination | `DUPONT_*` in martin workflow; `MARTIN_*` in dupont workflow | Zero matches in both directions | PASS |
| Follow-up chain fully wired | JSON connections trace: Owner SMS -> Wait -> BizHours -> IF -> Follow-up/Skip | All 5 links present and in correct order | PASS |
| Entry workflow isolation | Each entry reads only its prefixed env vars | Dupont uses `DUPONT_*`; Martin uses `MARTIN_*`; no cross-refs | PASS |
| Unique webhook slugs | `path` field in Webhook nodes | `dupont-plomberie` vs `cabinet-martin` — distinct | PASS |
| Wait node uses dynamic delay | `amount` field expression | `={{ $json.client_config.follow_up_delay_minutes }}` — not hardcoded | PASS |
| Business hours uses Europe/Paris | `setZone('Europe/Paris')` in BizHours Code node | Present; checks Mon-Sat (weekday 1-6), 08:00-19:59 | PASS |
| All phase commits exist in git | `git log` for all 7 SUMMARY-cited hashes | aa3e144, ddfb133, 2fbe833, 1c07080, dc7f10a, a50d201, af8b3d5 — all found | PASS |

---

### Requirements Coverage

| Requirement | Description | Source Plans | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| NOTIF-03 | If the owner has not called back after a configurable delay, the prospect receives an automatic follow-up | 02-02, 02-04 | SATISFIED | Wait node with `client_config.follow_up_delay_minutes`; Business Hours gate; Follow-up Twilio SMS node; all wired end-to-end |
| CONF-01 | Each client has its own configuration (name, channels, delays, service type) | 02-01, 02-03 | SATISFIED | Per-client JSON config files; entry Code node assembles `client_config` with per-client values; env var registry pattern in both config files |
| CONF-02 | A single shared Core Workflow for all clients (multi-tenant) | 02-02, 02-03 | SATISFIED | `speed-to-lead-core.json` triggered via `executeWorkflowTrigger`; zero client-specific `$env.*` refs; both entry workflows call the same Core Workflow |
| CONF-03 | Each client has a unique webhook URL slug | 02-03, 02-04 | SATISFIED | `dupont-plomberie` and `cabinet-martin` slugs in entry Webhook nodes; TESTING.md documents both URLs |

**All 4 requirements for Phase 2 accounted for. No orphaned requirements.**

---

### Anti-Patterns Found

| File | Item | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `speed-to-lead-entry-dupont-plomberie.json` | `workflowId.value: "CORE_WORKFLOW_ID"` | Placeholder string | INFO | Intentional and documented — must be replaced post-import in n8n UI by selecting the Core Workflow by name. Not a runtime bug; documents the manual onboarding step. |
| `speed-to-lead-entry-cabinet-martin.json` | `workflowId.value: "CORE_WORKFLOW_ID"` | Placeholder string | INFO | Same as above — same intentional pattern. |
| `tests/TESTING.md` (Prerequisites section, line 8) | Lists `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `GOOGLE_KEY` as global env var names | Stale Phase 1 naming in Prerequisites block | INFO | The Prerequisites block reflects Phase 1 naming. Phase 2 section correctly uses per-client naming (`DUPONT_GOOGLE_KEY`, `MARTIN_GOOGLE_KEY`). No functional impact but could cause minor confusion during Phase 2 setup if a reader only reads the Prerequisites block. |

No blocker anti-patterns found.

---

### Human Verification Required

#### 1. Follow-up SMS fires after delay

**Test:** Import all workflows into a live n8n instance with real or test Twilio credentials. Temporarily set `follow_up_delay_minutes` to 1 in the Dupont entry Code node. Send a test lead via `GOOGLE_KEY=your_dupont_key ./tests/test-webhook.sh happy dupont-plomberie`. Wait 1 minute. Check n8n Executions view.
**Expected:** Core Workflow execution resumes after ~1 minute and reaches "HTTP Request: Twilio SMS (Follow-up)". Prospect test phone receives follow-up SMS.
**Why human:** Requires a running n8n instance with real Twilio credentials or a verified test Twilio number. Wait node behavior cannot be verified from static JSON inspection.

#### 2. Business hours gate suppresses follow-up at off-hours

**Test:** Same as above but send the test lead such that the Wait fires outside 08:00-20:00 Mon-Sat Paris time (or trigger at a real off-hours moment).
**Expected:** "Code: Business Hours Check" output shows `business_hours_ok: false`; "IF: Business Hours OK?" routes to "Code: Log Follow-up Skipped"; no Twilio SMS (Follow-up) call appears in execution.
**Why human:** Requires triggering at or simulating an off-hours time on a live n8n instance. Cannot be verified from static JSON.

#### 3. CORE_WORKFLOW_ID post-import replacement

**Test:** Import `speed-to-lead-core.json`, then import both entry workflows. Open each entry workflow's "Execute: Core Workflow" node and select "Speed to Lead — Core" by name.
**Expected:** The `workflowId` updates from the placeholder string to the actual n8n-assigned workflow ID. Both entry workflows then correctly call the Core Workflow when a lead arrives.
**Why human:** n8n assigns workflow IDs dynamically at import time. The actual ID cannot be determined from the static JSON files. This is a one-time manual setup step.

---

### Gaps Summary

No gaps. All four Phase 2 requirements (NOTIF-03, CONF-01, CONF-02, CONF-03) are satisfied by substantive, wired, and data-flowing artifacts. The follow-up chain is fully connected in the Core Workflow JSON. Credential isolation is enforced by construction in both entry workflows with no cross-contamination. The two known placeholder items (`CORE_WORKFLOW_ID`) are intentional, documented, and do not block goal achievement — they are a required post-import step inherent to n8n's architecture.

The single informational inconsistency (Phase 1 global env var names in TESTING.md Prerequisites block) has no functional impact and does not require a gap closure plan.

---

_Verified: 2026-03-28_
_Verifier: Claude (gsd-verifier)_
