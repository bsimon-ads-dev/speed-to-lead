# Phase 3: WhatsApp + Hardening — Research

**Researched:** 2026-03-27
**Domain:** Twilio WhatsApp Business API (WABA), Meta message templates, UptimeRobot monitoring, n8n circuit breaker via staticData, Anthropic spend caps
**Confidence:** HIGH (Twilio API format, Anthropic limits), MEDIUM (WABA onboarding timeline), MEDIUM (circuit breaker pattern for this specific use case)

---

## Summary

Phase 3 has two distinct concerns: adding WhatsApp as a messaging channel (both prospect and owner) and hardening the system for production growth. These are largely independent workstreams that share only the config schema and the Core Workflow.

The WhatsApp channel follows a strict constraint: all outbound messages must use pre-approved Meta utility templates. Free-form text to a new prospect is not allowed by the WhatsApp Business Platform. The practical consequence is that the AI-generated message (Claude output) cannot be sent as-is over WhatsApp — a fixed template body with one or two variables must be pre-submitted to Meta for approval, and the Claude output is either repurposed to fill a template variable or dropped in favor of a fixed template text. This is a fundamental design constraint that shapes how WhatsApp prospect messages work compared to SMS.

The hardening concerns (UptimeRobot, circuit breaker, Anthropic spend cap) are each a single configuration step or a small Code node addition. None require new external services beyond UptimeRobot (free tier is sufficient). The circuit breaker is implemented in a new Code node at the top of the Core Workflow that reads and writes to `$getWorkflowStaticData('global')` — the same mechanism already used for the error handler's `lastLead` recovery. The Anthropic spend cap is a console setting with no code changes.

**Primary recommendation:** Build the WhatsApp channel as a parallel branch in the Core Workflow controlled by a new `whatsapp_enabled` flag in client config. The template body is fixed ("Bonjour [name], votre demande a bien été reçue. [Business] vous rappelle sous [X] minutes.") — Claude output is not used for WhatsApp. The circuit breaker and UptimeRobot can be added in the same phase with minimal scope.

---

## Standard Stack

### Core (no new dependencies — extends existing Twilio integration)

| Component | What Changes | Notes |
|-----------|-------------|-------|
| Twilio REST API (Messages.json) | From/To prefix `whatsapp:+E.164` instead of bare E.164 | Same endpoint, same HTTP Request node pattern already in use |
| Twilio Content Template Builder | New — templates created in Twilio Console, submitted for WhatsApp approval | ContentSid returned after approval (format `HXXXXXXXXXX`) |
| UptimeRobot | New external monitoring service | Free tier: 50 monitors, 5-min checks, email alerts |
| Anthropic Console | Monthly spend cap setting | No code change — console-only |
| n8n `$getWorkflowStaticData('global')` | New Code node at Core Workflow entry | Same API already used in Error Handler for `lastLead` |

### No new npm packages, no new n8n nodes required.

---

## Architecture Patterns

### How WhatsApp Differs from SMS in this Architecture

The existing SMS send is:
```
HTTP Request node → POST /Messages.json → Body: {{ $json.claude_message }}, From: DupontPlomb, To: +336...
```

The WhatsApp send is:
```
HTTP Request node → POST /Messages.json → ContentSid: HX..., ContentVariables: {"1":"Marie","2":"30"}, From: whatsapp:+33..., To: whatsapp:+336...
```

Key differences:
1. `From` and `To` must have `whatsapp:` prefix — bare E.164 sends via SMS, not WhatsApp
2. No `Body` field — `ContentSid` replaces it for template messages
3. `ContentVariables` is a JSON-stringified object `{"1":"value","2":"value"}` matching the template's `{{1}}`, `{{2}}` placeholders
4. The WhatsApp sender must be a Twilio-registered WhatsApp number, not an alphanumeric sender ID (alphanumeric sender IDs are SMS-only)

### Recommended Project Structure Changes

