# LiveRugby Backend - Firebase Functions

Backend Firebase pour l'application LiveRugby avec intégration API-Sports Rugby.

## 📋 Configuration du projet

### Prérequis
- Node.js 20+
- Firebase CLI (`npm install -g firebase-tools`)
- Compte Firebase avec projet `liverugby-6f075`

### Installation

```bash
cd liverugby-backend/functions
npm install
```

### Configuration de la clé API

Configurez votre clé API-Sports :

```bash
firebase functions:config:set apisports.key="VOTRE_CLE_API_SPORTS"
```

Pour vérifier la configuration :

```bash
firebase functions:config:get
```

## 🚀 Déploiement

### Déployer toutes les fonctions

```bash
firebase deploy --only functions
```

### Déployer les règles de sécurité

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
```

### Déployer tout

```bash
firebase deploy
```

## 🔧 Développement local

### Lancer les émulateurs

```bash
cd liverugby-backend
firebase emulators:start
```

Les émulateurs seront disponibles sur :
- Functions: http://localhost:5001
- Firestore: http://localhost:8080
- Auth: http://localhost:9099
- Storage: http://localhost:9199
- UI des émulateurs: http://localhost:4000

## 📦 Fonctions disponibles

### Gestion utilisateurs
- `createUserProfile` - Crée automatiquement un profil lors de l'inscription (Auth Trigger)
- `deleteUserData` - Nettoie les données lors de la suppression d'un compte (Auth Trigger)
- `sendWelcomeEmail` - Envoie un email de bienvenue (Firestore Trigger)

### API Rugby (API-Sports)
- `getTodayMatches` - Récupère les matchs du jour avec cache (5 min)
- `getLeagueMatches` - Récupère les matchs d'une ligue
- `getTeamMatches` - Récupère les matchs d'une équipe
- `getLeagueTeams` - Récupère les équipes d'une ligue
- `getLeagueStandings` - Récupère le classement d'une ligue
- `searchTeams` - Recherche des équipes par nom
- `getMatchDetails` - Récupère les détails d'un match

### Tâches automatisées
- `cleanOldData` - Nettoie les données temporaires (quotidien à 6h)
- `updateMatchesDaily` - Met à jour les matchs (quotidien à 6h)

### Webhooks
- `rugbyWebhook` - Reçoit les événements en temps réel d'API-Sports
- `api` - Endpoint API de base

## 🔒 Améliorations de sécurité

### ✅ Fichiers créés
- `.firebaserc` - Configuration du projet Firebase
- `storage.rules` - Règles de sécurité Storage

### ✅ Sécurité renforcée

#### 1. Règles Firestore améliorées
- ✅ Validation des données utilisateur
- ✅ Fonctions helpers pour l'authentification
- ✅ Protection des collections (matches, leagues, live-events)
- ✅ Accès contrôlé par utilisateur pour les favoris
- ✅ Blocage par défaut pour toutes les routes non définies

#### 2. CORS sécurisé
- ✅ Liste blanche de domaines autorisés
- ✅ Pas d'accès `*` (tous les domaines)
- ✅ Support localhost pour développement

**Domaines autorisés :**
- `http://localhost:3000` (dev)
- `http://localhost:5000` (dev)
- `https://liverugby-6f075.web.app`
- `https://liverugby-6f075.firebaseapp.com`

#### 3. Validation webhook sécurisée
- ✅ Comparaison timing-safe (évite timing attacks)
- ✅ Validation de la méthode HTTP (POST uniquement)
- ✅ Validation du payload
- ✅ Logs des tentatives d'accès non autorisées

#### 4. Validation des données
Toutes les fonctions Rugby API valident maintenant :
- ✅ `leagueId` : Nombre positif valide
- ✅ `teamId` : Nombre positif valide
- ✅ `season` : Année entre 2000-2100
- ✅ `teamName` : Chaîne de 2-100 caractères

#### 5. Gestion d'erreurs robuste
- ✅ Retry logic avec exponential backoff (3 tentatives max)
- ✅ Cache intelligent (5 minutes)
- ✅ Fallback sur cache ancien si API échoue
- ✅ Timeout de 10 secondes sur les requêtes API
- ✅ Logs structurés avec contexte

