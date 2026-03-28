# Requirements: Speed to Lead (Template)

**Defined:** 2026-03-28
**Core Value:** Reduire le temps de reponse aux leads a < 2 minutes, 24/7

## v1 Requirements

### Ingestion

- [ ] **INGEST-01**: Le workflow recoit les leads via webhook HTTP POST (JSON plat : name, phone, email, message)
- [ ] **INGEST-02**: Le webhook valide un secret dans le header HTTP (X-Webhook-Secret)
- [ ] **INGEST-03**: Le workflow deduplique les leads sur email+phone pour eviter les messages en double
- [ ] **INGEST-04**: Le workflow log le payload brut pour debug

### Reponse Prospect

- [ ] **RESP-01**: Claude API genere un SMS personnalise en francais qui reformule la demande du prospect
- [ ] **RESP-02**: Le SMS est envoye au prospect via Twilio si le telephone est disponible
- [ ] **RESP-03**: Un email est envoye au prospect via Brevo si seul l'email est disponible
- [ ] **RESP-04**: Le prompt est adapte au metier du dirigeant (configurable)
- [ ] **RESP-05**: Le message est envoye en moins de 2 minutes

### Notification Dirigeant

- [ ] **NOTIF-01**: Le dirigeant recoit un SMS avec les infos du lead (nom, demande, telephone)
- [ ] **NOTIF-02**: La notification contient un lien tel: pour rappeler en un clic
- [ ] **NOTIF-03**: Si le dirigeant n'a pas rappele apres un delai configurable, le prospect recoit une relance
- [ ] **NOTIF-04**: La relance ne se fait que pendant les heures ouvrables (08h-20h, lun-sam, Europe/Paris)
- [ ] **NOTIF-05**: En cas d'erreur, le dirigeant recoit le lead brut en fallback

### Packaging

- [ ] **PKG-01**: Un seul fichier JSON n8n importable (1 workflow)
- [ ] **PKG-02**: Configuration via variables d'environnement n8n uniquement
- [ ] **PKG-03**: Guide d'installation clair sur page Notion
- [ ] **PKG-04**: Compatible WordPress : CF7, WPForms, Elementor Forms (via plugin webhook)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-tenant / multi-clients | Chaque client a sa propre instance — template self-service |
| WhatsApp | WABA onboarding trop complexe pour un template gratuit |
| Circuit breaker / monitoring | Overengineering pour un lead magnet |
| Dashboard / CRM / reporting | Pas le but du template |
| Google Ads Lead Forms | Pivot vers formulaires WordPress existants |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INGEST-01 | Refactor | Pending |
| INGEST-02 | Refactor | Pending |
| INGEST-03 | Refactor | Pending |
| INGEST-04 | Refactor | Pending |
| RESP-01 | Refactor | Pending |
| RESP-02 | Refactor | Pending |
| RESP-03 | Refactor | Pending |
| RESP-04 | Refactor | Pending |
| RESP-05 | Refactor | Pending |
| NOTIF-01 | Refactor | Pending |
| NOTIF-02 | Refactor | Pending |
| NOTIF-03 | Refactor | Pending |
| NOTIF-04 | Refactor | Pending |
| NOTIF-05 | Refactor | Pending |
| PKG-01 | Refactor | Pending |
| PKG-02 | Refactor | Pending |
| PKG-03 | Refactor | Pending |
| PKG-04 | Refactor | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 0
- Unmapped: 18

---
*Requirements defined: 2026-03-28*
*Last updated: 2026-03-28 after pivot lead magnet + WordPress*
