# Phase 1: Critical Path — Research

**Researched:** 2026-03-27
**Domain:** n8n webhook automation + Claude API + Twilio SMS + Brevo email
**Confidence:** HIGH

---

## Summary

Phase 1 builds the complete lead-response loop for one client: Google Ads Lead Form webhook → deduplication → raw log → Claude Haiku message generation → Twilio SMS to prospect → Twilio SMS owner notification → error fallback to Baptiste. Every node in this chain is supported by native n8n integrations with official documentation. No custom code or external databases are required for the MVP.

The architecture is a single n8n workflow with a Webhook trigger node that returns HTTP 200 immediately (using "Respond immediately" mode), then executes two parallel branches (prospect message + owner notification) before an optional Wait node (deferred to Phase 2). Raw payload logging is a Code node before any processing. Deduplication uses the built-in Remove Duplicates node in "Remove Items Processed in Previous Executions" mode with `lead_id` as the comparison key — this stores history in n8n's database and survives server restarts when Postgres is configured (Railway default).

The single most important implementation detail: the n8n Twilio node has a known limitation with alphanumeric sender IDs — the "From" field expects a phone number format, not an alphanumeric string. For French carrier compliance (alphanumeric required for A2P), an HTTP Request node calling Twilio's REST API directly is the required workaround. France does support alphanumeric sender IDs but requires pre-registration in the Twilio Console. This is a blocking task before any production SMS send.

**Primary recommendation:** Build in layer order — Webhook → log → dedup → Claude call → Twilio SMS → owner notification → error fallback. Test each layer end-to-end before adding the next.

---

## Project Constraints (from CLAUDE.md)

| Directive | Requirement |
|-----------|-------------|
| Stack | n8n (self-hosted or cloud) + Claude API only — no custom stack, must remain maintainable by a solo freelance operator |
| Client interface | Zero technical exposure — all configuration is done by Baptiste; clients never touch anything |
| Channels | Depends on available lead form fields: phone → SMS/WhatsApp; email only → email |
| Cost | Per-lead cost (Claude API + SMS) must remain marginal vs. Google Ads CPL (€10-50) |
| Reliability | 24/7 — a lead arriving at 3am must receive its response |

---

<user_constraints>
## User Constraints (from STATE.md / project decisions)

### Locked Decisions
- Google Ads Lead Forms as sole v1 source — webhook native, most common in Baptiste's campaigns
- RGPD consent checkbox on every lead form is a pre-launch requirement — cannot be retrofitted
- `lead_id` deduplication and raw payload logging are embedded in Phase 1, not deferred
- WhatsApp deferred to Phase 3 — Meta template approval (1-3 days) and WABA onboarding complexity unjustified before SMS path is validated in production

### Claude's Discretion
- Exact implementation pattern for deduplication (Remove Duplicates node vs Code node with static data)
- Whether to use Twilio n8n node (with HTTP Request workaround for alphanumeric) or pure HTTP Request node for all SMS sends
- Webhook response mode ("Respond immediately" vs "Respond to Webhook" node)
- Brevo node vs SMTP/HTTP Request for email fallback