```
config/
├── dupont-plomberie.json       # Add: whatsapp_enabled, whatsapp_template_sid, whatsapp_sender
├── cabinet-martin.json         # Same additions
workflows/
├── speed-to-lead-core.json     # Add: circuit breaker node, WhatsApp branch
├── speed-to-lead-error-handler.json  # Unchanged
├── speed-to-lead-entry-dupont-plomberie.json  # Add: whatsapp config fields to clientConfig
└── speed-to-lead-entry-cabinet-martin.json    # Same
```

### Pattern 1: WhatsApp Branch in Core Workflow

The Core Workflow currently routes on phone availability. Phase 3 adds a second routing layer within the phone branch: if `client_config.whatsapp_enabled === true`, send via WhatsApp template; otherwise send via SMS (existing behavior).

```
IF: phone available?
  TRUE → IF: whatsapp_enabled?
            TRUE  → HTTP Request: Twilio WhatsApp (Prospect) [template]
            FALSE → HTTP Request: Twilio SMS (Prospect) [existing]
  FALSE → Brevo: Send Email (Prospect) [existing]
```

Both branches converge at "Code: Format Owner Notification" (existing node), which is unchanged.

Owner notification follows the same split: if `client_config.owner_whatsapp_enabled`, send owner notification via WhatsApp template; otherwise use existing SMS.

### Pattern 2: WhatsApp HTTP Request Node (exact format)

```javascript
// Source: https://www.twilio.com/docs/whatsapp/api (verified 2026-03-27)
// POST https://api.twilio.com/2010-04-01/Accounts/{SID}/Messages.json
// Body (form-encoded keypairs):
{
  To:               "whatsapp:+33612345678",       // whatsapp: prefix required
  From:             "whatsapp:+33600000001",        // registered WABA number, NOT alphanumeric
  ContentSid:       "HXabc123...",                  // from Twilio Console after approval
  ContentVariables: "{\"1\":\"Marie\",\"2\":\"30\"}" // JSON string, numbered keys
}
// Auth: Basic base64(account_sid:auth_token) — same as existing SMS nodes
```

In n8n HTTP Request node bodyParameters:
- `To`: `=whatsapp:{{ $json.phone }}`
- `From`: `=whatsapp:{{ $json.client_config.whatsapp_sender }}`
- `ContentSid`: `={{ $json.client_config.whatsapp_template_sid }}`
- `ContentVariables`: `={"1":"{{ $json.name }}","2":"{{ $json.client_config.callback_promise_minutes }}"}`

### Pattern 3: Circuit Breaker via staticData

The circuit breaker lives in a new first Code node in the Core Workflow, placed before "Code: Log Raw Payload":

```javascript
// Source: n8n staticData pattern — https://docs.n8n.io/code/cookbook/builtin/get-workflow-static-data/
// Adapted for lead_id window counting

const lead = $input.first().json;
const lead_id = lead.lead_id;

if (!lead_id) return $input.all(); // no lead_id — pass through

const staticData = $getWorkflowStaticData('global');
const WINDOW_MS = 10 * 60 * 1000; // 10 minutes
const THRESHOLD = 5;
const now = Date.now();

// Read existing tracker (keyed by lead_id)
const tracker = staticData.circuitBreaker || {};

if (!tracker[lead_id]) {
  tracker[lead_id] = { count: 0, first_seen: now };
}

const entry = tracker[lead_id];

// Reset if window has expired
if (now - entry.first_seen > WINDOW_MS) {
  entry.count = 0;
  entry.first_seen = now;
}

entry.count += 1;

// Prune stale entries (older than 20 minutes) to prevent unbounded growth
for (const id of Object.keys(tracker)) {
  if (now - tracker[id].first_seen > 2 * WINDOW_MS) {
    delete tracker[id];
  }
}

staticData.circuitBreaker = tracker;

if (entry.count > THRESHOLD) {
  // Return special halt flag — downstream IF node routes to alert branch
  return [{ json: { ...lead, circuit_breaker_tripped: true, cb_count: entry.count } }];
}

return [{ json: { ...lead, circuit_breaker_tripped: false } }];
```

After this node: an IF node checks `circuit_breaker_tripped`. If true, routes to a Twilio SMS alert to Baptiste then stops. If false, proceeds to "Code: Log Raw Payload" (existing flow).

