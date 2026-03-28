# Phase 2: Follow-up + Multi-tenant — Research

**Researched:** 2026-03-27
**Domain:** n8n delayed execution (Wait node), multi-tenant workflow architecture, credential isolation, business hours gating
**Confidence:** HIGH (n8n patterns), MEDIUM (credential isolation workaround — community-verified, not official docs)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NOTIF-03 | If the owner hasn't called back after a configurable delay, the prospect receives an automatic follow-up | Wait node (After Time Interval) + business hours IF gate + follow-up SMS send |
| CONF-01 | Each client has its own configuration (company name, channels, delays, service type) | Per-client JSON config schema; config passed as payload to Core Workflow via Execute Sub-workflow |
| CONF-02 | A single shared Core Workflow serves all clients (multi-tenant) | Entry workflow → Core Workflow via Execute Sub-workflow with Wait for completion disabled |
| CONF-03 | Each client has a unique webhook URL slug (`/webhook/dupont-plomberie`) | Thin entry workflows with one Webhook node each, slug hard-coded in `path` parameter |
</phase_requirements>

---

## Summary

Phase 2 adds two capabilities on top of the Phase 1 critical path: (1) an automated follow-up message to the prospect if the owner does not call back within a configurable delay, and (2) a multi-tenant architecture that lets a single Core Workflow serve N clients without credential cross-contamination.

The follow-up is implemented using the n8n Wait node in "After Time Interval" mode. For delays over 65 seconds, n8n serializes the full execution state to its Postgres database and resumes after the interval — surviving server restarts. This is the architecturally correct tool: no external cron, no Redis, no separate scheduler. The follow-up must be gated behind a business-hours check (08:00–20:00 Mon–Sat, Europe/Paris) using a Code node or IF node with Luxon datetime expressions.

Multi-tenancy is implemented with a "thin entry workflow + shared Core Workflow" pattern. Each client gets one lightweight entry workflow containing only a Webhook node (with the client-specific slug) and an Execute Sub-workflow node that calls the shared Core Workflow, passing the full lead payload plus the loaded client config. The critical credential isolation constraint: n8n community edition cannot dynamically switch which named credential is used at runtime (that is an enterprise feature). The correct solution for this project is to pass Twilio Account SID and Auth Token as data fields in the client config JSON, and use HTTP Request nodes with an `Authorization` header built from an expression (`Basic btoa(sid:token)`). This is already the pattern Phase 1 uses — the main workflow uses `genericAuthType: httpBasicAuth` with a stored credential, but the Twilio calls are HTTP Request nodes, not native Twilio nodes, so the header can be made fully expression-driven with per-client values.

**Primary recommendation:** Use Execute Sub-workflow (Wait for Completion = OFF for fire-and-forget) to call the shared Core Workflow from each thin entry workflow. Pass client config as a JSON field in the input payload. The Core Workflow receives the full lead + config in a single object via the "When Executed by Another Workflow" trigger (Accept All Data mode). Build Twilio Authorization headers from expressions using client-config-sourced credentials.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| n8n Wait node | Built-in (v1.x) | Pauses execution for configurable delay, resumes after | Serializes to Postgres; survives restarts; no external infra required |
| n8n Execute Sub-workflow node | Built-in | Calls Core Workflow from entry workflow | Passes full payload as JSON; fire-and-forget mode available |
| n8n Execute Sub-workflow Trigger | Built-in | Receives payload in Core Workflow | "Accept All Data" mode; all parent fields available as `$json` |
| Luxon (`$now`) | Built-in (n8n ships Luxon) | Business hours check with timezone | n8n expressions use Luxon for datetime; `$now.setZone('Europe/Paris').hour` works natively |

### No New External Dependencies
Phase 2 adds no new services. Same stack as Phase 1: n8n + Twilio (HTTP Request) + Brevo + Claude API.

---

## Architecture Patterns

### Recommended Project Structure

