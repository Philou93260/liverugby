const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Récupérer la clé API depuis la config Firebase
const API_KEY = functions.config().apisports?.key || process.env.API_SPORTS_KEY;
const API_BASE_URL = 'https://v1.rugby.api-sports.io';

// Configuration axios pour l'API Rugby
const rugbyAPI = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'x-apisports-key': API_KEY
  },
  timeout: 10000
});

// ============================================
// TYPES D'ÉVÉNEMENTS NOTIFIABLES
// ============================================
const EVENT_TYPES = {
  MATCH_STARTING: 'match_starting',      // Match commence dans 30 min
  MATCH_STARTED: 'match_started',        // Match a commencé
  SCORE_UPDATE: 'score_update',          // Score mis à jour
  HALFTIME: 'halftime',                  // Mi-temps
  MATCH_ENDED: 'match_ended',           // Match terminé
  FAVORITE_TEAM_PLAYING: 'favorite_team_playing' // Équipe favorite joue aujourd'hui
};

// ============================================
// FONCTION 1 : Enregistrer un token FCM (iOS)
// ============================================
exports.registerFCMToken = functions.https.onCall(async (data, context) => {
  try {
    // Vérifier l'authentification
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { token, platform, deviceId } = data;
    const userId = context.auth.uid;

    // Valider les paramètres
    if (!token || typeof token !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Token FCM invalide');
    }

    if (!platform || !['ios', 'android'].includes(platform.toLowerCase())) {
      throw new functions.https.HttpsError('invalid-argument', 'Platform doit être ios ou android');
    }

    // Stocker le token dans Firestore
    const tokenData = {
      token: token,
      userId: userId,
      platform: platform.toLowerCase(),
      deviceId: deviceId || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      enabled: true
    };

    await admin.firestore()
      .collection('fcmTokens')
      .doc(token)
      .set(tokenData, { merge: true });

    // Ajouter également au profil utilisateur
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .set({
        fcmTokens: admin.firestore.FieldValue.arrayUnion(token),
        lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

    console.log('FCM Token registered:', { userId, platform, token: token.substring(0, 20) + '...' });

    return {
      success: true,
      message: 'Token enregistré avec succès'
    };
  } catch (error) {
    console.error('Error registering FCM token:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 2 : Désactiver/Supprimer un token FCM
// ============================================
exports.unregisterFCMToken = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { token } = data;
    const userId = context.auth.uid;

    if (!token) {
      throw new functions.https.HttpsError('invalid-argument', 'Token requis');
    }

    // Désactiver le token
    await admin.firestore()
      .collection('fcmTokens')
      .doc(token)
      .update({
        enabled: false,
        disabledAt: admin.firestore.FieldValue.serverTimestamp()
      });

    // Retirer du profil utilisateur
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(token)
      });

    console.log('FCM Token unregistered:', { userId, token: token.substring(0, 20) + '...' });

    return {
      success: true,
      message: 'Token désactivé avec succès'
    };
  } catch (error) {
    console.error('Error unregistering FCM token:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 3 : S'abonner aux notifications d'un match
// ============================================
exports.subscribeToMatch = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { matchId, eventTypes } = data;
    const userId = context.auth.uid;

    if (!matchId) {
      throw new functions.https.HttpsError('invalid-argument', 'matchId requis');
    }

    // Types d'événements par défaut
    const subscribedEvents = eventTypes || [
      EVENT_TYPES.MATCH_STARTING,
      EVENT_TYPES.MATCH_STARTED,
      EVENT_TYPES.SCORE_UPDATE,
      EVENT_TYPES.MATCH_ENDED
    ];

    // Créer l'abonnement
    const subscriptionData = {
      userId: userId,
      matchId: matchId,
      eventTypes: subscribedEvents,
      subscribedAt: admin.firestore.FieldValue.serverTimestamp(),
      active: true
    };

    await admin.firestore()
      .collection('matchSubscriptions')
      .doc(`${userId}_${matchId}`)
      .set(subscriptionData, { merge: true });

    console.log('User subscribed to match:', { userId, matchId });

    return {
      success: true,
      message: 'Abonnement créé avec succès',
      subscription: subscriptionData
    };
  } catch (error) {
    console.error('Error subscribing to match:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 4 : Se désabonner d'un match
// ============================================
exports.unsubscribeFromMatch = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { matchId } = data;
    const userId = context.auth.uid;

    if (!matchId) {
      throw new functions.https.HttpsError('invalid-argument', 'matchId requis');
    }

    await admin.firestore()
      .collection('matchSubscriptions')
      .doc(`${userId}_${matchId}`)
      .update({
        active: false,
        unsubscribedAt: admin.firestore.FieldValue.serverTimestamp()
      });

    console.log('User unsubscribed from match:', { userId, matchId });

    return {
      success: true,
      message: 'Désabonnement effectué avec succès'
    };
  } catch (error) {
    console.error('Error unsubscribing from match:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 5 : Ajouter une équipe favorite
// ============================================
exports.addFavoriteTeam = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { teamId, teamName, teamLogo, notifyMatches } = data;
    const userId = context.auth.uid;

    if (!teamId) {
      throw new functions.https.HttpsError('invalid-argument', 'teamId requis');
    }

    const favoriteData = {
      teamId: teamId,
      teamName: teamName || '',
      teamLogo: teamLogo || '',
      notifyMatches: notifyMatches !== false, // true par défaut
      addedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('favorites')
      .doc(teamId.toString())
      .set(favoriteData, { merge: true });

    console.log('Favorite team added:', { userId, teamId });

    return {
      success: true,
      message: 'Équipe ajoutée aux favoris',
      favorite: favoriteData
    };
  } catch (error) {
    console.error('Error adding favorite team:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 6 : Monitoring des matchs en direct (exécution toutes les minutes)
// ============================================
exports.monitorLiveMatches = functions.pubsub
  .schedule('every 1 minutes')
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    try {
      console.log('Starting live matches monitoring...');
      const today = new Date().toISOString().split('T')[0];

      // Récupérer les matchs du jour depuis Firestore (cache)
      const matchesDoc = await admin.firestore()
        .collection('matches')
        .doc(today)
        .get();

      if (!matchesDoc.exists) {
        console.log('No matches found for today');
        return null;
      }

      const cachedMatches = matchesDoc.data().matches || [];

      // Filtrer les matchs en cours ou à venir dans l'heure
      const now = new Date();
      const oneHourLater = new Date(now.getTime() + 60 * 60 * 1000);

      const relevantMatches = cachedMatches.filter(match => {
        const matchDate = new Date(match.date);
        const status = match.status?.short;

        // Match en cours ou commence bientôt
        return status === 'LIVE' ||
               status === '1H' ||
               status === '2H' ||
               (matchDate >= now && matchDate <= oneHourLater);
      });

      console.log(`Found ${relevantMatches.length} relevant matches`);

      // Récupérer les détails à jour pour chaque match
      for (const match of relevantMatches) {
        await checkMatchForUpdates(match);
      }

      return null;
    } catch (error) {
      console.error('Error in live matches monitoring:', error);
      return null;
    }
  });

// ============================================
// FONCTION HELPER : Vérifier les mises à jour d'un match
// ============================================
async function checkMatchForUpdates(match) {
  try {
    const matchId = match.id;

    // Récupérer les détails à jour depuis l'API
    const response = await rugbyAPI.get('/games', {
      params: { id: matchId }
    });

    const updatedMatch = response.data.response[0];
    if (!updatedMatch) return;

    // Récupérer l'état précédent du match
    const previousMatchDoc = await admin.firestore()
      .collection('liveMatches')
      .doc(matchId.toString())
      .get();

    const previousMatch = previousMatchDoc.exists ? previousMatchDoc.data() : null;

    // Détecter les événements
    const events = detectMatchEvents(previousMatch, updatedMatch);

    // Sauvegarder l'état actuel
    await admin.firestore()
      .collection('liveMatches')
      .doc(matchId.toString())
      .set({
        ...updatedMatch,
        lastChecked: admin.firestore.FieldValue.serverTimestamp()
      });

    // Envoyer les notifications pour chaque événement détecté
    for (const event of events) {
      await sendMatchNotifications(matchId, event, updatedMatch);
    }

  } catch (error) {
    console.error('Error checking match updates:', error);
  }
}

// ============================================
// FONCTION HELPER : Détecter les événements d'un match
// ============================================
function detectMatchEvents(previousMatch, currentMatch) {
  const events = [];
  const currentStatus = currentMatch.status?.short;
  const previousStatus = previousMatch?.status?.short;

  // Match commence dans 30 minutes
  const matchTime = new Date(currentMatch.date);
  const now = new Date();
  const minutesUntilMatch = (matchTime - now) / 1000 / 60;

  if (minutesUntilMatch > 25 && minutesUntilMatch <= 30 && !previousMatch) {
    events.push({
      type: EVENT_TYPES.MATCH_STARTING,
      data: { minutesUntilStart: Math.round(minutesUntilMatch) }
    });
  }

  // Match a commencé
  if (currentStatus === 'LIVE' && previousStatus !== 'LIVE') {
    events.push({
      type: EVENT_TYPES.MATCH_STARTED,
      data: {}
    });
  }

  // Score mis à jour
  const currentHomeScore = currentMatch.scores?.home;
  const currentAwayScore = currentMatch.scores?.away;
  const previousHomeScore = previousMatch?.scores?.home;
  const previousAwayScore = previousMatch?.scores?.away;

  if (currentHomeScore !== previousHomeScore || currentAwayScore !== previousAwayScore) {
    if (previousMatch) { // Ne notifier que si on a un état précédent
      events.push({
        type: EVENT_TYPES.SCORE_UPDATE,
        data: {
          homeScore: currentHomeScore,
          awayScore: currentAwayScore,
          previousHomeScore,
          previousAwayScore
        }
      });
    }
  }

  // Mi-temps
  if (currentStatus === 'HT' && previousStatus !== 'HT') {
    events.push({
      type: EVENT_TYPES.HALFTIME,
      data: {
        homeScore: currentHomeScore,
        awayScore: currentAwayScore
      }
    });
  }

  // Match terminé
  if (currentStatus === 'FT' && previousStatus !== 'FT') {
    events.push({
      type: EVENT_TYPES.MATCH_ENDED,
      data: {
        homeScore: currentHomeScore,
        awayScore: currentAwayScore,
        winner: currentHomeScore > currentAwayScore ? 'home' :
                currentAwayScore > currentHomeScore ? 'away' : 'draw'
      }
    });
  }

  return events;
}

// ============================================
// FONCTION HELPER : Envoyer les notifications
// ============================================
async function sendMatchNotifications(matchId, event, matchData) {
  try {
    // Récupérer tous les utilisateurs abonnés à ce match
    const subscriptionsSnapshot = await admin.firestore()
      .collection('matchSubscriptions')
      .where('matchId', '==', matchId)
      .where('active', '==', true)
      .where('eventTypes', 'array-contains', event.type)
      .get();

    if (subscriptionsSnapshot.empty) {
      console.log('No subscriptions for match:', matchId);
      return;
    }

    console.log(`Sending notifications to ${subscriptionsSnapshot.size} subscribers`);

    // Pour chaque abonné, envoyer une notification
    const notificationPromises = [];

    for (const doc of subscriptionsSnapshot.docs) {
      const subscription = doc.data();
      const userId = subscription.userId;

      // Récupérer les tokens FCM de l'utilisateur
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();

      const userData = userDoc.data();
      const tokens = userData?.fcmTokens || [];

      if (tokens.length === 0) continue;

      // Créer le message de notification
      const notification = buildNotificationMessage(event, matchData);

      // Envoyer à tous les tokens de l'utilisateur
      for (const token of tokens) {
        notificationPromises.push(
          sendPushNotification(token, notification, matchData, event.type)
        );
      }
    }

    await Promise.allSettled(notificationPromises);
    console.log(`Sent ${notificationPromises.length} notifications`);

  } catch (error) {
    console.error('Error sending match notifications:', error);
  }
}

// ============================================
// FONCTION HELPER : Construire le message de notification
// ============================================
function buildNotificationMessage(event, matchData) {
  const homeTeam = matchData.teams?.home?.name || 'Équipe 1';
  const awayTeam = matchData.teams?.away?.name || 'Équipe 2';

  let title = '';
  let body = '';

  switch (event.type) {
    case EVENT_TYPES.MATCH_STARTING:
      title = '🏉 Match bientôt !';
      body = `${homeTeam} vs ${awayTeam} commence dans ${event.data.minutesUntilStart} minutes`;
      break;

    case EVENT_TYPES.MATCH_STARTED:
      title = '🏉 Match en cours !';
      body = `${homeTeam} vs ${awayTeam} a commencé`;
      break;

    case EVENT_TYPES.SCORE_UPDATE:
      title = '🎯 Score mis à jour !';
      body = `${homeTeam} ${event.data.homeScore} - ${event.data.awayScore} ${awayTeam}`;
      break;

    case EVENT_TYPES.HALFTIME:
      title = '⏸️ Mi-temps';
      body = `${homeTeam} ${event.data.homeScore} - ${event.data.awayScore} ${awayTeam}`;
      break;

    case EVENT_TYPES.MATCH_ENDED:
      title = '🏁 Match terminé !';
      body = `${homeTeam} ${event.data.homeScore} - ${event.data.awayScore} ${awayTeam}`;
      break;

    default:
      title = '🏉 LiveRugby';
      body = 'Nouvelle mise à jour';
  }

  return { title, body };
}

// ============================================
// FONCTION HELPER : Envoyer une notification push
// ============================================
async function sendPushNotification(token, notification, matchData, eventType) {
  try {
    const message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: {
        matchId: matchData.id.toString(),
        eventType: eventType,
        homeTeam: matchData.teams?.home?.name || '',
        awayTeam: matchData.teams?.away?.name || '',
        homeScore: (matchData.scores?.home || 0).toString(),
        awayScore: (matchData.scores?.away || 0).toString(),
        status: matchData.status?.short || ''
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1
          }
        }
      },
      token: token
    };

    const response = await admin.messaging().send(message);
    console.log('Push notification sent:', response);

    // Enregistrer la notification dans Firestore
    await admin.firestore().collection('sentNotifications').add({
      token: token.substring(0, 20) + '...',
      matchId: matchData.id,
      eventType: eventType,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      success: true
    });

    return response;
  } catch (error) {
    console.error('Error sending push notification:', error);

    // Si le token est invalide, le désactiver
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      await admin.firestore()
        .collection('fcmTokens')
        .doc(token)
        .update({ enabled: false, error: error.code });
    }

    // Enregistrer l'échec
    await admin.firestore().collection('sentNotifications').add({
      token: token.substring(0, 20) + '...',
      matchId: matchData.id,
      eventType: eventType,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      success: false,
      error: error.message
    });

    throw error;
  }
}

// ============================================
// FONCTION 7 : Notification pour équipes favorites (quotidien à 8h)
// ============================================
exports.notifyFavoriteTeamsMatches = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    try {
      console.log('Checking favorite teams matches...');
      const today = new Date().toISOString().split('T')[0];

      // Récupérer les matchs du jour
      const matchesDoc = await admin.firestore()
        .collection('matches')
        .doc(today)
        .get();

      if (!matchesDoc.exists) return null;

      const todayMatches = matchesDoc.data().matches || [];

      // Récupérer tous les utilisateurs avec des favoris
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .get();

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        const tokens = userData.fcmTokens || [];

        if (tokens.length === 0) continue;

        // Récupérer les favoris de l'utilisateur
        const favoritesSnapshot = await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .where('notifyMatches', '==', true)
          .get();

        const favoriteTeamIds = favoritesSnapshot.docs.map(doc => parseInt(doc.id));

        // Trouver les matchs des équipes favorites
        const favoriteMatches = todayMatches.filter(match => {
          const homeTeamId = match.teams?.home?.id;
          const awayTeamId = match.teams?.away?.id;
          return favoriteTeamIds.includes(homeTeamId) || favoriteTeamIds.includes(awayTeamId);
        });

        if (favoriteMatches.length > 0) {
          // Envoyer une notification récapitulative
          for (const token of tokens) {
            await sendFavoriteTeamsNotification(token, favoriteMatches);
          }
        }
      }

      console.log('Favorite teams notifications sent');
      return null;
    } catch (error) {
      console.error('Error notifying favorite teams:', error);
      return null;
    }
  });

