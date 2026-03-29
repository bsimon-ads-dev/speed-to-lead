# Speed to Lead

Template n8n gratuit qui **repond automatiquement aux leads de votre site web** en moins de 2 minutes.

Quand un prospect remplit le formulaire de votre site WordPress, le systeme :

1. **Envoie un message WhatsApp personnalise par IA** au prospect ("Bonjour Marie, votre fuite d'eau sous l'evier : notre plombier vous rappelle sous 30 minutes.")
2. **Vous envoie une notification WhatsApp** avec les infos du lead et un lien pour rappeler en un clic
3. **Relance automatiquement** le prospect si vous n'avez pas rappele apres un delai que vous choisissez
4. Si quelque chose plante, **vous recevez le lead brut par WhatsApp** — aucun lead n'est perdu

Compatible avec **Contact Form 7**, **WPForms**, **Elementor Forms** et tout plugin WordPress qui supporte les webhooks.

---

## Ce qu'il vous faut

| Service | A quoi ca sert | Cout |
|---------|----------------|------|
| [n8n Cloud](https://n8n.io/cloud) | L'outil qui fait tourner l'automatisation | A partir de ~20 EUR/mois (essai gratuit) |
| [WhatsApp Cloud API](https://developers.facebook.com/docs/whatsapp) | Envoyer les messages WhatsApp | ~0.05 EUR/conversation |
| [Brevo](https://brevo.com) | Envoyer les emails (si pas de telephone) | Gratuit (300 emails/jour) |
| [Claude API](https://console.anthropic.com) | Generer les messages personnalises | ~0.001 EUR/lead |

**Cout total :** environ 10-12 EUR/mois pour 30 leads.

---

## Installation pas a pas

### Etape 1 : Creer un compte n8n

1. Aller sur [n8n.io/cloud](https://n8n.io/cloud)
2. Creer un compte et choisir un plan (essai gratuit disponible)
3. Noter votre URL (ex: `https://votre-nom.app.n8n.cloud`)

### Etape 2 : Creer les comptes de services

**WhatsApp Cloud API (pour les messages WhatsApp) :**
1. Creer un Meta Business Manager sur [business.facebook.com](https://business.facebook.com) et verifier votre entreprise
2. Creer une App Meta avec le produit WhatsApp sur [developers.facebook.com](https://developers.facebook.com)
3. Enregistrer un numero de telephone dans votre App WhatsApp
4. Generer un token permanent via un System User dans Business Settings > System Users
5. Noter votre **Phone Number ID** et votre **Access Token**
6. Soumettre les 4 templates WhatsApp (voir section "Templates WhatsApp" ci-dessous) — approbation sous 24-48h

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

### Etape 4 : Configurer les credentials WhatsApp Cloud API

1. Dans n8n, aller dans **Settings** > **Credentials**
2. Cliquer **"Add credential"** > choisir **"HTTP Header Auth"**
3. Remplir :
   - **Name** = `Authorization`
   - **Value** = `Bearer VOTRE_WA_ACCESS_TOKEN`
4. Sauvegarder
5. Ouvrir chacun des noeuds WhatsApp dans le workflow
6. Dans chaque noeud, selectionner le credential que vous venez de creer

### Etape 5 : Configurer les variables d'environnement

Dans n8n, aller dans **Settings** > **Variables** et ajouter :

| Variable | Valeur | Description |
|----------|--------|-------------|
| `WEBHOOK_SECRET` | Un mot de passe de votre choix | Securise le webhook (ex: `mon-secret-123`) |
| `WA_PHONE_NUMBER_ID` | `1234567890` | Phone Number ID depuis le dashboard Meta/WhatsApp |
| `WA_ACCESS_TOKEN` | `EAAxxxxx...` | Token permanent depuis Business Settings > System Users |
| `OWNER_PHONE` | `+33600000000` | Votre numero de telephone (format international) |
| `ANTHROPIC_API_KEY` | `sk-ant-...` | Depuis console.anthropic.com |
| `BREVO_API_KEY` | `xkeysib-...` | Depuis Brevo > API Keys |
| `BREVO_SENDER_EMAIL` | `contact@votre-site.fr` | L'email d'expedition pour Brevo |
| `BUSINESS_NAME` | `Dupont Plomberie` | Le nom de votre entreprise |
| `SERVICE_TYPE` | `plombier` | Votre metier (adapte le ton du message) |
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
   - Le prospect (vous) recoit un message WhatsApp personnalise
   - Le dirigeant (vous) recoit un message WhatsApp avec les infos du lead
   - Le message contient un lien `tel:` cliquable

---

## Templates WhatsApp

Avant de pouvoir envoyer des messages, vous devez soumettre ces 4 templates a Meta pour approbation (24-48h). Allez dans votre App Meta > WhatsApp > Message Templates.

| Nom du template | Contenu |
|----------------|---------|
| `lead_confirm_fr` | `Bonjour {{1}}, {{2}}. On vous rappelle sous {{3}} minutes. {{4}}.` |
| `lead_owner_notify_fr` | `Nouveau lead : {{1}} — {{2}}. Rappeler : {{3}}` |
| `lead_followup_fr` | `{{1}}, toujours disponible pour votre demande ? {{2}}` |
| `lead_error_notify_fr` | `Un lead n'a pas pu etre traite automatiquement. {{1}} — {{2}}. Contactez-le : {{3}}` |

Pour chaque template :
- Categorie : **Utility** (ou Marketing pour le followup)
- Langue : **French (fr)**
- Les `{{1}}`, `{{2}}`, etc. sont des variables remplacees dynamiquement par le workflow

---

## Prerequis Meta Business Manager

Avant de commencer, vous avez besoin de :

1. **Creer un Meta Business Manager** sur [business.facebook.com](https://business.facebook.com) et verifier votre entreprise (piece d'identite ou document officiel demande)
2. **Creer une App Meta** sur [developers.facebook.com](https://developers.facebook.com) avec le produit **WhatsApp** active
3. **Enregistrer un numero de telephone** dans votre App WhatsApp (peut etre votre numero pro existant ou un nouveau numero)
4. **Generer un token permanent** : dans Business Settings > System Users, creer un System User, lui donner acces a l'App, et generer un token avec les permissions `whatsapp_business_messaging` et `whatsapp_business_management`
5. **Soumettre les 4 templates WhatsApp** (voir section ci-dessus) — comptez 24-48h pour l'approbation par Meta

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
   un message personnalise
        |
   +---------+---------+
   |                   |
   v                   v
Tel dispo?          Email seulement
   |                   |
WhatsApp           Email Brevo
   |                   |
   +------- + ---------+
            |
  WhatsApp au dirigeant
    (avec lien tel:)
            |
     Attend X minutes
            |
    Heures ouvrables ?
      Oui → Relance WhatsApp
      Non → Rien
```

---

## En cas de probleme

| Symptome | Solution |
|----------|----------|
| Le webhook ne recoit rien | Verifier que le workflow est **active** (pas juste ouvert) |
| "Invalid secret" | Verifier que le header `X-Webhook-Secret` correspond a la variable `WEBHOOK_SECRET` |
| Pas de message WhatsApp | Verifier le token `WA_ACCESS_TOKEN`, le `WA_PHONE_NUMBER_ID` et que les templates sont approuves |
| Message WhatsApp refuse | Verifier que le nom du template dans le workflow correspond exactement au nom soumis a Meta |
| SMS trop long ou bizarre | Verifier que `BUSINESS_NAME`, `SERVICE_TYPE` et `CITY` sont bien remplis |
| Le prospect recoit 2 messages | Normal au premier test — la deduplication marche sur les prochains envois identiques |
| Erreur Claude | Verifier la cle API et le solde sur console.anthropic.com |

---

## Besoin d'aide ?

Ce template est gratuit et open-source. Si vous avez besoin d'aide pour :
- L'installer et le configurer
- L'adapter a votre activite
- Ajouter des fonctionnalites (multi-sites, reporting...)

Contactez-moi : **Baptiste Simon** — Media Buyer & Automatisations IA