### Deferred Ideas (OUT OF SCOPE for Phase 1)
- NOTIF-03: Follow-up scheduler if owner hasn't called back (Phase 2)
- CONF-01/02/03: Multi-tenant architecture (Phase 2)
- WhatsApp channel for prospect or owner (Phase 3)
- Two-way AI conversation with prospect
- Dashboard or reporting UI
- CRM integration
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INGEST-01 | Receive Google Ads Lead Form leads via HTTP POST webhook | Webhook node, "Respond immediately" mode, JSON body parsing — fully documented |
| INGEST-02 | Deduplicate leads by `lead_id` — avoid duplicate messages | Remove Duplicates node "Previous Executions" mode on `lead_id` field — native, persists in DB |
| INGEST-03 | Log raw payload of each received lead for audit/debug | Code node before any processing — write to n8n execution data or append to static data |
| INGEST-04 | Validate webhook authenticity via `google_key` | IF node checking `$json.google_key === $env.GOOGLE_KEY` — `google_key` is in request body, not header |
| RESP-01 | Generate personalized message via Claude API reformulating prospect's request | HTTP Request node to `https://api.anthropic.com/v1/messages` with constrained system prompt |
| RESP-02 | Send message by SMS via Twilio if phone number available | HTTP Request node (Twilio REST API) — required for alphanumeric sender ID; native Twilio node cannot set alphanumeric From |
| RESP-03 | Send message by email via Brevo if only email available | Brevo node in n8n — native support, free tier, French company |
| RESP-04 | Claude prompt adapted to client business type (plumber vs dentist vs lawyer) | System prompt includes `service_type` from client config JSON — one prompt template, one variable |
| RESP-05 | Message sent in under 2 minutes after lead submission | End-to-end latency: webhook receipt + Claude call (~1s) + Twilio send (~0.5s) = well under 2 min |
| NOTIF-01 | Owner receives SMS/WhatsApp with key lead info (name, request, phone) | Second HTTP Request to Twilio after prospect SMS — same pattern, owner phone from config |
| NOTIF-02 | Notification contains `tel:` link for one-tap callback | String formatting in Code node: `tel:+33XXXXXXXXX` deep link embedded in owner SMS |
| NOTIF-04 | If pipeline fails, Baptiste receives raw lead by SMS as fallback | Error Trigger workflow — separate workflow, receives error data, sends Twilio SMS to Baptiste |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| n8n | 2.13.3 (local); Railway deploys latest 1.x | Workflow orchestration | Already on machine (`/opt/homebrew/bin/n8n`); Railway template for production |
| Claude Haiku 4.5 | `claude-haiku-4-5` (also: `claude-haiku-4-5-20251001`) | AI message generation | Confirmed model ID in official Anthropic API docs; ~$0.001/lead |
| Twilio REST API | v2010 | SMS to prospect and owner | Native n8n node for standard SMS; HTTP Request required for alphanumeric sender ID |
| Brevo | REST API v3 | Transactional email fallback | Native n8n Brevo node; free tier 300 emails/day; French company, GDPR-native |

### n8n Nodes Used

| Node | Purpose | Config Notes |
|------|---------|--------------|
| `Webhook` | Receive Google Ads lead POST | Response mode: "Respond immediately" (returns 200 + "Workflow got started" instantly) |
| `Code` | Raw payload log; `tel:` link formatting; lead data extraction from `user_column_data` array | Pure JS in Code node |
| `IF` | `google_key` validation; phone vs email routing | First IF: validate key; second IF: route channel |
| `Remove Duplicates` | Cross-execution deduplication by `lead_id` | Operation: "Remove Items Processed in Previous Executions"; Scope: Node; History: 10,000 |
| `HTTP Request` | Claude API call; Twilio SMS sends (prospect + owner) | Claude: POST to `https://api.anthropic.com/v1/messages`; Twilio: POST to REST API |
| `Brevo` | Email to prospect when no phone | Built-in node; requires Brevo API key credential |
| `Error Trigger` | Fallback workflow entry point | Separate workflow; fires on any execution error in main workflow |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| n8n environment variables | Store secrets (GOOGLE_KEY, Anthropic key, Twilio creds) | All sensitive values — never hard-code in node expressions |
| n8n Credentials (Header Auth) | Store Anthropic API key for HTTP Request | Creates a named credential reusable across nodes |
| Railway + Postgres addon | Production hosting + deduplication/Wait node persistence | Postgres is required for Remove Duplicates "Previous Executions" to survive restarts |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| HTTP Request for Twilio (alphanumeric) | Built-in Twilio node | Native node cannot set alphanumeric "From" field — blocked for France A2P |
| Remove Duplicates node | Code node + `getWorkflowStaticData` | Static data approach works but is manual; Remove Duplicates node is built for this exact use case |
| Brevo node | SMTP / SendGrid / HTTP Request | Brevo native node is simpler to configure; free tier sufficient; GDPR advantage |

**Installation:** No npm installs required. n8n nodes are built-in. Credentials configured in n8n UI.

---

## Architecture Patterns

### Recommended Workflow Structure

