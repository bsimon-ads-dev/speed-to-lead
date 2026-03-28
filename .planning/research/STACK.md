# Technology Stack

**Project:** Speed to Lead — n8n + Claude AI lead response automation
**Researched:** 2026-03-27
**Overall confidence:** HIGH (core choices), MEDIUM (pricing figures — verify before quoting to clients)

---

## Recommended Stack

### Trigger Layer — Receiving Google Ads Lead Form Submissions

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| n8n Webhook Node (generic) | Built-in | Receives Google Ads Lead Form POST | There is no dedicated "Google Ads Lead Form Trigger" node in n8n. Google Ads sends a raw HTTP POST to a URL you configure in the Lead Form settings. The generic Webhook node receives this perfectly. |

**Google Ads Lead Form Webhook — What you need to know:**

Google Ads sends a POST request with a JSON body structured as `WebhookLead`. Key fields available in the payload:
- `lead_id` — unique string, use this to deduplicate (leads can be delivered more than once)
- `gcl_id` — Google Click ID (tracks the ad click)
- `lead_submit_time` — ISO-8601 timestamp
- `user_column_data` — array of `{ column_id, column_name, string_value }` — this is where `PHONE_NUMBER`, `EMAIL`, `FULL_NAME`, and any custom questions live
- `google_key` — a shared secret you configure in Google Ads for request validation
- `form_id`, `campaign_id`, `adgroup_id` — campaign context
- `is_test` — boolean, set to `true` for test leads sent from Google Ads UI

Configuration in Google Ads: Campaign > Lead Form Asset > Webhook integration > paste your n8n webhook URL + webhook key.

**Phone format:** E.164 (e.g., `+33612345678`). No transformation needed for Twilio.

**Security:** Validate the `google_key` field in n8n (first node after webhook: IF `google_key` matches stored credential → continue, else stop). This prevents spam triggers.

---

### Orchestration Layer — n8n

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| n8n | Latest stable (1.x) | Core workflow engine | Already mastered by Baptiste. Handles webhook reception, branching logic (phone vs email), API calls, Wait node for follow-ups. Per-execution billing model is cheap at this lead volume. |

**Hosting decision: Self-host on Railway**

Use Railway, not n8n Cloud. Rationale:
- n8n Cloud starts at ~$20/month for 2,500 executions. At scale with multiple clients, this cap matters.
- Railway self-hosted: ~$5-7/month for unlimited executions, Postgres included, deploys in 5 minutes via their n8n template.
- OVH/Scaleway VPS (€3.60-€7/month) is the European alternative if data residency matters to a client.
- n8n Cloud is acceptable for a single-client MVP phase but Railway is the production target.

**Key n8n nodes used in this project:**
- `Webhook` — receives Google Ads lead
- `IF` / `Switch` — branches on phone vs email availability
- `HTTP Request` — calls Claude API (Anthropic node also works but HTTP Request is more explicit about model/version)
- `Twilio` (built-in node) — sends SMS and WhatsApp
- `Send Email` / `Gmail` / `SMTP` — sends email fallback
- `Wait` — pauses workflow for follow-up delay (supports "After Time Interval" and "On Webhook Call" modes)
- `Schedule Trigger` — not needed here; Wait node handles follow-up timing inline

---

### AI Layer — Claude API

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Claude Haiku 4.5 | `claude-haiku-4-5-20251001` | Generates personalized prospect message + owner notification | Cheapest Claude model. $1/M input tokens, $5/M output tokens. A single lead message generation uses ~300-500 tokens total. Cost per lead: < $0.003. This is marginal vs. a €10-50 Google Ads CPL. |

**Why Haiku, not Sonnet:**
The task is constrained — reformulate the prospect's request into a warm, professional SMS/email response using a system prompt that includes business name, service type, and tone. This does not require Sonnet-level reasoning. Haiku is 3x cheaper and fast enough (latency < 1s typical).

**n8n integration method:** Use the built-in `Anthropic Chat Model` node (available in n8n AI Agent nodes) OR a plain `HTTP Request` node to `https://api.anthropic.com/v1/messages`. The HTTP Request approach is recommended because it gives explicit control over model version, max_tokens, and system prompt — important for cost predictability and prompt stability across client deployments.

**Prompt caching:** Not needed at v1 volume. System prompt is short and per-client. Revisit at >1,000 leads/month per client.

**Cost estimation per lead:**
- Input: ~200 tokens (system prompt + lead data)
- Output: ~150 tokens (SMS message ~100 words)
- Total: ~350 tokens → ~$0.001 per lead at Haiku pricing

