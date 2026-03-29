# Speed to Lead v2 — Migration Twilio → WhatsApp Cloud API + Brevo Free

**Date:** 2026-03-29
**Statut:** Approuvé
**Auteur:** Baptiste Simon + Claude

---

## 1. Contexte et motivation

Speed to Lead v1 utilise Twilio (SMS + WhatsApp) comme canal principal. Problèmes :

- Twilio coûte ~10-12€/mois par client en messages
- Twilio + Brevo = 2 comptes de messaging à gérer
- Brevo seul (plan SMS) coûte 29€/mois — trop cher pour un freelance qui démarre

**Décision :** remplacer Twilio par WhatsApp Cloud API (Meta) en canal principal, garder Brevo Free (email) en fallback.

### Gains attendus

| Métrique | Avant (Twilio) | Après (WhatsApp + Brevo Free) |
|----------|---------------|-------------------------------|
| Coût messages/mois (30 leads) | ~10-12€ | ~4,50€ |
| Nombre de comptes messaging | 2 (Twilio + Brevo) | 1 (Meta) + Brevo gratuit |
| Taux d'ouverture | ~20% (SMS) | ~98% (WhatsApp) |
| Noeud n8n | HTTP Request (Twilio API) | Natif WhatsApp Business Cloud |

---

## 2. Stack technique

| Service | Rôle | Coût |
|---------|------|------|
| n8n (Cloud ou Railway) | Orchestration workflows | ~5-20€/mois |
| Claude Haiku 4.5 (Anthropic) | Génération message IA personnalisé | ~0,001€/lead |
| WhatsApp Cloud API (Meta) | Canal principal — prospect + dirigeant + relance | ~0,05€/conversation (utility) |
| Brevo Free | Email fallback si pas de numéro de téléphone | 0€ (300 emails/jour) |

---

## 3. Architecture

### Multi-tenant

Un seul n8n, un Core Workflow partagé, un Entry Workflow par client.

```
[Entry: /dupont-plomberie] → [Config Dupont] → [Execute: Core Workflow]
[Entry: /cabinet-martin]   → [Config Martin] → [Execute: Core Workflow]

Core Workflow (partagé, paramétré par la config client)
Error Handler (notifie le dirigeant, pas Baptiste)
```

### Standalone

Une version tout-en-un (1 seul fichier JSON) pour les clients qui n'ont qu'un seul formulaire WordPress. Même logique que le Core mais avec env vars directes.

---

## 4. Core Workflow — flux détaillé

```
Reçoit lead + client_config (depuis Entry Workflow)
  │
  ├─ CIRCUIT BREAKER
  │    >5 mêmes lead_id en 10 min ?
  │    OUI → WhatsApp template "error" au dirigeant (owner_phone) → STOP
  │    NON → continue
  │
  ├─ LOG RAW PAYLOAD (staticData.lastLead)
  │
  ├─ DÉDUPLICATION
  │    Clé : lead_id (Google Ads) OU email+phone (WordPress)
  │    Doublon → STOP silencieux
  │
  ├─ EXTRACT LEAD FIELDS
  │    Parse : name, phone, email, message
  │    Source WordPress : champs directs
  │    Source Google Ads : user_column_data array
  │
  ├─ CLAUDE HAIKU API
  │    System prompt : prompts/prospect-sms-fr.txt (inchangé)
  │    Génère un message <160 chars basé sur la demande du prospect
  │
  ├─ TRUNCATE à 155 chars (sécurité)
  │
  ├─ IF: phone disponible ?
  │    ├─ OUI → WhatsApp template "lead_confirm_fr" au prospect
  │    │         Params: {{1}}=prénom, {{2}}=message Claude, {{3}}=délai callback, {{4}}=nom business
  │    └─ NON → Email Brevo (HTML) au prospect
  │
  ├─ FORMAT OWNER NOTIFICATION
  │    Construit : nom + résumé demande + lien tel: (ou email si pas de tel)
  │
  ├─ WhatsApp template "lead_owner_notify_fr" au dirigeant (owner_phone)
  │    Params: {{1}}=nom prospect, {{2}}=résumé demande, {{3}}=tel ou email
  │
  ├─ WAIT (client_config.follow_up_delay_minutes)
  │
  ├─ BUSINESS HOURS CHECK (Luxon, Europe/Paris, Lun-Sam 08:00-20:00)
  │    ├─ OUI → WhatsApp template "lead_followup_fr" au prospect
  │    │         Params: {{1}}=prénom, {{2}}=nom business
  │    └─ NON → Log "follow-up skipped" → fin
  │
  └─ FIN
```

---

## 5. Entry Workflow — structure

Chaque Entry Workflow (1 par client) contient 4 noeuds :

1. **Webhook** — path: `/{client-slug}`, retourne 200 immédiatement
2. **IF: Secret Valid** — compare header `X-Webhook-Secret` vs env var
3. **Code: Assemble Client Config** — construit l'objet config :