```
[Webhook: /webhook/client-slug]
        │  (returns 200 immediately — "Respond immediately" mode)
        ▼
[Code: Log Raw Payload]          ← INGEST-03: persist full JSON to execution data
        │
        ▼
[IF: google_key valid?]          ← INGEST-04: body field comparison
   │ YES                │ NO
   ▼                    └──► [Stop] (no output, execution ends silently)
[Remove Duplicates: lead_id]     ← INGEST-02: "Previous Executions" mode
   │ NEW                │ SEEN
   ▼                    └──► [Stop]
[Code: Extract Fields]           ← parse user_column_data array → phone, email, name, request
        │
        ▼
[HTTP Request: Claude API]       ← RESP-01, RESP-04: personalized message generation
        │
        ▼
[IF: phone available?]
   │ YES                          │ NO
   ▼                              ▼
[HTTP Request: Twilio SMS]    [Brevo: Send Email]   ← RESP-02 / RESP-03
  (prospect)                  (prospect)
        │
        ▼
[HTTP Request: Twilio SMS]       ← NOTIF-01, NOTIF-02: owner notification
  (owner — includes tel: link)
```

**Error Workflow (separate):**

```
[Error Trigger]
        │
        ▼
[Code: Format raw lead data from $execution.lastNodeExecuted]
        │
        ▼
[HTTP Request: Twilio SMS to Baptiste]   ← NOTIF-04: fallback raw lead
```

### Pattern 1: Webhook — Return 200 Immediately

**What:** Set Webhook node Response Mode to "Respond immediately". n8n returns HTTP 200 with `{"message": "Workflow got started"}` before any processing nodes run.

**When to use:** Any time the triggering service (Google Ads) has a response timeout. This is always the correct pattern for inbound webhooks that trigger long-running processing.

**Configuration:**
```
Webhook node > Response Mode: "Respond immediately"
```

No "Respond to Webhook" node needed. The async processing continues automatically after the 200 is sent.

### Pattern 2: google_key Validation

**What:** `google_key` arrives in the **request body** (not headers). First processing node after log is an IF node comparing body field to stored env var.

**When to use:** Every lead — always first check before deduplication or processing.

**Example:**
```javascript
// IF node condition
{{ $json.google_key === $env.GOOGLE_KEY }}
// TRUE branch: continue
// FALSE branch: no output (workflow stops silently — returns nothing to Google)
```

Note: Return HTTP 4XX for invalid key using "Respond to Webhook" node if you want Google to stop retrying. Return HTTP 200 (and stop silently) if you don't want Google to know the key is invalid. For security, silent 200 is preferred.

### Pattern 3: Raw Payload Logging

**What:** Code node immediately after Webhook (before any processing) that stores the full incoming JSON.

**When to use:** Every execution — must log before any processing that could fail.

**Example:**
```javascript
// Code node — runs first, after Webhook
const lead = $input.first().json;
// Write to execution data (visible in n8n execution log)
console.log('RAW_LEAD:', JSON.stringify(lead));
// Pass through unchanged
return $input.all();
```

The execution log in n8n retains this for 7 days by default (configurable). For longer audit retention, append to a persistent store (Google Sheets, Airtable, or Postgres query node).

### Pattern 4: lead_id Deduplication

**What:** Remove Duplicates node in "Remove Items Processed in Previous Executions" mode.

**Configuration:**
- Operation: `Remove Items Processed in Previous Executions`
- Keep Items Where: `Value Is New`
- Value to Dedupe On: `{{ $json.lead_id }}`
- Scope: `Node` (independent per workflow — correct for single-client Phase 1)
- History Size: `10000` (default — more than sufficient for lead volumes)

**Persistence:** Stored in n8n's database (Postgres on Railway). Survives server restarts. Does NOT persist across manual test executions (only production/webhook-triggered executions).

### Pattern 5: Claude API HTTP Request

**What:** HTTP Request node calling Anthropic's Messages API.

**Configuration:**
```
Method: POST
URL: https://api.anthropic.com/v1/messages
Authentication: Predefined Credential Type → Anthropic (stores API key)
  OR: Header Auth credential with header "x-api-key": <key>
Headers:
  anthropic-version: 2023-06-01
  content-type: application/json
Body (JSON):
{
  "model": "claude-haiku-4-5",
  "max_tokens": 200,
  "system": "Tu es l'assistant de {{ $env.BUSINESS_NAME }}, {{ $env.SERVICE_TYPE }}. Tu reçois la demande d'un prospect qui vient de soumettre un formulaire Google Ads. Ta tâche : rédige un SMS de confirmation en français (max 160 caractères). Reformule la demande du prospect et confirme qu'il sera rappelé dans {{ $env.CALLBACK_MINUTES }} minutes. N'invente aucun prix, délai précis ou disponibilité. Commence directement par le message, sans formule d'introduction.",
  "messages": [
    {
      "role": "user",
      "content": "<prospect_input>Nom: {{ $json.name }}\nDemande: {{ $json.request }}</prospect_input>"
    }
  ]
}
```