```
workflows/
├── speed-to-lead-entry-dupont-plomberie.json   # Thin entry: webhook + config load + execute core
├── speed-to-lead-entry-cabinet-martin.json     # Same thin pattern, different slug and config
├── speed-to-lead-core.json                     # Shared Core Workflow (parameterized)
└── speed-to-lead-error-handler.json            # Unchanged from Phase 1

config/
├── dupont-plomberie.json                       # Per-client config (extended with follow_up fields)
└── cabinet-martin.json                         # New client config
```

### Pattern 1: Thin Entry Workflow

Each client has one entry workflow. It contains exactly:
1. **Webhook node** — path set to the client slug (e.g., `dupont-plomberie`), `responseMode: onReceived` to return 200 immediately
2. **Code node** — loads the client config (hardcoded JSON inline or read from a static config object), merges it with the incoming lead payload
3. **Execute Sub-workflow node** — calls Core Workflow with the merged payload, `waitForSubWorkflow: false` (fire-and-forget)

```json
// Entry workflow: Execute Sub-workflow node parameters (key fields)
{
  "name": "Execute: Core Workflow",
  "type": "n8n-nodes-base.executeWorkflow",
  "parameters": {
    "source": "database",
    "workflowId": { "__rl": true, "value": "CORE_WORKFLOW_ID", "mode": "id" },
    "options": { "waitForSubWorkflow": false }
  }
}
```

**Why fire-and-forget here:** The entry workflow's only obligation is to return HTTP 200 to Google Ads immediately (INGEST-01, RESP-05). The actual processing (Claude call, Twilio sends, Wait, follow-up) must run asynchronously. Setting `waitForSubWorkflow: false` ensures the entry workflow completes as soon as the sub-workflow is triggered.

### Pattern 2: Core Workflow Trigger — Accept All Data

The Core Workflow starts with an "Execute Sub-workflow Trigger" node (also called "When Executed by Another Workflow") configured with input data mode "Accept All Data". This makes all fields passed from the entry workflow available as `$json` in the next node.

```json
{
  "name": "When Executed by Another Workflow",
  "type": "n8n-nodes-base.executeWorkflowTrigger",
  "parameters": {
    "inputData": {}
  }
}
```

The incoming `$json` will contain the full lead fields (`lead_id`, `phone`, `name`, `request`, etc.) plus the client config fields (`client_slug`, `business_name`, `owner_phone`, `follow_up_delay_minutes`, `twilio_account_sid`, `twilio_auth_token`, `twilio_sender_id`).

### Pattern 3: Wait Node for Follow-up Delay

After the owner notification is sent, add a Wait node in "After Time Interval" mode. Duration comes from the client config passed through the execution.

```javascript
// Code node before Wait: read follow_up_delay from client config
// $json.follow_up_delay_minutes is available from the merged payload
```

Wait node parameters:
```json
{
  "name": "Wait: Follow-up Delay",
  "type": "n8n-nodes-base.wait",
  "parameters": {
    "resume": "timeInterval",
    "unit": "minutes",
    "amount": "={{ $json.follow_up_delay_minutes }}"
  }
}
```

**Persistence behavior:**
- Delays < 65 seconds: execution stays in memory (not persisted to DB)
- Delays >= 65 seconds: execution state serialized to Postgres; resumes after restart
- For this use case (45 min default), state is always persisted — server restarts are safe
- No known maximum duration; executions can wait hours or days

**Known issue to watch:** Community reports of Wait nodes not resuming after n8n version upgrades (1.36+), often caused by timezone mismatch between n8n instance and Postgres. Set `GENERIC_TIMEZONE=Europe/Paris` on the n8n Railway instance as a precaution.

### Pattern 4: Business Hours Gate

After the Wait node resumes, check whether the current time in France is within the allowed follow-up window before sending the follow-up message.