## 🔑 Variables d'environnement

### Configuration requise

```bash
# Clé API Sports
firebase functions:config:set apisports.key="VOTRE_CLE_API"
```

### Pour le développement local

Créez `.runtimeconfig.json` dans le dossier `functions/` :

```json
{
  "apisports": {
    "key": "VOTRE_CLE_API_SPORTS"
  }
}
```

⚠️ **N'oubliez pas d'ajouter `.runtimeconfig.json` au `.gitignore` !**

## 📊 Structure du projet

```
liverugby-backend/
├── .firebaserc              # Configuration du projet
├── firebase.json            # Configuration Firebase
├── firestore.rules          # Règles de sécurité Firestore
├── firestore.indexes.json   # Index Firestore
├── storage.rules            # Règles de sécurité Storage
├── README.md               # Cette documentation
└── functions/
    ├── package.json        # Dépendances
    ├── index.js            # Fonctions principales
    └── rugby-api.js        # API Rugby
```

## 🗄️ Collections Firestore

### `users/{userId}`
Profils utilisateurs avec paramètres

### `matches/{date}`
Cache des matchs par date (YYYY-MM-DD)

### `leagues/{leagueId}`
Cache des ligues et équipes

### `live-events/{eventId}`
Événements en temps réel des matchs

### `temporaryData/{docId}`
Données temporaires (nettoyées après 30 jours)

### `users/{userId}/favorites/{favoriteId}`
Équipes favorites de l'utilisateur

## 🔥 Règles Storage

### Avatars utilisateurs
- Chemin : `/users/{userId}/avatar/{fileName}`
- Lecture : Public
- Écriture : Propriétaire uniquement
- Limite : 5MB, images uniquement

### Fichiers privés
- Chemin : `/users/{userId}/private/**`
- Lecture/Écriture : Propriétaire uniquement
- Limite : 10MB

### Fichiers publics
- Chemin : `/public/**`
- Lecture : Tout le monde
- Écriture : Utilisateurs authentifiés
- Limite : 10MB

## ⚡ Performance

### Cache système
- Les matchs du jour sont cachés pendant 5 minutes
- Fallback automatique sur cache ancien si API échoue
- Les équipes des ligues sont mises en cache dans Firestore

### Retry Logic
- 3 tentatives maximum
- Exponential backoff (1s, 2s, 4s)
- Pas de retry pour les erreurs 4xx (sauf 429)

## 📝 Logs et monitoring

### Voir les logs en production

```bash
firebase functions:log
```

### Logs par fonction

```bash
firebase functions:log --only getTodayMatches
```

## 🧪 Tests

### Tests locaux avec émulateurs

```bash
firebase emulators:start
```

### Tester une fonction callable

```javascript
const functions = firebase.functions();
const getTodayMatches = functions.httpsCallable('getTodayMatches');

getTodayMatches()
  .then(result => console.log(result.data))
  .catch(error => console.error(error));
```

## 🛡️ Checklist de sécurité

- [x] Règles Firestore sécurisées
- [x] Règles Storage sécurisées
- [x] CORS restreint aux domaines autorisés
- [x] Validation des paramètres d'entrée
- [x] Webhook sécurisé avec timing-safe comparison
- [x] Clé API en variables d'environnement
- [x] Authentification requise pour toutes les fonctions Rugby
- [x] Rate limiting (via Firebase)
- [x] Timeout sur les requêtes API externes
- [x] Logs des tentatives d'accès non autorisées

## 📖 Documentation API-Sports

Documentation officielle : https://api-sports.io/documentation/rugby/v1

## 🆘 Support

En cas de problème :
1. Vérifiez les logs : `firebase functions:log`
2. Vérifiez la configuration : `firebase functions:config:get`
3. Testez avec les émulateurs locaux
4. Vérifiez votre quota API-Sports

## 🔄 Mises à jour

Pour mettre à jour le backend :

```bash
cd liverugby-backend/functions
npm update
firebase deploy --only functions
```

---

**Version :** 1.0.0 (Améliorée)
**Dernière mise à jour :** 2025-11-14
**Project ID :** liverugby-6f075
