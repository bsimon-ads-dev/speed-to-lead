# WhatsApp Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all Twilio SMS/WhatsApp nodes with native n8n WhatsApp Business Cloud nodes, redirect error notifications to the client (owner_phone) instead of Baptiste, and update all configs accordingly.

**Architecture:** Same multi-tenant architecture (entry workflows → core workflow → error handler). Twilio HTTP Request nodes replaced by n8n native WhatsApp Business Cloud nodes. Brevo email fallback unchanged. Error handler sends to owner_phone instead of BAPTISTE_PHONE.

**Tech Stack:** n8n (WhatsApp Business Cloud node), WhatsApp Cloud API (Meta), Brevo Free (email), Claude Haiku 4.5 (Anthropic)

**Spec:** `docs/superpowers/specs/2026-03-29-whatsapp-migration-design.md`

---

### Task 1: Update config files — remove Twilio, add WhatsApp Cloud API

**Files:**
- Modify: `config/dupont-plomberie.json`
- Modify: `config/cabinet-martin.json`

- [ ] **Step 1: Update `config/dupont-plomberie.json`**

Replace the entire file with:

```json
{
  "client_slug": "dupont-plomberie",
  "business_name": "Dupont Plomberie",
  "service_type": "plombier",
  "city": "Paris",
  "owner_phone": "+33600000000",
  "owner_email": "contact@dupont-plomberie.fr",
  "brevo_sender_email": "no-reply@dupont-plomberie.fr",
  "callback_promise_minutes": 30,
  "follow_up_delay_minutes": 45,
  "follow_up_enabled": true,
  "active": true,
  "wa_templates": {
    "confirm": "lead_confirm_fr",
    "owner_notify": "lead_owner_notify_fr",
    "followup": "lead_followup_fr",
    "error": "lead_error_notify_fr"
  },
  "env_vars_required": {
    "DUPONT_GOOGLE_KEY": "Shared secret from Google Ads Lead Form settings",
    "DUPONT_WA_PHONE_NUMBER_ID": "WhatsApp phone number ID from Meta Business Manager",
    "DUPONT_WA_ACCESS_TOKEN": "Permanent System User token from Meta Business Manager",
    "DUPONT_OWNER_PHONE": "Owner mobile in E.164 format (e.g. +33612345678)",
    "DUPONT_WEBHOOK_SECRET": "Secret for WordPress webhook validation",
    "ANTHROPIC_API_KEY": "Shared — from console.anthropic.com",
    "BREVO_API_KEY": "Shared — from app.brevo.com"
  },
  "RGPD": "Pre-launch: Lead Form must include consent checkbox"
}
```

- [ ] **Step 2: Update `config/cabinet-martin.json`**

Replace the entire file with:

```json
{
  "client_slug": "cabinet-martin",
  "business_name": "Cabinet Martin Avocats",
  "service_type": "avocat",
  "city": "Lyon",
  "owner_phone": "+33600000001",
  "owner_email": "contact@cabinet-martin.fr",
  "brevo_sender_email": "no-reply@cabinet-martin.fr",
  "callback_promise_minutes": 60,
  "follow_up_delay_minutes": 120,
  "follow_up_enabled": true,
  "active": true,
  "wa_templates": {
    "confirm": "lead_confirm_fr",
    "owner_notify": "lead_owner_notify_fr",
    "followup": "lead_followup_fr",
    "error": "lead_error_notify_fr"
  },
  "env_vars_required": {
    "MARTIN_GOOGLE_KEY": "Shared secret from Google Ads Lead Form settings",
    "MARTIN_WA_PHONE_NUMBER_ID": "WhatsApp phone number ID from Meta Business Manager",
    "MARTIN_WA_ACCESS_TOKEN": "Permanent System User token from Meta Business Manager",
    "MARTIN_OWNER_PHONE": "Owner mobile in E.164 format",
    "MARTIN_WEBHOOK_SECRET": "Secret for WordPress webhook validation",
    "ANTHROPIC_API_KEY": "Shared — from console.anthropic.com",
    "BREVO_API_KEY": "Shared — from app.brevo.com"
  },
  "RGPD": "Pre-launch: Lead Form must include consent checkbox"
}
```