```javascript
// Code node: Business Hours Check
const now = $now.setZone('Europe/Paris');
const hour = now.hour;           // 0–23
const weekday = now.weekday;     // 1=Mon ... 6=Sat ... 7=Sun

const isBusinessHours = (
  weekday >= 1 &&   // Monday or later
  weekday <= 6 &&   // Saturday or earlier (6=Sat, 7=Sun excluded)
  hour >= 8 &&      // 08:00 or later
  hour < 20         // before 20:00
);

return [{ json: { ...($input.first().json), business_hours_ok: isBusinessHours } }];
```

Then an IF node routes on `business_hours_ok`:
- TRUE branch → send follow-up SMS
- FALSE branch → log "Outside hours, follow-up skipped" (no send)

**Timezone note:** `$now` in n8n uses the workflow's configured timezone or the instance timezone. Using `.setZone('Europe/Paris')` explicitly is safer than relying on instance config — it works correctly regardless of the Railway server's system timezone.

**DST handling:** Luxon's `setZone('Europe/Paris')` handles DST automatically (CET = UTC+1 in winter, CEST = UTC+2 in summer). No manual offset needed.

### Pattern 5: Dynamic Twilio Credentials per Client

n8n community edition does not support dynamically selecting which named credential is used at runtime. Dynamic credential switching is an enterprise-only feature. However, Phase 1 already uses HTTP Request nodes for Twilio (not the built-in Twilio node), specifically because the built-in node doesn't support alphanumeric sender IDs required in France. This means credential injection via expression is straightforward: pass `twilio_account_sid` and `twilio_auth_token` in the client config JSON, then construct the Authorization header directly in the HTTP Request node.

```json
// HTTP Request node headers for Twilio — dynamic per-client credentials
{
  "name": "Authorization",
  "value": "=Basic {{ Buffer.from($json.twilio_account_sid + ':' + $json.twilio_auth_token).toString('base64') }}"
}
```

**URL also parameterized:**
```
=https://api.twilio.com/2010-04-01/Accounts/{{ $json.twilio_account_sid }}/Messages.json
```

**Security note:** `twilio_account_sid` and `twilio_auth_token` should NOT be stored in the client config JSON files committed to git. Options:
1. Store them as n8n environment variables with a client-slug prefix (e.g., `DUPONT_TWILIO_ACCOUNT_SID`) and read via `$env.DUPONT_TWILIO_ACCOUNT_SID` in a Code node that builds the config object.
2. Store them in the client config JSON but add the config files to `.gitignore`. The current `config/dupont-plomberie.json` has an `_comment` noting this constraint explicitly.

The simplest approach for a solo operator: store all per-client sensitive values as n8n environment variables with a `CLIENTSLUG_` prefix. The Code node in the entry workflow reads them and assembles the config object before passing to the Core Workflow.

### Pattern 6: Per-Client Config Schema (Extended for Phase 2)

The existing `config/dupont-plomberie.json` needs three new fields for Phase 2:

```json
{
  "client_slug": "dupont-plomberie",
  "business_name": "Dupont Plomberie",
  "service_type": "plombier",
  "city": "Paris",
  "owner_phone": "+33600000000",
  "owner_email": "contact@dupont-plomberie.fr",
  "callback_promise_minutes": 30,
  "follow_up_delay_minutes": 45,
  "follow_up_enabled": true,
  "active": true,
  "env_vars_required": {
    "GOOGLE_KEY": "...",
    "DUPONT_TWILIO_ACCOUNT_SID": "Per-client Twilio Account SID",
    "DUPONT_TWILIO_AUTH_TOKEN": "Per-client Twilio Auth Token",
    "DUPONT_TWILIO_SENDER_ID": "Per-client alphanumeric sender ID",
    "ANTHROPIC_API_KEY": "...",
    "BREVO_API_KEY": "...",
    "BAPTISTE_PHONE": "..."
  }
}
```

New fields:
- `follow_up_delay_minutes`: int, default 45. How long to wait before follow-up.
- `follow_up_enabled`: bool, default true. Allows disabling follow-up per client without removing the config.