**Important limitation:** `$getWorkflowStaticData('global')` persists across production executions (webhook-triggered), but NOT across manual test executions. Test executions use isolated static data. This is correct behavior for production; verify circuit breaker with real webhook-triggered executions, not manual runs.

**Known issue:** Versions of n8n around 1.86.x had a Docker-specific bug where `getWorkflowStaticData` threw "not a function" — resolved in later patches. If Baptiste hits this, the workaround is to use `this.getWorkflowStaticData('global')` inside older-style Function nodes, or upgrade n8n.

### Pattern 4: Meta Utility Template Design

Meta rejects templates that are generic or promotional. For a "lead received" notification, the correct category is **UTILITY** — the user submitted a form (requested interaction), so this qualifies.

Approved example:
```
Template name: speed_to_lead_confirm_fr
Category: UTILITY
Language: fr
Body: "Bonjour {{1}}, votre demande a bien été reçue. {{2}} vous rappelle sous {{3}} minutes."
Variables: {"1":"Marie","2":"Dupont Plomberie","3":"30"}
```

Rejection-risk patterns to avoid:
- Generic openers like "Important: {{1}}" (rejected — vague content)
- Persuasive/promotional wording ("Profitez de notre offre...")
- Prices or guarantees ("intervention à 80€")
- Beginning or ending with a placeholder variable alone
- The template already defined as an SMS message sent verbatim (Claude output varies — cannot be a template body)

Since Claude generates variable text, the WhatsApp template must use fixed body text with the prospect name and business name as variables. Claude's output is NOT used for WhatsApp — it is used for SMS and email only.

Owner notification template:
```
Template name: speed_to_lead_owner_notif_fr
Category: UTILITY
Language: fr
Body: "Nouveau lead: {{1}} — Demande: {{2}} — Tel: {{3}}"
Variables: {"1":"Marie Dupont","2":"fuite d'eau sous l'évier","3":"+33612345678"}
```

### Pattern 5: UptimeRobot Setup for n8n Webhook

Monitor type: **HTTP(s)**
URL to monitor: `https://[n8n-host]/webhook/dupont-plomberie` (the live webhook URL, not webhook-test)
Alert condition: Returns non-2xx OR times out in > 10 seconds
Alert contact: Baptiste's email (free) or SMS credits (purchased separately, ~$0.02/alert)
Check interval: 5 minutes (free tier maximum frequency)
Alert delay: Send alert after 1 failed check (no need to wait 2-3) — for a lead response system, 5 minutes downtime is already serious.

Free tier has 50 monitors and 5 integrations (email is one) — more than sufficient.

**Note:** UptimeRobot webhooks (which could POST to an n8n workflow for richer alerting) require Team plan ($20/month). For this use case, email alert is sufficient on the free tier.

### Pattern 6: Anthropic Spend Cap

Location: Claude Console → Settings → Limits → Spend limits → "Change Limit"

Recommended setting for v1 (2-3 clients, ~100 leads/month):
- Set customer-configured limit to **$20/month** (current actual spend ≈ $0.30/month; $20 is a 65x safety margin that still catches runaway bugs)
- At Tier 1, the Anthropic-enforced ceiling is $100/month — the customer-set limit overrides this downward

When the customer-set limit is hit, the API returns HTTP 429 with a rate-limit error. This triggers the n8n Error Handler workflow, which sends Baptiste a fallback SMS. The lead is lost but Baptiste is alerted.

**No code change required** — the spend cap is entirely a console setting. The existing error handler already covers the 429 response scenario.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WhatsApp template management | Custom template DB or file registry | Twilio Console Content Template Builder | Twilio handles template status, ContentSid, and Meta submission — no custom tracking needed |
| Uptime monitoring | n8n self-ping cron workflow | UptimeRobot free tier | n8n monitoring itself with n8n fails when n8n goes down — external monitoring is the only reliable option |
| Rate limiting / spend capping | Token counting in n8n | Anthropic console spend limit | Anthropic enforces it server-side; n8n-side counting is unreliable under concurrent executions |
| WABA account management | Per-client Twilio sub-accounts | One WABA with multiple phone numbers | Twilio constrains each account to one WABA; multiple phone numbers within one WABA is the supported multi-tenant pattern for small ISVs |

