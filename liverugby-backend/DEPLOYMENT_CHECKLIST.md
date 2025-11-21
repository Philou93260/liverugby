# ✅ Checklist de déploiement - Notifications Push

## Avant le déploiement

- [ ] Firebase CLI installé : `npm install -g firebase-tools`
- [ ] Connecté à Firebase : `firebase login`
- [ ] Projet sélectionné : `firebase use PROJECT_ID`
- [ ] Clé API configurée : `firebase functions:config:set apisports.key="..."`
- [ ] Dépendances installées : `cd functions && npm install`

## Déploiement

```bash
cd /home/user/liverugby/liverugby-backend

# Déployer les fonctions et les règles
firebase deploy --only functions,firestore:rules
```

## Après le déploiement

### 1. Vérifier les fonctions déployées

```bash
firebase functions:list
```

Vous devriez voir :
- ✅ `createUserProfile`
- ✅ `registerFCMToken`
- ✅ `removeFCMToken`
- ✅ `updateNotificationPreferences`
- ✅ `manageFavoriteTeam`
- ✅ `onMatchUpdate` ⭐ (trigger principal)
- ✅ `sendDailyDigest`
- ✅ `getTodayMatches`
- ✅ `getLeagueMatches`
- ✅ `getTeamMatches`
- ✅ `getLeagueTeams`
- ✅ `getLeagueStandings`
- ✅ `searchTeams`
- ✅ `getMatchDetails`
- ✅ `updateMatchesDaily`
- ✅ `rugbyWebhook`

### 2. Activer Firebase Cloud Messaging

- [ ] Aller sur https://console.firebase.google.com
- [ ] Sélectionner le projet
- [ ] Paramètres du projet → Cloud Messaging
- [ ] Activer Cloud Messaging API
- [ ] Générer une clé VAPID pour le web
- [ ] Copier la clé VAPID (vous en aurez besoin côté client)

### 3. Configurer le webhook API-Sports

URL : `https://REGION-PROJET.cloudfunctions.net/rugbyWebhook`

Exemple : `https://europe-west1-liverugby-12345.cloudfunctions.net/rugbyWebhook`

En-têtes :
```
x-api-key: VOTRE_CLE_API_SPORTS
Content-Type: application/json
```

- [ ] Webhook configuré dans API-Sports
- [ ] Tester avec un événement test

### 4. Tester les fonctions

#### Test 1 : Enregistrer un token FCM

Depuis votre application client :
```javascript
const registerToken = httpsCallable(functions, 'registerFCMToken');
const result = await registerToken({ token: 'test-token-123' });
console.log(result); // { success: true, message: 'Token enregistré' }
```

#### Test 2 : Ajouter une équipe favorite

```javascript
const manageFavoriteTeam = httpsCallable(functions, 'manageFavoriteTeam');
const result = await manageFavoriteTeam({
  teamId: 123,
  action: 'add'
});
console.log(result); // { success: true, message: 'Équipe ajoutée' }
```

#### Test 3 : Vérifier les logs

```bash
# Voir les logs en temps réel
firebase functions:log

# Filtrer par fonction
firebase functions:log --only onMatchUpdate
```

### 5. Monitoring

- [ ] Vérifier les logs : `firebase functions:log`
- [ ] Consulter la console Firebase → Functions
- [ ] Vérifier Firestore → Voir les collections : `users`, `matches`, `live-events`

## Troubleshooting

### Problème : "Error: HTTP Error: 403, Permission denied"

**Solution :**
```bash
# Vérifier que vous êtes connecté au bon compte
firebase login --reauth

# Vérifier les permissions IAM dans Google Cloud Console
```

### Problème : "Missing configuration for apisports.key"

**Solution :**
```bash
firebase functions:config:set apisports.key="VOTRE_CLE"
# Puis redéployer
firebase deploy --only functions
```

### Problème : Les notifications ne sont pas envoyées

**Vérifications :**
1. Les utilisateurs ont-ils des tokens FCM enregistrés ?
   ```bash
   # Vérifier dans Firestore → users → fcmTokens
   ```

2. Les préférences de notification sont-elles activées ?
   ```bash
   # Vérifier dans Firestore → users → notificationPreferences
   ```

3. Le webhook reçoit-il les événements ?
   ```bash
   firebase functions:log --only rugbyWebhook
   ```

4. Le trigger onMatchUpdate se déclenche-t-il ?
   ```bash
   firebase functions:log --only onMatchUpdate
   ```

### Problème : Erreur "messaging/invalid-registration-token"

**Solution :** C'est normal, les tokens invalides sont automatiquement nettoyés. Vérifiez les logs pour voir le nettoyage.

## URLs importantes

- Console Firebase : https://console.firebase.google.com
- Logs Cloud Functions : https://console.cloud.google.com/functions/list
- Firestore Database : https://console.firebase.google.com/project/PROJECT_ID/firestore
- API-Sports Dashboard : https://dashboard.api-football.com/

## Commandes rapides

```bash
# Déployer rapidement
cd /home/user/liverugby/liverugby-backend && firebase deploy --only functions

# Voir les logs
firebase functions:log

# Voir la config
firebase functions:config:get

# Tester localement
firebase emulators:start --only functions,firestore

# Lister les projets
firebase projects:list

# Changer de projet
firebase use PROJECT_ID
```

## Support

Consultez la documentation complète dans `NOTIFICATIONS_PUSH.md`
