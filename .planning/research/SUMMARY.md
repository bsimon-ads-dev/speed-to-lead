# Project Research Summary

**Project:** Speed to Lead — n8n + Claude AI lead response automation
**Domain:** Automated lead response for local service SMEs (Google Ads Lead Forms)
**Researched:** 2026-03-27
**Confidence:** HIGH (architecture and stack), MEDIUM-HIGH (regulatory)

## Executive Summary

Speed to Lead is a webhook-triggered automation that receives Google Ads Lead Form submissions, generates a personalized acknowledgment message via Claude AI, notifies the business owner, and sends a follow-up if no callback happens within a configurable window. The product category is well-documented: competitors like Callingly, Hatch, and Setter.ai have validated the market and the table stakes. What differentiates this offering is AI-personalized messaging (not templates), a zero-interface model for business owners, and direct integration into Baptiste's existing media buying client base. The build is entirely within the n8n + Claude API + Twilio stack Baptiste already operates — there are no novel technology choices.

The recommended architecture is a single shared n8n instance with one thin entry workflow per client (webhook + config load) feeding into a shared Core Workflow. This balances multi-tenant isolation against the operational overhead a solo operator can sustain. Client configuration lives in a per-client JSON schema — no database required at v1 (2-10 clients). The critical path is: Google Ads webhook → deduplication → Claude message generation → prospect send + owner notification. The follow-up scheduler is a secondary branch and can be added after the critical path is validated end-to-end with a real client.

The primary risks are regulatory, not technical. France requires explicit RGPD opt-in consent before sending SMS to a prospect — the Google Ads Lead Form submission alone is not sufficient. WhatsApp outbound contact requires pre-approved Meta message templates, which take 1-3 business days to approve. Both of these must be addressed before any client goes live, not retrofitted afterward. The secondary risk is silent failure: Google's webhook delivers leads with limited retry guarantees, so raw payload logging and idempotency (deduplication on `lead_id`) must be built into the ingress from day one.

---

## Key Findings

### Recommended Stack

The entire product runs on four services: n8n (orchestration), Claude Haiku 4.5 (message generation), Twilio (SMS and WhatsApp), and Brevo (email fallback). All four have native n8n nodes, verified French market support, and marginal per-lead costs — totaling ~$10-12/month per client at 30 leads/month. Self-hosting n8n on Railway (~$5-7/month flat, unlimited executions) is the production target; n8n Cloud (~$20/month) is acceptable for a single-client MVP phase.

**Core technologies:**
- **n8n self-hosted on Railway:** Workflow orchestration — unlimited executions at ~$5-7/month flat, Postgres included, 5-minute deploy via Railway template
- **Claude Haiku 4.5 (`claude-haiku-4-5-20251001`):** AI message generation — ~$0.001/lead, sufficient quality for constrained SMS reformulation task; Sonnet is 3x more expensive with no quality gain here
- **Twilio:** SMS + WhatsApp to prospects and owners — single integration covers both channels, native n8n node, verified French market; French mobile numbers ~$1/month, SMS ~$0.08/message
- **Brevo:** Transactional email fallback — free tier (300 emails/day) covers all v1 volume, native n8n node, French company (GDPR-native)
- **n8n Wait node:** Follow-up scheduler — serializes execution state to Postgres, resumes after configurable delay, survives server restarts

No external database, no Redis, no cron service. The Wait node handles all delayed execution natively. Configuration is stored as JSON in n8n workflow static data per client — no additional infra required until 10+ clients.

### Expected Features

**Must have (table stakes):**
- Sub-2-minute first response to prospect (24/7, including nights and weekends)
- AI-personalized first message reformulating the prospect's specific request
- Owner notification via SMS/WhatsApp with name, need, phone, and one-tap `tel:` callback link
- Automated follow-up to prospect if owner hasn't called back within configurable window
- Google Ads Lead Form webhook ingestion with `lead_id` deduplication
- Per-client configuration (channels, delays, business name, service type)
- Graceful error fallback — raw lead data to Baptiste if AI/SMS pipeline fails