---

## WABA Architecture: One Account, Multiple Numbers

**Key constraint (verified via Twilio docs):** A single Twilio account can only have one WABA. All WhatsApp senders (phone numbers) within that Twilio account must belong to that one WABA.

For Baptiste's multi-client use case this means:
- One Twilio account → one WABA → multiple registered WhatsApp phone numbers (one per client)
- Each client gets their own WhatsApp number — quality rating issues on one client's number don't directly affect other numbers (each number has its own quality rating)
- Template approval is per-WABA — if the same template is used for all clients, it can be approved once and all clients share the same ContentSid
- If clients need different templates, each template has its own ContentSid (still within the same WABA)

**If per-client WABA isolation is required** (e.g., a client demands their own Meta Business Account): Twilio ISV/Tech Provider program allows Twilio sub-accounts each with their own WABA. This adds significant onboarding complexity — treat as out of scope for v1.

**Business verification timeline:** If the Twilio account's associated Meta Business Portfolio has not completed Meta Business Verification, this is required before WhatsApp senders can be activated. Meta verification takes 5-20 business days. Start this early if the Meta Business Portfolio is new.

---

## Common Pitfalls

### Pitfall 1: Sending Free-Form Text Over WhatsApp to a New Prospect

**What goes wrong:** A Code node builds a message body and sends it via the Messages API with a `Body` parameter and the `whatsapp:` prefix. Twilio accepts the request (returns a message SID), but Meta never delivers the message to the prospect, or the WABA account gets flagged. No error is returned — silent failure.

**Why it happens:** WhatsApp requires pre-approved templates for business-initiated messages to users who have not previously messaged the business. `Body` parameter on a WhatsApp message only works inside a 24-hour customer service window (after the prospect messages first). Sending `ContentSid` + `ContentVariables` instead of `Body` is mandatory for outbound-initiated contact.

**How to avoid:** Never set a `Body` parameter on a WhatsApp HTTP Request node. Always use `ContentSid` + `ContentVariables`. Verify in the n8n node that no `Body` key-pair is present.

**Warning signs:** Twilio returns an `MM...` SID but recipient sees nothing. No delivery receipt in Twilio Console.

### Pitfall 2: Using Alphanumeric Sender ID for WhatsApp

**What goes wrong:** The existing `twilio_sender_id` config field contains an alphanumeric value (e.g., "DupontPlomb"). Using this as the WhatsApp `From` field will fail — WhatsApp only supports E.164 phone numbers as senders, not alphanumeric IDs.

**How to avoid:** Add a separate `whatsapp_sender` field to client config storing the E.164 phone number registered as a WhatsApp sender (`+33600000001`). Never reuse `twilio_sender_id` for WhatsApp sends.

### Pitfall 3: Missing `whatsapp:` Prefix on To/From

**What goes wrong:** A WhatsApp HTTP Request node sends to `+33612345678` instead of `whatsapp:+33612345678`. Twilio routes this as an SMS instead of WhatsApp — no error, wrong channel.

**How to avoid:** Hardcode the `whatsapp:` prefix in the node's `To` and `From` parameter expressions: `=whatsapp:{{ $json.phone }}`. Do not rely on `client_config` to include the prefix.

### Pitfall 4: Circuit Breaker staticData Lost After n8n Restart

**What goes wrong:** n8n restarts (deployment update, OOM kill). The `staticData.circuitBreaker` object is cleared. After restart, the same lead_id that was at count 4 before the restart starts from 0 — it takes 5 more duplicate calls before the breaker trips.

**Why it happens:** n8n persists staticData to Postgres (on Railway with Postgres addon) after each successful workflow execution. This means data IS persisted across restarts IF the workflow completed normally. However, if n8n crashes mid-execution, the last staticData write may not have flushed. The circuit breaker window is 10 minutes — a crash + restart under 10 minutes could allow a few extra duplicate calls through.

