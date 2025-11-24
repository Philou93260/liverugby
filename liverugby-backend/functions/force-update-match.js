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
// FONCTION : Forcer la mise à jour d'un match
// ============================================
exports.forceUpdateMatch = functions.https.onCall(async (data, context) => {
  try {
    const { matchId } = data;

    if (!matchId) {
      throw new functions.https.HttpsError('invalid-argument', 'matchId requis');
    }

    console.log(`[ForceUpdate] Mise à jour forcée du match ${matchId}`);

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

    console.log(`[ForceUpdate] Match trouvé: ${match.teams?.home?.name} vs ${match.teams?.away?.name}`);
    console.log(`[ForceUpdate] Score: ${match.scores?.home} - ${match.scores?.away}`);
    console.log(`[ForceUpdate] Status: ${match.status?.short}`);

    // Mettre à jour dans Firestore
    const matchDocRef = admin.firestore().collection('liveMatches').doc(matchId.toString());

    const currentStatus = match.status?.short;
    const currentHomeScore = match.scores?.home || 0;
    const currentAwayScore = match.scores?.away || 0;

    await matchDocRef.set({
      matchId,
      status: currentStatus || null,
      homeScore: currentHomeScore,
      awayScore: currentAwayScore,

      // Informations des équipes avec logos
      homeTeam: {
        id: match.teams?.home?.id || null,
        name: match.teams?.home?.name || null,
        logo: match.teams?.home?.logo || null
      },
      awayTeam: {
        id: match.teams?.away?.id || null,
        name: match.teams?.away?.name || null,
        logo: match.teams?.away?.logo || null
      },

      // Informations de la ligue
      league: {
        id: match.league?.id || null,
        name: match.league?.name || null,
        logo: match.league?.logo || null,
        country: match.league?.country || null
      },

      // Temps du match
      time: {
        date: match.date || null,
        timestamp: match.timestamp || null,
        timer: match.status?.timer || null,
        elapsed: match.status?.elapsed || null
      },

      // Événements du match (essais, cartons, pénalités)
      events: match.events || [],

      // Analyse des événements
      eventsSummary: {
        tries: (match.events || []).filter(e => e.type === 'try').length,
        conversions: (match.events || []).filter(e => e.type === 'conversion').length,
        penalties: (match.events || []).filter(e => e.type === 'penalty').length,
        yellowCards: (match.events || []).filter(e => e.type === 'yellowcard').length,
        redCards: (match.events || []).filter(e => e.type === 'redcard').length,
        substitutions: (match.events || []).filter(e => e.type === 'substitution').length
      },

      // Stade
      venue: match.venue || null,

      // Statistiques
      statistics: match.statistics || [],

      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      fullData: match
    });

    console.log(`[ForceUpdate] ✅ Match ${matchId} mis à jour avec succès`);

    return {
      success: true,
      matchId,
      score: `${currentHomeScore} - ${currentAwayScore}`,
      status: currentStatus,
      message: 'Match mis à jour avec succès'
    };

  } catch (error) {
    console.error('[ForceUpdate] Erreur:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});