// ============================================
// FONCTION HELPER : Envoyer notification équipes favorites
// ============================================
async function sendFavoriteTeamsNotification(token, matches) {
  try {
    const matchCount = matches.length;
    const firstMatch = matches[0];

    let body = '';
    if (matchCount === 1) {
      body = `${firstMatch.teams?.home?.name} vs ${firstMatch.teams?.away?.name}`;
    } else {
      body = `${matchCount} matchs de vos équipes favorites aujourd'hui`;
    }

    const message = {
      notification: {
        title: '⭐ Vos équipes favorites jouent aujourd\'hui !',
        body: body
      },
      data: {
        type: 'favorite_teams_playing',
        matchCount: matchCount.toString()
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      },
      token: token
    };

    await admin.messaging().send(message);
    console.log('Favorite teams notification sent');
  } catch (error) {
    console.error('Error sending favorite teams notification:', error);
  }
}

module.exports = {
  registerFCMToken: exports.registerFCMToken,
  unregisterFCMToken: exports.unregisterFCMToken,
  subscribeToMatch: exports.subscribeToMatch,
  unsubscribeFromMatch: exports.unsubscribeFromMatch,
  addFavoriteTeam: exports.addFavoriteTeam,
  monitorLiveMatches: exports.monitorLiveMatches,
  notifyFavoriteTeamsMatches: exports.notifyFavoriteTeamsMatches
};