- [ ] **Step 3: Commit**

```bash
git add config/dupont-plomberie.json config/cabinet-martin.json
git commit -m "config: replace Twilio with WhatsApp Cloud API credentials"
```

---

### Task 2: Update entry workflow — Dupont Plomberie

**Files:**
- Modify: `workflows/speed-to-lead-entry-dupont-plomberie.json`

- [ ] **Step 1: Update the "Code: Assemble Client Config" node**

In the workflow JSON, find the Code node that assembles the client config object. Replace the JavaScript code inside it with:

```javascript
const lead = $input.first().json;

return {
  json: {
    ...lead,
    client_config: {
      client_slug: 'dupont-plomberie',
      business_name: 'Dupont Plomberie',
      service_type: 'plombier',
      city: 'Paris',
      owner_phone: $env.DUPONT_OWNER_PHONE || '+33600000000',
      owner_email: 'contact@dupont-plomberie.fr',
      brevo_sender_email: 'no-reply@dupont-plomberie.fr',
      callback_promise_minutes: 30,
      follow_up_delay_minutes: 45,
      follow_up_enabled: true,
      wa_phone_number_id: $env.DUPONT_WA_PHONE_NUMBER_ID,
      wa_access_token: $env.DUPONT_WA_ACCESS_TOKEN,
      wa_confirm_template: 'lead_confirm_fr',
      wa_owner_template: 'lead_owner_notify_fr',
      wa_followup_template: 'lead_followup_fr',
      wa_error_template: 'lead_error_notify_fr'
    }
  }
};
```

- [ ] **Step 2: Remove setup notes referencing Twilio credentials**

In the workflow JSON, find any `_setup_notes` fields that mention Twilio and remove them. Add a new setup note:

```json
"_setup_notes": "Post-import: 1) Select Core Workflow ID in Execute node. 2) Set env vars: DUPONT_WA_PHONE_NUMBER_ID, DUPONT_WA_ACCESS_TOKEN, DUPONT_OWNER_PHONE, DUPONT_GOOGLE_KEY, DUPONT_WEBHOOK_SECRET"
```

- [ ] **Step 3: Commit**

```bash
git add workflows/speed-to-lead-entry-dupont-plomberie.json
git commit -m "feat(entry-dupont): replace Twilio config with WhatsApp Cloud API"
```

---

### Task 3: Update entry workflow — Cabinet Martin

**Files:**
- Modify: `workflows/speed-to-lead-entry-cabinet-martin.json`

- [ ] **Step 1: Update the "Code: Assemble Client Config" node**

Replace the JavaScript code with:

```javascript
const lead = $input.first().json;

return {
  json: {
    ...lead,
    client_config: {
      client_slug: 'cabinet-martin',
      business_name: 'Cabinet Martin Avocats',
      service_type: 'avocat',
      city: 'Lyon',
      owner_phone: $env.MARTIN_OWNER_PHONE || '+33600000001',
      owner_email: 'contact@cabinet-martin.fr',
      brevo_sender_email: 'no-reply@cabinet-martin.fr',
      callback_promise_minutes: 60,
      follow_up_delay_minutes: 120,
      follow_up_enabled: true,
      wa_phone_number_id: $env.MARTIN_WA_PHONE_NUMBER_ID,
      wa_access_token: $env.MARTIN_WA_ACCESS_TOKEN,
      wa_confirm_template: 'lead_confirm_fr',
      wa_owner_template: 'lead_owner_notify_fr',
      wa_followup_template: 'lead_followup_fr',
      wa_error_template: 'lead_error_notify_fr'
    }
  }
};
```

- [ ] **Step 2: Update setup notes**

