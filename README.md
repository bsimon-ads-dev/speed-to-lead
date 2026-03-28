# Speed to Lead

Automatisation qui **repond instantanement aux leads Google Ads** pour les PME de services locaux (plombiers, dentistes, avocats, coachs...).

Quand un prospect remplit un formulaire Google Ads, le systeme :

1. Envoie un **SMS personnalise par IA** au prospect en moins de 2 minutes ("Bonjour Marie, votre fuite d'eau sous l'evier : notre plombier vous rappelle sous 30 minutes.")
2. Envoie une **notification SMS au dirigeant** avec les infos du lead et un lien pour rappeler en un clic
3. **Relance automatiquement** le prospect si le dirigeant n'a pas rappele apres un delai configurable
4. Si quelque chose plante, **Baptiste recoit le lead brut** par SMS — aucun lead n'est perdu

## Ce qu'il faut

- Un compte [n8n](https://n8n.io) (auto-heberge sur Railway recommande, ou n8n Cloud)
- Un compte [Twilio](https://twilio.com) (pour envoyer les SMS)
- Un compte [Brevo](https://brevo.com) (pour envoyer les emails — gratuit jusqu'a 300/jour)
- Une cle API [Claude](https://console.anthropic.com) (pour generer les messages personnalises — environ 0.001 EUR/lead)
- Des campagnes Google Ads avec des Lead Forms

**Cout par client :** environ 10-12 EUR/mois pour 30 leads.

---

## Mise en place pas a pas

### Etape 1 : Installer n8n

**Option recommandee — Railway (5-7 EUR/mois, illimite) :**

1. Aller sur [railway.app](https://railway.app)
2. Creer un compte
3. Chercher "n8n" dans les templates
4. Cliquer "Deploy" — n8n est installe en 5 minutes
5. Noter l'URL de votre instance (ex: `https://n8n-production-xxxx.up.railway.app`)

**Option alternative — n8n Cloud (20 EUR/mois) :**

1. Aller sur [n8n.io/cloud](https://n8n.io/cloud)
2. Creer un compte et choisir un plan
3. L'URL est fournie directement

### Etape 2 : Creer les comptes de services

**Twilio (SMS) :**

1. Creer un compte sur [twilio.com](https://twilio.com)
2. Aller dans "Messaging" > "Senders" > "Alphanumeric Sender ID"
3. Enregistrer un nom d'expediteur pour la France (ex: "DupontPlomb" — max 11 caracteres)
4. Acheter un numero de telephone francais (environ 1 EUR/mois)
5. Noter votre **Account SID** et **Auth Token** (visibles sur le dashboard)

**Brevo (Email) :**

1. Creer un compte gratuit sur [brevo.com](https://brevo.com)
2. Aller dans "Settings" > "SMTP & API" > "API Keys"
3. Creer une cle API et la noter

**Claude (IA) :**

1. Aller sur [console.anthropic.com](https://console.anthropic.com)
2. Creer un compte et ajouter un moyen de paiement
3. Aller dans "API Keys" et creer une cle
4. **Recommande :** Aller dans "Settings" > "Limits" et fixer un plafond a 20 EUR/mois

### Etape 3 : Configurer les variables d'environnement dans n8n

Dans n8n, aller dans **Settings** > **Variables** (ou Environment Variables sur Railway).

Ajouter ces variables pour chaque client. Exemple pour le client "Dupont Plomberie" :

| Variable | Valeur | Ou la trouver |
|----------|--------|---------------|
| `DUPONT_GOOGLE_KEY` | Le secret partage de votre Lead Form | Google Ads > Formulaire > Webhook |
| `DUPONT_TWILIO_ACCOUNT_SID` | `ACxxxxxxx...` | Dashboard Twilio |
| `DUPONT_TWILIO_AUTH_TOKEN` | `xxxxxxx...` | Dashboard Twilio |
| `DUPONT_TWILIO_SENDER_ID` | `DupontPlomb` | Twilio > Alphanumeric Sender |
| `ANTHROPIC_API_KEY` | `sk-ant-...` | Console Anthropic (partage entre clients) |
| `BREVO_API_KEY` | `xkeysib-...` | Brevo > API Keys (partage entre clients) |
| `BAPTISTE_PHONE` | `+336XXXXXXXX` | Votre numero perso au format international |

Pour un deuxieme client, remplacer `DUPONT_` par le prefixe du client (ex: `MARTIN_`).

### Etape 4 : Importer les workflows dans n8n

1. Dans n8n, cliquer sur **"..."** > **"Import from file"**
2. Importer les fichiers suivants **dans cet ordre** :
   - `workflows/speed-to-lead-error-handler.json` (en premier)
   - `workflows/speed-to-lead-core.json` (en deuxieme)
   - `workflows/speed-to-lead-entry-dupont-plomberie.json` (un par client)

3. **Apres l'import du Core Workflow :**
   - Aller dans Settings > Error Workflow
   - Selectionner "Speed to Lead — Error Handler"

4. **Apres l'import de chaque Entry Workflow :**
   - Ouvrir le noeud "Execute: Core Workflow"
   - Verifier qu'il pointe vers le workflow "Speed to Lead — Core"
   - Creer un credential "HTTP Basic Auth" pour Twilio (Account SID = username, Auth Token = password)

5. **Activer les workflows** (bouton ON/OFF en haut a droite) :
   - Activer l'Error Handler
   - Activer le Core Workflow
   - Activer chaque Entry Workflow

### Etape 5 : Connecter Google Ads

1. Dans Google Ads, ouvrir votre campagne
2. Aller dans le **formulaire de lead** (Lead Form Extension)
3. Dans les parametres du formulaire, activer le **Webhook**
4. Entrer l'URL du webhook :
   ```
   https://votre-instance-n8n.up.railway.app/webhook/dupont-plomberie
   ```
5. Entrer la **Google Key** (le meme secret que `DUPONT_GOOGLE_KEY`)
6. Envoyer un lead test depuis Google Ads pour verifier

### Etape 6 : Tester

Utiliser le script de test fourni :

```bash
# Tester avec le client par defaut (dupont-plomberie)
bash tests/test-webhook.sh https://votre-instance-n8n.up.railway.app

# Tester avec un autre client
bash tests/test-webhook.sh https://votre-instance-n8n.up.railway.app cabinet-martin
```

Verifier que :
- Le prospect recoit un SMS personnalise en moins de 2 minutes
- Le dirigeant recoit un SMS avec les infos du lead
- Un lead envoye 2 fois ne genere qu'un seul SMS

### Etape 7 : Monitoring (recommande)

**UptimeRobot (gratuit) :**

1. Creer un compte sur [uptimerobot.com](https://uptimerobot.com)
2. Ajouter un monitor HTTP(S) pointant vers votre URL webhook
3. Configurer l'alerte email — vous serez prevenu en 5 min si n8n tombe

---

## Ajouter un nouveau client

1. **Copier** un fichier config existant dans `config/` et l'adapter (nom, ville, metier, delais)
2. **Copier** un fichier entry workflow existant dans `workflows/` et remplacer :
   - Le slug dans le webhook (ex: `cabinet-martin`)
   - Le prefixe des variables d'environnement (ex: `MARTIN_`)
   - Les valeurs non-sensibles (nom entreprise, ville, metier)
3. **Ajouter** les variables d'environnement du nouveau client dans n8n
4. **Importer** le nouveau entry workflow dans n8n
5. **Connecter** le webhook dans Google Ads
6. **Activer** le workflow

Le Core Workflow n'a pas besoin d'etre modifie — il est partage entre tous les clients.

---

## Structure des fichiers

```
speed-to-lead/
├── workflows/
│   ├── speed-to-lead-core.json           # Workflow principal (partage)
│   ├── speed-to-lead-error-handler.json  # Fallback erreur
│   ├── speed-to-lead-entry-dupont-plomberie.json   # Client 1
│   └── speed-to-lead-entry-cabinet-martin.json     # Client 2
├── config/
│   ├── dupont-plomberie.json             # Config client 1
│   └── cabinet-martin.json              # Config client 2
├── prompts/
│   └── prospect-sms-fr.txt             # Prompt IA pour generer les SMS
└── tests/
    ├── payloads/                        # Donnees de test
    ├── test-webhook.sh                  # Script de test
    └── TESTING.md                       # Guide de test detaille
```

## Configuration par client

Chaque client a un fichier JSON dans `config/` avec :

| Champ | Description | Exemple |
|-------|-------------|---------|
| `client_slug` | Identifiant unique (dans l'URL webhook) | `dupont-plomberie` |
| `business_name` | Nom de l'entreprise | `Dupont Plomberie` |
| `service_type` | Metier (adapte le ton du SMS) | `plombier` |
| `city` | Ville | `Paris` |
| `owner_phone` | Telephone du dirigeant | `+33600000000` |
| `callback_promise_minutes` | Delai promis au prospect | `30` |
| `follow_up_delay_minutes` | Delai avant relance auto | `45` |
| `follow_up_enabled` | Activer la relance | `true` |

## RGPD

Le formulaire Google Ads de chaque client **doit** inclure une case a cocher (non pre-cochee) :

> "J'accepte d'etre contacte(e) par SMS par [Nom Entreprise] concernant ma demande."

Cette case est **obligatoire** avant la mise en production. Sans consentement explicite, l'envoi de SMS commerciaux en France est illegal (CNIL/CPCE).

## WhatsApp (optionnel)

Pour activer WhatsApp sur un client :

1. Enregistrer un numero WhatsApp Business via Twilio (WABA)
2. Soumettre un template de message a Meta pour approbation (1-3 jours)
3. Ajouter les variables `CLIENTSLUG_WHATSAPP_SENDER` et `CLIENTSLUG_WHATSAPP_TEMPLATE_SID` dans n8n
4. Passer `whatsapp_enabled` a `true` dans la config du client

---

**Developpe par Baptiste Simon** — Media Buyer Google/Meta Ads + Automatisations IA
