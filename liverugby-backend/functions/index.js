// Firebase Cloud Functions
const functionsBase = require('firebase-functions');
const functions = functionsBase.region('europe-west1');
const admin = require('firebase-admin');
admin.initializeApp();

// Importer le module rugby-api
const rugbyAPI = require('./rugby-api');

// Importer les helpers de notifications
const notificationHelpers = require('./notification-helpers');

// ============================================
// FONCTION 1 : Créer un profil utilisateur lors de l'inscription
// ============================================
exports.createUserProfile = functions.auth.user().onCreate(async (user) => {
  const userProfile = {
    uid: user.uid,
    email: user.email,
    displayName: user.displayName || '',
    photoURL: user.photoURL || '',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isPublic: false,
    settings: {
      notifications: true,
      theme: 'auto'
    },
    fcmTokens: [], // Tokens pour les notifications push
    notificationPreferences: {
      matchStart: true,        // Notifications quand un match commence
      scoreUpdate: true,        // Notifications lors des changements de score
      matchEnd: true,          // Notifications à la fin du match
      favoriteTeams: true,     // Notifications pour les équipes favorites
      dailyDigest: false       // Résumé quotidien des matchs
    },
    favoriteTeams: [],         // IDs des équipes favorites
    favoriteLeagues: []        // IDs des ligues favorites
  };

  try {
    await admin.firestore().collection('users').doc(user.uid).set(userProfile);
    console.log('Profil utilisateur créé:', user.uid);
  } catch (error) {
    console.error('Erreur création profil:', error);
  }
});

// ============================================
// FONCTION 2 : Nettoyer les données lors de la suppression d'un compte
// ============================================
exports.deleteUserData = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  
  try {
    // Supprimer le document utilisateur
    await admin.firestore().collection('users').doc(uid).delete();
    
    // Supprimer les fichiers storage de l'utilisateur
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({
      prefix: `users/${uid}/`
    });
    
    console.log('Données utilisateur supprimées:', uid);
  } catch (error) {
    console.error('Erreur suppression données:', error);
  }
});

// ============================================
// FONCTION 3 : Envoyer une notification de bienvenue
// ============================================
exports.sendWelcomeEmail = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();

    // Logique d'envoi d'email (intégrer avec un service comme SendGrid)
    console.log('Email de bienvenue pour:', userData.email);

    return null;
  });