```json
"_setup_notes": "Post-import: 1) Select Core Workflow ID in Execute node. 2) Set env vars: MARTIN_WA_PHONE_NUMBER_ID, MARTIN_WA_ACCESS_TOKEN, MARTIN_OWNER_PHONE, MARTIN_GOOGLE_KEY, MARTIN_WEBHOOK_SECRET"
```

- [ ] **Step 3: Commit**

```bash
git add workflows/speed-to-lead-entry-cabinet-martin.json
git commit -m "feat(entry-martin): replace Twilio config with WhatsApp Cloud API"
```

---

### Task 4: Rewrite Core Workflow — replace Twilio nodes with WhatsApp native nodes

This is the biggest task. We replace 6 Twilio HTTP Request nodes with WhatsApp Business Cloud native n8n nodes, remove the WhatsApp/SMS branching (everything is WhatsApp now), and redirect circuit breaker alerts to owner_phone.

**Files:**
- Modify: `workflows/speed-to-lead-core.json`

- [ ] **Step 1: Remove the WhatsApp/SMS branching nodes**

Delete these nodes from the JSON:
- `node-wa-if-prospect` (IF: whatsapp_enabled for prospect)
- `node-wa-prospect` (Twilio WhatsApp to prospect)
- `node-twilio-prospect` (Twilio SMS to prospect)
- `node-wa-if-owner` (IF: whatsapp_enabled for owner)
- `node-wa-owner` (Twilio WhatsApp to owner)
- `node-twilio-owner` (Twilio SMS to owner)
- `node-twilio-followup` (Twilio SMS follow-up)
- `node-cb-alert` (Twilio SMS circuit breaker alert)

Also remove all connections referencing these node IDs from the `connections` object.

- [ ] **Step 2: Add WhatsApp prospect confirmation node**

Add this node to the `nodes` array (replaces `node-twilio-prospect` and `node-wa-prospect`):

```json
{
  "id": "node-wa-prospect",
  "name": "WhatsApp: Confirmation Prospect",
  "type": "n8n-nodes-base.whatsApp",
  "typeVersion": 1,
  "position": [1780, 220],
  "parameters": {
    "resource": "message",
    "operation": "sendTemplate",
    "phoneNumberId": "={{ $json.client_config.wa_phone_number_id }}",
    "recipientPhoneNumber": "={{ $json.phone }}",
    "templateName": "={{ $json.client_config.wa_confirm_template }}",
    "language": "fr",
    "templateParameters": {
      "parameters": [
        {
          "type": "body",
          "componentParameters": [
            { "parameterType": "text", "textValue": "={{ $json.name.split(' ')[0] }}" },
            { "parameterType": "text", "textValue": "={{ $json.claude_message }}" },
            { "parameterType": "text", "textValue": "={{ $json.client_config.callback_promise_minutes }}" },
            { "parameterType": "text", "textValue": "={{ $json.client_config.business_name }}" }
          ]
        }
      ]
    }
  },
  "credentials": {
    "whatsAppApi": {
      "id": "REPLACE_WITH_CREDENTIAL_ID",
      "name": "WhatsApp Business Cloud"
    }
  }
}
```

**Note:** n8n's WhatsApp Business Cloud node uses credential-level `accessToken` and `businessAccountId`. The `phoneNumberId` is set per-node via expression. Since each client may have a different phone number, the credential stores the shared access token and the `phoneNumberId` comes from `client_config`.

However, if clients have separate access tokens, we need to use HTTP Request nodes instead of the native node (native node uses a single credential). Let's use HTTP Request nodes calling the Meta Graph API directly — this gives us per-client token flexibility.

**Revised approach:** Replace Twilio HTTP Request nodes with Meta Graph API HTTP Request nodes.

Replace the node above with:

