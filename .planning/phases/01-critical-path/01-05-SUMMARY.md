---
phase: 01-critical-path
plan: 05
subsystem: api
tags: [claude, anthropic, twilio, brevo, sms, email, n8n, ai]

# Dependency graph
requires:
  - phase: 01-critical-path plan 03
    provides: Code: Extract Lead Fields node outputting phone, email, name, request, lead_id fields
provides:
  - HTTP Request: Claude API node calling claude-haiku-4-5 with embedded French SMS prompt
  - Code: Truncate SMS to 155 chars node parsing Claude response and carrying all lead fields
  - IF: phone available? routing node (TRUE→Twilio, FALSE→Brevo)
  - HTTP Request: Twilio SMS (Prospect) using alphanumeric TWILIO_SENDER_ID
  - Brevo: Send Email (Prospect) sending claude_message as HTML
affects: [01-06-owner-notification, testing, deployment]

# Tech tracking
tech-stack:
  added: [Anthropic Messages API, Twilio REST API SMS, Brevo transactional email]
  patterns:
    - Claude HTTP Request uses genericCredentialType httpHeaderAuth with x-api-key header
    - Twilio uses HTTP Request node (not built-in Twilio node) for alphanumeric A2P sender support
    - System prompt embeds env var references resolved by n8n at runtime before sending to Claude
    - Prospect input wrapped in XML tags for prompt injection protection

key-files:
  created: []
  modified:
    - workflows/speed-to-lead-main.json

key-decisions:
  - "Use HTTP Request node for Twilio (not built-in Twilio node) — alphanumeric sender ID required for France A2P, built-in node only supports E.164"
  - "System prompt from prompts/prospect-sms-fr.txt embedded verbatim in workflow JSON — n8n resolves $env vars at runtime before POST to Anthropic"
  - "Truncate at 155 chars (not 160) — 5-char safety margin for encoding variations"
  - "prospect_input XML tag wrapping prevents prompt injection from malicious lead form submissions"

patterns-established:
  - "Pattern: Claude API call uses genericCredentialType httpHeaderAuth, not Anthropic node — avoids credential type mismatch"
  - "Pattern: Code node after AI call carries all upstream lead fields forward so IF/downstream nodes have full context"

requirements-completed: [RESP-01, RESP-02, RESP-03, RESP-04, RESP-05]

# Metrics
duration: 2min
completed: 2026-03-28
---

# Phase 01 Plan 05: AI Layer and Prospect Channel Dispatch Summary

**Claude haiku-4-5 generates personalized French SMS from lead request, truncated to 155 chars, then routed to Twilio alphanumeric SMS or Brevo email based on phone availability**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-28T14:02:26Z
- **Completed:** 2026-03-28T14:04:04Z
- **Tasks:** 2 auto + 1 checkpoint (auto-approved)
- **Files modified:** 1

## Accomplishments
- Claude HTTP Request node fully implemented: calls api.anthropic.com/v1/messages with claude-haiku-4-5, max_tokens 200, embedded French SMS prompt, prospect data in XML tags, ANTHROPIC_API_KEY env var
- Truncation Code node parses content[0].text, truncates to 155 chars with ellipsis, and carries all lead fields (phone, email, name, request, claude_message, claude_raw) forward
- IF routing node uses isNotEmpty operator on $json.phone — TRUE branch sends Twilio SMS, FALSE branch sends Brevo email
- Twilio Prospect node uses HTTP Request (not built-in Twilio node) to support alphanumeric sender ID for France A2P registration
- Brevo email node wraps claude_message in HTML with business name footer for email-only leads

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement Claude API call and SMS truncation** - `ad85357` (feat)
2. **Task 2: Implement phone/email routing, Twilio SMS, and Brevo email** - `8003097` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `workflows/speed-to-lead-main.json` - Claude API node, truncation node, IF routing, Twilio prospect, Brevo email — all fully implemented

## Decisions Made
- Used HTTP Request node for Twilio instead of built-in Twilio node. The built-in node only accepts E.164 From numbers; France A2P requires an alphanumeric sender ID pre-registered with carriers. HTTP Request with httpBasicAuth gives full control over the From parameter.
- System prompt embedded verbatim in workflow JSON body field (not referenced by path). n8n resolves `{{ $env.* }}` expressions inside the JSON body string at runtime before sending the HTTP request to Anthropic. This means BUSINESS_NAME, SERVICE_TYPE, CITY, CALLBACK_MINUTES are client-specific values without any additional lookup node.
- `<prospect_input>` XML tag wrapping around the user message prevents prompt injection if a malicious actor submits a lead form with instructions designed to override the system prompt.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

Before testing, the following n8n credentials must be created:

1. **HTTP Header Auth** for Anthropic Claude API node — Header name: `x-api-key`, Value: your Anthropic API key
2. **Basic Auth** for Twilio HTTP Request node — Username: TWILIO_ACCOUNT_SID value, Password: TWILIO_AUTH_TOKEN value
3. **Brevo API** credential for Brevo email node — API key from app.brevo.com > Settings > API Keys

Environment variables required in n8n:
- `ANTHROPIC_API_KEY` — Anthropic API key
- `TWILIO_ACCOUNT_SID` — Twilio Account SID
- `TWILIO_AUTH_TOKEN` — Twilio Auth Token
- `TWILIO_SENDER_ID` — Alphanumeric sender ID (pre-registered in France)
- `BREVO_SENDER_EMAIL` — Verified sender email in Brevo
- `BUSINESS_NAME` — Client business name (e.g., "Dupont Plomberie")
- `SERVICE_TYPE` — Client service type (e.g., "plombier")
- `CITY` — Client city (e.g., "Paris")
- `CALLBACK_MINUTES` — Callback promise in minutes (e.g., "30")

## Next Phase Readiness
- Plan 06 (owner notification) can proceed: Code: Format Owner Notification and HTTP Request: Twilio SMS (Owner) nodes are already in the workflow as stubs, connected after the Twilio Prospect node
- The `claude_message` and all lead fields (phone, email, name, request, lead_id) are available at the owner notification node
- Full end-to-end test (Plans 01+03+05+06) possible after Plan 06 completes

---
*Phase: 01-critical-path*
*Completed: 2026-03-28*
