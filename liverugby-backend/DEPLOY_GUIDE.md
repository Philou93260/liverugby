# 🚀 Guide de déploiement - LiveRugby Backend

Guide complet pour déployer votre backend Firebase en production.

---

## ⚡ Déploiement rapide (Automatique)

**Option recommandée si vous êtes sur macOS/Linux :**

```bash
cd liverugby-backend
./deploy.sh
```

Le script fera tout automatiquement ! Suivez simplement les instructions à l'écran.

---

## 📋 Déploiement manuel (Étape par étape)

### Prérequis

✅ **Node.js** installé (version 18+)
✅ **npm** installé
✅ **Firebase CLI** installé
✅ **Compte Google** avec accès au projet Firebase

---

## ÉTAPE 1 : Installer Firebase CLI

### macOS / Linux

```bash
npm install -g firebase-tools
```

### Windows

```powershell
npm install -g firebase-tools
```

### Vérifier l'installation

```bash
firebase --version
```

Vous devriez voir quelque chose comme : `13.x.x`

---

## ÉTAPE 2 : Authentification Firebase

### Se connecter à Firebase

```bash
firebase login
```

- Une page web s'ouvrira
- Connectez-vous avec votre compte Google
- Autorisez Firebase CLI

### Vérifier l'accès au projet

```bash
firebase projects:list
```

Vous devriez voir `liverugby-6f075` dans la liste.

---

## ÉTAPE 3 : Configuration de la clé API-Sports

⚠️ **IMPORTANT** : Cette étape est obligatoire pour que les fonctions Rugby fonctionnent !

### Configurer la clé

```bash
firebase functions:config:set apisports.key="cc235d58ce04e8ed2b057dfe4b169783" --project liverugby-6f075
```

### Vérifier la configuration

```bash
firebase functions:config:get --project liverugby-6f075
```

Vous devriez voir :

```json
{
  "apisports": {
    "key": "cc235d58ce04e8ed2b057dfe4b169783"
  }
}
```

---

## ÉTAPE 4 : Installer les dépendances

```bash
cd liverugby-backend/functions
npm install
cd ..
```

Vous devriez voir :

```
added 530 packages
found 0 vulnerabilities
```

---

## ÉTAPE 5 : Déploiement

### Option A : Déployer tout (Recommandé)

```bash
firebase deploy --project liverugby-6f075
```

Cela déploiera :
- ✅ Cloud Functions (16 fonctions)
- ✅ Règles Firestore
- ✅ Règles Storage
- ✅ Index Firestore

**Durée estimée :** 3-5 minutes

### Option B : Déployer seulement les fonctions

```bash
firebase deploy --only functions --project liverugby-6f075
```

**Durée estimée :** 2-3 minutes

### Option C : Déployer seulement les règles

```bash
firebase deploy --only firestore:rules,storage:rules --project liverugby-6f075
```

**Durée estimée :** 10-20 secondes

---

## ÉTAPE 6 : Vérification du déploiement

### Vérifier les fonctions déployées

```bash
firebase functions:list --project liverugby-6f075
```

Vous devriez voir 16 fonctions :

```
┌────────────────────────────────┬────────────────────┐
│ Function Name                  │ Status             │
├────────────────────────────────┼────────────────────┤
│ createUserProfile              │ DEPLOYED           │
│ deleteUserData                 │ DEPLOYED           │
│ sendWelcomeEmail               │ DEPLOYED           │
│ api                            │ DEPLOYED           │
│ cleanOldData                   │ DEPLOYED           │
│ getTodayMatches                │ DEPLOYED           │
│ getLeagueMatches               │ DEPLOYED           │
│ getTeamMatches                 │ DEPLOYED           │
│ getLeagueTeams                 │ DEPLOYED           │
│ getLeagueStandings             │ DEPLOYED           │
│ searchTeams                    │ DEPLOYED           │
│ getMatchDetails                │ DEPLOYED           │
│ updateMatchesDaily             │ DEPLOYED           │
│ rugbyWebhook                   │ DEPLOYED           │
│ registerFCMToken               │ DEPLOYED           │
│ unregisterFCMToken             │ DEPLOYED           │
│ subscribeToMatch               │ DEPLOYED           │
│ unsubscribeFromMatch           │ DEPLOYED           │
│ addFavoriteTeam                │ DEPLOYED           │
│ monitorLiveMatches             │ DEPLOYED           │
│ notifyFavoriteTeamsMatches     │ DEPLOYED           │
└────────────────────────────────┴────────────────────┘
```