```json
{
  "id": "node-wa-prospect",
  "name": "WhatsApp: Confirmation Prospect",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [1780, 220],
  "parameters": {
    "method": "POST",
    "url": "=https://graph.facebook.com/v22.0/{{ $json.client_config.wa_phone_number_id }}/messages",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $json.client_config.wa_access_token }}"
        }
      ]
    },
    "sendBody": true,
    "contentType": "json",
    "body": {
      "json": {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "={{ $json.phone }}",
        "type": "template",
        "template": {
          "name": "={{ $json.client_config.wa_confirm_template }}",
          "language": { "code": "fr" },
          "components": [
            {
              "type": "body",
              "parameters": [
                { "type": "text", "text": "={{ $json.name.split(' ')[0] }}" },
                { "type": "text", "text": "={{ $json.claude_message }}" },
                { "type": "text", "text": "={{ String($json.client_config.callback_promise_minutes) }}" },
                { "type": "text", "text": "={{ $json.client_config.business_name }}" }
              ]
            }
          ]
        }
      }
    }
  }
}
```

- [ ] **Step 3: Add WhatsApp owner notification node**

Add this node (replaces `node-twilio-owner` and `node-wa-owner`):

```json
{
  "id": "node-wa-owner",
  "name": "WhatsApp: Notification Dirigeant",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [2220, 220],
  "parameters": {
    "method": "POST",
    "url": "=https://graph.facebook.com/v22.0/{{ $json.client_config.wa_phone_number_id }}/messages",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $json.client_config.wa_access_token }}"
        }
      ]
    },
    "sendBody": true,
    "contentType": "json",
    "body": {
      "json": {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "={{ $json.client_config.owner_phone }}",
        "type": "template",
        "template": {
          "name": "={{ $json.client_config.wa_owner_template }}",
          "language": { "code": "fr" },
          "components": [
            {
              "type": "body",
              "parameters": [
                { "type": "text", "text": "={{ $json.name }}" },
                { "type": "text", "text": "={{ $json.owner_request_summary }}" },
                { "type": "text", "text": "={{ $json.phone || $json.email }}" }
              ]
            }
          ]
        }
      }
    }
  }
}
```

- [ ] **Step 4: Add WhatsApp follow-up node**

Add this node (replaces `node-twilio-followup`):

```json
{
  "id": "node-wa-followup",
  "name": "WhatsApp: Relance Prospect",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [3100, 140],
  "parameters": {
    "method": "POST",
    "url": "=https://graph.facebook.com/v22.0/{{ $json.client_config.wa_phone_number_id }}/messages",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $json.client_config.wa_access_token }}"
        }
      ]
    },
    "sendBody": true,
    "contentType": "json",
    "body": {
      "json": {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "={{ $json.phone }}",
        "type": "template",
        "template": {
          "name": "={{ $json.client_config.wa_followup_template }}",
          "language": { "code": "fr" },
          "components": [
            {
              "type": "body",
              "parameters": [
                { "type": "text", "text": "={{ $json.name.split(' ')[0] }}" },
                { "type": "text", "text": "={{ $json.client_config.business_name }}" }
              ]
            }
          ]
        }
      }
    }
  }
}
```

- [ ] **Step 5: Add WhatsApp circuit breaker alert node (to owner, not Baptiste)**

Add this node (replaces `node-cb-alert`):

```json
{
  "id": "node-cb-alert",
  "name": "WhatsApp: Alerte Circuit Breaker",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [680, 100],
  "parameters": {
    "method": "POST",
    "url": "=https://graph.facebook.com/v22.0/{{ $json.client_config.wa_phone_number_id }}/messages",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $json.client_config.wa_access_token }}"
        }
      ]
    },
    "sendBody": true,
    "contentType": "json",
    "body": {
      "json": {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "={{ $json.client_config.owner_phone }}",
        "type": "template",
        "template": {
          "name": "={{ $json.client_config.wa_error_template }}",
          "language": { "code": "fr" },
          "components": [
            {
              "type": "body",
              "parameters": [
                { "type": "text", "text": "Circuit breaker" },
                { "type": "text", "text": "=Trop de leads identiques détectés (lead_id: {{ $json.lead_id }})" },
                { "type": "text", "text": "Vérifiez votre formulaire" }
              ]
            }
          ]
        }
      }
    }
  }
}
```

