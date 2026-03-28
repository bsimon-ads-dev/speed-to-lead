---
phase: 3
slug: whatsapp-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-28
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | n8n JSON structural checks + curl webhook tests + manual WABA verification |
| **Config file** | n8n workflow JSON (exported) |
| **Quick run command** | `node -e "..." < workflows/speed-to-lead-core.json` |
| **Full suite command** | Run all Phase 3 structural checks + manual WhatsApp test |
| **Estimated runtime** | ~10 seconds (automated), manual for WhatsApp + UptimeRobot |

---

## Sampling Rate

- **After every task commit:** Run structural JSON verify command from plan
- **After every plan wave:** Full structural checks on all modified workflow files
- **Before `/gsd:verify-work`:** All 4 success criteria must pass
- **Max feedback latency:** 10 seconds (automated checks)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Test Type | Automated Command | Status |
|---------|------|------|-----------|-------------------|--------|
| 03-01-01 | 01 | 1 | structural | `node -e` JSON field checks on configs | ⬜ pending |
| 03-01-02 | 01 | 1 | structural | `node -e` circuit breaker node + connections check | ⬜ pending |
| 03-02-01 | 02 | 2 | structural | `node -e` WhatsApp nodes ContentSid check, no Body | ⬜ pending |
| 03-02-02 | 02 | 2 | structural | `node -e` entry workflow whatsapp fields check | ⬜ pending |
| 03-03-01 | 03 | 1 | structural | `grep -c "Phase 3" tests/TESTING.md` | ⬜ pending |
| 03-03-02 | 03 | 1 | manual | UptimeRobot dashboard — cannot automate | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Phase 1 + 2 workflows deployed and functional in n8n
- [ ] Twilio WABA number registered (or sandbox for testing)
- [ ] Meta utility template submitted for approval
