# Disclaimers et Informations Importantes pour Google Play

## ⚠️ IMPORTANT - Conformité Google Play

### Nature de l'Application
**Le P'tit Cash** est une application de jeu et divertissement. Tous les points, récompenses et monnaies mentionnés dans l'application sont **VIRTUELS** et n'ont **AUCUNE VALEUR MONÉTAIRE RÉELLE**.

### Avertissements Requis

1. **Aucun Gain d'Argent Réel**
   - Les points "PtitCoins" sont une monnaie virtuelle de jeu
   - Aucun paiement PayPal réel n'est effectué
   - Aucune carte cadeau réelle n'est distribuée
   - Les "récompenses" sont des déblocages de contenu dans l'application uniquement

2. **Publicités**
   - L'application contient des publicités via Google AdMob
   - Les publicités peuvent être personnalisées selon vos préférences
   - Vous pouvez désactiver la personnalisation dans les paramètres de votre appareil

3. **Données Collectées**
   - Adresse email (authentification)
   - Progression de jeu
   - Identifiant publicitaire
   - Voir privacy_policy.html pour plus de détails

4. **Contenu Tiers**
   - BitLabs : enquêtes de recherche légitime
   - Les enquêtes BitLabs peuvent offrir des points virtuels dans l'app

### Modifications à Effectuer Avant Publication

#### Dans le Google Play Console :

1. **Catégorie de l'App**
   - Choisir: "Jeux > Décontracté" ou "Arcade"
   - NE PAS choisir "Productivité" ou "Finance"

2. **Description de l'App**
   - Mentionner clairement : "Application de divertissement avec monnaie virtuelle"
   - Éviter : "gagner de l'argent", "cash", "gains réels", "PayPal"
   - Utiliser : "points de jeu", "récompenses virtuelles", "débloquer du contenu"

3. **Questionnaire de Contenu**
   - Gambling/Paris : NON (pas d'argent réel)
   - Publicités : OUI (AdMob)
   - Achats intégrés : Si vous en avez
   - Collecte de données : OUI (voir privacy policy)

4. **Politique de Confidentialité**
   - URL à fournir : https://[VOTRE-DOMAINE]/privacy_policy.html
   - Assurez-vous que le fichier privacy_policy.html est hébergé et accessible

5. **Public Cible**
   - Âge minimum : 13+ ou 16+ (selon COPPA/RGPD)
   - Préciser : Application générale, pas pour enfants

6. **Permissions à Justifier**
   - INTERNET : Pour publicités et fonctionnalités en ligne
   - (CAMERA supprimée - non nécessaire)

### Textes Conformes pour la Description Google Play

#### Titre (30 caractères max)
```
Le P'tit Cash - Jeu de Points
```

#### Description Courte (80 caractères max)
```
Jeu amusant pour collecter des points virtuels et débloquer des récompenses!
```

#### Description Longue
```
🎮 Le P'tit Cash - Jeu de Récompenses Virtuelles

Amusez-vous avec nos mini-jeux et collectez des PtitCoins (points virtuels) !

✨ Fonctionnalités :
• 🎯 Mini-jeux variés (Clicker, Memory, Cartes à gratter)
• 🏆 Système de niveaux et progression
• 🎁 Boutique de récompenses virtuelles
• 📊 Classement hebdomadaire
• 🎯 Missions quotidiennes
• 🔥 Système de séries

🎁 Débloquez :
• Badges exclusifs
• Avatars premium
• Thèmes colorés
• Bonus multiplicateurs

⚠️ IMPORTANT :
Cette application est à but de divertissement uniquement. Les PtitCoins sont une monnaie virtuelle de jeu sans valeur monétaire réelle. Les récompenses sont des déblocages de contenu dans l'application.

📱 Fonctionnalités en ligne :
• Sauvegarde cloud de votre progression
• Classements mondiaux
• Enquêtes partenaires (BitLabs)

L'application contient des publicités (Google AdMob).

🔒 Vos données sont protégées conformément au RGPD.
Consultez notre politique de confidentialité complète dans l'application.

Amusez-vous et collectez un maximum de PtitCoins ! 🎉
```

### Captures d'Écran Recommandées

1. Écran d'accueil avec solde de points
2. Mini-jeu en action
3. Boutique de récompenses (avec disclaimer visible)
4. Classement
5. Profil utilisateur

**Assurez-vous qu'aucune capture ne montre :**
- Montants en $ ou €
- Mentions de PayPal
- Cartes cadeaux réelles
- Promesses d'argent réel

### Checklist Finale Avant Soumission

- [ ] Permission CAMERA supprimée
- [ ] Textes modifiés (pas de mention d'argent réel)
- [ ] Privacy policy hébergée et URL ajoutée
- [ ] Description conforme ajoutée
- [ ] Catégorie = Jeux
- [ ] Disclaimers visibles dans l'app
- [ ] Captures d'écran sans mentions d'argent réel
- [ ] Version de test fonctionnelle
- [ ] Gradle version ≥ 8.11.1
- [ ] TargetSDK ≥ 33 (Android 13)

### Raisons Courantes de Rejet

1. ❌ **Promesses d'argent réel** → Corrigé (transformé en points virtuels)
2. ❌ **Permissions non justifiées** → Corrigé (CAMERA supprimée)
3. ❌ **Politique de confidentialité manquante** → Corrigé (privacy_policy.html créé)
4. ❌ **Icônes suggérant gambling** → Corrigé (casino → card_giftcard)
5. ❌ **Catégorie inappropriée** → À vérifier dans console
6. ❌ **Description trompeuse** → À modifier avec textes fournis
7. ❌ **Données sensibles non déclarées** → À déclarer dans questionnaire

### Support

Pour toute question sur la conformité, consultez :
- [Politique Google Play - Apps de récompense](https://support.google.com/googleplay/android-developer/answer/9888379)
- [Politique de contenu Google Play](https://support.google.com/googleplay/android-developer/topic/9858052)

---

**Dernière mise à jour :** 3 janvier 2026
**Version minimum SDK requise :** 21
**Version cible SDK :** 34
**Gradle minimum :** 8.11.1