```javascript
{
  // Business
  business_name: "Dupont Plomberie",
  service_type: "plombier",
  city: "Paris",
  owner_phone: $env.DUPONT_OWNER_PHONE,
  owner_email: "contact@dupont-plomberie.fr",

  // WhatsApp
  wa_phone_number_id: $env.DUPONT_WA_PHONE_NUMBER_ID,
  wa_access_token: $env.DUPONT_WA_ACCESS_TOKEN,
  wa_confirm_template: "lead_confirm_fr",
  wa_owner_template: "lead_owner_notify_fr",
  wa_followup_template: "lead_followup_fr",
  wa_error_template: "lead_error_notify_fr",

  // Brevo
  brevo_sender_email: "no-reply@dupont-plomberie.fr",

  // Timing
  callback_promise_minutes: 30,
  follow_up_delay_minutes: 45
}
```

4. **Execute Workflow** — appelle le Core, fire-and-forget (waitForSubWorkflow: false)

---

## 6. Error Handler

3 noeuds :

1. **Error Trigger** — déclenché par erreur dans le Core
2. **Code: Format Fallback** — extrait lead brut depuis staticData.lastLead
3. **WhatsApp template "lead_error_notify_fr"** — envoie au **dirigeant** (owner_phone de la config client)

**Important :** Baptiste n'est PAS dans la boucle. Pas de `BAPTISTE_PHONE`. Le template est 100% autonome.

---

## 7. Templates WhatsApp

4 templates à faire approuver par Meta (catégorie: utility, langue: fr) :

### 7.1 `lead_confirm_fr` — Confirmation prospect

```
Bonjour {{1}}, {{2}}. On vous rappelle sous {{3}} minutes. {{4}}.
```

| Param | Contenu | Source |
|-------|---------|--------|
| `{{1}}` | Prénom prospect | Extract Lead Fields |
| `{{2}}` | Message IA (reformulation demande) | Claude Haiku |
| `{{3}}` | Délai callback | client_config.callback_promise_minutes |
| `{{4}}` | Nom entreprise | client_config.business_name |

### 7.2 `lead_owner_notify_fr` — Notification dirigeant

```
Nouveau lead : {{1}} — {{2}}. Rappeler : {{3}}
```

| Param | Contenu | Source |
|-------|---------|--------|
| `{{1}}` | Nom complet prospect | Extract Lead Fields |
| `{{2}}` | Résumé demande (tronqué) | Extract Lead Fields |
| `{{3}}` | Téléphone ou email du prospect | Extract Lead Fields |

### 7.3 `lead_followup_fr` — Relance prospect

```
{{1}}, toujours disponible pour votre demande ? {{2}}
```

| Param | Contenu | Source |
|-------|---------|--------|
| `{{1}}` | Prénom prospect | Extract Lead Fields |
| `{{2}}` | Nom entreprise | client_config.business_name |

### 7.4 `lead_error_notify_fr` — Erreur (dirigeant)

```
Un lead n'a pas pu être traité automatiquement. {{1}} — {{2}}. Contactez-le : {{3}}
```

| Param | Contenu | Source |
|-------|---------|--------|
| `{{1}}` | Nom prospect | staticData.lastLead |
| `{{2}}` | Résumé demande | staticData.lastLead |
| `{{3}}` | Téléphone ou email | staticData.lastLead |

---

## 8. Variables d'environnement

### Par client (préfixe CLIENT_)

```
# WhatsApp (obligatoire)
DUPONT_WA_PHONE_NUMBER_ID=       # ID du numéro dans Meta Business Manager
DUPONT_WA_ACCESS_TOKEN=          # Token permanent System User
DUPONT_OWNER_PHONE=              # Numéro du dirigeant (format E.164)
DUPONT_OWNER_EMAIL=              # Email du dirigeant (fallback)
DUPONT_WEBHOOK_SECRET=           # Secret webhook WordPress
DUPONT_GOOGLE_KEY=               # Clé validation Google Ads (si applicable)
```

### Partagées

```
ANTHROPIC_API_KEY=               # Claude API
BREVO_API_KEY=                   # Brevo (email fallback)
CORE_WORKFLOW_ID=                # ID du Core Workflow dans n8n
```

### Supprimées (vs v1)

```
# Plus nécessaires :
BAPTISTE_PHONE
*_TWILIO_ACCOUNT_SID
*_TWILIO_AUTH_TOKEN
*_TWILIO_SENDER_ID
*_WHATSAPP_SENDER
*_WHATSAPP_TEMPLATE_SID
*_WHATSAPP_OWNER_TEMPLATE_SID
```

---

## 9. Prérequis client (guide Notion)

Le client doit configurer (documenté dans le guide fourni) :

1. **Meta Business Manager** — créer + vérifier son entreprise
2. **App Meta** — créer dans developers.facebook.com, activer le produit WhatsApp
3. **Numéro de téléphone** — enregistrer + vérifier (SMS ou appel vocal)
4. **Token permanent** — créer un System User dans Business Manager
5. **4 templates WhatsApp** — copier-coller les textes fournis (section 7), soumettre pour approbation (24-48h)
6. **Compte Brevo** — s'inscrire (plan gratuit), récupérer la clé API
7. **n8n** — importer le workflow JSON (Cloud ou self-hosted)
8. **Credentials n8n** — WhatsApp Business Cloud + Brevo
9. **Variables d'environnement** — remplir selon la section 8

