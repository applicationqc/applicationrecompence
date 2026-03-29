# Configuration Tremendous - Distribution Automatique de Cartes Cadeaux

## Étapes de Configuration

### 1. Créer un Compte Tremendous
1. Allez sur https://www.tremendous.com/
2. Cliquez sur "Get Started" ou "Sign Up"
3. Remplissez le formulaire d'inscription
4. Vérifiez votre email

### 2. Configurer votre Compte
1. Connectez-vous à votre compte Tremendous
2. Ajoutez des fonds à votre compte (Menu: Funding)
   - Carte de crédit
   - Virement bancaire
   - Solde minimum recommandé: 500$ CAD

### 3. Obtenir votre Clé API
1. Allez dans **Settings** > **API Keys**
2. Cliquez sur **"Create API Key"**
3. Copiez votre clé API (commence par `TEST_` pour le mode test)
4. **IMPORTANT**: Gardez cette clé secrète et sécurisée!

### 4. Créer une Campagne
1. Allez dans **Campaigns**
2. Cliquez sur **"Create Campaign"**
3. Nom: "Le P'tit Cash Rewards"
4. Copiez le **Campaign ID** (format: `CXXXXXXXXXX`)

### 5. Configurer l'App
Ouvrez le fichier: `lib/services/tremendous_service.dart`

Remplacez les valeurs suivantes:

```dart
// Ligne 7: Remplacer par votre clé API
static const String _apiKey = 'VOTRE_CLE_API_ICI';

// Ligne 42: Remplacer par votre Campaign ID
'campaign_id': 'VOTRE_CAMPAIGN_ID_ICI',

// Ligne 94: Même Campaign ID pour PayPal
'campaign_id': 'VOTRE_CAMPAIGN_ID_ICI',
```

### 6. Mode Test vs Production

**Mode Test (Développement):**
```dart
static const String _baseUrl = 'https://testflight.tremendous.com/api/v2';
```
- Utilise des fonds fictifs
- Aucun email envoyé réellement
- Pour tester l'intégration

**Mode Production (Après tests):**
```dart
static const String _baseUrl = 'https://www.tremendous.com/api/v2';
```
- Utilise de vrais fonds
- Envoie de vraies cartes cadeaux
- À utiliser seulement quand tout est testé!

### 7. Produits Disponibles

Cartes cadeaux pré-configurées dans l'app:
- **Amazon.ca**: ID `QEVAW8LSGMJ4`
- **Google Play**: ID `Q24BD9EZ3E7D`
- **iTunes/App Store**: ID `QPM9EZP6VD4E`
- **PayPal**: ID `Q24BD4EKV4EK`

### 8. Coûts

**Commission Tremendous:**
- 3-5% par transaction
- Exemple: Carte de 25$ = 25$ + ~1.25$ = 26.25$ total

**Calcul pour Le P'tit Cash:**
- Utilisateur gagne: 25$ en points
- Coût carte: 25$
- Commission Tremendous: ~1.25$
- **Total coût pour vous**: 26.25$

### 9. Sécurité

**⚠️ IMPORTANT:**
1. Ne JAMAIS partager votre clé API
2. Ne JAMAIS commit la clé dans Git
3. Utiliser des variables d'environnement en production
4. Surveiller les transactions dans le dashboard Tremendous

### 10. Test de l'Intégration

Une fois configuré, testez:
1. Lancez l'app
2. Accédez à Withdrawals
3. Sélectionnez une carte cadeau
4. Complétez une demande
5. Vérifiez dans le dashboard Tremendous que la commande apparaît
6. En mode test, l'email ne sera pas envoyé mais la commande sera créée

### 11. Passage en Production

Quand tout fonctionne en test:
1. Changez `_baseUrl` vers production
2. Générez une nouvelle clé API de production
3. Ajoutez suffisamment de fonds
4. Activez les webhooks pour recevoir les notifications
5. Testez avec un petit montant réel

### 12. Surveillance

Dashboard Tremendous vous permet de:
- Voir toutes les transactions
- Télécharger les rapports
- Vérifier le solde
- Voir les cartes envoyées
- Gérer les remboursements

### Support Tremendous
- Email: support@tremendous.com
- Documentation: https://developers.tremendous.com/
- Chat en direct dans le dashboard

---

**Questions fréquentes:**

**Q: Combien ça coûte?**
R: 3-5% de commission + le montant de la carte

**Q: Quand l'utilisateur reçoit la carte?**
R: Instantanément par email après la transaction

**Q: Puis-je tester sans payer?**
R: Oui, utilisez le mode testflight

**Q: Quelles devises sont supportées?**
R: CAD, USD, EUR, GBP, et autres

**Q: Y a-t-il un montant minimum?**
R: 1$ minimum par carte

**Q: Puis-je automatiser les paiements PayPal aussi?**
R: Oui, Tremendous supporte PayPal!