- [ ] **Step 6: Update connections**

Simplify the connections — remove the WhatsApp/SMS branching IF nodes. The new flow is:

```
node-route-channel (IF: phone?)
  ├─ true  → node-wa-prospect → node-owner-format → node-wa-owner → node-wait-followup → node-biz-hours → node-if-biz-hours
  │                                                                                                          ├─ true  → node-wa-followup
  │                                                                                                          └─ false → node-log-followup-skipped
  └─ false → node-brevo-email → node-owner-format (merge)

node-cb-if (IF: circuit breaker tripped?)
  ├─ true  → node-cb-alert (WhatsApp to owner)
  └─ false → node-log-raw (continue pipeline)
```

Update the `connections` object in the JSON accordingly. Remove all entries for deleted nodes (`node-wa-if-prospect`, `node-wa-if-owner`, `node-twilio-prospect`, `node-twilio-owner`, `node-twilio-followup`).

- [ ] **Step 7: Remove BAPTISTE_PHONE references**

Search the workflow JSON for any reference to `BAPTISTE_PHONE` or `$env.BAPTISTE_PHONE` and remove them.

- [ ] **Step 8: Commit**

```bash
git add workflows/speed-to-lead-core.json
git commit -m "feat(core): replace Twilio with WhatsApp Cloud API, redirect alerts to owner"
```

---

### Task 5: Rewrite Error Handler — send to owner instead of Baptiste

**Files:**
- Modify: `workflows/speed-to-lead-error-handler.json`

- [ ] **Step 1: Replace the Twilio SMS fallback node**

Replace the Twilio HTTP Request node with a WhatsApp Cloud API HTTP Request node. The error handler needs access to `client_config` from the failed workflow's staticData. Update the "Code: Format Fallback" node to also extract `client_config`:

```javascript
const staticData = $getWorkflowStaticData('global');
const lastLead = staticData.lastLead || {};
const clientConfig = lastLead.client_config || {};
const errorInfo = $input.first().json;

const name = lastLead.name || 'Inconnu';
const phone = lastLead.phone || lastLead.email || 'N/A';
const request = (lastLead.message || lastLead.request || 'N/A').substring(0, 80);

return {
  json: {
    owner_phone: clientConfig.owner_phone || '',
    wa_phone_number_id: clientConfig.wa_phone_number_id || '',
    wa_access_token: clientConfig.wa_access_token || '',
    wa_error_template: clientConfig.wa_error_template || 'lead_error_notify_fr',
    name,
    phone,
    request,
    has_wa_config: !!(clientConfig.owner_phone && clientConfig.wa_phone_number_id && clientConfig.wa_access_token)
  }
};
```

- [ ] **Step 2: Replace the Twilio SMS node with WhatsApp HTTP Request**

Replace the existing Twilio node with:

```json
{
  "id": "node-error-wa",
  "name": "WhatsApp: Erreur au Dirigeant",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [680, 300],
  "parameters": {
    "method": "POST",
    "url": "=https://graph.facebook.com/v22.0/{{ $json.wa_phone_number_id }}/messages",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $json.wa_access_token }}"
        }
      ]
    },
    "sendBody": true,
    "contentType": "json",
    "body": {
      "json": {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "={{ $json.owner_phone }}",
        "type": "template",
        "template": {
          "name": "={{ $json.wa_error_template }}",
          "language": { "code": "fr" },
          "components": [
            {
              "type": "body",
              "parameters": [
                { "type": "text", "text": "={{ $json.name }}" },
                { "type": "text", "text": "={{ $json.request }}" },
                { "type": "text", "text": "={{ $json.phone }}" }
              ]
            }
          ]
        }
      }
    }
  }
}
```