**Should have (differentiators):**
- Vertical-aware prompt tone (plumber vs. dentist vs. lawyer messages feel different)
- Smart channel selection: phone available → SMS first; no phone → email; WhatsApp if client configured
- Zero-interface for business owner — no app, no login, no dashboard required
- Setup-and-forget reliability with error alerting back to Baptiste (not the client)

**Defer to v2+:**
- WhatsApp channel (v1 ships SMS + email; WhatsApp added after Twilio/WABA onboarding is validated)
- Multi-step lead nurture sequences (J+1, J+3, J+7) — requires conversation state and opt-out management
- Two-way AI conversation with prospect — doubles complexity for marginal v1 gain
- Dashboard or reporting UI for clients — explicitly anti-feature for local SME owners
- CRM integration, appointment booking, inbound call handling

### Architecture Approach

The architecture is a shared n8n instance with config-driven routing. Each client gets one thin entry workflow (Webhook node + config loader) that feeds a single shared Core Workflow. The Core Workflow runs two parallel branches on lead receipt: Branch A generates the Claude message and dispatches to prospect; Branch B formats and sends the owner notification. After both branches, a Wait node pauses execution for the configured delay, then a follow-up check fires. Client identity is established via a slug in the webhook URL path (e.g., `/webhook/dupont-plomberie`) — more stable than extracting from `form_id`, which changes when campaigns are rebuilt.

**Major components:**
1. **Ingress Webhook** — receives Google Ads POST, validates `google_key`, returns HTTP 200 immediately, hands off async
2. **Router / Config Loader** — identifies client from URL slug, loads per-client JSON config
3. **Core Workflow** — orchestrates full lead lifecycle: Claude call, channel dispatch, owner notify, Wait, follow-up
4. **Claude API node** — generates personalized prospect message from lead data + client context; constrained prompt prevents hallucinated prices or promises
5. **Channel Dispatcher** — IF node routing to Twilio SMS, Twilio WhatsApp, or Brevo email based on available lead fields
6. **Owner Notifier** — Twilio SMS with formatted lead summary and `tel:` deep link
7. **Follow-up Scheduler** — Wait node (v1: time-based only); v2 upgrade path: Twilio call log check before sending

### Critical Pitfalls

1. **RGPD consent missing on lead forms** — Sending SMS to a prospect without prior explicit opt-in is illegal under French law (CNIL / CPCE). The Lead Form submission alone is not consent. Mandatory fix: add a dedicated, pre-unchecked RGPD checkbox to every client's lead form before launch. Store consent timestamp per `lead_id`. Cannot be retrofitted without changing the live form.

2. **WhatsApp outbound without approved Meta template** — Business-initiated WhatsApp to a new prospect (who has never messaged you) requires a pre-approved Meta message template. Free-form outbound fails silently or gets the account flagged. Templates take 1-3 business days. Plan template submission as part of client onboarding, not an afterthought.

3. **Webhook not returning 200 immediately** — Google Ads webhook has a response timeout. Processing (Claude call, SMS send) must happen asynchronously after the 200 is returned. A blocking wait inside the synchronous response path will cause timeouts and missed leads.

4. **No deduplication on `lead_id`** — Google does not guarantee exactly-once delivery. The same lead can arrive multiple times. Without deduplication, a prospect receives two identical messages and the owner gets two notifications. Check `lead_id` as idempotency key before any send.

5. **AI message generating unverified business claims** — Without a constrained prompt, Claude may generate specific prices, timelines, or service promises ("intervention sous 30 minutes pour 80€") that the business never validated. The prompt must explicitly restrict Claude to reformulating the prospect's stated need and confirming a callback is coming — nothing else. Output length cap (~160 chars for SMS) prevents elaborate hallucinations.

---

