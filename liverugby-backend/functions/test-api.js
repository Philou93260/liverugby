const functionsBase = require('firebase-functions');
const functions = functionsBase.region('us-central1');
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
// FONCTION TEST : Voir les données de l'API Rugby
// ============================================
exports.testRugbyAPI = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { date, matchId } = data;
    const testDate = date || new Date().toISOString().split('T')[0];

    console.log(`[TEST] Test de l'API Rugby pour la date: ${testDate}`);

    // 1. Récupérer les matchs du jour
    const matchesResponse = await rugbyAPI.get('/games', {
      params: {
        date: testDate,
        timezone: 'Europe/Paris'
      }
    });

    const matches = matchesResponse.data.response || [];

    console.log(`[TEST] ${matches.length} match(s) trouvé(s)`);

    // Si un matchId est fourni, récupérer les détails
    let matchDetails = null;
    if (matchId) {
      const detailsResponse = await rugbyAPI.get('/games', {
        params: {
          id: matchId
        }
      });
      matchDetails = detailsResponse.data.response[0] || null;
    } else if (matches.length > 0) {
      // Sinon prendre le premier match comme exemple
      matchDetails = matches[0];
    }

    // Analyser la structure des données
    const analysis = {
      totalMatches: matches.length,
      exampleMatch: matchDetails,
      dataStructure: matchDetails ? {
        // Informations générales
        hasMatchId: !!matchDetails.id,
        hasDate: !!matchDetails.date,
        hasTimestamp: !!matchDetails.timestamp,

        // Statut du match
        status: {
          available: !!matchDetails.status,
          long: matchDetails.status?.long || null,
          short: matchDetails.status?.short || null,
          timer: matchDetails.status?.timer || null
        },

        // Équipes
        teams: {
          available: !!matchDetails.teams,
          homeTeam: {
            hasId: !!matchDetails.teams?.home?.id,
            hasName: !!matchDetails.teams?.home?.name,
            hasLogo: !!matchDetails.teams?.home?.logo,
            name: matchDetails.teams?.home?.name || null,
            logo: matchDetails.teams?.home?.logo || null
          },
          awayTeam: {
            hasId: !!matchDetails.teams?.away?.id,
            hasName: !!matchDetails.teams?.away?.name,
            hasLogo: !!matchDetails.teams?.away?.logo,
            name: matchDetails.teams?.away?.name || null,
            logo: matchDetails.teams?.away?.logo || null
          }
        },

        // Scores
        scores: {
          available: !!matchDetails.scores,
          home: matchDetails.scores?.home || null,
          away: matchDetails.scores?.away || null
        },

        // Ligue/Compétition
        league: {
          available: !!matchDetails.league,
          hasId: !!matchDetails.league?.id,
          hasName: !!matchDetails.league?.name,
          hasLogo: !!matchDetails.league?.logo,
          hasCountry: !!matchDetails.league?.country,
          name: matchDetails.league?.name || null,
          logo: matchDetails.league?.logo || null,
          country: matchDetails.league?.country || null
        },

        // Événements (essais, cartons, etc.)
        events: {
          available: !!matchDetails.events,
          count: matchDetails.events?.length || 0,
          types: matchDetails.events ?
            [...new Set(matchDetails.events.map(e => e.type))] : [],
          examples: matchDetails.events?.slice(0, 3) || []
        },

        // Stade
        venue: {
          available: !!matchDetails.venue,
          name: matchDetails.venue?.name || null,
          city: matchDetails.venue?.city || null
        },

        // Statistiques
        statistics: {
          available: !!matchDetails.statistics,
          count: matchDetails.statistics?.length || 0
        },

        // Toutes les clés disponibles
        allKeys: matchDetails ? Object.keys(matchDetails) : []
      } : null
    };

    return {
      success: true,
      date: testDate,
      analysis,
      rawData: matchDetails, // Données brutes complètes
      quota: {
        remaining: matchesResponse.headers['x-ratelimit-requests-remaining'],
        limit: matchesResponse.headers['x-ratelimit-requests-limit']
      }
    };

  } catch (error) {
    console.error('[TEST] Erreur:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION TEST : Voir un match spécifique en détail
// ============================================
exports.getMatchFullDetails = functions.https.onCall(async (data, context) => {
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

    const match = response.data.response[0];

    return {
      success: true,
      match,
      details: {
        // Logos
        logos: {
          homeTeamLogo: match.teams?.home?.logo,
          awayTeamLogo: match.teams?.away?.logo,
          leagueLogo: match.league?.logo
        },

        // Événements du match (essais, cartons, etc.)
        events: match.events || [],
        eventTypes: match.events ?
          [...new Set(match.events.map(e => e.type))] : [],

        // Recherche spécifique
        hasTrials: match.events?.some(e => e.type === 'try') || false,
        hasYellowCards: match.events?.some(e => e.type === 'yellowcard') || false,
        hasRedCards: match.events?.some(e => e.type === 'redcard') || false,
        hasHalfTime: match.status?.short === 'HT',

        // Statistiques
        statistics: match.statistics || []
      }
    };

  } catch (error) {
    console.error('[TEST] Erreur:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
