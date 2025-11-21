const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Récupérer la clé API depuis la config Firebase
const API_KEY = functions.config().apisports?.key || process.env.API_SPORTS_KEY;
const API_BASE_URL = 'https://v1.rugby.api-sports.io';

// Configuration axios
const rugbyAPI = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'x-apisports-key': API_KEY
  }
});

// ============================================
// FONCTION 1 : Récupérer les matchs du jour
// ============================================
exports.getTodayMatches = functions.https.onCall(async (data, context) => {
  try {
    // Vérifier que l'utilisateur est connecté
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const today = new Date().toISOString().split('T')[0]; // Format: YYYY-MM-DD

    const response = await rugbyAPI.get('/games', {
      params: {
        date: today,
        timezone: 'Europe/Paris'
      }
    });

    // Sauvegarder dans Firestore (cache)
    await admin.firestore().collection('matches').doc(today).set({
      date: today,
      matches: response.data.response,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      matches: response.data.response
    };
  } catch (error) {
    console.error('Error fetching today matches:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION : Récupérer les matchs d'une ligue
// ============================================
exports.getLeagueMatches = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { league, season } = data;

    if (!league) {
      throw new functions.https.HttpsError('invalid-argument', 'league requis');
    }

    const params = { league };
    if (season) params.season = season;

    const response = await rugbyAPI.get('/games', { params });

    return {
      success: true,
      matches: response.data.response
    };
  } catch (error) {
    console.error('Error fetching league matches:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 2 : Récupérer les matchs d'une équipe
// ============================================
exports.getTeamMatches = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { teamId, season } = data;

    if (!teamId) {
      throw new functions.https.HttpsError('invalid-argument', 'teamId requis');
    }

    const response = await rugbyAPI.get('/games', {
      params: {
        team: teamId,
        season: season || new Date().getFullYear()
      }
    });

    return {
      success: true,
      matches: response.data.response
    };
  } catch (error) {
    console.error('Error fetching team matches:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 3 : Récupérer les équipes d'une ligue
// ============================================
exports.getLeagueTeams = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { leagueId, season } = data;

    if (!leagueId) {
      throw new functions.https.HttpsError('invalid-argument', 'leagueId requis');
    }

    const response = await rugbyAPI.get('/teams', {
      params: {
        league: leagueId,
        season: season || new Date().getFullYear()
      }
    });

    // Mettre en cache dans Firestore
    await admin.firestore().collection('leagues').doc(leagueId.toString()).set({
      leagueId,
      teams: response.data.response,
      season: season || new Date().getFullYear(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return {
      success: true,
      teams: response.data.response
    };
  } catch (error) {
    console.error('Error fetching league teams:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 4 : Récupérer le classement d'une ligue
// ============================================
exports.getLeagueStandings = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { leagueId, season } = data;

    if (!leagueId) {
      throw new functions.https.HttpsError('invalid-argument', 'leagueId requis');
    }

    const response = await rugbyAPI.get('/standings', {
      params: {
        league: leagueId,
        season: season || new Date().getFullYear()
      }
    });

    return {
      success: true,
      standings: response.data.response
    };
  } catch (error) {
    console.error('Error fetching standings:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 5 : Rechercher des équipes
// ============================================
exports.searchTeams = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { teamName } = data;

    if (!teamName) {
      throw new functions.https.HttpsError('invalid-argument', 'teamName requis');
    }

    const response = await rugbyAPI.get('/teams', {
      params: {
        search: teamName
      }
    });

    return {
      success: true,
      teams: response.data.response
    };
  } catch (error) {
    console.error('Error searching teams:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 6 : Récupérer les détails d'un match
// ============================================
exports.getMatchDetails = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { matchId } = data;

    if (!matchId) {
      throw new functions.https.HttpsError('invalid-argument', 'matchId requis');
    }

    const response = await rugbyAPI.get('/games', {
      params: {
        id: matchId
      }
    });

    return {
      success: true,
      match: response.data.response[0]
    };
  } catch (error) {
    console.error('Error fetching match details:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 7 : Mise à jour automatique des matchs (Scheduled)
// ============================================
exports.updateMatchesDaily = functions.pubsub
  .schedule('0 6 * * *') // Tous les jours à 6h du matin
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    try {
      const today = new Date().toISOString().split('T')[0];

      const response = await rugbyAPI.get('/games', {
        params: {
          date: today,
          timezone: 'Europe/Paris'
        }
      });

      // Sauvegarder dans Firestore
      await admin.firestore().collection('matches').doc(today).set({
        date: today,
        matches: response.data.response,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        autoUpdated: true
      });

      console.log(`Matches updated for ${today}`);
      return null;
    } catch (error) {
      console.error('Error in scheduled update:', error);
      return null;
    }
  });

// ============================================
// FONCTION 8 : Webhook pour mises à jour en temps réel (optionnel)
// ============================================
exports.rugbyWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Vérifier que c'est bien API-Sports qui appelle
    const apiKey = req.headers['x-api-key'];
    if (apiKey !== API_KEY) {
      return res.status(401).send('Unauthorized');
    }

    const eventData = req.body;

    // Traiter l'événement (match commencé, but marqué, etc.)
    // En l'ajoutant à Firestore, cela déclenche automatiquement
    // le trigger onMatchUpdate qui envoie les notifications push
    const eventDoc = await admin.firestore().collection('live-events').add({
      event: eventData,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false
    });

    console.log(`Événement reçu et enregistré: ${eventDoc.id}`);
    console.log(`Type: ${eventData.type || 'unknown'}, Match: ${eventData.fixture?.id || 'unknown'}`);

    // Marquer l'événement comme traité
    await eventDoc.update({ processed: true });

    res.status(200).send('OK');
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).send('Error');
  }
});
