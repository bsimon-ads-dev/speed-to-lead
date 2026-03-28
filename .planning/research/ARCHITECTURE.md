# Architecture Patterns — Speed to Lead

**Domain:** n8n automation, multi-tenant lead response, AI messaging
**Researched:** 2026-03-27
**Overall confidence:** HIGH (n8n patterns well-documented; multi-tenant validated by production examples)

---

## Recommended Architecture

A **single n8n instance, shared-workflow, config-driven** architecture. One set of core workflows serves all clients. Client identity is injected at ingress and carried through execution. Per-client configuration lives in a flat JSON file (n8n static data or an external file) — no database required for v1.

This is the right choice for a solo operator running 5–20 clients. Separate instances per client (the "hard isolation" approach) is operationally correct in theory but creates a maintenance burden that does not fit a one-person shop. The shared instance + config-driven routing pattern is validated in production at scale (50+ clients on single n8n instance with queue mode).

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **Ingress Webhook** | Receive Google Ads Lead Form POST, validate `google_key`, extract lead payload | Router Workflow |
| **Router Workflow** | Identify client from webhook path or `form_id`, load client config, dispatch to Core Workflow | Client Config Store, Core Workflow |
| **Client Config Store** | Hold per-client settings (name, channels, delays, API keys, owner phone/email) | Router Workflow, Core Workflow |
| **Core Workflow** | Orchestrate the full lead lifecycle for one execution | Claude API, Channel Dispatcher, Wait/Follow-up Logic |
| **Claude API** | Generate personalized prospect message from lead data + client context | Core Workflow |
| **Channel Dispatcher** | Route outbound messages to the correct channel (SMS, WhatsApp, email) based on available lead data | Twilio (SMS/WhatsApp), SMTP/SendGrid (email) |
| **Follow-up Scheduler** | Wait for configured delay, then check if owner called, send follow-up if not | Core Workflow (resume via Wait node) |
| **Owner Notifier** | Send lead summary notification to business owner | Twilio (SMS/WhatsApp) |

---

## Data Flow

### Happy Path (prospect has phone number, owner calls back in time)

```
1. Google Ads Lead Form submitted
        │
        ▼
2. INGRESS WEBHOOK (n8n Webhook node)
   - POST /webhook/{client-slug}
   - Validates google_key header
   - Returns 200 immediately (async)
        │
        ▼
3. ROUTER WORKFLOW
   - Extracts client-slug from webhook path
   - Loads client config (name, service type, owner phone, delay, channel prefs)
   - Passes enriched payload to Core Workflow
        │
        ▼
4. CORE WORKFLOW — parallel branches
   ┌────────────────────────┐    ┌──────────────────────────┐
   │ Branch A: Prospect Msg │    │ Branch B: Owner Notif    │
   │                        │    │                          │
   │ - Send lead data +     │    │ - Format lead summary    │
   │   client context to    │    │   (name, service, phone) │
   │   Claude API           │    │ - Send SMS/WhatsApp to   │
   │ - Claude returns       │    │   owner with tel: link   │
   │   personalized message │    │   for one-tap callback   │
   │ - Channel Dispatcher   │    └──────────────────────────┘
   │   sends to prospect    │
   │   (SMS > WhatsApp >    │
   │    email, per avail.)  │
   └────────────────────────┘
        │
        ▼
5. WAIT NODE — pauses execution for configured delay (e.g., 30 min)
   - Execution state serialized to n8n database
   - Resumes automatically after delay
        │
        ▼
6. FOLLOW-UP CHECK
   - [V1: time-based only] Assume owner has not called if no signal
   - Send follow-up message to prospect: "Still looking for a [service]?
     [Owner name] will call you shortly."
        │
        ▼
7. EXECUTION COMPLETE — logged in n8n execution history
```

### Channel Selection Logic (Channel Dispatcher)

```
Lead data contains phone? ──YES──► Send SMS via Twilio
                                    Also attempt WhatsApp if client config enables it
Lead data contains email? ──YES──► Send email via SMTP/SendGrid
Neither available? ────────────► Log error, notify owner to handle manually
```

Google Ads Lead Forms always capture email. Phone is optional but very common for service SMEs. Default order: SMS first (highest read rate), then WhatsApp if SMS fails or client preference, then email as fallback.