### Anti-Patterns to Avoid

- **Hard-coding client values in Core Workflow:** If the Claude system prompt embeds `$env.BUSINESS_NAME`, it only works for one client. Phase 2 requires these values come from the client config payload via `$json.business_name`.
- **Using `waitForSubWorkflow: true` in entry workflow:** This blocks the entry workflow until the Core Workflow finishes (including the 45-minute Wait). The entry workflow's HTTP 200 response would never return to Google Ads — all leads would time out.
- **Storing `twilio_account_sid` / `twilio_auth_token` in plain text in config JSON committed to git:** Credential leak. Use environment variables with client-slug prefix.
- **IF node business hours check without explicit timezone:** Using `$now.hour` without `.setZone('Europe/Paris')` will use the server's system timezone (Railway defaults to UTC). Leads arriving at 09:00 Paris time (08:00 UTC in winter) would be incorrectly blocked.
- **One workflow copy per client:** Duplicating the Core Workflow for each client means any bug fix requires N edits. Unsustainable beyond 3 clients.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Delayed execution / scheduled follow-up | Cron job + Redis + custom scheduler | n8n Wait node (After Time Interval) | Wait node serializes to Postgres natively; no extra infra; survives restarts |
| Multi-client routing | Form_id → client lookup table | Per-client webhook URL slug | Slug is stable; form_id changes when campaigns rebuild |
| Timezone-aware business hours | Custom UTC offset calculation | Luxon `.setZone('Europe/Paris')` | Handles DST automatically; verified in n8n official cookbook |
| Dynamic credentials | n8n credential store per client (enterprise) | HTTP Request node with Authorization header built from expression | Phase 1 already uses HTTP Request for Twilio; extend to parameterize the credentials |

---

## Common Pitfalls

### Pitfall 1: Core Workflow Nodes Still Reference `$env.*` for Client-Specific Values

**What goes wrong:** Phase 1 Core Workflow nodes use `$env.BUSINESS_NAME`, `$env.SERVICE_TYPE`, `$env.CITY`, `$env.OWNER_PHONE`, `$env.TWILIO_ACCOUNT_SID`, `$env.TWILIO_SENDER_ID` directly. These must all be replaced with `$json.business_name`, `$json.owner_phone`, etc. — values coming from the client config payload.

**Why it happens:** Phase 1 was hardcoded for one client. Straightforward refactor, but every node that touches a client-specific value must be audited.

**How to avoid:** Audit each node in speed-to-lead-main.json for `$env.*` references. Replace each with the corresponding `$json.*` field from the client config. Keep `$env.ANTHROPIC_API_KEY` and `$env.BAPTISTE_PHONE` as shared env vars (not per-client).

**Nodes in Phase 1 with `$env.*` that need refactoring:**
- `HTTP Request: Claude API` — system prompt embeds `$env.BUSINESS_NAME`, `$env.SERVICE_TYPE`, `$env.CITY`, `$env.CALLBACK_MINUTES`
- `HTTP Request: Twilio SMS (Prospect)` — `$env.TWILIO_ACCOUNT_SID` in URL, `$env.TWILIO_SENDER_ID` as From
- `HTTP Request: Twilio SMS (Owner)` — `$env.OWNER_PHONE` as To, `$env.TWILIO_ACCOUNT_SID` in URL, `$env.TWILIO_SENDER_ID` as From
- `Brevo: Send Email (Prospect)` — `$env.BREVO_SENDER_EMAIL`, `$env.BUSINESS_NAME`

### Pitfall 2: Entry Workflow Blocks on Sub-workflow (Loses 200 Response)

**What goes wrong:** If `waitForSubWorkflow` is set to `true` (the default in some n8n versions), the entry workflow thread waits for the Core Workflow to complete before returning the HTTP response. Since the Core Workflow includes a 45-minute Wait node, Google Ads receives a timeout — not a 200 — and may retry the lead.

