const admin = require('firebase-admin');

/**
 * Envoyer une notification push à plusieurs tokens
 * @param {Array} tokens - Liste des tokens FCM
 * @param {Object} notification - Objet notification {title, body, imageUrl}
 * @param {Object} data - Données additionnelles
 * @returns {Promise}
 */
async function sendPushNotification(tokens, notification, data = {}) {
  if (!tokens || tokens.length === 0) {
    console.log('Aucun token à notifier');
    return { success: false, message: 'Aucun token' };
  }

  const message = {
    notification: {
      title: notification.title,
      body: notification.body,
      ...(notification.imageUrl && { imageUrl: notification.imageUrl })
    },
    data: {
      ...data,
      timestamp: Date.now().toString()
    },
    tokens: tokens.slice(0, 500) // FCM limite à 500 tokens par envoi
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);

    // Nettoyer les tokens invalides
    const failedTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        console.error(`Erreur envoi au token ${idx}:`, resp.error);
        if (resp.error.code === 'messaging/invalid-registration-token' ||
            resp.error.code === 'messaging/registration-token-not-registered') {
          failedTokens.push(tokens[idx]);
        }
      }
    });

    console.log(`${response.successCount} notifications envoyées avec succès`);
    console.log(`${response.failureCount} échecs`);

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
      failedTokens
    };
  } catch (error) {
    console.error('Erreur sendPushNotification:', error);
    throw error;
  }
}

/**
 * Récupérer les utilisateurs avec leurs tokens pour une équipe spécifique
 * @param {number} teamId - ID de l'équipe
 * @returns {Promise<Array>} Liste des utilisateurs avec leurs tokens
 */
async function getUsersForTeam(teamId) {
  try {
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('favoriteTeams', 'array-contains', teamId)
      .get();

    const users = [];
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.fcmTokens && userData.fcmTokens.length > 0) {
        users.push({
          uid: doc.id,
          tokens: userData.fcmTokens,
          preferences: userData.notificationPreferences || {}
        });
      }
    });

    return users;
  } catch (error) {
    console.error('Erreur getUsersForTeam:', error);
    return [];
  }
}

/**
 * Récupérer tous les utilisateurs avec notifications activées
 * @returns {Promise<Array>} Liste des utilisateurs avec leurs tokens
 */
async function getAllUsersWithNotifications() {
  try {
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('settings.notifications', '==', true)
      .get();

    const users = [];
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      if (userData.fcmTokens && userData.fcmTokens.length > 0) {
        users.push({
          uid: doc.id,
          tokens: userData.fcmTokens,
          preferences: userData.notificationPreferences || {},
          favoriteTeams: userData.favoriteTeams || []
        });
      }
    });

    return users;
  } catch (error) {
    console.error('Erreur getAllUsersWithNotifications:', error);
    return [];
  }
}

/**
 * Nettoyer les tokens invalides d'un utilisateur
 * @param {string} userId - ID de l'utilisateur
 * @param {Array} invalidTokens - Tokens invalides à supprimer
 */
async function cleanupInvalidTokens(userId, invalidTokens) {
  if (!invalidTokens || invalidTokens.length === 0) return;

  try {
    const userRef = admin.firestore().collection('users').doc(userId);

    for (const token of invalidTokens) {
      await userRef.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(token)
      });
    }

    console.log(`${invalidTokens.length} tokens invalides supprimés pour ${userId}`);
  } catch (error) {
    console.error('Erreur cleanupInvalidTokens:', error);
  }
}

/**
 * Créer un message de notification pour un début de match
 * @param {Object} match - Objet match
 * @returns {Object} Notification formatée
 */
function createMatchStartNotification(match) {
  const homeTeam = match.teams?.home?.name || 'Équipe domicile';
  const awayTeam = match.teams?.away?.name || 'Équipe extérieure';

  return {
    title: '🏉 Match en cours',
    body: `${homeTeam} vs ${awayTeam} vient de commencer !`,
    imageUrl: match.league?.logo || null
  };
}

/**
 * Créer un message de notification pour un changement de score
 * @param {Object} match - Objet match
 * @returns {Object} Notification formatée
 */
function createScoreUpdateNotification(match) {
  const homeTeam = match.teams?.home?.name || 'Équipe domicile';
  const awayTeam = match.teams?.away?.name || 'Équipe extérieure';
  const homeScore = match.scores?.home || 0;
  const awayScore = match.scores?.away || 0;

  return {
    title: '🎯 Mise à jour du score',
    body: `${homeTeam} ${homeScore} - ${awayScore} ${awayTeam}`,
    imageUrl: match.league?.logo || null
  };
}

/**
 * Créer un message de notification pour une fin de match
 * @param {Object} match - Objet match
 * @returns {Object} Notification formatée
 */
function createMatchEndNotification(match) {
  const homeTeam = match.teams?.home?.name || 'Équipe domicile';
  const awayTeam = match.teams?.away?.name || 'Équipe extérieure';
  const homeScore = match.scores?.home || 0;
  const awayScore = match.scores?.away || 0;
  const winner = homeScore > awayScore ? homeTeam : awayTeam;

  return {
    title: '🏆 Match terminé',
    body: `${homeTeam} ${homeScore} - ${awayScore} ${awayTeam}. Victoire de ${winner} !`,
    imageUrl: match.league?.logo || null
  };
}

module.exports = {
  sendPushNotification,
  getUsersForTeam,
  getAllUsersWithNotifications,
  cleanupInvalidTokens,
  createMatchStartNotification,
  createScoreUpdateNotification,
  createMatchEndNotification
};