---

## Multi-Tenant Configuration

### Webhook Routing Strategy

Each client gets a **dedicated webhook URL path** in n8n using the client slug:

```
https://n8n.yourdomain.com/webhook/dupont-plomberie
https://n8n.yourdomain.com/webhook/cabinet-martin
https://n8n.yourdomain.com/webhook/coach-legrand
```

This URL is configured once in Google Ads Lead Form settings for that client's campaign. When a lead comes in, n8n knows immediately which client it belongs to — no lookup needed. This is simpler and more reliable than extracting client identity from payload fields.

**Rationale:** Using `form_id` to identify clients is fragile — form IDs change when campaigns are rebuilt. Slug-based webhook paths are stable and explicit.

### Client Config Schema

Store as a single JSON object per client, loaded by the Router via n8n's Static Data (workflow-level) or a local JSON file read with the Read Binary File node. For v1 with fewer than 20 clients, a flat JSON file is sufficient. Supabase or Airtable if it needs to be editable without touching n8n.

```json
{
  "client_slug": "dupont-plomberie",
  "business_name": "Dupont Plomberie",
  "service_type": "plombier",
  "owner_phone": "+33612345678",
  "owner_whatsapp": "+33612345678",
  "owner_email": "contact@dupont-plomberie.fr",
  "preferred_channels": ["sms", "whatsapp", "email"],
  "callback_promise_minutes": 30,
  "follow_up_delay_minutes": 45,
  "google_key": "gads_secret_key_abc123",
  "active": true
}
```

### Workflow Structure (n8n canvas)

```
[Webhook: /dupont-plomberie] ──► [Load Config] ──► [Execute: Core Workflow]
[Webhook: /cabinet-martin]   ──► [Load Config] ──► [Execute: Core Workflow]
[Webhook: /coach-legrand]    ──► [Load Config] ──► [Execute: Core Workflow]
                                                            │
                                                    [Core Workflow]
                                                    (shared, parameterized)
```

Each client has a thin "entry workflow" (webhook + config load + dispatcher). The Core Workflow is one shared workflow that receives client config as input. This means:
- Bug fixes and improvements to Core Workflow apply to all clients instantly
- Adding a new client = create one entry workflow, no Core Workflow changes
- Each execution is isolated (n8n executions are stateless between runs)

---

## Delayed Follow-up — Implementation Pattern

n8n's **Wait node** (resume: After Time Interval) is the correct tool. It:
- Serializes the full execution state to the n8n Postgres database
- Releases the execution thread (does not block a worker)
- Resumes automatically after the configured interval, even after server restarts
- Survival through restarts is confirmed in n8n docs (state persists in DB)

### V1 — Time-Based Only (Recommended Starting Point)

```
[Send prospect message] → [Notify owner] → [Wait: 45 min] → [Send follow-up to prospect]
```

No call-back detection in v1. The follow-up always sends after the delay. This is acceptable because:
- The follow-up message is soft ("still available if you have questions")
- False positives (owner already called) are low-friction for the prospect
- Detecting actual phone calls requires telephony integration (Twilio call logs) — significant added complexity

### V2 — Call Detection (Future)

To detect if the owner actually called back, two approaches:

1. **Twilio call log check:** Before the follow-up sends, query Twilio's API for outbound calls from the owner's number to the prospect's number in the time window. If a call record exists, skip follow-up.

2. **Owner confirmation webhook:** In the owner notification, include a "I called them" link that hits a webhook to mark the lead as handled. Simple but requires one action from the owner (low friction, but not zero).

V2 approach 1 (Twilio log check) is cleaner and requires no owner action. It is the recommended upgrade path.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: One Workflow Per Client
**What:** Duplicate the entire Core Workflow for each client with hard-coded client values.
**Why bad:** Updating logic (e.g., changing follow-up message format) requires editing N workflows. Drift and bugs accumulate. Unsustainable beyond 5 clients.
**Instead:** Shared Core Workflow with client config injected as parameters.

### Anti-Pattern 2: Identifying Client by `form_id`
**What:** Look up which client owns a lead by matching `form_id` from the Google Ads payload.
**Why bad:** Form IDs change when campaigns are restructured. A changed form_id means leads silently fail. Requires maintaining a form_id → client mapping that goes stale.
**Instead:** Dedicated webhook URL per client. Slug in the URL path is stable and explicit.