### Voir les logs en temps réel

```bash
firebase functions:log --project liverugby-6f075
```

### Tester une fonction

Allez sur [Firebase Console](https://console.firebase.google.com/project/liverugby-6f075/functions)

---

## 🎉 Déploiement terminé !

### ✅ Ce qui a été déployé

**16 Cloud Functions :**
- 3 fonctions de gestion utilisateurs
- 9 fonctions API Rugby
- 7 fonctions notifications push
- 3 tâches automatisées (cron)
- 2 webhooks

**Règles de sécurité :**
- Firestore rules (protection des collections)
- Storage rules (protection des fichiers)

**Index Firestore :**
- Optimisation des requêtes

---

## 🔧 Configuration post-déploiement

### 1. Configurer APNs pour iOS (Obligatoire pour les notifications)

⚠️ **Sans APNs, les notifications push ne fonctionneront pas sur iOS !**

**Étapes :**

1. Allez sur [Firebase Console](https://console.firebase.google.com/project/liverugby-6f075/settings/cloudmessaging)

2. Section **iOS app configuration**

3. **Créer une clé APNs :**
   - Allez sur [Apple Developer](https://developer.apple.com/account/)
   - Certificates, IDs & Profiles > Keys
   - Créez une nouvelle clé avec **Apple Push Notifications service (APNs)**
   - Téléchargez le fichier .p8 (⚠️ Une seule chance de télécharger !)

4. **Uploader dans Firebase :**
   - Uploadez le fichier .p8
   - Entrez votre **Key ID** (visible sur Apple Developer)
   - Entrez votre **Team ID** (visible sur Apple Developer)

5. Cliquez sur **Upload**

✅ Les notifications push sont maintenant activées !

### 2. Télécharger GoogleService-Info.plist pour iOS

1. Firebase Console > Paramètres du projet
2. Section **Vos applications** > iOS
3. Téléchargez **GoogleService-Info.plist**
4. Ajoutez ce fichier à votre projet Xcode

### 3. Activer les APIs Firebase nécessaires

Si ce n'est pas déjà fait, activez :

- ✅ Authentication (Email/Password)
- ✅ Firestore Database
- ✅ Storage
- ✅ Cloud Functions
- ✅ Cloud Messaging

---

## 📱 Intégration iOS

Suivez le guide complet : [IOS_PUSH_NOTIFICATIONS.md](./IOS_PUSH_NOTIFICATIONS.md)

**Résumé rapide :**

1. Installer les pods Firebase
2. Configurer AppDelegate
3. Demander permissions notifications
4. Enregistrer le token FCM après login
5. Tester sur device physique

---

## 🧪 Tester le backend

### Test 1 : Vérifier que les fonctions répondent

```bash
# Via Firebase Console
# Allez sur : https://console.firebase.google.com/project/liverugby-6f075/functions
# Cliquez sur une fonction > Onglet "Logs"
```

### Test 2 : Appeler une fonction depuis votre app

```swift
// Dans votre app iOS
let functions = Functions.functions()
let getTodayMatches = functions.httpsCallable("getTodayMatches")

getTodayMatches().continueWith { task in
    if let error = task.error {
        print("Error:", error)
    } else if let result = task.result?.data as? [String: Any] {
        print("Success:", result)
    }
}
```

### Test 3 : Vérifier le monitoring automatique

Les fonctions `monitorLiveMatches` et `updateMatchesDaily` s'exécutent automatiquement :

- `monitorLiveMatches` : Toutes les minutes
- `updateMatchesDaily` : Tous les jours à 6h
- `notifyFavoriteTeamsMatches` : Tous les jours à 8h

**Voir les logs :**

```bash
firebase functions:log --only monitorLiveMatches --project liverugby-6f075
```

---

## 🐛 Dépannage

### Erreur : "Command not found: firebase"

**Solution :** Installer Firebase CLI

```bash
npm install -g firebase-tools
```

### Erreur : "Permission denied"

**Solution :** Vérifier que vous êtes connecté

```bash
firebase login
firebase projects:list
```

### Erreur : "Billing account required"

**Solution :** Firebase Functions nécessite le plan Blaze (pay-as-you-go)

1. Allez sur [Firebase Console](https://console.firebase.google.com/project/liverugby-6f075/usage)
2. Passez au plan Blaze
3. Configurez un budget (ex: 10€/mois) pour éviter les surprises

**💡 Note :** Le plan gratuit inclut :
- 2 millions d'invocations/mois
- 400 000 Go-secondes de calcul/mois
- 200 Go-secondes de réseau/mois

C'est largement suffisant pour commencer !

### Erreur : "Error parsing triggers"

**Solution :** Vérifier la syntaxe dans functions/index.js

```bash
cd functions
npm run lint  # Si vous avez configuré un linter
node index.js  # Tester qu'il n'y a pas d'erreur de syntaxe
```

### Erreur : "The caller does not have permission"

**Solution :** Vérifier les permissions IAM

1. Firebase Console > Paramètres du projet > Utilisateurs et autorisations
2. Vérifiez que votre compte a le rôle **Éditeur** ou **Propriétaire**

### Les notifications ne marchent pas

**Checklist :**

- ✅ APNs configuré dans Firebase Console ?
- ✅ GoogleService-Info.plist dans le projet Xcode ?
- ✅ Capabilities activées (Push Notifications, Background Modes) ?
- ✅ Token FCM enregistré après login ?
- ✅ Test sur device physique (pas simulateur) ?
- ✅ Permissions notifications accordées ?

**Voir les logs :**

```bash
firebase functions:log --only monitorLiveMatches,registerFCMToken --project liverugby-6f075
```

---

## 📊 Monitoring et Logs

### Voir tous les logs

```bash
firebase functions:log --project liverugby-6f075
```

### Logs d'une fonction spécifique

```bash
firebase functions:log --only getTodayMatches --project liverugby-6f075
```

### Logs en temps réel

```bash
firebase functions:log --project liverugby-6f075 --follow
```

### Dashboard Firebase

Allez sur : https://console.firebase.google.com/project/liverugby-6f075/functions

Vous verrez :
- 📊 Nombre d'invocations
- ⏱️ Temps d'exécution
- ❌ Taux d'erreur
- 💰 Coûts estimés

---

## 🔄 Mettre à jour le backend

### Après avoir modifié le code

```bash
# 1. Tester localement (optionnel)
firebase emulators:start

# 2. Déployer
firebase deploy --project liverugby-6f075
```

### Déployer seulement une fonction

```bash
firebase deploy --only functions:getTodayMatches --project liverugby-6f075
```

---

## 💰 Coûts estimés

**Plan Blaze (pay-as-you-go) :**

Avec votre configuration actuelle (monitoring chaque minute) :

- **Invocations** : ~45 000/mois (monitoring) + usage utilisateurs
- **Calcul** : ~2-3 Go-secondes par invocation
- **Réseau** : ~1 Mo par invocation API Rugby

**Estimation mensuelle :** 0-5€ pour démarrer

**Pour réduire les coûts :**

1. Augmenter l'intervalle de monitoring (5 min au lieu de 1 min)
2. Optimiser le cache (déjà fait !)
3. Limiter les appels API externes (déjà fait avec retry logic)

---

## 🎯 Checklist finale

Avant de dire "C'est déployé !" :

- [ ] Firebase CLI installé
- [ ] Connecté avec `firebase login`
- [ ] Dépendances installées (`npm install` dans functions/)
- [ ] Clé API configurée (`functions:config:set`)
- [ ] Déployé avec succès (`firebase deploy`)
- [ ] 16 fonctions visibles dans la console
- [ ] APNs configuré (pour iOS)
- [ ] GoogleService-Info.plist téléchargé
- [ ] Testé au moins une fonction
- [ ] Plan Blaze activé

---

## 📚 Ressources

- [Firebase Console](https://console.firebase.google.com/project/liverugby-6f075)
- [Documentation Cloud Functions](https://firebase.google.com/docs/functions)
- [API-Sports Documentation](https://api-sports.io/documentation/rugby/v1)
- [Guide iOS](./IOS_PUSH_NOTIFICATIONS.md)
- [README](./README.md)

---

## 🆘 Besoin d'aide ?

**Problème de déploiement ?**
- Consultez les logs : `firebase functions:log`
- Vérifiez la console Firebase
- Lisez la section Dépannage ci-dessus

**Problème de code ?**
- Consultez les exemples dans README.md
- Consultez IOS_PUSH_NOTIFICATIONS.md pour l'intégration iOS

---

**Version :** 1.0.0
**Dernière mise à jour :** 2025-11-14
**Project ID :** liverugby-6f075

Bon déploiement ! 🚀