**How to avoid:** Accept this as a minor gap. The circuit breaker is a defense against webhook bugs (sending 50+ identical leads), not against the 1-2 duplicate calls Google Ads may naturally deliver. The existing `lead_id` deduplication via `Remove Duplicates` node is the primary defense against duplicates; the circuit breaker is the secondary defense against runaway loops.

### Pitfall 5: UptimeRobot Monitoring the Webhook-Test URL

**What goes wrong:** UptimeRobot is configured to monitor `/webhook-test/dupont-plomberie` instead of `/webhook/dupont-plomberie`. The test URL only responds when the workflow is in test mode (open in the n8n editor). In production, the test URL returns 404 — UptimeRobot fires constant false-positive alerts.

**How to avoid:** Use the production webhook URL (`/webhook/`, not `/webhook-test/`) in UptimeRobot. Verify the URL returns 200 with the workflow activated.

### Pitfall 6: Template ContentVariables as Object vs. JSON String

**What goes wrong:** `ContentVariables` is passed as a JavaScript object `{ "1": "Marie" }` in the n8n bodyParameters. Twilio expects a JSON string `'{"1":"Marie"}'`. When passed as an object, Twilio rejects the request or silently ignores the variables.

**How to avoid:** In the n8n HTTP Request node bodyParameters, set ContentVariables to the JSON string form. In the expression: `={"1":"{{ $json.name }}","2":"{{ $json.client_config.callback_promise_minutes }}"}`. This constructs a JSON string literal (n8n expression evaluates to string). Do not use `JSON.stringify()` in the expression field — the expression engine double-encodes it.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WhatsApp per-conversation pricing ($0.05-0.10/24h window) | Per-template-message pricing (utility: ~$0.02/msg) | July 2025 (Meta) | Phase 3 messaging is cheaper than original research assumed |
| WhatsApp template approval: 1-3 business days | Automated ML review: minutes to 24 hours | Late 2024 | Templates can be approved same-day; plan for 24h buffer |
| Template category auto-reclassification: manual | Meta auto-upgrades category if wrong (e.g., utility → marketing) | April 9, 2025 | `allow_category_change` no longer needed; Meta reclassifies automatically |
| WhatsApp outbound pricing with sessions | Flat per-message utility pricing | July 1, 2025 | Simplified cost model: each outbound template message billed individually |

**Deprecated:**
- `allow_category_change` parameter in template submission: removed as of April 2025, no longer needed
- Per-conversation billing: replaced by per-message billing in July 2025

---

## Config Schema Changes Required

The `client_config` assembled by entry workflows needs new fields for WhatsApp:

```json
{
  "whatsapp_enabled": false,           // prospect WhatsApp channel on/off
  "owner_whatsapp_enabled": false,     // owner notification via WhatsApp
  "whatsapp_sender": "+33600000001",   // E.164, registered WABA number (not alphanumeric)
  "whatsapp_template_sid": "HXabc...", // ContentSid from Twilio Console after approval
  "whatsapp_owner_template_sid": "HXdef..." // separate template for owner notification
}
```

New env vars per client (for clients enabling WhatsApp):
- `DUPONT_WHATSAPP_SENDER` — E.164 phone number registered as WhatsApp sender
- `DUPONT_WHATSAPP_TEMPLATE_SID` — prospect message template ContentSid
- `DUPONT_WHATSAPP_OWNER_TEMPLATE_SID` — owner notification template ContentSid

No new Twilio credentials needed (same account_sid/auth_token used for SMS works for WhatsApp).

---

## Onboarding Checklist (per new WhatsApp-enabled client)

Steps that must happen before activating a client's WhatsApp channel:

1. Buy a French virtual phone number in Twilio Console (~$1/month)
2. Enable WhatsApp on that number via Twilio Console Self Sign-up (requires Facebook login + Meta Business Portfolio access)
3. Complete Meta Business Verification if new portfolio (allow 5-20 business days)
4. Create prospect message template in Twilio Content Template Builder (category: UTILITY, language: fr)
5. Submit template for WhatsApp approval (typically minutes to 24h)
6. Create owner notification template (same process)
7. Copy ContentSids from approved templates into client config
8. Set DUPONT_WHATSAPP_SENDER, DUPONT_WHATSAPP_TEMPLATE_SID env vars in n8n
9. Set `whatsapp_enabled: true` in client config