- [ ] **Step 3: Add IF node to check WhatsApp config is available**

Before the WhatsApp node, add an IF node that checks `$json.has_wa_config`. If false (no config in staticData), the error is silently logged — we can't notify anyone if we don't know who to notify.

```json
{
  "id": "node-error-if-config",
  "name": "IF: Config disponible ?",
  "type": "n8n-nodes-base.if",
  "typeVersion": 2,
  "position": [480, 300],
  "parameters": {
    "conditions": {
      "options": { "caseSensitive": true, "leftValue": "" },
      "conditions": [
        {
          "leftValue": "={{ $json.has_wa_config }}",
          "rightValue": true,
          "operator": { "type": "boolean", "operation": "equals" }
        }
      ]
    }
  }
}
```

Update connections: Error Trigger → Format Fallback → IF Config → (true: WhatsApp) / (false: end)

- [ ] **Step 4: Remove all BAPTISTE_PHONE and Twilio references**

Remove any `BAPTISTE_PHONE` env var references and Twilio credential references from the workflow JSON.

- [ ] **Step 5: Commit**

```bash
git add workflows/speed-to-lead-error-handler.json
git commit -m "feat(error-handler): notify owner via WhatsApp instead of Baptiste via Twilio"
```

---

### Task 6: Rewrite Standalone Workflow (WordPress)

**Files:**
- Modify: `workflows/speed-to-lead.json`

- [ ] **Step 1: Replace 4 Twilio SMS nodes with WhatsApp HTTP Request nodes**

Replace `node-twilio-prospect` with the same WhatsApp HTTP Request pattern as Task 4 Step 2, but using `$env` vars instead of `$json.client_config`:

```json
{
  "id": "node-wa-prospect",
  "name": "WhatsApp: Confirmation Prospect",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [2000, 200],
  "parameters": {
    "method": "POST",
    "url": "=https://graph.facebook.com/v22.0/{{ $env.WA_PHONE_NUMBER_ID }}/messages",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $env.WA_ACCESS_TOKEN }}"
        }
      ]
    },
    "sendBody": true,
    "contentType": "json",
    "body": {
      "json": {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "={{ $json.phone }}",
        "type": "template",
        "template": {
          "name": "lead_confirm_fr",
          "language": { "code": "fr" },
          "components": [
            {
              "type": "body",
              "parameters": [
                { "type": "text", "text": "={{ $json.name.split(' ')[0] }}" },
                { "type": "text", "text": "={{ $json.sms }}" },
                { "type": "text", "text": "={{ $env.CALLBACK_MINUTES || '30' }}" },
                { "type": "text", "text": "={{ $env.BUSINESS_NAME }}" }
              ]
            }
          ]
        }
      }
    }
  }
}
```

- [ ] **Step 2: Replace `node-twilio-owner` with WhatsApp owner notification**

```json
{
  "id": "node-wa-owner",
  "name": "WhatsApp: Notification Dirigeant",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [2440, 300],
  "parameters": {
    "method": "POST",
    "url": "=https://graph.facebook.com/v22.0/{{ $env.WA_PHONE_NUMBER_ID }}/messages",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $env.WA_ACCESS_TOKEN }}"
        }
      ]
    },
    "sendBody": true,
    "contentType": "json",
    "body": {
      "json": {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "={{ $env.OWNER_PHONE }}",
        "type": "template",
        "template": {
          "name": "lead_owner_notify_fr",
          "language": { "code": "fr" },
          "components": [
            {
              "type": "body",
              "parameters": [
                { "type": "text", "text": "={{ $json.name }}" },
                { "type": "text", "text": "={{ $json.owner_request_summary }}" },
                { "type": "text", "text": "={{ $json.phone || $json.email }}" }
              ]
            }
          ]
        }
      }
    }
  }
}
```

- [ ] **Step 3: Replace `node-twilio-followup` with WhatsApp follow-up**