## Implications for Roadmap

### Phase 1: Foundation and Critical Path

**Rationale:** The core value proposition is the <2-minute response loop. Nothing else matters until this works end-to-end. All critical pitfalls (RGPD, dedup, 200-response, prompt constraints) must be embedded here — they cannot be retrofitted.

**Delivers:** A working webhook → Claude message → prospect SMS + owner notification flow for one client. Verified with real Google Ads test lead.

**Addresses:** Webhook ingestion, deduplication, AI message generation, SMS to prospect, owner notification, basic error fallback (raw lead data to Baptiste on failure).

**Must embed from day 1:**
- `google_key` validation at first node
- `is_test` filter (test leads → log only, no sends)
- `lead_id` deduplication
- HTTP 200 returned immediately before any processing
- Constrained Claude prompt with `<prospect_input>` input wrapping
- Output length cap on Claude response (~160 chars)
- Raw payload logging before processing
- Alphanumeric SMS sender ID (not long code — blocked by French operators)
- RGPD consent checkbox on client lead form (pre-launch requirement)

**Stack used:** n8n on Railway, Twilio SMS, Claude Haiku 4.5, Brevo email fallback

### Phase 2: Follow-up Scheduler and Multi-Client Architecture

**Rationale:** Follow-up is the "no lead left behind" promise that justifies the recurring monthly fee. Multi-client architecture must be finalized before onboarding client 2 — credential cross-contamination between clients is a RGPD violation.

**Delivers:** Configurable follow-up that fires after owner inaction; shared Core Workflow pattern supporting N clients via thin per-client entry workflows.

**Addresses:** Follow-up automation, per-client config schema, multi-tenant isolation, opt-out capture (inbound STOP → blocklist before follow-up).

**Must embed:**
- Business-hours gate on follow-up (no sends outside 08:00-20:00 Mon-Sat, no Sundays or public holidays)
- Opt-out check before follow-up send
- Strict credential naming convention per client (e.g., `[ClientSlug]_twilio`) to prevent cross-contamination
- Error trigger workflow alerting Baptiste on any execution failure

**Stack used:** n8n Wait node, shared Core Workflow pattern, per-client JSON config

### Phase 3: WhatsApp Channel and Hardening

**Rationale:** WhatsApp has higher read rates than SMS and is the preferred channel for many French mobile users, but it requires Meta template pre-approval (1-3 days) and adds setup complexity. Defer until the SMS/email path is validated in production. Hardening (uptime monitoring, spend caps, execution logging) makes the product production-safe for a growing client base.

**Delivers:** WhatsApp channel for both prospect messages and owner notifications; production hardening for reliability.

**Addresses:** Twilio WhatsApp integration, Meta template submission workflow for client onboarding, UptimeRobot monitoring, Anthropic spend cap, Claude API call count logging per client.

**Must embed:**
- Pre-approved WhatsApp utility templates per client (submitted during onboarding, before activation)
- One WhatsApp number per client (never shared — quality rating degradation on one client affects all)
- Monthly spend limit in Anthropic Console
- Circuit breaker: >5 executions for same `lead_id` in 10 minutes → halt and alert Baptiste

### Phase Ordering Rationale

- Phase 1 before Phase 2: The follow-up is a secondary branch off the critical path. Validating end-to-end delivery first avoids building follow-up logic on top of an untested foundation.
- Phase 2 before Phase 3: Multi-tenant architecture must be locked before WhatsApp adds another per-client configuration axis (WABA account, templates). Adding WhatsApp to a flawed multi-tenant setup multiplies the risk of cross-contamination.
- RGPD consent and deduplication are not phases — they are embedded in Phase 1 and cannot be deferred. They affect every subsequent phase.

### Research Flags

**Phases with well-documented patterns (skip additional research-phase):**
- **Phase 1 (n8n webhook + Twilio SMS):** All integration details confirmed in official docs. Build directly.
- **Phase 2 (Wait node follow-up, multi-client JSON config):** Pattern validated in production case studies.