This is a Baptiste-side onboarding task, not a client task. The client never touches any of this.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Twilio account (existing) | WhatsApp sends | Assumed yes (used in Phase 1+2) | — | — |
| Twilio WhatsApp-enabled number | WhatsApp prospect/owner | Requires onboarding | — | Keep SMS (whatsapp_enabled: false) |
| Meta Business Portfolio | WABA registration | Unknown — must be created/verified | — | Cannot proceed without |
| UptimeRobot account | Uptime monitoring | Free signup required | — | No fallback; monitoring is the safety net |
| Anthropic Console access | Spend cap setting | Assumed yes | — | — |
| n8n Railway (existing) | All | Assumed yes | 1.x | — |

**Pre-phase requirement:** Verify whether Baptiste already has a Meta Business Portfolio. If not, create one before the phase starts — Meta Business Verification blocks WABA activation and can take 5-20 days.

---

## Validation Architecture

Nyquist validation is enabled (config.json `nyquist_validation: true`).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell script (tests/test-webhook.sh) + manual verification |
| Config file | tests/TESTING.md |
| Quick run command | `GOOGLE_KEY=your_key ./tests/test-webhook.sh happy dupont-plomberie` |
| Full suite command | See tests/TESTING.md Phase 2 section + Phase 3 additions |

### Phase Requirements → Test Map

| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|-------------|
| CHAN-01 (success criterion 1) | WhatsApp prospect message sent via Twilio WABA template | manual + visual | Send test lead to WhatsApp-enabled client; verify WhatsApp delivery receipt in Twilio Console | Wave 0 — new test procedure |
| CHAN-01 (success criterion 1) | Free-form WhatsApp never sent | unit (Code node review) | Grep core.json for Body parameter on WhatsApp node | ❌ Wave 0 |
| Success criterion 2 | Owner WhatsApp notification when configured | manual + visual | Send test lead; check owner phone receives WhatsApp | Wave 0 — new test procedure |
| Success criterion 3 | UptimeRobot alerts within 5 min of n8n going down | manual | Stop n8n process; verify alert email arrives within 5 minutes | Manual, cannot automate |
| Success criterion 4 | Circuit breaker trips on >5 same lead_id in 10 min | integration | `for i in {1..7}; do ./tests/test-webhook.sh happy dupont-plomberie; done` then verify halt SMS | ❌ Wave 0 — new test scenario |

### Wave 0 Gaps
- [ ] `tests/TESTING.md` Phase 3 section — procedures for WhatsApp delivery verification, circuit breaker test, UptimeRobot setup verification
- [ ] `tests/test-whatsapp.sh` (optional) — dedicated WhatsApp test scenario with pre-approved template phone number

---

## Open Questions

1. **Does Baptiste already have a Meta Business Portfolio?**
   - What we know: WABA registration requires an existing Meta Business Portfolio with admin access
   - What's unclear: Whether Baptiste has created one for prior Meta Ads activity (common for agency accounts)
   - Recommendation: Verify before planning. If a portfolio exists, WABA onboarding can start immediately. If not, create the portfolio as Wave 0 and allow 5-20 days for Meta verification.

2. **Single template for all clients vs. per-client templates?**
   - What we know: Template approval is per WABA. All clients share the same WABA in Baptiste's account. A template approved in the WABA is usable by all numbers in that WABA.
   - What's unclear: Whether clients would object to receiving a message that mentions a different business name (the template variable fills in the correct name at send time — this is fine)
   - Recommendation: Submit two shared templates (one prospect, one owner) with `{{1}}`=prospect_name, `{{2}}`=business_name, `{{3}}`=callback_minutes. One template approval covers all current and future clients.