---

### Messaging Layer — SMS and WhatsApp

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Twilio | REST API v2010 | SMS to prospect + SMS to owner | Native n8n node, battle-tested, works in France, single SDK covers SMS + WhatsApp. Most important: one integration covers both channels. |
| Twilio WhatsApp | WhatsApp Business Platform | WhatsApp to prospect + owner | Twilio is a Meta-approved Business Solution Provider (BSP). One Twilio account covers both SMS and WhatsApp. No separate WhatsApp BSP needed. |

**Twilio SMS pricing for France:**
- Outbound SMS to French mobile: **$0.0798/message** (verified March 2026 on Twilio pricing page)
- At €0.08/message, 4 messages per lead (1 to prospect + 1 owner notification + 1 follow-up to prospect + 1 follow-up owner) = ~€0.32/lead total SMS cost. Marginal vs. CPL.

**Twilio WhatsApp pricing (post-July 2025 Meta pricing change):**
- Meta moved to per-template-message pricing (no longer per-conversation)
- Utility template messages sent within a customer service window: $0.00 Meta fee (only Twilio markup applies at ~$0.005/message)
- Business-initiated utility messages outside window: varies by country; estimate $0.02-0.05/message for France
- **Important:** All business-initiated WhatsApp messages require pre-approved message templates. You cannot send free-form text to a user who has not first messaged you. Design your system prompt to generate text that fits within approved templates.

**WhatsApp setup gotcha — template approval required:**
For the "We received your request, you'll be called back within X minutes" message to a prospect who just submitted a Lead Form, that prospect has NOT messaged your WhatsApp number first. Therefore this is a business-initiated message and requires a pre-approved utility template. Plan ~24-48 hours for Meta template approval per client phone number during onboarding.

**Alternative for WhatsApp — 360dialog:**
If Twilio WhatsApp approval proves slow or complex per client, 360dialog is a leaner API-first BSP focused exclusively on WhatsApp. They charge no markup on Meta rates. However, they have no native n8n node — use HTTP Request node. Not recommended for v1; use Twilio for simplicity.

---

### Email Layer

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Brevo (ex-Sendinblue) | REST API v3 | Transactional email to prospect when no phone | French company, GDPR-native, free tier covers 300 emails/day (more than sufficient for v1), native n8n node exists. Cheaper and simpler than Sendgrid for low-volume transactional. |

**Why Brevo, not SendGrid or Mailgun:**
- Brevo's free tier (300 emails/day) is sufficient for the entire v1 client base
- French company — easier GDPR compliance argument to French SME clients
- Native n8n node (`Brevo` node) handles transactional send directly
- SendGrid would be overkill; Mailgun has no native n8n node

**Email volume context:** Email is a fallback channel when Lead Form has no phone number. At typical French SME Google Ads lead volume (10-50 leads/month per client), this is negligible.

---

### Follow-up Logic Layer

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| n8n Wait Node | Built-in | Pauses workflow then sends follow-up if owner hasn't called | The Wait node's "After Time Interval" mode suspends workflow execution and resumes after a configurable delay (e.g., 30 minutes). On resume, check a flag stored in Postgres/Airtable/n8n variable to see if owner called back. If not, send follow-up SMS to prospect. |

**Follow-up detection approach (choose one):**

Option A — Simple timer only (MVP):
Wait X minutes → assume no callback → send follow-up to prospect. No callback tracking. Simple, zero extra infra.

Option B — Webhook-based confirmation (v2):
Owner's notification SMS includes a "mark as called" link (e.g., `https://your-n8n.app/webhook/called?lead_id=xyz`). Wait node uses "On Webhook Call" mode. If owner clicks the link within the window, workflow terminates without sending follow-up. If no callback from the link within X minutes, follow-up fires.

**Recommendation:** Ship Option A in v1. It's invisible to the owner (no action required) and still prevents lost leads. Option B adds a UX element that requires client education.

---

### Client Configuration Storage

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| n8n Environment Variables + Workflow-level variables | Built-in | Per-client config: business name, service type, delay, channels | For v1 with 1-5 clients, store per-client config as a JSON object in n8n workflow static data or environment variable per workflow instance. No external DB needed. |

**Per-client workflow isolation:** Create one copy of the master workflow per client. Each copy has its own webhook URL (given to Google Ads), its own env vars (Twilio number, business name, Claude system prompt, follow-up delay). This is the simplest possible architecture for a solo freelance operator.

