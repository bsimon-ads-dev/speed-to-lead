---
phase: 1
slug: critical-path
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-27
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | n8n manual test execution + curl webhook tests |
| **Config file** | n8n workflow JSON (exported) |
| **Quick run command** | `curl -X POST http://localhost:5678/webhook-test/{slug} -H "Content-Type: application/json" -d @test-lead.json` |
| **Full suite command** | Run all test scenarios via shell script |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Test webhook with curl
- **After every plan wave:** Full end-to-end test with all scenarios
- **Before `/gsd:verify-work`:** All 5 success criteria must pass
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Verification Method | Status |
|---------|------|------|-------------|-----------|---------------------|--------|
| 01-01 | 01 | 1 | INGEST-01 | integration | Webhook receives POST, n8n execution starts | ⬜ pending |
| 01-02 | 01 | 1 | INGEST-04 | integration | Invalid google_key → rejected | ⬜ pending |
| 01-03 | 01 | 1 | INGEST-03 | integration | Raw payload logged in execution data | ⬜ pending |
| 01-04 | 01 | 1 | INGEST-02 | integration | Duplicate lead_id → no second message | ⬜ pending |
| 01-05 | 01 | 1 | RESP-01 | integration | Claude generates personalized French message | ⬜ pending |
| 01-06 | 01 | 1 | RESP-02, RESP-03 | integration | SMS sent via Twilio OR email via Brevo | ⬜ pending |
| 01-07 | 01 | 1 | RESP-04 | manual | Prompt tone matches client business type | ⬜ pending |
| 01-08 | 01 | 1 | RESP-05 | timing | End-to-end < 2 minutes | ⬜ pending |
| 01-09 | 01 | 1 | NOTIF-01, NOTIF-02 | integration | Owner gets SMS with name, need, tel: link | ⬜ pending |
| 01-10 | 01 | 1 | NOTIF-04 | integration | Pipeline failure → Baptiste gets raw lead | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test-lead.json` — sample Google Ads Lead Form payload for testing
- [ ] `test-lead-duplicate.json` — same lead_id for dedup testing
- [ ] `test-lead-email-only.json` — lead with email but no phone (Brevo fallback)
- [ ] Test script for running all scenarios sequentially