// ============================================
// FONCTION 3A : Enregistrer/Mettre à jour un token FCM
// ============================================
exports.registerFCMToken = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { token } = data;
    if (!token) {
      throw new functions.https.HttpsError('invalid-argument', 'token requis');
    }

    const userId = context.auth.uid;
    const userRef = admin.firestore().collection('users').doc(userId);

    // Ajouter le token s'il n'existe pas déjà
    await userRef.update({
      fcmTokens: admin.firestore.FieldValue.arrayUnion(token),
      lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Token FCM enregistré pour l'utilisateur ${userId}`);
    return { success: true, message: 'Token enregistré' };
  } catch (error) {
    console.error('Erreur enregistrement token:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 3B : Supprimer un token FCM
// ============================================
exports.removeFCMToken = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { token } = data;
    if (!token) {
      throw new functions.https.HttpsError('invalid-argument', 'token requis');
    }

    const userId = context.auth.uid;
    const userRef = admin.firestore().collection('users').doc(userId);

    await userRef.update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(token)
    });

    console.log(`Token FCM supprimé pour l'utilisateur ${userId}`);
    return { success: true, message: 'Token supprimé' };
  } catch (error) {
    console.error('Erreur suppression token:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 3C : Mettre à jour les préférences de notifications
// ============================================
exports.updateNotificationPreferences = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { preferences } = data;
    if (!preferences) {
      throw new functions.https.HttpsError('invalid-argument', 'preferences requis');
    }

    const userId = context.auth.uid;
    const userRef = admin.firestore().collection('users').doc(userId);

    await userRef.update({
      notificationPreferences: preferences
    });

    console.log(`Préférences mises à jour pour ${userId}`);
    return { success: true, message: 'Préférences mises à jour' };
  } catch (error) {
    console.error('Erreur mise à jour préférences:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 3D : Gérer les équipes favorites
// ============================================
exports.manageFavoriteTeam = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { teamId, action } = data;
    if (!teamId || !action) {
      throw new functions.https.HttpsError('invalid-argument', 'teamId et action requis');
    }

    const userId = context.auth.uid;
    const userRef = admin.firestore().collection('users').doc(userId);

    if (action === 'add') {
      await userRef.update({
        favoriteTeams: admin.firestore.FieldValue.arrayUnion(teamId)
      });
    } else if (action === 'remove') {
      await userRef.update({
        favoriteTeams: admin.firestore.FieldValue.arrayRemove(teamId)
      });
    }

    console.log(`Équipe ${teamId} ${action === 'add' ? 'ajoutée' : 'retirée'} pour ${userId}`);
    return { success: true, message: `Équipe ${action === 'add' ? 'ajoutée' : 'retirée'}` };
  } catch (error) {
    console.error('Erreur gestion équipe favorite:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 4 : API endpoint exemple
// ============================================
exports.api = functions.https.onRequest((req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  
  res.json({ 
    message: 'API Firebase fonctionnelle',
    timestamp: Date.now()
  });
});

// ============================================
// FONCTION 5 : Nettoyer les anciennes données (exécution quotidienne)
// ============================================
exports.cleanOldData = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const snapshot = await admin.firestore()
      .collection('temporaryData')
      .where('createdAt', '<', thirtyDaysAgo)
      .get();
    
    const batch = admin.firestore().batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`${snapshot.size} documents supprimés`);
    
    return null;
  });

// ============================================
// FONCTION 6 : Trigger pour détecter les changements de matchs
// ============================================
exports.onMatchUpdate = functions.firestore
  .document('live-events/{eventId}')
  .onCreate(async (snap, context) => {
    try {
      const eventData = snap.data();
      const event = eventData.event;

      if (!event || !event.fixture) {
        console.log('Événement sans données de match');
        return null;
      }

      const match = event;
      const status = match.status?.short;
      const homeTeamId = match.teams?.home?.id;
      const awayTeamId = match.teams?.away?.id;

      // Récupérer les utilisateurs concernés
      let usersToNotify = [];

      // Utilisateurs qui suivent l'équipe domicile
      if (homeTeamId) {
        const homeUsers = await notificationHelpers.getUsersForTeam(homeTeamId);
        usersToNotify = [...usersToNotify, ...homeUsers];
      }

      // Utilisateurs qui suivent l'équipe extérieure
      if (awayTeamId) {
        const awayUsers = await notificationHelpers.getUsersForTeam(awayTeamId);
        usersToNotify = [...usersToNotify, ...awayUsers];
      }

      // Dédupliquer les utilisateurs
      const uniqueUsers = Array.from(
        new Map(usersToNotify.map(user => [user.uid, user])).values()
      );

      if (uniqueUsers.length === 0) {
        console.log('Aucun utilisateur à notifier');
        return null;
      }

      let notification;
      let shouldNotify = false;

      // Déterminer le type de notification selon le statut du match
      if (status === '1H' || status === '2H' || status === 'LIVE') {
        // Match en cours - vérifier préférences matchStart
        const usersWithMatchStart = uniqueUsers.filter(
          u => u.preferences.matchStart !== false
        );
        if (usersWithMatchStart.length > 0) {
          notification = notificationHelpers.createMatchStartNotification(match);
          shouldNotify = true;
          uniqueUsers.splice(0, uniqueUsers.length, ...usersWithMatchStart);
        }
      } else if (status === 'FT' || status === 'AET' || status === 'PEN') {
        // Match terminé - vérifier préférences matchEnd
        const usersWithMatchEnd = uniqueUsers.filter(
          u => u.preferences.matchEnd !== false
        );
        if (usersWithMatchEnd.length > 0) {
          notification = notificationHelpers.createMatchEndNotification(match);
          shouldNotify = true;
          uniqueUsers.splice(0, uniqueUsers.length, ...usersWithMatchEnd);
        }
      } else if (event.type === 'score' || event.type === 'try' || event.type === 'goal') {
        // Changement de score - vérifier préférences scoreUpdate
        const usersWithScoreUpdate = uniqueUsers.filter(
          u => u.preferences.scoreUpdate !== false
        );
        if (usersWithScoreUpdate.length > 0) {
          notification = notificationHelpers.createScoreUpdateNotification(match);
          shouldNotify = true;
          uniqueUsers.splice(0, uniqueUsers.length, ...usersWithScoreUpdate);
        }
      }

      if (!shouldNotify || !notification) {
        console.log('Pas de notification à envoyer pour cet événement');
        return null;
      }

      // Regrouper tous les tokens
      const allTokens = uniqueUsers.flatMap(user => user.tokens);

      // Envoyer les notifications
      const result = await notificationHelpers.sendPushNotification(
        allTokens,
        notification,
        {
          matchId: match.id?.toString() || '',
          type: event.type || 'match_update',
          homeTeamId: homeTeamId?.toString() || '',
          awayTeamId: awayTeamId?.toString() || ''
        }
      );

      // Nettoyer les tokens invalides
      if (result.failedTokens && result.failedTokens.length > 0) {
        for (const user of uniqueUsers) {
          const userFailedTokens = user.tokens.filter(
            t => result.failedTokens.includes(t)
          );
          if (userFailedTokens.length > 0) {
            await notificationHelpers.cleanupInvalidTokens(user.uid, userFailedTokens);
          }
        }
      }

      console.log(`Notifications envoyées: ${result.successCount} succès, ${result.failureCount} échecs`);
      return null;
    } catch (error) {
      console.error('Erreur onMatchUpdate:', error);
      return null;
    }
  });

// ============================================
// FONCTION 7 : Envoi quotidien de résumé des matchs du jour
// ============================================
exports.sendDailyDigest = functions.pubsub
  .schedule('0 8 * * *') // Tous les jours à 8h du matin
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    try {
      const today = new Date().toISOString().split('T')[0];

      // Récupérer les matchs du jour depuis Firestore
      const matchesDoc = await admin.firestore()
        .collection('matches')
        .doc(today)
        .get();

      if (!matchesDoc.exists) {
        console.log('Aucun match prévu aujourd\'hui');
        return null;
      }

      const matches = matchesDoc.data().matches || [];

      if (matches.length === 0) {
        console.log('Aucun match aujourd\'hui');
        return null;
      }

      // Récupérer les utilisateurs avec dailyDigest activé
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('notificationPreferences.dailyDigest', '==', true)
        .get();

      if (usersSnapshot.empty) {
        console.log('Aucun utilisateur avec dailyDigest activé');
        return null;
      }

      const users = [];
      usersSnapshot.forEach(doc => {
        const userData = doc.data();
        if (userData.fcmTokens && userData.fcmTokens.length > 0) {
          users.push({
            uid: doc.id,
            tokens: userData.fcmTokens
          });
        }
      });

      if (users.length === 0) {
        console.log('Aucun utilisateur avec token FCM');
        return null;
      }

      // Créer la notification
      const notification = {
        title: '📅 Matchs du jour',
        body: `${matches.length} match${matches.length > 1 ? 's' : ''} prévu${matches.length > 1 ? 's' : ''} aujourd'hui !`,
        imageUrl: null
      };

      // Regrouper tous les tokens
      const allTokens = users.flatMap(user => user.tokens);

      // Envoyer les notifications
      const result = await notificationHelpers.sendPushNotification(
        allTokens,
        notification,
        {
          type: 'daily_digest',
          matchCount: matches.length.toString(),
          date: today
        }
      );

      console.log(`Résumé quotidien envoyé: ${result.successCount} succès`);
      return null;
    } catch (error) {
      console.error('Erreur sendDailyDigest:', error);
      return null;
    }
  });

// ============================================
// EXPORTER LES FONCTIONS RUGBY
// ============================================
exports.getTodayMatches = rugbyAPI.getTodayMatches;
exports.getLeagueMatches = rugbyAPI.getLeagueMatches;
exports.getTeamMatches = rugbyAPI.getTeamMatches;
exports.getLeagueTeams = rugbyAPI.getLeagueTeams;
exports.getLeagueStandings = rugbyAPI.getLeagueStandings;
exports.searchTeams = rugbyAPI.searchTeams;
exports.getMatchDetails = rugbyAPI.getMatchDetails;
exports.updateMatchesDaily = rugbyAPI.updateMatchesDaily;
exports.rugbyWebhook = rugbyAPI.rugbyWebhook;