**Response:** `$json.content[0].text` — the generated message string.

### Pattern 6: Twilio SMS via HTTP Request (Alphanumeric Sender)

**What:** HTTP Request node calling Twilio's REST API directly. Required because the n8n Twilio node cannot set an alphanumeric "From" field — it only accepts E.164 phone numbers.

**Configuration:**
```
Method: POST
URL: https://api.twilio.com/2010-04-01/Accounts/{{ $env.TWILIO_ACCOUNT_SID }}/Messages.json
Authentication: Basic Auth
  Username: {{ $env.TWILIO_ACCOUNT_SID }}
  Password: {{ $env.TWILIO_AUTH_TOKEN }}
Body Type: Form-Data (x-www-form-urlencoded)
Parameters:
  To: {{ $json.phone }}          (E.164 format from Google Ads: +33XXXXXXXXX)
  From: DupontPlomb              (alphanumeric — max 11 chars, at least 1 letter, no spaces)
  Body: {{ $json.sms_message }}
```

**Note on France registration:** France requires Twilio alphanumeric sender ID pre-registration. Submit via Twilio Console before sending. Timeline: typically same-day to 48 hours. Without registration, messages may be delivered with a generic sender ID or blocked.

### Pattern 7: Owner Notification with tel: Link

**What:** Second Twilio HTTP Request after prospect SMS, sending lead summary to owner.

**Example body content:**
```javascript
// Code node before owner SMS send
const name = $json.name;
const request = $json.request;
const phone = $json.phone;
const telLink = `tel:${phone}`;

return [{
  json: {
    owner_sms: `Nouveau lead: ${name}\n"${request}"\n📞 ${telLink}`
  }
}];
```

**Note:** `tel:` URI scheme works as a one-tap call link on iOS and Android when received via SMS.

### Pattern 8: Error Fallback Workflow

**What:** Separate n8n workflow starting with Error Trigger node. Assigned to main workflow in Settings > Error Workflow.

**Setup:**
1. Create workflow "Speed to Lead — Error Handler"
2. Add Error Trigger as first node
3. Add Code node to format message: `"LEAD PERDU - {{ $json.workflow.name }}: {{ $json.execution.error.message }}\nPayload: {{ JSON.stringify($json.execution.lastNodeExecuted) }}"`
4. Add HTTP Request → Twilio SMS to Baptiste's number
5. In main workflow Settings > Error Workflow: select "Speed to Lead — Error Handler"

The Error Trigger provides: `$json.workflow.name`, `$json.execution.id`, `$json.execution.error.message`, `$json.execution.lastNodeExecuted`.

### Anti-Patterns to Avoid

- **Using the built-in Twilio node for French SMS:** The n8n Twilio node's "From" field only accepts phone numbers, not alphanumeric sender IDs. Use HTTP Request node instead.
- **Storing google_key in IF node expression directly:** The key appears in workflow JSON export. Use `$env.GOOGLE_KEY` (n8n environment variable) or an n8n Credential.
- **Processing before logging raw payload:** If Claude or Twilio fail and the log hasn't written yet, the lead is unrecoverable. Log first, always.
- **Trusting is_test absence as production signal:** Check explicitly: `$json.is_test !== true` before sending — absence of the field defaults to production, but defensive check is safer.
- **Using parallel branches for both sends without error isolation:** If the prospect SMS fails, the owner notification should still fire. Use separate error handling per branch, not a single catch.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cross-execution deduplication | Code node + manual array in static data | Remove Duplicates node "Previous Executions" mode | Built-in, persists in DB, handles FIFO rotation at 10k items |
| Webhook immediate response | Custom response logic | Webhook node "Respond immediately" mode | Native feature, one dropdown change |
| Error notification routing | Try/catch in every node | Error Trigger workflow (separate) | Catches all execution failures in one place, reusable |
| French phone number parsing | E.164 conversion logic | None needed — Google Ads delivers E.164 already (`+33XXXXXXXXX`) | Google normalizes on submission |
| Claude prompt injection protection | Custom sanitizer | XML tag wrapping `<prospect_input>` + system prompt instruction | Standard Anthropic-recommended pattern |

