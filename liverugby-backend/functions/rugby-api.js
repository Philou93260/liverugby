const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const crypto = require('crypto');

// Récupérer la clé API depuis la config Firebase
const API_KEY = functions.config().apisports?.key || process.env.API_SPORTS_KEY;
const API_BASE_URL = 'https://v1.rugby.api-sports.io';

// Configuration axios
const rugbyAPI = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'x-apisports-key': API_KEY
  },
  timeout: 10000 // 10 secondes
});

// ============================================
// FONCTION HELPER : Retry logic pour les appels API
// ============================================
async function apiCallWithRetry(apiCall, maxRetries = 3) {
  let lastError;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const response = await apiCall();
      return response;
    } catch (error) {
      lastError = error;

      // Ne pas retry pour les erreurs 4xx (sauf 429 - Too Many Requests)
      if (error.response && error.response.status >= 400 && error.response.status < 500) {
        if (error.response.status !== 429) {
          throw error;
        }
      }

      // Si c'est le dernier essai, on throw l'erreur
      if (attempt === maxRetries) {
        break;
      }

      // Attendre avant de retry (exponential backoff)
      const delay = Math.min(1000 * Math.pow(2, attempt - 1), 8000);
      console.log(`API call failed (attempt ${attempt}/${maxRetries}), retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw lastError;
}

// ============================================
// FONCTION HELPER : Validation des données
// ============================================
function validateLeagueId(leagueId) {
  if (!leagueId) {
    throw new functions.https.HttpsError('invalid-argument', 'leagueId est requis');
  }
  if (typeof leagueId !== 'number' && typeof leagueId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'leagueId doit être un nombre ou une chaîne');
  }
  const numLeagueId = typeof leagueId === 'string' ? parseInt(leagueId, 10) : leagueId;
  if (isNaN(numLeagueId) || numLeagueId <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'leagueId invalide');
  }
  return numLeagueId;
}

function validateTeamId(teamId) {
  if (!teamId) {
    throw new functions.https.HttpsError('invalid-argument', 'teamId est requis');
  }
  const numTeamId = typeof teamId === 'string' ? parseInt(teamId, 10) : teamId;
  if (isNaN(numTeamId) || numTeamId <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'teamId invalide');
  }
  return numTeamId;
}

function validateSeason(season) {
  if (!season) {
    return new Date().getFullYear(); // Retourner l'année courante par défaut
  }
  const numSeason = typeof season === 'string' ? parseInt(season, 10) : season;
  if (isNaN(numSeason) || numSeason < 2000 || numSeason > 2100) {
    throw new functions.https.HttpsError('invalid-argument', 'Season invalide (doit être entre 2000 et 2100)');
  }
  return numSeason;
}

function validateTeamName(teamName) {
  if (!teamName) {
    throw new functions.https.HttpsError('invalid-argument', 'teamName est requis');
  }
  if (typeof teamName !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'teamName doit être une chaîne');
  }
  if (teamName.trim().length < 2) {
    throw new functions.https.HttpsError('invalid-argument', 'teamName doit contenir au moins 2 caractères');
  }
  if (teamName.length > 100) {
    throw new functions.https.HttpsError('invalid-argument', 'teamName est trop long (max 100 caractères)');
  }
  return teamName.trim();
}

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

    // Essayer de récupérer depuis le cache d'abord
    const cachedDoc = await admin.firestore().collection('matches').doc(today).get();
    const cachedData = cachedDoc.data();

    // Si le cache a moins de 5 minutes, le retourner
    if (cachedData && cachedData.updatedAt) {
      const cacheAge = Date.now() - cachedData.updatedAt.toMillis();
      if (cacheAge < 5 * 60 * 1000) { // 5 minutes
        console.log('Returning cached matches for:', today);
        return {
          success: true,
          matches: cachedData.matches,
          cached: true
        };
      }
    }

    // Appeler l'API avec retry logic
    const response = await apiCallWithRetry(() =>
      rugbyAPI.get('/games', {
        params: {
          date: today,
          timezone: 'Europe/Paris'
        }
      })
    );

    // Sauvegarder dans Firestore (cache)
    await admin.firestore().collection('matches').doc(today).set({
      date: today,
      matches: response.data.response,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      matches: response.data.response,
      cached: false
    };
  } catch (error) {
    console.error('Error fetching today matches:', {
      message: error.message,
      stack: error.stack,
      response: error.response?.data
    });

    // Si l'API échoue, essayer de retourner le cache même s'il est ancien
    const cachedDoc = await admin.firestore().collection('matches').doc(new Date().toISOString().split('T')[0]).get();
    if (cachedDoc.exists) {
      console.warn('API failed, returning stale cache');
      return {
        success: true,
        matches: cachedDoc.data().matches,
        cached: true,
        stale: true
      };
    }

    throw new functions.https.HttpsError('internal', 'Unable to fetch matches: ' + error.message);
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

    // Valider les paramètres
    const validatedTeamId = validateTeamId(data.teamId);
    const validatedSeason = validateSeason(data.season);

    const response = await apiCallWithRetry(() =>
      rugbyAPI.get('/games', {
        params: {
          team: validatedTeamId,
          season: validatedSeason
        }
      })
    );

    return {
      success: true,
      matches: response.data.response,
      teamId: validatedTeamId,
      season: validatedSeason
    };
  } catch (error) {
    console.error('Error fetching team matches:', {
      teamId: data.teamId,
      error: error.message
    });
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

    // Valider le nom de l'équipe
    const validatedTeamName = validateTeamName(data.teamName);

    const response = await apiCallWithRetry(() =>
      rugbyAPI.get('/teams', {
        params: {
          search: validatedTeamName
        }
      })
    );

    return {
      success: true,
      teams: response.data.response,
      query: validatedTeamName
    };
  } catch (error) {
    console.error('Error searching teams:', {
      teamName: data.teamName,
      error: error.message
    });
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
// Fonction helper pour comparaison sécurisée (évite timing attacks)
function timingSafeCompare(a, b) {
  if (!a || !b || a.length !== b.length) {
    return false;
  }
  try {
    const bufferA = Buffer.from(a);
    const bufferB = Buffer.from(b);
    return crypto.timingSafeEqual(bufferA, bufferB);
  } catch (error) {
    return false;
  }
}

exports.rugbyWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Vérifier la méthode HTTP
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    // Vérifier que c'est bien API-Sports qui appelle (comparaison sécurisée)
    const apiKey = req.headers['x-api-key'] || req.headers['x-apisports-key'];

    if (!apiKey || !API_KEY || !timingSafeCompare(apiKey, API_KEY)) {
      console.warn('Webhook: Unauthorized access attempt', {
        timestamp: new Date().toISOString(),
        ip: req.ip,
        headers: req.headers
      });
      return res.status(401).send('Unauthorized');
    }

    // Valider que le body contient des données
    const eventData = req.body;
    if (!eventData || Object.keys(eventData).length === 0) {
      return res.status(400).send('Bad Request: Empty payload');
    }

    // Traiter l'événement (match commencé, but marqué, etc.)
    const docRef = await admin.firestore().collection('live-events').add({
      event: eventData,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'api-sports-webhook'
    });

    console.log('Webhook event processed:', docRef.id);
    res.status(200).json({
      success: true,
      eventId: docRef.id
    });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});