---

## 10. Noeuds n8n — mapping technique

### Noeud WhatsApp (natif n8n)

Chaque envoi WhatsApp utilise le noeud **WhatsApp Business Cloud** natif de n8n :

- **Resource:** Message
- **Operation:** Send Template
- **Template Name:** depuis client_config (ex: `lead_confirm_fr`)
- **Language:** `fr`
- **Components:** body parameters mappés depuis les données du workflow
- **Phone Number ID:** depuis client_config.wa_phone_number_id
- **Recipient:** numéro E.164 du destinataire

### Noeud Brevo Email (natif n8n, inchangé)

- **Operation:** Send Transactional Email
- **From:** client_config.brevo_sender_email
- **To:** email du prospect
- **Subject:** "Confirmation de votre demande — {business_name}"
- **HTML:** template avec message Claude + nom business

### Noeud Claude API (HTTP Request, inchangé)

- **Method:** POST
- **URL:** `https://api.anthropic.com/v1/messages`
- **Model:** claude-haiku-4-5
- **Max tokens:** 200
- **System prompt:** contenu de prompts/prospect-sms-fr.txt avec variables client

---

## 11. Fichiers du projet (structure finale)

```
speed-to-lead/
├── workflows/
│   ├── speed-to-lead.json                      # Standalone WordPress (tout-en-un)
│   ├── speed-to-lead-core.json                 # Core multi-tenant
│   ├── speed-to-lead-entry-dupont-plomberie.json
│   ├── speed-to-lead-entry-cabinet-martin.json
│   └── speed-to-lead-error-handler.json
├── config/
│   ├── dupont-plomberie.json
│   └── cabinet-martin.json
├── prompts/
│   └── prospect-sms-fr.txt                     # Prompt Claude (inchangé)
├── tests/
│   ├── test-webhook.sh
│   ├── TESTING.md
│   └── payloads/
│       ├── wordpress-lead.json
│       ├── wordpress-lead-email-only.json
│       ├── google-ads-lead.json
│       ├── google-ads-lead-email-only.json
│       ├── google-ads-lead-duplicate.json
│       └── google-ads-lead-invalid-key.json
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-03-29-whatsapp-migration-design.md  # Ce document
├── README.md
└── CLAUDE.md
```

---

## 12. Tests

### Scénarios inchangés

- Happy path (lead avec téléphone) → WhatsApp confirmation part
- Email-only (pas de téléphone) → email Brevo part
- Duplicate lead → rejeté silencieusement
- Invalid secret/key → rejeté avec 401
- Circuit breaker (>5 mêmes lead_id) → WhatsApp erreur au dirigeant

### Nouveaux scénarios

- Error handler → vérifie que le dirigeant reçoit le WhatsApp erreur (plus Baptiste)
- Template WhatsApp → vérifie que les paramètres {{1}}-{{4}} sont correctement mappés
- Token expiré → vérifie que l'error handler se déclenche

### Fixtures

Les payloads de test existants sont réutilisés tels quels. Pas de changement de format.

---

## 13. Coûts (30 leads/mois)

| Service | Calcul | Coût |
|---------|--------|------|
| n8n Railway | Hosting | ~5-7€ |
| Claude Haiku | 30 appels × ~0,001€ | ~0,03€ |
| WhatsApp | ~3 conversations/lead × 30 × 0,05€ | ~4,50€ |
| Brevo email | Gratuit | 0€ |
| **Total** | | **~10-12€/mois** |

vs. v1 Twilio : ~15-25€/mois

---

## 14. Migration — ce qui change par rapport à v1

### Supprimé

- Tous les noeuds HTTP Request Twilio (10 noeuds au total)
- Env vars Twilio (`*_TWILIO_ACCOUNT_SID`, `*_TWILIO_AUTH_TOKEN`, `*_TWILIO_SENDER_ID`)
- `BAPTISTE_PHONE` et toute notification à Baptiste
- Les noeuds WhatsApp Twilio (remplacés par noeuds natifs n8n)

### Remplacé

- 8 noeuds SMS Twilio → noeuds WhatsApp Business Cloud natifs n8n
- 2 noeuds WhatsApp Twilio → noeuds WhatsApp Business Cloud natifs n8n
- Error handler destination : Baptiste → dirigeant (owner_phone)
- Circuit breaker alert destination : Baptiste → dirigeant (owner_phone)

### Inchangé

- Architecture multi-tenant (entry + core + error handler)
- Claude API (prompt, modèle, logique)
- Brevo email fallback
- Déduplication, logging, circuit breaker (logique)
- Business hours check
- Wait node follow-up
- Fixtures de test
- Structure des fichiers

### Ajouté

- 4 templates WhatsApp pré-rédigés (à copier-coller dans Meta)
- Guide de setup Meta Business Manager dans le Notion
- Credential WhatsApp Business Cloud dans n8n