```json
{
  "id": "node-wa-followup",
  "name": "WhatsApp: Relance Prospect",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [3320, 200],
  "parameters": {
    "method": "POST",
    "url": "=https://graph.facebook.com/v22.0/{{ $env.WA_PHONE_NUMBER_ID }}/messages",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $env.WA_ACCESS_TOKEN }}"
        }
      ]
    },
    "sendBody": true,
    "contentType": "json",
    "body": {
      "json": {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "={{ $json.phone }}",
        "type": "template",
        "template": {
          "name": "lead_followup_fr",
          "language": { "code": "fr" },
          "components": [
            {
              "type": "body",
              "parameters": [
                { "type": "text", "text": "={{ $json.name.split(' ')[0] }}" },
                { "type": "text", "text": "={{ $env.BUSINESS_NAME }}" }
              ]
            }
          ]
        }
      }
    }
  }
}
```

- [ ] **Step 4: Replace `node-error-sms` (error fallback) with WhatsApp to owner**

```json
{
  "id": "node-error-wa",
  "name": "WhatsApp: Erreur au Dirigeant",
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4,
  "position": [680, 600],
  "parameters": {
    "method": "POST",
    "url": "=https://graph.facebook.com/v22.0/{{ $env.WA_PHONE_NUMBER_ID }}/messages",
    "authentication": "genericCredentialType",
    "genericAuthType": "httpHeaderAuth",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "=Bearer {{ $env.WA_ACCESS_TOKEN }}"
        }
      ]
    },
    "sendBody": true,
    "contentType": "json",
    "body": {
      "json": {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": "={{ $env.OWNER_PHONE }}",
        "type": "template",
        "template": {
          "name": "lead_error_notify_fr",
          "language": { "code": "fr" },
          "components": [
            {
              "type": "body",
              "parameters": [
                { "type": "text", "text": "={{ $json.name }}" },
                { "type": "text", "text": "={{ $json.request }}" },
                { "type": "text", "text": "={{ $json.phone }}" }
              ]
            }
          ]
        }
      }
    }
  }
}
```

- [ ] **Step 5: Update connections — remove WhatsApp/SMS branching**

Same simplification as Task 4 Step 6. The phone routing IF now goes directly to WhatsApp (no SMS/WA branching).

- [ ] **Step 6: Update setup notes**

Replace Twilio credential references with:

```json
"_setup_notes": "Post-import: Set env vars WA_PHONE_NUMBER_ID, WA_ACCESS_TOKEN, OWNER_PHONE, BUSINESS_NAME, CALLBACK_MINUTES, WEBHOOK_SECRET, ANTHROPIC_API_KEY, BREVO_API_KEY, BREVO_SENDER_EMAIL, FOLLOWUP_DELAY_MINUTES"
```

- [ ] **Step 7: Commit**

```bash
git add workflows/speed-to-lead.json
git commit -m "feat(standalone): replace Twilio SMS with WhatsApp Cloud API"
```

---

### Task 7: Update Core Workflow — save client_config in staticData for error handler

**Files:**
- Modify: `workflows/speed-to-lead-core.json`

- [ ] **Step 1: Update the "Code: Log Raw Payload" node**

The existing node logs the raw lead to staticData. Update it to also store `client_config` so the error handler can access it:

```javascript
const staticData = $getWorkflowStaticData('global');
const input = $input.first().json;

staticData.lastLead = {
  ...input,
  client_config: input.client_config,
  logged_at: new Date().toISOString()
};

return { json: input };
```

- [ ] **Step 2: Commit**

```bash
git add workflows/speed-to-lead-core.json
git commit -m "fix(core): persist client_config in staticData for error handler"
```

---

### Task 8: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace all Twilio references with WhatsApp Cloud API**