**Why it happens:** `waitForSubWorkflow: true` is the safe default because it lets the parent workflow use the sub-workflow's output. For fire-and-forget use cases it must be explicitly disabled.

**How to avoid:** In the Execute Sub-workflow node, set `options.waitForSubWorkflow: false`. Verify in the exported JSON that the `options` block contains `"waitForSubWorkflow": false`.

### Pitfall 3: Wait Node Not Resuming After n8n Update

**What goes wrong:** Community reports (n8n 1.36+) of Wait nodes getting stuck in "Waiting" status after n8n instance restarts or updates, caused by timezone configuration drift between the n8n process and Postgres.

**Why it happens:** n8n stores resume timestamps in UTC in the database. If the instance's `GENERIC_TIMEZONE` environment variable disagrees with the Postgres timezone setting, resume time comparisons fail silently.

**How to avoid:** Set `GENERIC_TIMEZONE=Europe/Paris` consistently in Railway's n8n environment variables. After any n8n version upgrade, verify a test execution resumes correctly by setting a 2-minute Wait and waiting.

### Pitfall 4: Follow-up Fires When Owner Already Called

**What goes wrong:** The v1 design always sends the follow-up after the delay, even if the owner called the prospect. The prospect receives a confusing second message.

**Why it happens:** No call detection in v1 — this is an explicit v1 limitation documented in the architecture.

**How to avoid:** Make the follow-up message soft: "Toujours disponible si vous avez des questions — [Business Name] peut vous rappeler maintenant." Not a "sorry we haven't called" message. Annoying if redundant, but not damaging. SUIV-01 (Twilio call log check) in v2 Roadmap is the proper fix.

### Pitfall 5: Client Config Credentials in Git

**What goes wrong:** `twilio_account_sid` and `twilio_auth_token` are stored in `config/dupont-plomberie.json` and committed to the repo.

**Why it happens:** Convenience. The existing config JSON is already in git.

**How to avoid:** Sensitive values (`twilio_account_sid`, `twilio_auth_token`) must live in n8n environment variables. The config JSON file stores only non-sensitive values. Use a `CLIENTSLUG_` prefix naming convention: `DUPONT_TWILIO_ACCOUNT_SID`, `DUPONT_TWILIO_AUTH_TOKEN`, `DUPONT_TWILIO_SENDER_ID`. The Code node in the entry workflow reads these via `$env.*` and injects them into the config object before passing to the Core Workflow.

---

## Code Examples

### Business Hours Check (Code Node)

```javascript
// Source: Luxon docs + n8n Luxon cookbook (https://docs.n8n.io/code/cookbook/luxon/)
const now = $now.setZone('Europe/Paris');
const hour = now.hour;       // 0-23
const weekday = now.weekday; // 1=Mon, 2=Tue, ..., 6=Sat, 7=Sun

// NOTIF-03: Only send follow-up Mon-Sat 08:00-20:00 Paris time
const business_hours_ok = (
  weekday >= 1 &&
  weekday <= 6 &&
  hour >= 8 &&
  hour < 20
);

return [{ json: { ...$input.first().json, business_hours_ok } }];
```

### Dynamic Twilio Authorization Header (HTTP Request Node)

```javascript
// Header value expression (in HTTP Request node headerParameters)
// Source: n8n community pattern — HTTP Request node sendHeaders
// $json.twilio_account_sid and $json.twilio_auth_token come from client config payload

"=Basic {{ Buffer.from($json.twilio_account_sid + ':' + $json.twilio_auth_token).toString('base64') }}"
```

### Entry Workflow Code Node: Assemble Client Config