**Key insight:** Every critical path operation (dedup, webhook response, error handling) has a native n8n mechanism. The only custom work is configuration — not code.

---

## Common Pitfalls

### Pitfall 1: n8n Twilio Node Cannot Set Alphanumeric Sender ID

**What goes wrong:** You configure the built-in Twilio node, enter the business name in the "From" field, and all test SMS sends fail or default to a long code number. French carriers block A2P long-code messages.

**Why it happens:** The n8n Twilio node validates the "From" field as an E.164 phone number. Alphanumeric strings are rejected at the node level. This is a known open issue as of May 2025 with no fix shipped.

**How to avoid:** Use HTTP Request node to call Twilio's REST API directly. Set `From` to the alphanumeric sender ID string (max 11 chars, at least 1 letter). Pre-register the sender ID in Twilio Console before first send.

**Warning signs:** n8n execution showing "Invalid From number" Twilio error; SMS received from random long code number.

### Pitfall 2: google_key Is in the Request Body, Not Headers

**What goes wrong:** You build validation looking for `google_key` in HTTP headers and it always fails — every lead is rejected.

**Why it happens:** Google Ads webhook documentation specifies `google_key` as a field in the JSON request body, not as an Authorization header. Easy to misread.

**How to avoid:** Check `$json.google_key` (body field), not `$request.headers['google_key']`.

**Warning signs:** All leads failing `google_key` validation even when key is correct.

### Pitfall 3: Remove Duplicates "Previous Executions" Does Not Work in Manual Test Mode

**What goes wrong:** You test the workflow manually (clicking "Test Workflow" in n8n). The same `lead_id` passes through multiple times because the deduplication history doesn't save during manual tests.

**Why it happens:** Static data and the Remove Duplicates node's history only persist across production executions (triggered by active webhook). Manual "Test" executions are isolated.

**How to avoid:** Test deduplication by activating the workflow and sending real test payloads to the production webhook URL, or by using the Google Ads "SEND TEST DATA" button (with `is_test: true` filter in place).

**Warning signs:** Seeming deduplication failure during development that disappears in production.

### Pitfall 4: Claude Output Exceeds SMS Character Limit

**What goes wrong:** Claude generates a response of 300+ characters. The Twilio SMS splits it into 2 messages (160 chars each), and the prospect receives a fragmented, confusing double-message.

**Why it happens:** Without a strict max_tokens constraint and a character count instruction in the system prompt, Claude optimizes for helpfulness, not brevity.

**How to avoid:** Set `max_tokens: 200` in Claude API call (150 chars of output ~= 100-150 tokens). Include in system prompt: "Le message doit tenir en moins de 160 caractères." Add a Code node after Claude's response to truncate if `text.length > 155` (leave room for safe margin).

**Warning signs:** Prospect receiving 2-part SMS; execution logs showing Claude output > 160 characters.

### Pitfall 5: Error Fallback Only Gets Last Node Data, Not Full Lead Payload

**What goes wrong:** The Error Trigger fires. Baptiste receives an SMS saying "Error in SMS node" but without the prospect's phone number or name — the lead is still lost.

**Why it happens:** By the time the error fires, the input data to the failed node may not be reconstructable from `$json.execution.lastNodeExecuted` alone.

**How to avoid:** In the raw logging Code node (very first node), store the full lead data in n8n's workflow static data: `const staticData = $getWorkflowStaticData('global'); staticData.lastLead = $input.first().json;`. The Error fallback workflow can then read this via a Code node to include full lead data in the fallback SMS.

**Warning signs:** Error fallback messages arriving without identifiable lead information.

---

## Code Examples

### Extract user_column_data Fields

Google Ads Lead Forms deliver prospect data in an array — not flat JSON. You must extract fields by `column_name`.