**Phases that may need targeted research during planning:**
- **Phase 3 (WhatsApp WABA setup per client):** Meta's WABA onboarding for BSP-managed numbers via Twilio has specific steps that vary by country and account age. Worth checking Twilio's current WABA onboarding docs before planning this phase.
- **Phase 3 (French public holiday API for follow-up hours gate):** The api.gouv.fr jours feries endpoint is well-known but its n8n integration pattern is undocumented — a quick proof of concept during planning is recommended.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies verified via official docs. Pricing figures accurate as of March 2026 — verify Twilio SMS France rate before quoting clients. |
| Features | HIGH | Table stakes consistent across Callingly, Hatch, Setter.ai, Apten.ai, GoHighLevel. Anti-features aligned with PROJECT.md explicit out-of-scope. |
| Architecture | HIGH | Shared Core Workflow + per-client entry pattern validated in production multi-tenant n8n case studies (50+ clients on single instance). |
| Pitfalls | MEDIUM-HIGH | Regulatory items (CNIL SMS consent, WhatsApp templates) verified against official sources. Technical pitfalls (dedup, 200-response) verified against Google Ads webhook docs and n8n docs. |

**Overall confidence:** HIGH

### Gaps to Address

- **RGPD consent wording for lead forms:** The exact required checkbox copy ("J'accepte d'être contacté(e) par SMS par [Nom]...") should be reviewed by a RGPD-aware lawyer or a CNIL-approved compliance template before client onboarding. The requirement is confirmed; the exact wording is a legal detail.
- **Twilio WhatsApp France WABA onboarding time:** Anecdotal reports suggest 1-3 business days for template approval and 1-7 days for number registration. Validate with Twilio support before committing a client launch date that depends on WhatsApp.
- **Client channel preference validation:** FEATURES.md assumes phone leads prefer SMS over WhatsApp. This is a reasonable default but has not been validated with Baptiste's actual clients. Confirm with first client during Phase 1.
- **Follow-up conversion uplift:** The assumption that a follow-up message increases callback rate (and client retention) is validated by competitor marketing claims, not by Baptiste's own data. Track outcome per lead in Phase 2 to build this evidence.

---

## Sources

### Primary (HIGH confidence)
- Google Ads Webhook docs — https://developers.google.com/google-ads/webhook/docs/overview and /implementation
- n8n official docs (Webhook, Wait, Twilio, Brevo nodes) — https://docs.n8n.io
- CNIL prospection commerciale SMS — https://www.cnil.fr/fr/la-prospection-commerciale-par-sms-mms
- Meta WhatsApp Business Policy and Messaging Limits — https://business.whatsapp.com/policy and https://developers.facebook.com/docs/whatsapp/messaging-limits/
- Vonage France SMS restrictions — https://api.support.vonage.com/hc/en-us/articles/204017483-France-SMS-Features-and-Restrictions
- Anthropic Claude Haiku pricing — https://www.anthropic.com/claude/haiku

### Secondary (MEDIUM confidence)
- Twilio WhatsApp pricing post-July 2025 — https://www.twilio.com/en-us/changelog/meta-is-updating-whatsapp-pricing-on-july-1--2025
- Multi-tenant n8n WhatsApp platform case study — https://dev.to/achiya-automation/how-i-built-a-multi-tenant-whatsapp-automation-platform-using-n8n-and-waha-4jj4
- Apten.ai speed-to-lead benchmarks — https://www.apten.ai/blog/speed-to-lead-ai-sales-automation-2025
- Callingly, Hatch, Setter.ai product pages (competitive reference)
- Railway vs Render for n8n — https://flowengine.cloud/blog/railway-vs-render-for-n8n-pricing-performance-and-real-world-considerations-in-2025

---
*Research completed: 2026-03-27*
*Ready for roadmap: yes*