```javascript
// Code node in entry workflow: read env vars + assemble config for Core Workflow
// Runs AFTER the Webhook node, BEFORE Execute Sub-workflow
const lead = $input.first().json;

const clientConfig = {
  client_slug: "dupont-plomberie",
  business_name: "Dupont Plomberie",
  service_type: "plombier",
  city: "Paris",
  owner_phone: "+33600000000",
  callback_promise_minutes: 30,
  follow_up_delay_minutes: 45,
  follow_up_enabled: true,
  // Sensitive: pulled from env vars, never from committed JSON
  twilio_account_sid: $env.DUPONT_TWILIO_ACCOUNT_SID,
  twilio_auth_token: $env.DUPONT_TWILIO_AUTH_TOKEN,
  twilio_sender_id: $env.DUPONT_TWILIO_SENDER_ID
};

// Merge lead payload with client config for Core Workflow
return [{ json: { ...lead, client_config: clientConfig } }];
```

### Wait Node JSON Structure

```json
{
  "name": "Wait: Follow-up Delay",
  "type": "n8n-nodes-base.wait",
  "typeVersion": 1,
  "parameters": {
    "resume": "timeInterval",
    "unit": "minutes",
    "amount": "={{ $json.client_config.follow_up_delay_minutes }}"
  }
}
```

### Execute Sub-workflow Node (Fire-and-Forget)

```json
{
  "name": "Execute: Core Workflow",
  "type": "n8n-nodes-base.executeWorkflow",
  "typeVersion": 2,
  "parameters": {
    "source": "database",
    "workflowId": {
      "__rl": true,
      "value": "CORE_WORKFLOW_ID",
      "mode": "id"
    },
    "options": {
      "waitForSubWorkflow": false
    }
  }
}
```

---

## Phase 1 Refactor Inventory

The Phase 1 `speed-to-lead-main.json` must be transformed into the shared Core Workflow. The following changes are required:

| Node | Current (Phase 1) | Required (Core Workflow) |
|------|-------------------|--------------------------|
| Webhook trigger | `path: dupont-plomberie` | Remove webhook — replaced by Execute Sub-workflow Trigger node |
| `Code: Log Raw Payload` | `$getWorkflowStaticData` write | Retain as-is (staticData still useful for error recovery) |
| `IF: google_key valid?` | Compares `$json.google_key` to `$env.GOOGLE_KEY` | Retain `$env.GOOGLE_KEY` (shared env var is acceptable — google_key comes from Google, not per-client) OR move to entry workflow |
| `Code: Extract Lead Fields` | Standalone | Retain |
| `HTTP Request: Claude API` | System prompt has `$env.BUSINESS_NAME`, `$env.SERVICE_TYPE`, `$env.CITY`, `$env.CALLBACK_MINUTES` | Replace with `$json.client_config.business_name`, etc. |
| `HTTP Request: Twilio SMS (Prospect)` | `$env.TWILIO_ACCOUNT_SID` in URL, `$env.TWILIO_SENDER_ID` as From | Dynamic Authorization header + URL from `$json.client_config.twilio_*` |
| `HTTP Request: Twilio SMS (Owner)` | `$env.OWNER_PHONE`, `$env.TWILIO_ACCOUNT_SID`, `$env.TWILIO_SENDER_ID` | Replace with `$json.client_config.owner_phone` and dynamic Twilio creds |
| `Brevo: Send Email (Prospect)` | `$env.BREVO_SENDER_EMAIL`, `$env.BUSINESS_NAME` | `$json.client_config.brevo_sender_email`, `$json.client_config.business_name` |
| NEW: Wait node | Not present | Add after owner notification |
| NEW: Business hours check | Not present | Code node + IF node after Wait |
| NEW: Follow-up SMS | Not present | HTTP Request Twilio with follow-up message |

**New node additions to the Core Workflow (after owner notification):**
1. `Wait: Follow-up Delay` — After Time Interval, duration from `$json.client_config.follow_up_delay_minutes`
2. `Code: Business Hours Check` — Luxon check, sets `business_hours_ok` field
3. `IF: Business Hours OK?` — Routes TRUE/FALSE
4. `HTTP Request: Twilio SMS (Follow-up)` — Follow-up message to prospect (TRUE branch)
5. `Code: Log Follow-up Skipped` — Log only, no send (FALSE branch)