```javascript
// Source: Google Ads webhook documentation — https://developers.google.com/google-ads/webhook/docs/implementation
// Code node: parse user_column_data into usable fields

const lead = $input.first().json;
const fields = {};

for (const col of lead.user_column_data || []) {
  fields[col.column_name] = col.string_value;
}

return [{
  json: {
    lead_id: lead.lead_id,
    is_test: lead.is_test || false,
    phone: fields['PHONE_NUMBER'] || null,
    email: fields['EMAIL'] || null,
    name: fields['FULL_NAME'] || 'Prospect',
    request: fields['demande'] || fields['message'] || '',  // custom question column_name
    submit_time: lead.lead_submit_time,
    raw: lead  // carry raw payload forward for fallback use
  }
}];
```

### Claude API HTTP Request Body (n8n expression)

```json
{
  "model": "claude-haiku-4-5",
  "max_tokens": 200,
  "system": "Tu travailles pour {{ $env.BUSINESS_NAME }}, {{ $env.SERVICE_TYPE }} basé(e) à {{ $env.CITY }}. Un prospect vient de soumettre un formulaire de contact. Rédige un SMS de confirmation en français (STRICTEMENT moins de 160 caractères). Reformule en une phrase la demande du prospect et confirme qu'on le rappelle sous {{ $env.CALLBACK_MINUTES }} minutes. N'invente aucun prix, délai exact, ni disponibilité. Commence directement par le contenu du SMS.",
  "messages": [
    {
      "role": "user",
      "content": "<prospect_input>Nom: {{ $json.name }}\nDemande: {{ $json.request }}</prospect_input>"
    }
  ]
}
```

### Twilio HTTP Request (alphanumeric sender — France)

```
URL: https://api.twilio.com/2010-04-01/Accounts/{{ $env.TWILIO_ACCOUNT_SID }}/Messages.json
Method: POST
Auth: Basic — SID as username, Auth Token as password
Content-Type: application/x-www-form-urlencoded
Body parameters:
  To    → {{ $json.phone }}
  From  → {{ $env.TWILIO_SENDER_ID }}   (e.g. "DupontPlomb" — 11 chars max)
  Body  → {{ $json.claude_message }}
```

### Owner Notification SMS Content

```javascript
// Code node: format owner notification
const n = $json.name;
const r = $json.request;
const p = $json.phone;
const email = $json.email || 'non fourni';

const sms = p
  ? `Lead: ${n}\n"${r}"\nTél: tel:${p}`
  : `Lead: ${n}\n"${r}"\nEmail: ${email}`;

return [{ json: { owner_sms: sms } }];
```

### Error Fallback Static Data Pattern

```javascript
// Code node — runs first (raw log node), stores lead for error recovery
const staticData = $getWorkflowStaticData('global');
const lead = $input.first().json;
staticData.lastLead = JSON.stringify(lead);
console.log('RAW_LEAD_LOG:', JSON.stringify(lead));
return $input.all();
```

```javascript
// Code node in Error Trigger workflow — recovers lead data
const staticData = $getWorkflowStaticData('global');
const lead = staticData.lastLead ? JSON.parse(staticData.lastLead) : null;
const errorMsg = $json.execution?.error?.message || 'Erreur inconnue';
const summary = lead
  ? `LEAD PERDU - ${$json.workflow.name}\nErreur: ${errorMsg}\nLead: ${JSON.stringify(lead)}`
  : `LEAD PERDU - ${$json.workflow.name}\nErreur: ${errorMsg}\nPayload non récupérable`;
return [{ json: { fallback_sms: summary } }];
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WhatsApp free-form outbound | Pre-approved utility templates required | July 2025 Meta pricing | WhatsApp correctly deferred to Phase 3 |
| n8n Cloud (execution-limited) | Self-hosted on Railway (unlimited) | Available since 2024 | $5-7/month flat vs $20/month capped |
| Claude Sonnet for SMS generation | Claude Haiku 4.5 | Oct 2025 Haiku 4.5 release | 10x cheaper, same quality for constrained short-text tasks |
| Per-execution dedup via Code node | Remove Duplicates node "Previous Executions" | n8n 1.x | Built-in, no custom code needed |

**Current model ID:** `claude-haiku-4-5` (or pinned: `claude-haiku-4-5-20251001`). Do not use `claude-haiku-3` — significantly lower quality.

---

## Open Questions

1. **France Twilio alphanumeric sender registration timeline**
   - What we know: France requires pre-registration in Twilio Console; supports alphanumeric; process exists per Twilio docs
   - What's unclear: Exact approval time (same-day vs 2-3 business days); whether it requires business documents or just account verification
   - Recommendation: Register sender ID in Wave 0 of Phase 1 (setup task) before any production SMS send. Do not block workflow build on this — test with E.164 long code locally, switch to alphanumeric for production.

2. **Remove Duplicates node persistence on server restart**
   - What we know: Stored in n8n's database; Railway uses Postgres — designed for persistence
   - What's unclear: Official docs don't explicitly confirm restart survival; community reports suggest it persists with Postgres backend
   - Recommendation: Treat as HIGH confidence for Railway/Postgres deployment. Add a fallback check: if Remove Duplicates is bypassed somehow, the double-send is a minor UX issue, not a critical failure.

3. **Brevo node exact operation name for transactional email**
   - What we know: Native Brevo node exists in n8n; supports transactional email send; requires API key credential
   - What's unclear: Exact resource/operation UI path in current n8n 2.x version
   - Recommendation: Verify in n8n UI when building. If Brevo node operation has changed, fallback is HTTP Request to `https://api.brevo.com/v3/smtp/email` with JSON body `{sender, to, subject, htmlContent}`.

