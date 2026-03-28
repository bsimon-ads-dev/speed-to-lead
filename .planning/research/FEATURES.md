# Feature Landscape: Speed-to-Lead Automation

**Domain:** Lead response automation for local service SMEs (Google Ads Lead Forms)
**Researched:** 2026-03-27
**Competitive reference:** Callingly, Hatch, Setter.ai, Respond.io, GoHighLevel, Apten.ai

---

## Table Stakes

Features that users (and the businesses they serve) expect as a baseline. Missing any of these makes the product feel broken or unreliable.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Sub-5-minute first response to prospect | Industry benchmark: 100x more likely to connect vs. 30-min delay; 35-50% of sales go to first responder | Low | Our target is <2 min. Every competitor leads with this stat. |
| Automated first message to prospect (SMS/WhatsApp/email) | Prospect expects acknowledgment before the business calls back | Low | Content must feel human, not robotic. Generic template is table stakes; AI personalization is differentiating. |
| 24/7 coverage (including nights and weekends) | 41% of local service jobs are booked after hours; leads at 3am must be handled | Low | Handled natively by n8n cloud/self-hosted — no on-call needed. |
| Owner/operator notification with lead details | The business owner is on the field, not at a desk — they must be reached where they are (SMS/WhatsApp) | Low | All competitors do this. Failure to notify promptly = lead wasted despite automation. |
| Direct callback action from notification | Owner must be able to call or WhatsApp prospect in one tap from the notification | Low | `tel:` link or wa.me deep link in the notification message body. |
| Automated follow-up if owner doesn't call back | A lead that isn't called back within a configurable window gets a second message from the AI | Medium | Configurable delay (e.g., 30 min). This is the core "no lead left behind" loop. |
| Google Ads Lead Form webhook ingestion | Source of truth for all leads in v1 — native webhook via Google Ads is real-time and free | Low | Google sends HTTP POST in JSON format; lead_id must be used to deduplicate (Google may send duplicates). |
| Per-client configuration | Business name, service type, response channels, follow-up delays — must be customizable per client | Low | No client should share config with another. n8n workflow params per webhook endpoint. |
| Duplicate lead handling | Google does not guarantee exactly-once delivery — same lead_id may arrive twice | Low | Deduplicate on lead_id before triggering any message. |
| Graceful failure / error handling | If Claude API or SMS gateway is down, the workflow must not silently drop the lead | Medium | Fallback: send raw lead data to owner even if AI message fails. Alert Baptiste if failure detected. |

---

## Differentiators

Features that separate this product from a generic template-based autoresponder. These create competitive advantage and justify the pricing.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| AI-personalized first message (Claude API) | Reformulates the prospect's specific request back to them — "on m'a bien écouté" effect increases callback rate | Medium | Requires well-crafted system prompt per vertical (plumber, dentist, lawyer, coach). Template tools (Callingly, GoHighLevel) cannot do this natively. |
| Vertical-aware message tone | A dentist's response feels different from a plumber's — adapts formality, vocabulary, urgency | Medium | Controlled via Claude system prompt with vertical context. Requires prompt engineering per vertical archetype. |
| Smart channel selection based on available data | Phone number → SMS first, then WhatsApp; email-only → email. No hardcoded channel logic | Low-Medium | Lead Form may contain phone, email, or both. Priority logic: WhatsApp > SMS > email, depending on what the business uses. |
| Owner notification with pre-formatted lead summary | Owner receives a single message with name, need, phone number, and a call-to-action link — zero reading required | Low | Formatting matters here: busy tradesperson should be able to act in 10 seconds. |
| Configurable follow-up window per client | Some clients want 15-min follow-up, others 1 hour — not all businesses have the same call cadence | Low | Single n8n config variable per client webhook. |
| Zero-interface for the business owner | No app, no login, no dashboard — the owner never touches the tool. All action happens via their existing phone | Low | This is a deliberate anti-CRM positioning. Competitors like Hatch and Respond.io require the business to engage with a UI. |
| Setup-and-forget model | Baptiste configures once, client pays monthly, nothing breaks without notice | Medium | Requires reliable error alerting back to Baptiste, not to the client. |

---

## Anti-Features

