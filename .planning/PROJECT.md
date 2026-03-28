# Speed to Lead

## What This Is

Workflow d'automatisation n8n + Claude API qui répond instantanément aux leads Google Ads pour le compte de PME de services locaux. Le dirigeant reçoit une notification prête à l'action pendant que le prospect est déjà engagé par un message IA personnalisé. Vendu comme upsell séparé du service de media buying Google/Meta Ads.

## Core Value

Réduire le temps de réponse aux leads à < 2 minutes, 24/7 — pour que plus aucun lead payé ne soit perdu par manque de réactivité.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Captation automatique des leads depuis Google Ads Lead Forms (webhook)
- [ ] Génération d'un message personnalisé par Claude API qui reformule la demande du prospect
- [ ] Envoi du message au prospect via SMS, WhatsApp ou email selon les coordonnées disponibles dans le Lead Form
- [ ] Le message confirme au prospect qu'il sera rappelé sous X minutes
- [ ] Notification SMS/WhatsApp au dirigeant avec les infos clés du lead (nom, demande, téléphone)
- [ ] Le dirigeant peut rappeler directement depuis la notification (lien tel: / lien WhatsApp)
- [ ] Relance automatique au prospect si le dirigeant n'a pas rappelé après un délai configurable
- [ ] Configuration par client : canaux, délais, nom de l'entreprise, type de service
- [ ] Solution 100% clé en main — aucune action requise du dirigeant au quotidien

### Out of Scope

- CRM ou dashboard client — les dirigeants ne veulent pas consulter un outil de plus
- Reporting/analytics avancé — sera proposé comme add-on futur
- Lead nurturing multi-séquences (J+1, J+3, J+7) — v2 potentielle
- Gestion des appels entrants/click-to-call — source de leads non prioritaire pour l'instant
- Landing pages ou formulaires custom — on se branche sur Google Ads Lead Forms existants

## Context

- Baptiste Simon est media buyer freelance Google/Meta Ads pour PME en lead generation
- Les automatisations IA (n8n + Claude) sont une offre complémentaire en upsell
- Les clients PME sont des services locaux : plombiers, dentistes, avocats, coachs, etc.
- Aujourd'hui c'est le chaos côté gestion des leads — les dirigeants ne savent même pas combien ils en ratent
- Les clients communiquent via un mix téléphone/SMS/WhatsApp/email selon leurs habitudes
- Les clients ont zéro compétence technique et un petit budget — la solution doit être invisible
- Modèle commercial : setup one-shot facturé à l'installation + upsell mensuel séparé du media buying

## Constraints

- **Stack** : n8n (self-hosted ou cloud) + Claude API — pas de stack custom, doit rester maintenable par un freelance solo
- **Clients** : Zéro technique — toute la configuration se fait côté freelance, le client ne touche à rien
- **Canaux** : Dépend des coordonnées disponibles dans le Lead Form (téléphone → SMS/WhatsApp, email → email)
- **Coût** : Le coût par lead (API Claude + SMS/WhatsApp) doit rester marginal vs. le coût d'acquisition du lead
- **Fiabilité** : 24/7, pas de downtime — un lead à 3h du matin doit recevoir sa réponse

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Google Ads Lead Forms comme source unique v1 | C'est le format le plus courant dans les campagnes de Baptiste, webhook natif disponible | — Pending |
| n8n + Claude API comme stack | Déjà maîtrisé par Baptiste, maintenable en solo, coût maîtrisé | — Pending |
| Message IA personnalisé (pas template statique) | Reformuler la demande du prospect crée un effet "on m'a écouté" qui augmente le taux de rappel | — Pending |
| Notification dirigeant SMS/WhatsApp (pas email) | Le dirigeant est sur le terrain, il lit ses SMS/WhatsApp, pas ses emails | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-27 after initialization*
