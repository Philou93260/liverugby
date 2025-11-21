# Système de Notifications Push - Live Rugby

## Vue d'ensemble

Le système de notifications push permet d'envoyer des alertes en temps réel aux utilisateurs de l'application pour :
- Démarrage de matchs
- Mises à jour des scores
- Fin de matchs
- Résumés quotidiens des matchs

## Architecture

### 1. Composants principaux

#### `notification-helpers.js`
Module contenant les fonctions utilitaires pour :
- Envoyer des notifications via Firebase Cloud Messaging (FCM)
- Récupérer les utilisateurs selon leurs préférences
- Créer des messages de notification formatés
- Nettoyer les tokens invalides

#### Fonctions Cloud Functions

**Gestion des tokens FCM :**
- `registerFCMToken` - Enregistrer un token FCM pour un utilisateur
- `removeFCMToken` - Supprimer un token FCM
- `updateNotificationPreferences` - Mettre à jour les préférences de notification
- `manageFavoriteTeam` - Ajouter/Retirer des équipes favorites

**Triggers automatiques :**
- `onMatchUpdate` - Déclenché lors de nouveaux événements dans `live-events`
- `sendDailyDigest` - Envoi quotidien à 8h du résumé des matchs

**Webhook :**
- `rugbyWebhook` - Réception des événements en temps réel d'API-Sports

### 2. Structure des données utilisateur

```javascript
{
  uid: "user123",
  email: "user@example.com",
  fcmTokens: ["token1", "token2"], // Tokens des appareils
  notificationPreferences: {
    matchStart: true,        // Notifications de début de match
    scoreUpdate: true,       // Notifications de score
    matchEnd: true,          // Notifications de fin de match
    favoriteTeams: true,     // Notifications pour équipes favorites
    dailyDigest: false       // Résumé quotidien
  },
  favoriteTeams: [123, 456], // IDs des équipes favorites
  favoriteLeagues: [1, 2]    // IDs des ligues favorites
}
```

## Utilisation côté client

### 1. Enregistrer un token FCM

```javascript
import { getFunctions, httpsCallable } from 'firebase/functions';
import { getMessaging, getToken } from 'firebase/messaging';

const functions = getFunctions();
const messaging = getMessaging();

// Obtenir le token FCM
const token = await getToken(messaging, {
  vapidKey: 'VOTRE_VAPID_KEY'
});

// Enregistrer le token
const registerToken = httpsCallable(functions, 'registerFCMToken');
await registerToken({ token });
```

### 2. Ajouter une équipe favorite

```javascript
const manageFavoriteTeam = httpsCallable(functions, 'manageFavoriteTeam');

// Ajouter une équipe
await manageFavoriteTeam({
  teamId: 123,
  action: 'add'
});

// Retirer une équipe
await manageFavoriteTeam({
  teamId: 123,
  action: 'remove'
});
```

### 3. Mettre à jour les préférences

```javascript
const updatePreferences = httpsCallable(functions, 'updateNotificationPreferences');

await updatePreferences({
  preferences: {
    matchStart: true,
    scoreUpdate: false,
    matchEnd: true,
    favoriteTeams: true,
    dailyDigest: true
  }
});
```

### 4. Écouter les notifications en avant-plan

```javascript
import { onMessage } from 'firebase/messaging';

onMessage(messaging, (payload) => {
  console.log('Notification reçue:', payload);

  const { title, body } = payload.notification;
  const { matchId, type, homeTeamId, awayTeamId } = payload.data;

  // Afficher la notification
  new Notification(title, {
    body,
    icon: '/logo.png',
    data: { matchId, type }
  });
});
```

## Configuration Firebase

### 1. Activer Firebase Cloud Messaging

1. Allez dans la console Firebase
2. Paramètres du projet > Cloud Messaging
3. Générer une clé VAPID pour le web
4. Activer l'API Cloud Messaging

### 2. Configuration du service worker

Créer `firebase-messaging-sw.js` à la racine :

```javascript
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "...",
  authDomain: "...",
  projectId: "...",
  storageBucket: "...",
  messagingSenderId: "...",
  appId: "..."
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification;

  self.registration.showNotification(title, {
    body,
    icon: '/logo.png'
  });
});
```

### 3. Demander la permission

```javascript
const requestPermission = async () => {
  const permission = await Notification.requestPermission();

  if (permission === 'granted') {
    console.log('Permission accordée');
    // Enregistrer le token
  } else {
    console.log('Permission refusée');
  }
};
```

## Déploiement

### 1. Installer les dépendances

```bash
cd liverugby-backend/functions
npm install
```

### 2. Configurer la clé API

```bash
firebase functions:config:set apisports.key="VOTRE_CLE_API"
```

### 3. Déployer les fonctions

```bash
firebase deploy --only functions
```

### 4. Déployer les règles Firestore

```bash
firebase deploy --only firestore:rules
```

## Webhook API-Sports

Pour recevoir les événements en temps réel :

1. Configurer le webhook dans API-Sports dashboard
2. URL du webhook : `https://REGION-PROJET.cloudfunctions.net/rugbyWebhook`
3. Ajouter l'en-tête : `x-api-key: VOTRE_CLE_API`

## Monitoring et Logs

### Voir les logs des fonctions

```bash
firebase functions:log
```

### Statistiques des notifications

Les logs affichent :
- Nombre de notifications envoyées avec succès
- Nombre d'échecs
- Tokens invalides nettoyés
- Événements traités

## Limites et quotas

- **FCM gratuit :** Illimité
- **Batch d'envoi :** 500 tokens par requête maximum
- **Payload :** 4 Ko maximum par notification
- **Fréquence :** Pas de limite, mais éviter le spam

## Optimisations

### 1. Gestion des tokens invalides

Les tokens invalides sont automatiquement supprimés lors de l'envoi pour :
- Réduire les coûts
- Améliorer les performances
- Maintenir une base de données propre

### 2. Préférences utilisateur

Le système respecte les préférences de chaque utilisateur :
- Notifications désactivées globalement
- Préférences par type d'événement
- Filtrage par équipes favorites

### 3. Dédoublonnage

Les utilisateurs suivant plusieurs équipes d'un même match reçoivent une seule notification.

## Dépannage

### Les notifications ne sont pas reçues

1. Vérifier que le token FCM est enregistré
2. Vérifier les permissions du navigateur
3. Vérifier les préférences de notification
4. Consulter les logs Firebase Functions

### Erreur "messaging/invalid-registration-token"

Le token a expiré ou est invalide. Il sera automatiquement nettoyé.

### Les webhooks ne fonctionnent pas

1. Vérifier la configuration dans API-Sports
2. Vérifier l'URL du webhook
3. Vérifier l'en-tête `x-api-key`
4. Consulter les logs du webhook

## Support

Pour toute question ou problème :
- Consulter la documentation Firebase : https://firebase.google.com/docs/cloud-messaging
- Consulter la documentation API-Sports : https://www.api-sports.io/documentation/rugby
