const functionsBase = require('firebase-functions');
const functions = functionsBase.region('us-central1');
const admin = require('firebase-admin');
const axios = require('axios');

// Récupérer la clé API depuis la config Firebase
const API_KEY = functionsBase.config().apisports?.key || process.env.API_SPORTS_KEY;
const API_BASE_URL = 'https://v1.rugby.api-sports.io';

// Configuration axios
const rugbyAPI = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'x-apisports-key': API_KEY
  }
});

// ============================================
// FONCTION DEBUG : Voir la structure EXACTE d'un match
// ============================================
exports.debugMatchStructure = functions.https.onCall(async (data, context) => {
  try {
    const { matchId } = data;

    if (!matchId) {
      throw new functions.https.HttpsError('invalid-argument', 'matchId requis');
    }

    console.log(`[DEBUG] Récupération du match ${matchId} depuis l'API`);

    // Récupérer le match depuis l'API
    const response = await rugbyAPI.get('/games', {
      params: {
        id: matchId
      }
    });

    const match = response.data.response[0];

    if (!match) {
      throw new functions.https.HttpsError('not-found', 'Match non trouvé dans l\'API');
    }

    // Analyser la structure
    const debug = {
      matchId: match.id,
      status: match.status,

      // Vérifier events
      hasEvents: !!match.events,
      eventsIsArray: Array.isArray(match.events),
      eventsLength: match.events ? match.events.length : 0,
      eventsType: typeof match.events,
      eventsSample: match.events ? match.events.slice(0, 3) : null,

      // Vérifier toutes les clés du match
      allKeys: Object.keys(match),

      // Structure complète
      fullMatch: match
    };

    console.log('[DEBUG] Structure analysée:', JSON.stringify(debug, null, 2));

    return {
      success: true,
      debug
    };

  } catch (error) {
    console.error('[DEBUG] Erreur:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION DEBUG : Voir TOUS les matchs du jour et leur structure
// ============================================
exports.debugTodayMatches = functions.https.onCall(async (data, context) => {
  try {
    const today = new Date().toISOString().split('T')[0];

    console.log(`[DEBUG] Récupération des matchs du ${today}`);

    const response = await rugbyAPI.get('/games', {
      params: {
        date: today,
        timezone: 'Europe/Paris'
      }
    });

    const matches = response.data.response || [];

    console.log(`[DEBUG] ${matches.length} match(s) trouvé(s)`);

    const analysis = matches.map(match => ({
      id: match.id,
      teams: `${match.teams?.home?.name} vs ${match.teams?.away?.name}`,
      status: match.status?.short,

      // Analyse des événements
      hasEvents: !!match.events,
      eventsCount: match.events ? match.events.length : 0,
      eventsTypes: match.events ? [...new Set(match.events.map(e => e.type))] : [],

      // Analyse de ce qui existe
      hasScores: !!match.scores,
      hasTeams: !!match.teams,
      hasLeague: !!match.league,

      // Toutes les clés
      allKeys: Object.keys(match)
    }));

    return {
      success: true,
      totalMatches: matches.length,
      analysis,
      firstMatchFullData: matches[0] || null
    };

  } catch (error) {
    console.error('[DEBUG] Erreur:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
