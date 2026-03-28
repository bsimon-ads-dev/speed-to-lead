# Speed to Lead

Template n8n gratuit qui **repond automatiquement aux leads de votre site web** en moins de 2 minutes.

Quand un prospect remplit le formulaire de votre site WordPress, le systeme :

1. **Envoie un SMS personnalise par IA** au prospect ("Bonjour Marie, votre fuite d'eau sous l'evier : notre plombier vous rappelle sous 30 minutes.")
2. **Vous envoie une notification SMS** avec les infos du lead et un lien pour rappeler en un clic
3. **Relance automatiquement** le prospect si vous n'avez pas rappele apres un delai que vous choisissez
4. Si quelque chose plante, **vous recevez le lead brut par SMS** — aucun lead n'est perdu

Compatible avec **Contact Form 7**, **WPForms**, **Elementor Forms** et tout plugin WordPress qui supporte les webhooks.

---

## Ce qu'il vous faut

| Service | A quoi ca sert | Cout |
|---------|----------------|------|
| [n8n](https://n8n.io) | L'outil qui fait tourner l'automatisation | Gratuit (self-hosted) ou ~20 EUR/mois (cloud) |
| [Twilio](https://twilio.com) | Envoyer les SMS | ~0.08 EUR/SMS |
| [Brevo](https://brevo.com) | Envoyer les emails (si pas de telephone) | Gratuit (300 emails/jour) |
| [Claude API](https://console.anthropic.com) | Generer les messages personnalises | ~0.001 EUR/lead |

**Cout total :** environ 3-5 EUR/mois pour 30 leads.

---

## Installation pas a pas

### Etape 1 : Creer un compte n8n

**Option A — n8n Cloud (plus simple, payant) :**
1. Aller sur [n8n.io/cloud](https://n8n.io/cloud)
2. Creer un compte
3. Noter votre URL (ex: `https://votre-nom.app.n8n.cloud`)

**Option B — Self-hosted sur Railway (moins cher) :**
1. Aller sur [railway.app](https://railway.app)
2. Creer un compte
3. Chercher "n8n" dans les templates et cliquer "Deploy"
4. Attendre 5 minutes, noter votre URL

### Etape 2 : Creer les comptes de services

**Twilio (pour les SMS) :**
1. Creer un compte sur [twilio.com](https://twilio.com)
2. Acheter un numero de telephone francais (~1 EUR/mois)
3. Ou enregistrer un "Alphanumeric Sender ID" (ex: "VotreSociete", max 11 caracteres)
4. Noter votre **Account SID** et **Auth Token** depuis le dashboard

**Brevo (pour les emails) :**
1. Creer un compte gratuit sur [brevo.com](https://brevo.com)
2. Aller dans Settings > SMTP & API > API Keys
3. Creer et noter votre cle API

**Claude (pour l'IA) :**
1. Aller sur [console.anthropic.com](https://console.anthropic.com)
2. Creer un compte, ajouter un moyen de paiement
3. Creer une cle API dans "API Keys"
4. (Recommande) Fixer un plafond a 5 EUR/mois dans Settings > Limits

### Etape 3 : Importer le workflow dans n8n

1. Telecharger le fichier `speed-to-lead.json` (dans le dossier `workflows/`)
2. Dans n8n, cliquer sur le menu **"..."** en haut a droite > **"Import from file"**
3. Selectionner le fichier `speed-to-lead.json`
4. Le workflow apparait avec tous les noeuds pre-configures

### Etape 4 : Configurer les credentials Twilio

1. Dans n8n, aller dans **Settings** > **Credentials**
2. Cliquer **"Add credential"** > choisir **"HTTP Basic Auth"**
3. Remplir :
   - **Username** = votre Twilio Account SID (commence par `AC...`)
   - **Password** = votre Twilio Auth Token
4. Sauvegarder
5. Ouvrir chacun des 4 noeuds Twilio dans le workflow (ils s'appellent "Twilio: ...")
6. Dans chaque noeud, selectionner le credential que vous venez de creer

### Etape 5 : Configurer les variables d'environnement

Dans n8n, aller dans **Settings** > **Variables** et ajouter :

| Variable | Valeur | Description |
|----------|--------|-------------|
| `WEBHOOK_SECRET` | Un mot de passe de votre choix | Securise le webhook (ex: `mon-secret-123`) |
| `TWILIO_ACCOUNT_SID` | `ACxxxxxxx...` | Depuis le dashboard Twilio |
| `TWILIO_SENDER_ID` | `+33...` ou `VotreSociete` | Numero ou nom d'expediteur Twilio |
| `ANTHROPIC_API_KEY` | `sk-ant-...` | Depuis console.anthropic.com |
| `BREVO_API_KEY` | `xkeysib-...` | Depuis Brevo > API Keys |
| `BREVO_SENDER_EMAIL` | `contact@votre-site.fr` | L'email d'expedition pour Brevo |
| `OWNER_PHONE` | `+33600000000` | Votre numero de telephone (format international) |
| `BUSINESS_NAME` | `Dupont Plomberie` | Le nom de votre entreprise |
| `SERVICE_TYPE` | `plombier` | Votre metier (adapte le ton du SMS) |
| `CITY` | `Paris` | Votre ville |
| `CALLBACK_MINUTES` | `30` | Delai promis au prospect ("on vous rappelle sous X min") |
| `FOLLOWUP_DELAY_MINUTES` | `45` | Delai avant relance automatique (en minutes) |

### Etape 6 : Configurer le error handler

1. Dans le workflow, cliquer sur **Settings** (icone engrenage en haut)
2. Dans **"Error Workflow"**, selectionner **"Speed to Lead"** (ce meme workflow)
3. Sauvegarder

### Etape 7 : Connecter votre formulaire WordPress

Le webhook attend des donnees en JSON. Votre formulaire WordPress doit envoyer les soumissions vers l'URL :

```
https://votre-instance-n8n/webhook/speed-to-lead
```

**Avec Contact Form 7 :**
- Installer le plugin [CF7 to Webhook](https://wordpress.org/plugins/cf7-to-webhook/)
- Dans les parametres du formulaire, ajouter l'URL webhook
- Ajouter le header : `X-Webhook-Secret: votre-secret`

**Avec WPForms :**
- Installer le plugin [WP Webhooks](https://wordpress.org/plugins/wp-webhooks/)
- Creer un webhook "Send Data" sur l'evenement "Form submitted"
- URL = votre webhook, ajouter le header secret

**Avec Elementor Forms :**
- Dans l'action apres soumission, ajouter "Webhook"
- Coller l'URL du webhook
- Ajouter le header `X-Webhook-Secret` dans les options avancees

Les champs du formulaire doivent s'appeler `name` (ou `nom`), `phone` (ou `tel`), `email`, `message` (ou `demande`). Le workflow reconnait automatiquement les variantes courantes.

### Etape 8 : Activer et tester

1. **Activer le workflow** (bouton ON/OFF en haut a droite de n8n)
2. Remplir votre propre formulaire WordPress avec un faux lead
3. Verifier que :
   - Le prospect (vous) recoit un SMS personnalise
   - Le dirigeant (vous) recoit un SMS avec les infos du lead
   - Le SMS contient un lien `tel:` cliquable

---

## Comment ca marche

```
Formulaire WordPress
        |
        v
   [Webhook n8n]
        |
   Verifie le secret
        |
   Deduplication
        |
   Claude AI genere
   un SMS personnalise
        |
   +---------+---------+
   |                   |
   v                   v
Tel dispo?          Email seulement
   |                   |
SMS Twilio        Email Brevo
   |                   |
   +------- + ---------+
            |
    SMS au dirigeant
    (avec lien tel:)
            |
     Attend X minutes
            |
    Heures ouvrables ?
      Oui → Relance SMS
      Non → Rien
```

---

## En cas de probleme

| Symptome | Solution |
|----------|----------|
| Le webhook ne recoit rien | Verifier que le workflow est **active** (pas juste ouvert) |
| "Invalid secret" | Verifier que le header `X-Webhook-Secret` correspond a la variable `WEBHOOK_SECRET` |
| Pas de SMS | Verifier le credential Twilio (Account SID + Auth Token) et le solde du compte |
| SMS trop long ou bizarre | Verifier que `BUSINESS_NAME`, `SERVICE_TYPE` et `CITY` sont bien remplis |
| Le prospect recoit 2 SMS | Normal au premier test — la deduplication marche sur les prochains envois identiques |
| Erreur Claude | Verifier la cle API et le solde sur console.anthropic.com |

---

## Besoin d'aide ?

Ce template est gratuit et open-source. Si vous avez besoin d'aide pour :
- L'installer et le configurer
- L'adapter a votre activite
- Ajouter des fonctionnalites (WhatsApp, multi-sites, reporting...)

Contactez-moi : **Baptiste Simon** — Media Buyer & Automatisations IA
