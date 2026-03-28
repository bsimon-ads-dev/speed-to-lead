<!-- GSD:project-start source:PROJECT.md -->
## Project

**Speed to Lead**

Workflow d'automatisation n8n + Claude API qui répond instantanément aux leads Google Ads pour le compte de PME de services locaux. Le dirigeant reçoit une notification prête à l'action pendant que le prospect est déjà engagé par un message IA personnalisé. Vendu comme upsell séparé du service de media buying Google/Meta Ads.

**Core Value:** Réduire le temps de réponse aux leads à < 2 minutes, 24/7 — pour que plus aucun lead payé ne soit perdu par manque de réactivité.

### Constraints

- **Stack** : n8n (self-hosted ou cloud) + Claude API — pas de stack custom, doit rester maintenable par un freelance solo
- **Clients** : Zéro technique — toute la configuration se fait côté freelance, le client ne touche à rien
- **Canaux** : Dépend des coordonnées disponibles dans le Lead Form (téléphone → SMS/WhatsApp, email → email)
- **Coût** : Le coût par lead (API Claude + SMS/WhatsApp) doit rester marginal vs. le coût d'acquisition du lead
- **Fiabilité** : 24/7, pas de downtime — un lead à 3h du matin doit recevoir sa réponse
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Trigger Layer — Receiving Google Ads Lead Form Submissions
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| n8n Webhook Node (generic) | Built-in | Receives Google Ads Lead Form POST | There is no dedicated "Google Ads Lead Form Trigger" node in n8n. Google Ads sends a raw HTTP POST to a URL you configure in the Lead Form settings. The generic Webhook node receives this perfectly. |
- `lead_id` — unique string, use this to deduplicate (leads can be delivered more than once)
- `gcl_id` — Google Click ID (tracks the ad click)
- `lead_submit_time` — ISO-8601 timestamp
- `user_column_data` — array of `{ column_id, column_name, string_value }` — this is where `PHONE_NUMBER`, `EMAIL`, `FULL_NAME`, and any custom questions live
- `google_key` — a shared secret you configure in Google Ads for request validation
- `form_id`, `campaign_id`, `adgroup_id` — campaign context
- `is_test` — boolean, set to `true` for test leads sent from Google Ads UI
### Orchestration Layer — n8n
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| n8n | Latest stable (1.x) | Core workflow engine | Already mastered by Baptiste. Handles webhook reception, branching logic (phone vs email), API calls, Wait node for follow-ups. Per-execution billing model is cheap at this lead volume. |
- n8n Cloud starts at ~$20/month for 2,500 executions. At scale with multiple clients, this cap matters.
- Railway self-hosted: ~$5-7/month for unlimited executions, Postgres included, deploys in 5 minutes via their n8n template.
- OVH/Scaleway VPS (€3.60-€7/month) is the European alternative if data residency matters to a client.
- n8n Cloud is acceptable for a single-client MVP phase but Railway is the production target.
- `Webhook` — receives Google Ads lead
- `IF` / `Switch` — branches on phone vs email availability
- `HTTP Request` — calls Claude API (Anthropic node also works but HTTP Request is more explicit about model/version)
- `Twilio` (built-in node) — sends SMS and WhatsApp
- `Send Email` / `Gmail` / `SMTP` — sends email fallback
- `Wait` — pauses workflow for follow-up delay (supports "After Time Interval" and "On Webhook Call" modes)
- `Schedule Trigger` — not needed here; Wait node handles follow-up timing inline
### AI Layer — Claude API
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Claude Haiku 4.5 | `claude-haiku-4-5-20251001` | Generates personalized prospect message + owner notification | Cheapest Claude model. $1/M input tokens, $5/M output tokens. A single lead message generation uses ~300-500 tokens total. Cost per lead: < $0.003. This is marginal vs. a €10-50 Google Ads CPL. |
- Input: ~200 tokens (system prompt + lead data)
- Output: ~150 tokens (SMS message ~100 words)
- Total: ~350 tokens → ~$0.001 per lead at Haiku pricing
### Messaging Layer — SMS and WhatsApp
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Twilio | REST API v2010 | SMS to prospect + SMS to owner | Native n8n node, battle-tested, works in France, single SDK covers SMS + WhatsApp. Most important: one integration covers both channels. |
| Twilio WhatsApp | WhatsApp Business Platform | WhatsApp to prospect + owner | Twilio is a Meta-approved Business Solution Provider (BSP). One Twilio account covers both SMS and WhatsApp. No separate WhatsApp BSP needed. |
- Outbound SMS to French mobile: **$0.0798/message** (verified March 2026 on Twilio pricing page)
- At €0.08/message, 4 messages per lead (1 to prospect + 1 owner notification + 1 follow-up to prospect + 1 follow-up owner) = ~€0.32/lead total SMS cost. Marginal vs. CPL.
- Meta moved to per-template-message pricing (no longer per-conversation)
- Utility template messages sent within a customer service window: $0.00 Meta fee (only Twilio markup applies at ~$0.005/message)
- Business-initiated utility messages outside window: varies by country; estimate $0.02-0.05/message for France
- **Important:** All business-initiated WhatsApp messages require pre-approved message templates. You cannot send free-form text to a user who has not first messaged you. Design your system prompt to generate text that fits within approved templates.
### Email Layer
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Brevo (ex-Sendinblue) | REST API v3 | Transactional email to prospect when no phone | French company, GDPR-native, free tier covers 300 emails/day (more than sufficient for v1), native n8n node exists. Cheaper and simpler than Sendgrid for low-volume transactional. |
- Brevo's free tier (300 emails/day) is sufficient for the entire v1 client base
- French company — easier GDPR compliance argument to French SME clients
- Native n8n node (`Brevo` node) handles transactional send directly
- SendGrid would be overkill; Mailgun has no native n8n node
### Follow-up Logic Layer
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| n8n Wait Node | Built-in | Pauses workflow then sends follow-up if owner hasn't called | The Wait node's "After Time Interval" mode suspends workflow execution and resumes after a configurable delay (e.g., 30 minutes). On resume, check a flag stored in Postgres/Airtable/n8n variable to see if owner called back. If not, send follow-up SMS to prospect. |
### Client Configuration Storage
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| n8n Environment Variables + Workflow-level variables | Built-in | Per-client config: business name, service type, delay, channels | For v1 with 1-5 clients, store per-client config as a JSON object in n8n workflow static data or environment variable per workflow instance. No external DB needed. |
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
## Installation
# 1. Deploy n8n on Railway
# Use the official Railway n8n template:
# https://railway.com/deploy/n8n
# Configure with Postgres addon for workflow persistence
# 2. Required environment variables in Railway n8n instance
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
## Cost Model Per Client Per Month
| Line item | Unit cost | Monthly (30 leads) |
|-----------|-----------|-------------------|
| Claude Haiku (4 API calls/lead: prospect msg + owner notif + 2 follow-ups) | ~$0.001/call | ~$0.12 |
| Twilio SMS France (4 SMS/lead) | $0.0798/SMS | ~$9.58 |
| Twilio WhatsApp (if used, utility template) | ~$0.02/msg | ~$2.40 |
| n8n Railway hosting | $5-7/month flat | ~$0.20/client (amortized over 5 clients) |
| Brevo email (fallback) | Free tier | $0 |
| **Total per client** | | **~$10-12/month** |
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