**Env vars that remain shared (not per-client):**
- `ANTHROPIC_API_KEY` — single Anthropic account for Baptiste
- `BAPTISTE_PHONE` — Baptiste's own phone for error fallback
- `BREVO_API_KEY` — single Brevo account is sufficient (sender email per-client)

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| One workflow copy per client | Thin entry + shared Core Workflow | n8n subworkflows stable since ~1.0 | Bug fixes propagate to all clients instantly |
| Credential hardcoded in workflow | HTTP Request with expression-built Authorization header | Phase 2 requirement | Per-client Twilio accounts supported without enterprise license |
| Phase 1: hardcoded `dupont-plomberie` webhook path | Per-client entry workflow with client-specific slug | Phase 2 | N clients supported without Core Workflow changes |

---

## Environment Availability

Phase 2 adds no new external services or CLI tools. All dependencies were established in Phase 1.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| n8n (Railway) | Core orchestration | ✓ | Already running; Phase 2 adds workflows, not infra |
| Twilio (HTTP) | Prospect SMS, owner SMS, follow-up SMS | ✓ | Phase 1 validated; Phase 2 parameterizes per-client |
| Claude API (Anthropic) | AI message generation | ✓ | Shared key; unchanged |
| Brevo | Email fallback | ✓ | Shared key; email subject/sender parameterized per-client |
| Postgres (Railway) | Wait node persistence | ✓ | Required for Wait node > 65 seconds; Railway Postgres addon already present |

**Step 2.6: No new external dependencies identified. Environment fully available.**

---

## Validation Architecture

Config (`nyquist_validation: true`) — validation section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell scripts + curl (existing `tests/test-webhook.sh` pattern from Phase 1) |
| Config file | `tests/TESTING.md` — existing testing guide |
| Quick run command | `GOOGLE_KEY=<key> ./tests/test-webhook.sh happy` against entry workflow URL |
| Full suite command | Run all 4 fixtures: happy, duplicate, invalid-key, email-only |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| NOTIF-03 | Follow-up SMS fires after delay if owner doesn't call | Manual (live timing) | Set `follow_up_delay_minutes: 1` in test config, send lead, wait 1 min, verify Twilio log | Requires live Twilio; 45-min delay not practical for automated CI |
| NOTIF-03 | Follow-up does NOT fire outside business hours | Manual | Set test to 22:00 wait or mock clock | Timing-dependent; verify by inspecting "Log Follow-up Skipped" execution node |
| CONF-01 | Client config fields flow through to Core Workflow correctly | Integration | Send lead to entry workflow; verify `business_name` appears in Claude-generated SMS | Requires live Claude |
| CONF-02 | Second client entry workflow triggers same Core Workflow | Smoke | Import second entry workflow (cabinet-martin), send test lead, confirm Core Workflow execution appears in n8n execution log | Manual n8n UI check |
| CONF-03 | Each client has unique webhook URL slug | Smoke | `curl -X POST https://n8n.host/webhook/dupont-plomberie ...` and `.../cabinet-martin ...` both return 200 | `./tests/test-webhook.sh` with updated host |

### Wave 0 Gaps

- [ ] `tests/payloads/google-ads-lead.json` — reuse from Phase 1 (no changes needed)
- [ ] New test fixture or script parameter for second client (cabinet-martin slug)
- [ ] Test instructions for 1-minute follow-up delay test in TESTING.md

---

## Open Questions

