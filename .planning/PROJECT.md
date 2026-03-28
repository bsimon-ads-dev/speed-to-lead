# Speed to Lead

## What This Is

Template n8n gratuit qui repond instantanement aux leads de formulaire WordPress pour les PME de services locaux. Distribue comme lead magnet via LinkedIn — les prospects qui n'arrivent pas a l'installer contactent Baptiste pour un accompagnement payant.

Un seul workflow a importer dans n8n. Quand un prospect remplit un formulaire WordPress (Contact Form 7, WPForms, Elementor...), le systeme :
1. Genere un SMS personnalise par IA (Claude) qui reformule la demande
2. Envoie le SMS au prospect en < 2 minutes
3. Notifie le dirigeant par SMS avec les infos du lead + lien pour rappeler
4. Relance automatiquement le prospect si pas de rappel

## Core Value

Reduire le temps de reponse aux leads a < 2 minutes, 24/7 — pour que plus aucun lead soit perdu par manque de reactivite.

## Business Model

**Lead magnet** pour la prospection LinkedIn de Baptiste :
- Post LinkedIn → lien page Notion avec template + guide
- Le prospect telecharge et essaie d'installer
- ~80% galereat et contactent Baptiste → conversion en client media buying + automatisations
- Le "galere" controlé est le mecanisme de conversion

## Requirements

### Active

- [ ] Un seul workflow n8n tout-en-un (pas de multi-workflow)
- [ ] Webhook generique compatible avec n'importe quel formulaire WordPress (CF7, WPForms, Elementor)
- [ ] Payload JSON plat attendu : name, phone, email, message (champs standards)
- [ ] Validation du webhook par secret dans le header HTTP
- [ ] Deduplication sur email+phone (pas de lead_id Google)
- [ ] Generation d'un SMS personnalise par Claude API qui reformule la demande du prospect
- [ ] Envoi SMS au prospect via Twilio
- [ ] Envoi email au prospect via Brevo si pas de telephone
- [ ] Notification SMS au dirigeant avec infos cles + lien tel: pour rappel direct
- [ ] Relance automatique au prospect si pas de rappel apres delai configurable
- [ ] Relance uniquement pendant les heures ouvrables (08h-20h, lun-sam)
- [ ] Fallback erreur : le dirigeant recoit le lead brut si le pipeline plante
- [ ] Configuration simple : variables d'environnement n8n uniquement
- [ ] Template importable en 1 clic dans n8n
- [ ] Guide d'installation sur page Notion

### Out of Scope

- Multi-tenant / multi-clients dans un seul workflow — chaque client a sa propre instance n8n
- WhatsApp — necessite WABA onboarding trop complexe pour un template self-service
- Circuit breaker / monitoring avance — overengineering pour un lead magnet
- CRM, dashboard, reporting
- Landing pages ou formulaires custom — on se branche sur l'existant WordPress

## Context

- Baptiste Simon est media buyer freelance Google/Meta Ads pour PME en lead generation
- Les automatisations IA (n8n + Claude) sont une offre complementaire en upsell
- Les clients PME sont des services locaux : plombiers, dentistes, avocats, coachs, etc.
- La plupart ont un site WordPress avec un formulaire de contact (CF7, WPForms, Elementor)
- Les dirigeants ne gerent pas leurs leads — c'est le chaos, ils ratent des opportunites
- Ce template est un lead magnet LinkedIn, pas un produit SaaS
- Le guide Notion doit avoir l'air simple mais etre suffisamment technique pour creer du "galere" convert

## Constraints

- **Format** : Un seul fichier JSON n8n importable — pas de setup multi-workflow
- **Source** : Formulaires WordPress via webhook HTTP POST (JSON plat)
- **Stack** : n8n + Claude API + Twilio + Brevo — rien d'autre
- **Difficulte** : Le guide doit etre comprehensible mais pas trivial a suivre (mecanisme de conversion)
- **Cout** : Le template est gratuit, les services de Baptiste sont payants

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Formulaire WordPress (pas Google Ads Lead Forms) | Les PME ont deja un site WordPress avec formulaire — plus universel | ✓ Pivot |
| Un seul workflow (pas multi-workflow) | Template self-service doit etre importable en 1 clic, pas 4 fichiers | ✓ Simplifie |
| Lead magnet LinkedIn (pas produit vendu) | Le gratuit attire, le "galere" convertit en clients payants | ✓ Business model |
| Pas de WhatsApp dans le template | WABA onboarding trop complexe pour du self-service | ✓ Simplifie |
| Pas de circuit breaker/monitoring | Overengineering pour un template gratuit | ✓ Simplifie |

---
*Last updated: 2026-03-28 after pivot lead magnet + WordPress*