**Scale trigger:** When you have 10+ clients, consider a Postgres lookup table where `lead_id` maps to client config. But for v1, per-workflow config is zero overhead.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Orchestration | n8n self-host (Railway) | n8n Cloud | Execution limits become a cost issue at scale; Railway is $5-7/month unlimited |
| AI model | Claude Haiku 4.5 | Claude Sonnet 4.6 | Sonnet is 3x more expensive ($3/M input) with no quality gain for constrained SMS generation task |
| SMS/WhatsApp | Twilio | 360dialog (WhatsApp-only) + separate SMS provider | Two accounts to manage; Twilio covers both channels with one integration and has a native n8n node |
| SMS/WhatsApp | Twilio | Bird (formerly MessageBird) | More complex setup, no native n8n node, higher minimum commitment |
| Email | Brevo | SendGrid | SendGrid free tier is 100 emails/day and requires credit card; Brevo is more generous and GDPR-native |
| Email | Brevo | Mailgun | No native n8n node; requires HTTP Request node with more setup |
| Hosting | Railway | OVH/Scaleway VPS | VPS requires server management (nginx, SSL, Docker Compose); Railway is fully managed and faster for a solo freelance operator |
| Follow-up logic | n8n Wait Node | External cron + Redis | Massive overkill for <100 leads/day; Wait node handles this natively |

---

## Installation

```bash
# 1. Deploy n8n on Railway
# Use the official Railway n8n template:
# https://railway.com/deploy/n8n
# Configure with Postgres addon for workflow persistence

# 2. Required environment variables in Railway n8n instance
N8N_ENCRYPTION_KEY=<random-32-char-string>
DB_TYPE=postgresdb
# (Railway auto-fills DB_* vars from Postgres addon)

# 3. Twilio — no install needed, credentials only
# Create account at twilio.com
# Get Account SID, Auth Token
# Register a French phone number (~$1/month)
# For WhatsApp: enable WhatsApp on that number and submit message templates

# 4. Anthropic API key
# Create at console.anthropic.com
# Store as n8n credential (Anthropic type) or HTTP Request header

# 5. Brevo API key
# Create at app.brevo.com > Settings > API Keys
# Store as n8n credential (Brevo type)
```

---

## Cost Model Per Client Per Month

Assuming 30 leads/month (typical French SME Google Ads campaign):

| Line item | Unit cost | Monthly (30 leads) |
|-----------|-----------|-------------------|
| Claude Haiku (4 API calls/lead: prospect msg + owner notif + 2 follow-ups) | ~$0.001/call | ~$0.12 |
| Twilio SMS France (4 SMS/lead) | $0.0798/SMS | ~$9.58 |
| Twilio WhatsApp (if used, utility template) | ~$0.02/msg | ~$2.40 |
| n8n Railway hosting | $5-7/month flat | ~$0.20/client (amortized over 5 clients) |
| Brevo email (fallback) | Free tier | $0 |
| **Total per client** | | **~$10-12/month** |

At a recurring monthly fee of €49-99/month per client, margin is strong.

---

## Sources

- n8n Twilio node docs: https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.twilio/
- n8n Anthropic credentials: https://docs.n8n.io/integrations/builtin/credentials/anthropic/
- n8n Wait node docs: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.wait/
- n8n Webhook node docs: https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/
- Google Ads Lead Form Webhook overview: https://developers.google.com/google-ads/webhook/docs/overview
- Google Ads Lead Form Webhook implementation (payload schema): https://developers.google.com/google-ads/webhook/docs/implementation
- Twilio SMS pricing France: https://www.twilio.com/en-us/sms/pricing/fr
- Twilio WhatsApp pricing: https://www.twilio.com/en-us/whatsapp/pricing
- Twilio WhatsApp July 2025 pricing change: https://www.twilio.com/en-us/changelog/meta-is-updating-whatsapp-pricing-on-july-1--2025
- Claude Haiku 4.5 pricing: https://www.anthropic.com/claude/haiku
- Anthropic API pricing: https://platform.claude.com/docs/en/about-claude/pricing
- n8n Railway deployment: https://railway.com/deploy/n8n
- Railway vs Render for n8n: https://flowengine.cloud/blog/railway-vs-render-for-n8n-pricing-performance-and-real-world-considerations-in-2025
- n8n Brevo integration: https://n8n.io/integrations/brevo/
- Brevo transactional SMS: https://developers.brevo.com/docs/transactional-sms-endpoints
- n8n automated lead follow-up example: https://n8n.blog/automated-lead-follow-up-system-with-email-sms-whatsapp-2/