### Anti-Pattern 3: Blocking Wait Without Async
**What:** Using a Wait node in the same execution as the webhook response.
**Why bad:** Google Ads Lead Form webhook has a response timeout. The initial webhook response (200 OK) must return immediately. A Wait node inside the webhook's synchronous execution will cause a timeout.
**Instead:** Respond 200 immediately in the Ingress Webhook, then trigger the Core Workflow asynchronously. In n8n, this means "Respond to Webhook" node fires first, then the processing continues or is handed off to an Execute Workflow node.

### Anti-Pattern 4: Storing `google_key` in Workflow Nodes
**What:** Paste the `google_key` validation string directly into a node's expression or code block.
**Why bad:** Keys appear in plain text in n8n's workflow JSON, which gets exported/backed up. If the workflow is shared or exported, the key leaks.
**Instead:** Store in n8n Credentials (Header Auth type) or n8n environment variable. Reference via `$credentials` expression.

---

## Scalability Considerations

| Concern | At 5 clients | At 20 clients | At 50+ clients |
|---------|-------------|--------------|----------------|
| Config storage | JSON file on disk | JSON file or Airtable | Supabase (query by slug) |
| Webhook management | Manual creation per client | Manual but manageable | Script-generated or API-driven |
| n8n instance | Single instance, default mode | Single instance, consider queue mode | Queue mode + Redis + workers |
| Execution history | n8n default (7-day retention) | Prune regularly | External logging (Postgres long-term) |
| Claude API cost | Negligible | Budget per client per month | Enforce max tokens per execution |

For v1 (2–10 clients), single n8n instance in default execution mode with JSON file config is sufficient and operationally simple. Queue mode adds Redis and worker processes — real overhead for a solo operator. Introduce only when execution concurrency becomes a bottleneck.

---

## Build Order (Dependencies)

Build in this sequence — each layer depends on the one below it:

```
Layer 1 — Foundation
  ├── Client config schema (JSON structure)
  ├── n8n instance setup (self-hosted or n8n Cloud)
  └── Twilio account + phone numbers

Layer 2 — Ingress
  ├── Ingress Webhook node (one per client)
  ├── google_key validation
  └── Config loader (reads client JSON by slug)

Layer 3 — AI Message
  ├── Claude API integration node
  ├── Prompt template (uses client config + lead data)
  └── Response parser

Layer 4 — Channel Dispatcher
  ├── Channel selection IF node (phone vs email)
  ├── Twilio SMS send
  ├── Twilio WhatsApp send (uses WhatsApp Business sandbox or approved number)
  └── Email send (SMTP or SendGrid)

Layer 5 — Owner Notification
  ├── Message formatter (lead summary)
  └── Twilio SMS to owner with tel: link

Layer 6 — Follow-up
  ├── Wait node (configurable delay from client config)
  └── Follow-up message via Channel Dispatcher (reuse layer 4)

Layer 7 — Hardening
  ├── Error handling (catch nodes, owner alert on failure)
  ├── Execution logging
  └── google_key stored in n8n Credentials (not plain text)
```

Layers 1–3 can be validated end-to-end before Channel Dispatcher is built (log output to n8n execution log). Layers 4 and 5 can be tested independently from the full flow using n8n's manual test execution.

---

## Sources

- Google Ads Lead Form Webhook payload spec: https://developers.google.com/google-ads/webhook/docs/implementation
- n8n Wait node documentation: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.wait/
- n8n Sub-workflows / Execute Workflow: https://docs.n8n.io/flow-logic/subworkflows/
- Multi-tenant WhatsApp platform on n8n (production case study): https://dev.to/achiya-automation/how-i-built-a-multi-tenant-whatsapp-automation-platform-using-n8n-and-waha-4jj4
- n8n agency multi-tenant patterns: https://www.wednesday.is/writing-articles/building-multi-tenant-n8n-workflows-for-agency-clients
- n8n Twilio node: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.twilio/
- n8n webhook security: https://automategeniushub.com/mastering-the-n8n-webhook-node-part-b/