Update the README to reflect the new stack:
- Replace "Twilio (~0.08€/SMS)" with "WhatsApp Cloud API (~0.05€/conversation)"
- Replace credential setup instructions (Twilio Account SID/Auth Token → Meta Business Manager / System User token / Phone Number ID)
- Update env vars list (remove TWILIO_*, add WA_*)
- Remove BAPTISTE_PHONE from env vars
- Update cost table
- Add section: "Templates WhatsApp" with the 4 templates to submit to Meta
- Add section: "Prérequis Meta Business Manager" with setup steps

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README for WhatsApp Cloud API migration"
```

---

### Task 9: Update test script and TESTING.md

**Files:**
- Modify: `tests/test-webhook.sh`
- Modify: `tests/TESTING.md`

- [ ] **Step 1: Update `test-webhook.sh`**

The test script itself doesn't change (it just sends POST payloads to the webhook). But update any comments or output messages that reference Twilio/SMS:

- Replace "SMS envoyé" → "WhatsApp envoyé"
- Replace "Twilio" → "WhatsApp Cloud API"

- [ ] **Step 2: Update `tests/TESTING.md`**

Update verification checklists:
- Replace "Twilio SMS arrives" → "WhatsApp message arrives"
- Replace "Check Twilio dashboard" → "Check Meta Business Manager > WhatsApp > Insights"
- Update env var references (remove TWILIO_*, add WA_*)
- Update Phase 3 tests: remove WhatsApp Twilio WABA references, update to Meta Cloud API
- Update error handler test: verify dirigeant receives WhatsApp (not Baptiste)

- [ ] **Step 3: Commit**

```bash
git add tests/test-webhook.sh tests/TESTING.md
git commit -m "docs(tests): update test docs for WhatsApp Cloud API"
```

---

### Task 10: Update planning docs and CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `.planning/STATE.md`

- [ ] **Step 1: Update `CLAUDE.md`**

Add a section noting the v2 migration:

```markdown
## Stack v2 (2026-03-29)
- Canal principal : WhatsApp Cloud API (Meta) — remplace Twilio SMS
- Email fallback : Brevo Free (inchangé)
- Error handler : notifie le dirigeant (owner_phone), pas Baptiste
- Spec : docs/superpowers/specs/2026-03-29-whatsapp-migration-design.md
```

- [ ] **Step 2: Update `.planning/STATE.md`**

Add a decision entry:

```markdown
### Migration v2 — Twilio → WhatsApp Cloud API (2026-03-29)
- Remplacé Twilio SMS/WhatsApp par WhatsApp Cloud API (Meta Graph API)
- Error handler redirigé vers owner_phone (plus BAPTISTE_PHONE)
- 4 templates WhatsApp à soumettre à Meta pour approbation
- Brevo Free conservé pour email fallback
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md .planning/STATE.md
git commit -m "docs: update project docs for v2 WhatsApp migration"
```

---

### Task 11: Final verification

- [ ] **Step 1: Search for remaining Twilio references**

```bash
cd /Users/server/speed-to-lead && grep -ri "twilio" --include="*.json" --include="*.md" --include="*.sh" --include="*.txt" .
```

Expected: Zero matches in workflow/config files. Only matches should be in the spec doc (which documents the migration from Twilio) and possibly historical planning docs.

- [ ] **Step 2: Search for remaining BAPTISTE_PHONE references**

```bash
cd /Users/server/speed-to-lead && grep -ri "BAPTISTE_PHONE" --include="*.json" --include="*.md" --include="*.sh" .
```

Expected: Zero matches in workflow/config files.

- [ ] **Step 3: Validate JSON syntax of all workflow files**

```bash
cd /Users/server/speed-to-lead && for f in workflows/*.json config/*.json; do echo "Validating $f..."; python3 -c "import json; json.load(open('$f'))" && echo "  OK" || echo "  INVALID JSON"; done
```

Expected: All files report OK.

- [ ] **Step 4: Commit any remaining fixes**

```bash
git add -A
git commit -m "chore: clean up remaining Twilio references"
```
