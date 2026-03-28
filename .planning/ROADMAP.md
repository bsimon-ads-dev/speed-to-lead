# Roadmap: Speed to Lead

## Overview

Three phases that build outward from the critical path. Phase 1 establishes the end-to-end lead response loop for one client — webhook to prospect SMS to owner notification — with all mandatory reliability and RGPD requirements embedded from day one. Phase 2 adds the follow-up scheduler and multi-tenant architecture that turn a prototype into a sellable recurring product. Phase 3 adds the WhatsApp channel and production hardening needed to grow the client base with confidence.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Critical Path** - Webhook to prospect SMS + owner notification, end-to-end, one client
- [ ] **Phase 2: Follow-up + Multi-tenant** - Configurable follow-up scheduler and shared Core Workflow for N clients
- [ ] **Phase 3: WhatsApp + Hardening** - WhatsApp channel for both branches and production reliability ops

## Phase Details

### Phase 1: Critical Path
**Goal**: A real Google Ads lead triggers a personalized AI response to the prospect and an actionable notification to the owner — in under 2 minutes — for one client
**Depends on**: Nothing (first phase)
**Requirements**: INGEST-01, INGEST-02, INGEST-03, INGEST-04, RESP-01, RESP-02, RESP-03, RESP-04, RESP-05, NOTIF-01, NOTIF-02, NOTIF-04
**Success Criteria** (what must be TRUE):
  1. A test lead submitted via Google Ads Lead Form webhook reaches n8n and is logged with its raw payload within seconds
  2. The prospect receives a personalized SMS within 2 minutes that reformulates their stated need and confirms a callback is coming — no prices, no promises, no hallucinated details
  3. The owner receives an SMS with the prospect's name, need, and phone number plus a one-tap `tel:` link to call back immediately
  4. Submitting the same `lead_id` twice results in exactly one message sent (deduplication works)
  5. If the Claude or Twilio call fails, Baptiste receives the raw lead data by SMS so no lead is silently dropped
**Plans**: 6 plans

Plans:
- [x] 01-01-PLAN.md — Test fixture library: 4 JSON payloads + shell test runner + testing guide
- [x] 01-02-PLAN.md — Project scaffold: client config JSON, n8n workflow skeletons, Claude prompt template
- [x] 01-03-PLAN.md — Ingestion layer: webhook (200 immediately) + raw log + google_key validation + dedup + field extraction
- [x] 01-04-PLAN.md — Error handler workflow: Error Trigger + fallback SMS to Baptiste via Twilio
- [ ] 01-05-PLAN.md — AI + channel dispatch: Claude API call + SMS truncation + Twilio prospect SMS + Brevo email
- [ ] 01-06-PLAN.md — Owner notification + wiring: owner SMS with tel: link + error workflow link + end-to-end verification

### Phase 2: Follow-up + Multi-tenant
**Goal**: The system automatically follows up with prospects the owner hasn't called back, and the same Core Workflow serves multiple clients without credential cross-contamination
**Depends on**: Phase 1
**Requirements**: NOTIF-03, CONF-01, CONF-02, CONF-03
**Success Criteria** (what must be TRUE):
  1. A second prospect message fires automatically after the configured delay if the owner has not called back — and does not fire outside 08:00–20:00 Mon–Sat
  2. Adding a second client requires only creating a new per-client JSON config and thin entry workflow — no changes to the Core Workflow
  3. Each client's Twilio credentials and Claude prompts are isolated; a misconfiguration for client A cannot cause a message to be sent on behalf of client B
  4. Each client has a unique webhook URL slug (e.g., `/webhook/dupont-plomberie`) and Baptiste can identify which client triggered each execution at a glance
**Plans**: TBD

### Phase 3: WhatsApp + Hardening
**Goal**: WhatsApp is available as a channel for both prospect messages and owner notifications, and the system is hardened for a growing client base with spend caps, uptime monitoring, and circuit breakers
**Depends on**: Phase 2
**Requirements**: (no unassigned v1 requirements — this phase delivers v2-adjacent hardening using CONF-01/02/03 multi-tenant infrastructure built in Phase 2)
**Success Criteria** (what must be TRUE):
  1. A client configured for WhatsApp has a prospect message sent via Twilio WABA using a pre-approved Meta utility template — free-form messages are never sent
  2. The owner notification is delivered via WhatsApp when their preferred channel is configured as WhatsApp
  3. UptimeRobot alerts Baptiste within 5 minutes if the n8n instance stops responding
  4. More than 5 executions for the same `lead_id` in 10 minutes triggers a halt and alert to Baptiste rather than sending repeated messages
**Plans**: TBD
**UI hint**: no

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Critical Path | 3/6 | In Progress|  |
| 2. Follow-up + Multi-tenant | 0/TBD | Not started | - |
| 3. WhatsApp + Hardening | 0/TBD | Not started | - |