---

## Environment Availability

| Dependency | Required By | Available | Version | Notes |
|------------|------------|-----------|---------|-------|
| Node.js | n8n local | Yes | v24.14.1 | Exceeds minimum |
| n8n (local) | Development / testing | Yes | 2.13.3 | Can use for local workflow development |
| n8n (Railway) | Production | Not yet | — | Deploy via Railway template before go-live |
| Twilio account | SMS sends | Not verified | — | Baptiste must provide Account SID + Auth Token |
| Anthropic API key | Claude calls | Not verified | — | Baptiste must provide key from console.anthropic.com |
| Brevo API key | Email fallback | Not verified | — | Baptiste must create at app.brevo.com |
| Google Ads campaign with Lead Form | Real lead testing | Not verified | — | Required for end-to-end Phase 1 validation |
| Twilio French phone number | Owner notification | Not verified | — | ~$1/month; needed for owner SMS receive |
| Twilio alphanumeric sender registration | Prospect SMS (France A2P) | Not verified | — | Must register before production send |

**Missing dependencies with no fallback:**
- Twilio Account SID + Auth Token — blocks all SMS sends
- Anthropic API key — blocks prospect message generation
- Google Ads campaign with Lead Form webhook configured — blocks end-to-end test

**Missing dependencies with fallback:**
- Twilio alphanumeric sender — fallback is E.164 long code during development (blocked for production A2P in France)
- Brevo API key — fallback is log the email intent without sending during initial build

---

## Validation Architecture

nyquist_validation is enabled in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | n8n manual execution + webhook test trigger |
| Config file | No config file — tests are n8n workflow executions |
| Quick run command | Activate workflow → POST test payload to webhook URL |
| Full suite command | End-to-end: real Google Ads test lead → verify SMS received + owner notified |

n8n workflows are not unit-testable with Jest/pytest. Validation is execution-based:
- **Unit-level:** Manually execute individual nodes with sample data in n8n editor
- **Integration:** Activate workflow, POST JSON payload to webhook URL, inspect execution log
- **End-to-end:** Use Google Ads "SEND TEST DATA" button (with `is_test: true` filter), verify no SMS sent; then submit real test lead form, verify SMS received

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INGEST-01 | Webhook receives POST and returns 200 | integration | `curl -X POST https://[n8n-url]/webhook/[slug] -H 'Content-Type: application/json' -d '{"lead_id":"test-001","google_key":"[key]","user_column_data":[]}'` | Wave 0: document curl command |
| INGEST-02 | Duplicate lead_id → only one execution reaches send nodes | integration | POST same payload twice, verify only one SMS in Twilio logs | Manual verification |
| INGEST-03 | Raw payload appears in n8n execution log | integration | Inspect n8n execution log after test POST | Manual verification |
| INGEST-04 | Invalid google_key → workflow stops before any send | integration | POST with wrong key, verify no execution proceeds past IF node | Manual verification |
| RESP-01 | Claude generates French SMS message | integration | Inspect `$json.content[0].text` in Claude node output | Manual verification |
| RESP-02 | SMS arrives on prospect test phone | e2e | Submit test lead with real phone → check phone received SMS | Manual verification |
| RESP-03 | Email arrives in prospect test inbox | e2e | Submit test lead with email only → check inbox | Manual verification |
| RESP-04 | Message tone matches service type | manual | Read generated message, verify it mentions service type context | Manual review |
| RESP-05 | SMS received within 2 minutes of form submit | e2e | Record submit time, compare to SMS receive timestamp | Manual timing |
| NOTIF-01 | Owner receives SMS with name + request + phone | e2e | Submit test lead, check Baptiste's phone | Manual verification |
| NOTIF-02 | Owner SMS contains clickable tel: link | e2e | Inspect owner SMS content | Manual verification |
| NOTIF-04 | Baptiste receives fallback SMS when pipeline fails | integration | Manually break Twilio node (wrong credentials) → verify fallback fires | Manual verification |