Features to explicitly NOT build — either because they destroy the value proposition, add complexity without ROI, or target the wrong user.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Dashboard / reporting UI for clients | SME owners in local services don't want another tool to log into. Hatch and Respond.io require this — it increases churn and support burden | Offer a monthly summary by email or WhatsApp from Baptiste, manually or as a future add-on |
| CRM for lead tracking | Explicitly out of scope in PROJECT.md. Adds weeks of build time and zero perceived value to a plumber | If a client eventually wants CRM, route to Pipedrive/HubSpot via Zapier as a separate engagement |
| Multi-step lead nurture sequences (J+1, J+3, J+7) | Requires conversation state management, opt-out tracking, RGPD compliance — v2 complexity | Build the single follow-up (owner didn't call back) cleanly in v1. Multi-sequence is a separate paid add-on. |
| AI conversation / chatbot with the prospect | Two-way AI dialogue requires intent parsing, reply handling, fallback logic — doubles complexity with marginal v1 gain | First message is one-way: acknowledge + set callback expectation. Human (the owner) takes over on callback. |
| Inbound call handling / IVR | Different infrastructure (Twilio Voice, Vapi, etc.), different use case — not triggered by Google Ads Lead Forms | Explicitly out of scope in PROJECT.md |
| Lead scoring / qualification filtering | No data to score at lead form submission time (no behavior signal, just form fields) | Claude can flag obvious spam/test leads via heuristics (e.g., "Test" name, invalid phone format) |
| White-label SaaS with client self-service | Building multi-tenant SaaS is a different product entirely — requires auth, billing, tenant isolation | Baptiste configures manually per client. This is a concierge model, not a platform. |
| Custom landing pages or forms | Adds scope, reduces focus — Google Ads Lead Forms are the wedge | If a client needs a website form, that's a separate web project |
| Appointment booking via the bot | Requires calendar integration (Calendly, Cal.com), availability logic — high complexity for marginal v1 gain | Owner books the appointment during the callback phone call |

---

## Feature Dependencies

```
Google Ads Lead Form webhook
  └── Duplicate detection (lead_id dedup)
        └── AI message generation (Claude API)
              ├── Channel selection (phone? email? both?)
              │     ├── SMS send (prospect)
              │     ├── WhatsApp send (prospect)
              │     └── Email send (prospect)
              └── Owner notification (SMS/WhatsApp)
                    └── Follow-up trigger (timer after notification)
                          └── Follow-up message to prospect (if owner hasn't acted)

Error handling wraps the entire chain:
  └── On any failure: raw lead data sent to Baptiste via alert channel
```

**Critical path:** Webhook → Dedup → Claude → Prospect message + Owner notification

The follow-up is a secondary branch — it can be built after the critical path is validated.

---

## MVP Recommendation

**Prioritize (must ship to validate the core value):**
1. Google Ads webhook ingestion with dedup
2. Claude-generated personalized first message to prospect (SMS or email based on available data)
3. Owner notification with lead summary + one-tap callback link
4. Basic error fallback (raw lead data to Baptiste if anything breaks)

**Build second (completes the "no lead left behind" promise):**
5. Automated follow-up to prospect when owner hasn't called back within configurable window

**Defer:**
- Multi-channel smart routing (WhatsApp vs SMS): start with SMS/email in v1, add WhatsApp in v2 once Twilio/WABA is validated
- Vertical-specific prompt tuning: start with one or two verticals, expand after first client feedback
- Reporting: not needed until clients ask — and they probably won't

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Table stakes features | HIGH | Consistent across Callingly, Hatch, Setter.ai, Apten.ai, GoHighLevel documentation |
| Differentiators (AI personalization) | HIGH | Clear gap vs. template-based tools; confirmed via product pages and user reviews |
| Anti-features | MEDIUM | Based on PROJECT.md explicit out-of-scope + market pattern analysis; not empirically validated with Baptiste's clients yet |
| Google Ads webhook behavior (dedup) | HIGH | Official Google Ads Webhook docs confirm duplicate delivery is possible and lead_id is the dedup key |
| Channel priority logic | MEDIUM | Based on PROJECT.md constraints (phone → SMS/WhatsApp, email → email); actual client preference to validate in v1 |

---

## Sources

- [Callingly Speed to Lead](https://callingly.com/benefits/speed-to-lead/) — Callingly product page
- [Callingly Intelligent Lead Routing](https://callingly.com/benefits/intelligent-lead-routing/) — Routing feature details
- [Hatch — AI Voice, SMS and Email](https://www.usehatchapp.com/) — Hatch product overview
- [Setter AI](https://www.trysetter.com/) — Setter.ai lead follow-up automation
- [Apten.ai — Speed to Lead AI in 2025](https://www.apten.ai/blog/speed-to-lead-ai-sales-automation-2025) — Table stakes vs. differentiators analysis
- [Google Ads Lead Form Webhook Overview](https://developers.google.com/google-ads/webhook/docs/overview) — Official Google Ads webhook documentation
- [Google Ads Lead Form Webhook Implementation](https://developers.google.com/google-ads/webhook/docs/implementation) — Technical implementation including dedup requirements
- [SuperAGI — Top 10 Speed-to-Lead Tools 2025](https://superagi.com/top-10-speed-to-lead-automation-tools-of-2025-a-comprehensive-comparison-and-review/) — Market overview
- [Respond.io WhatsApp Lead Management](https://respond.io/blog/whatsapp-lead-management) — Multi-channel lead management patterns
- [GoHighLevel Lead Management Guide](https://theloadedlab.com/lead-management-in-gohighlevel-a-complete-guide-for-2025/) — GHL automation feature reference
