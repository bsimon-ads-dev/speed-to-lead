# Requirements: Speed to Lead

**Defined:** 2026-03-27
**Core Value:** Réduire le temps de réponse aux leads à < 2 minutes, 24/7 — pour que plus aucun lead payé ne soit perdu par manque de réactivité.

## v1 Requirements

### Ingestion

- [ ] **INGEST-01**: Le système reçoit les leads Google Ads Lead Forms via webhook HTTP POST
- [ ] **INGEST-02**: Le système déduplique les leads par `lead_id` pour éviter les messages en double
- [ ] **INGEST-03**: Le système log le payload brut de chaque lead reçu pour audit/debug
- [ ] **INGEST-04**: Le système valide l'authenticité du webhook via `google_key`

### Réponse Prospect

- [ ] **RESP-01**: Le système génère un message personnalisé via Claude API qui reformule la demande du prospect et confirme un rappel sous X minutes
- [ ] **RESP-02**: Le système envoie le message par SMS via Twilio si le numéro de téléphone est disponible
- [ ] **RESP-03**: Le système envoie le message par email via Brevo si seul l'email est disponible
- [ ] **RESP-04**: Le prompt Claude est adapté au métier du client (plombier vs dentiste vs avocat)
- [ ] **RESP-05**: Le message est envoyé en moins de 2 minutes après la soumission du lead

### Notification Dirigeant

- [ ] **NOTIF-01**: Le dirigeant reçoit un SMS/WhatsApp avec les infos clés du lead (nom, demande, téléphone)
- [ ] **NOTIF-02**: La notification contient un lien `tel:` permettant de rappeler le prospect en un clic
- [ ] **NOTIF-03**: Si le dirigeant n'a pas rappelé après un délai configurable, le prospect reçoit une relance automatique
- [ ] **NOTIF-04**: En cas d'erreur du pipeline, Baptiste reçoit le lead brut en fallback

### Configuration

- [ ] **CONF-01**: Chaque client a sa propre configuration (nom entreprise, canaux, délais, type de service)
- [ ] **CONF-02**: Un seul Core Workflow n8n partagé entre tous les clients (multi-tenant)
- [ ] **CONF-03**: Chaque client a une URL webhook unique par slug (`/webhook/dupont-plomberie`)

## v2 Requirements

### Canaux

- **CHAN-01**: Envoi WhatsApp au prospect via Twilio WABA (après validation templates Meta)
- **CHAN-02**: Conversation IA bidirectionnelle avec le prospect

### Nurturing

- **NURT-01**: Séquences de relance multi-étapes (J+1, J+3, J+7)
- **NURT-02**: Gestion des opt-out prospect

### Suivi

- **SUIV-01**: Détection de rappel effectif via Twilio call logs (au lieu de relance systématique)
- **SUIV-02**: Reporting/dashboard pour Baptiste (taux de réponse, leads traités, coûts)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Dashboard/CRM pour le client | Les dirigeants ne veulent pas d'outil de plus — zero-interface est le positionnement |
| Landing pages ou formulaires custom | On se branche sur les Google Ads Lead Forms existants |
| Gestion des appels entrants (click-to-call) | Source de leads non prioritaire pour v1 |
| Application mobile | Le SMS/WhatsApp suffit, pas besoin d'app |
| Intégration CRM tiers (HubSpot, Pipedrive...) | Complexité injustifiée pour des PME qui n'ont pas de CRM |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INGEST-01 | Phase 1 | Pending |
| INGEST-02 | Phase 1 | Pending |
| INGEST-03 | Phase 1 | Pending |
| INGEST-04 | Phase 1 | Pending |
| RESP-01 | Phase 1 | Pending |
| RESP-02 | Phase 1 | Pending |
| RESP-03 | Phase 1 | Pending |
| RESP-04 | Phase 1 | Pending |
| RESP-05 | Phase 1 | Pending |
| NOTIF-01 | Phase 1 | Pending |
| NOTIF-02 | Phase 1 | Pending |
| NOTIF-03 | Phase 2 | Pending |
| NOTIF-04 | Phase 1 | Pending |
| CONF-01 | Phase 2 | Pending |
| CONF-02 | Phase 2 | Pending |
| CONF-03 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-27*
*Last updated: 2026-03-27 after roadmap creation*