### Sampling Rate

- **Per node build:** Execute node manually in n8n editor with sample JSON
- **Per workflow section:** POST test payload to webhook, inspect execution log
- **Phase gate:** All 12 requirements verified via test lead before marking Phase 1 complete

### Wave 0 Gaps

- [ ] Test payload JSON file: `tests/payloads/google-ads-lead.json` — sample webhook payload for curl testing
- [ ] Test payload JSON file: `tests/payloads/google-ads-lead-duplicate.json` — same lead_id for dedup test
- [ ] Test payload JSON file: `tests/payloads/google-ads-lead-invalid-key.json` — wrong google_key
- [ ] Test payload JSON file: `tests/payloads/google-ads-lead-email-only.json` — no phone, email only
- [ ] Curl test script: `tests/test-webhook.sh` — wrapper around curl for manual test runs
- [ ] Document: `tests/TESTING.md` — instructions for end-to-end test execution

---

## Sources

### Primary (HIGH confidence)

- Google Ads Webhook implementation — payload schema, google_key in body, is_test field, response expectations: https://developers.google.com/google-ads/webhook/docs/implementation
- Anthropic Messages API — exact endpoint, headers, request schema, model IDs: https://platform.claude.com/docs/en/api/messages
- n8n Remove Duplicates node — "Previous Executions" mode, scope, history size: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.removeduplicates/
- n8n Error Handling — Error Trigger node, error workflow setup: https://docs.n8n.io/flow-logic/error-handling/
- Twilio Alphanumeric Sender ID France registration: https://help.twilio.com/articles/36973882933787-Documents-Required-and-Instructions-to-Register-Your-Alphanumeric-Sender-ID-in-France
- Twilio International Alphanumeric Sender ID support (France confirmed): https://help.twilio.com/articles/223133767-International-support-for-Alphanumeric-Sender-ID

### Secondary (MEDIUM confidence)

- n8n Twilio node alphanumeric limitation (community confirmed, May 2025): https://community.n8n.io/t/twilio-node-alphanumeric-sender-id/121802
- n8n webhook immediate response pattern (official docs reference): https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.respondtowebhook/
- n8n workflow export/import JSON: https://docs.n8n.io/workflows/export-import/
- Brevo n8n node integration: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.brevo/

### Tertiary (LOW confidence — needs validation during build)

- Remove Duplicates persistence across server restart: inferred from Postgres storage + community reports — verify empirically during Wave 0
- Brevo node exact operation path in n8n 2.x UI: not confirmed for current version — verify in n8n editor

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| Google Ads webhook payload | HIGH | Official Google Ads dev docs — exact field names and types confirmed |
| Claude API call format | HIGH | Official Anthropic docs — exact endpoint, headers, model ID confirmed |
| n8n Twilio alphanumeric limitation | HIGH | Confirmed in n8n community (May 2025) — open issue, no fix shipped |
| n8n Remove Duplicates cross-execution | MEDIUM | Official docs confirm operation exists; restart persistence inferred from DB storage |
| Twilio France alphanumeric registration | MEDIUM | Confirmed France is supported; registration process exists; exact timeline unverified |
| Brevo node operations | MEDIUM | Node exists in n8n; exact UI path in v2.x not confirmed via docs fetch |
| Error Trigger workflow pattern | HIGH | Official n8n docs confirm pattern; Error Trigger node confirmed |

**Research date:** 2026-03-27
**Valid until:** 2026-04-27 (stable stack — 30-day window is conservative)