3. **Circuit breaker: halt means no send, or return 429 to Google?**
   - What we know: The Core Workflow runs as a sub-workflow (fire-and-forget). It cannot return anything to Google Ads.
   - What's unclear: Whether "halt" should simply stop all processing (no sends) or also attempt to cancel any in-flight Wait nodes for the same lead_id
   - Recommendation: Halt = stop the current execution silently (no sends for this call) + send alert SMS to Baptiste. No attempt to cancel other executions — the circuit breaker only affects new calls coming in after the threshold is exceeded.

4. **WhatsApp sender number: one shared number or one per client?**
   - What we know: Each registered WhatsApp sender has its own quality rating. Quality degradation on one number affects only that number's sending limits.
   - What's unclear: Whether using one number for all clients (cheaper: one phone number at $1/month vs. N numbers) is architecturally sound
   - Recommendation: One number per client. The quality rating risk (one bad campaign degrades the sender for all clients) is not worth the $1/month saving per client. Per-client numbers also make it clear to the prospect which business is contacting them.

---

## Sources

### Primary (HIGH confidence)
- Twilio WhatsApp API docs (verified 2026-03-27) — https://www.twilio.com/docs/whatsapp/api — WhatsApp From/To format, ContentSid, ContentVariables
- Twilio Content API quickstart (verified 2026-03-27) — https://www.twilio.com/docs/content/create-and-send-your-first-content-api-template — template creation, ContentSid format
- Twilio template approval statuses (verified 2026-03-27) — https://www.twilio.com/docs/whatsapp/tutorial/message-template-approvals-statuses — approval timeline (minutes to 48h)
- Twilio WhatsApp self-sign-up (verified 2026-03-27) — https://www.twilio.com/docs/whatsapp/self-sign-up — onboarding steps, Meta Business Portfolio requirement, verification timeline
- Anthropic rate limits and spend caps (verified 2026-03-27) — https://platform.claude.com/docs/en/api/rate-limits — customer-set spend limit in console, tier ceiling $100 at Tier 1
- UptimeRobot free tier (verified 2026-03-27) — https://uptimerobot.com/pricing/ — 50 monitors, 5-min interval, email alerts free, SMS credits separate purchase

### Secondary (MEDIUM confidence)
- Meta template category guidelines July 2025 — https://www.ycloud.com/blog/whatsapp-api-message-template-category-guidelines-update/ — auto-reclassification since April 2025
- Twilio WABA multi-tenant architecture — https://www.twilio.com/docs/whatsapp/tutorial/whatsapp-business-account — one WABA per Twilio account constraint
- n8n circuit breaker patterns — https://www.pagelines.com/blog/n8n-error-handling-patterns — staticData failure counting pattern
- n8n staticData persistence across executions — https://community.n8n.io/t/workflow-static-data-not-persisting-between-production-executions/255097 — known issues in some versions
- Twilio WhatsApp n8n ContentSid community issue — https://community.n8n.io/t/twilio-whatsapp-contentsid-template-sending-as-plain-text-from-n8n-no-buttons/225820 — confirmed ContentSid + ContentVariables format; button rendering issue is not relevant for text-only utility templates

### Tertiary (LOW confidence — validate if needed)
- Meta Business Verification 5-20 business day timeline — multiple sources agree on range; actual time varies by country and account history
- UptimeRobot webhook integration limited to Team plan — stated in search results; verify current pricing before recommending paid upgrade

---

## Metadata

**Confidence breakdown:**
- WhatsApp HTTP API format: HIGH — verified against official Twilio docs with exact parameter names
- Meta template design (utility category): HIGH — official Meta developer docs confirm utility classification criteria
- WABA onboarding timeline: MEDIUM — official docs say "can take several weeks" for Meta verification; actual time varies
- Circuit breaker pattern: MEDIUM — staticData is well-documented; the specific lead_id windowing logic is custom and untested
- UptimeRobot free tier capabilities: HIGH — verified on pricing page
- Anthropic spend cap: HIGH — console UI confirmed in official docs

**Research date:** 2026-03-27
**Valid until:** 2026-05-27 (stable APIs — Twilio and Anthropic APIs change slowly; Meta template policy more volatile, re-verify if > 30 days)