1. **google_key validation: shared or per-client?**
   - What we know: Phase 1 compares `$json.google_key` to `$env.GOOGLE_KEY`. In multi-client setup, each client's Google Ads form sends a different `google_key`.
   - What's unclear: Should this move to the entry workflow (compared to a client-slug-specific env var: `$env.DUPONT_GOOGLE_KEY`) or stay in Core Workflow with the key passed in client config?
   - Recommendation: Move to entry workflow. The entry workflow is the right place for auth that is per-client. Core Workflow then trusts the payload it receives from authenticated entry workflows. Simpler: compare in entry workflow Code node before calling Execute Sub-workflow.

2. **Workflow ID vs workflow name for Execute Sub-workflow reference**
   - What we know: The Execute Sub-workflow node can reference by ID or name. IDs are assigned at import time and differ between n8n instances. Names are stable across exports.
   - What's unclear: Whether the `workflowId` parameter accepts a name string in current n8n versions, or whether we need to document a post-import step to update the ID reference.
   - Recommendation: Use workflow name reference where supported, or document a one-time post-import step to update the Core Workflow ID. Include in `_setup_notes` of the entry workflow JSON.

3. **Error handler workflow scope in multi-tenant setup**
   - What we know: The existing error handler reads `staticData.lastLead` from the main workflow. In multi-tenant setup, the Core Workflow becomes the "main workflow." The error handler must be linked to the Core Workflow (not entry workflows).
   - What's unclear: Whether staticData carries correctly in the sub-workflow context when error triggers fire.
   - Recommendation: Link error handler to Core Workflow in its settings. Test with an intentional failure in a Core Workflow execution to verify `staticData.lastLead` is available in the error handler.

---

## Sources

### Primary (HIGH confidence)
- n8n Wait node docs — https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.wait/ — "After Time Interval" mode, persistence behavior
- n8n Luxon cookbook — https://docs.n8n.io/code/cookbook/luxon/ — `$now.setZone()`, `.hour`, `.weekday` syntax
- n8n Execute Sub-workflow docs — https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executeworkflow/ — parameters, fire-and-forget mode
- n8n Execute Sub-workflow Trigger docs — https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executeworkflowtrigger/ — Accept All Data mode
- n8n Sub-workflows flow logic — https://docs.n8n.io/flow-logic/subworkflows/

### Secondary (MEDIUM confidence)
- n8n community: Wait node 65s threshold and Postgres persistence — https://community.n8n.io/t/wait-node-does-not-continue-after-65-seconds/32550 — confirmed in community (not yet in official docs)
- n8n community: Dynamic credentials (enterprise-only) + HTTP Request workaround — https://community.n8n.io/t/possible-to-do-multi-tenant-workflows-that-can-reference-credentials-dynamically/62218
- n8n community: Basic auth expression usage — https://community.n8n.io/t/how-to-use-basic-auth-with-dynamic-username-password/31658 — expressions work in credentials; single-item execution limit
- Multi-tenant n8n agency patterns — https://www.wednesday.is/writing-articles/building-multi-tenant-n8n-workflows-for-agency-clients
- n8n Execute Sub-workflow data passing — https://community.n8n.io/t/passing-parameters-to-a-sub-workflow/40842

### Tertiary (LOW confidence — verify before relying)
- n8n Wait node not resuming in v1.36+ — https://community.n8n.io/t/wait-node-not-resuming-after-the-date-has-passed/44733 — community reports only; check current n8n version on Railway before Phase 2 execution

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Wait node, Execute Sub-workflow, Luxon are all core n8n features with official docs
- Architecture (thin entry + shared core): HIGH — validated in production multi-tenant case studies; matches prior Phase 1 research
- Credential isolation (HTTP header expression): MEDIUM — community workaround, not official multi-tenant docs; confirmed working for Twilio (HTTP Request pattern already in Phase 1)
- Business hours check: HIGH — Luxon `.setZone()` + `.weekday` syntax confirmed in official n8n Luxon cookbook
- Phase 1 refactor scope: HIGH — derived from reading actual workflow JSON, not inferred

**Research date:** 2026-03-27
**Valid until:** 2026-05-27 (n8n updates frequently; verify Wait node behavior on current Railway version before execution)
