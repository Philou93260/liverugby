const functionsBase = require('firebase-functions');
const functions = functionsBase.region('us-central1');
const admin = require('firebase-admin');
const axios = require('axios');

// ============================================
// CONFIGURATION SPORTRADAR
// ============================================
// À configurer avec: firebase functions:config:set sportradar.key="VOTRE_CLE_API"
const SPORTRADAR_API_KEY = functionsBase.config().sportradar?.key || process.env.SPORTRADAR_API_KEY;

// Base URLs Sportradar Rugby Union API
// Documentation: https://developer.sportradar.com/rugby-union/reference/rugby-union-api-overview
const SPORTRADAR_BASE_URL = 'https://api.sportradar.com/rugby-union/trial/v3/en';

// Configuration axios pour Sportradar
const sportradarAPI = axios.create({
  baseURL: SPORTRADAR_BASE_URL,
  params: {
    api_key: SPORTRADAR_API_KEY
  }
});

// ============================================
// COMPTEUR DE REQUÊTES (limite: 1000/mois)
// ============================================
async function trackAPICall(endpoint) {
  const monthKey = new Date().toISOString().slice(0, 7); // Format: YYYY-MM
  const counterRef = admin.firestore()
    .collection('apiUsage')
    .doc('sportradar')
    .collection('monthly')
    .doc(monthKey);

  await counterRef.set({
    [endpoint]: admin.firestore.FieldValue.increment(1),
    lastUpdate: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  // Récupérer le total
  const doc = await counterRef.get();
  const data = doc.data() || {};
  const total = Object.keys(data)
    .filter(key => key !== 'lastUpdate')
    .reduce((sum, key) => sum + (data[key] || 0), 0);

  console.log(`[Sportradar] Requêtes ce mois (${monthKey}): ${total}/1000`);

  if (total > 950) {
    console.warn(`⚠️ [Sportradar] ATTENTION: ${total}/1000 requêtes utilisées ce mois !`);
  }

  return total;
}

// ============================================
// WEBHOOK HANDLER - LA CLÉ POUR ÉCONOMISER LES REQUÊTES !
// ============================================
// Sportradar envoie automatiquement les updates de matchs
// = 0 requête API consommée !
exports.sportradarWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Vérifier que c'est bien Sportradar (validation optionnelle)
    const signature = req.headers['x-sportradar-signature'];

    // Log pour debug
    console.log('[Webhook] Événement reçu de Sportradar:', {
      type: req.body.event,
      matchId: req.body.match?.id
    });

    const event = req.body;

    // Traiter selon le type d'événement
    switch (event.event) {
      case 'match_started':
        await handleMatchStarted(event.match);
        break;

      case 'score_change':
        await handleScoreChange(event.match);
        break;

      case 'match_ended':
        await handleMatchEnded(event.match);
        break;

      case 'period_start':
      case 'period_end':
        await handlePeriodChange(event.match);
        break;

      default:
        console.log(`[Webhook] Type d'événement non géré: ${event.event}`);
    }

    // Toujours répondre 200 OK rapidement
    res.status(200).send({ received: true });

  } catch (error) {
    console.error('[Webhook] Erreur traitement:', error);
    // Répondre 200 quand même pour ne pas que Sportradar réessaie
    res.status(200).send({ error: 'processed with errors' });
  }
});

// ============================================
// HANDLERS WEBHOOK
// ============================================
async function handleMatchStarted(match) {
  console.log(`[Webhook] Match commencé: ${match.id}`);

  // Sauvegarder dans liveMatches
  await admin.firestore()
    .collection('liveMatches')
    .doc(match.id.toString())
    .set({
      matchId: match.id,
      status: match.status,
      homeTeam: match.home_team?.name,
      awayTeam: match.away_team?.name,
      homeScore: match.home_score || 0,
      awayScore: match.away_score || 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'webhook'
    }, { merge: true });

  // Créer événement pour notifications
  await admin.firestore().collection('liveEvents').add({
    event: {
      ...match,
      type: 'match_start',
      fixture: { id: match.id }
    },
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    processed: false,
    source: 'webhook'
  });
}

async function handleScoreChange(match) {
  console.log(`[Webhook] Score changé: ${match.home_score}-${match.away_score}`);

  await admin.firestore()
    .collection('liveMatches')
    .doc(match.id.toString())
    .set({
      matchId: match.id,
      homeScore: match.home_score || 0,
      awayScore: match.away_score || 0,
      status: match.status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'webhook'
    }, { merge: true });

  // Événement pour notifications
  await admin.firestore().collection('liveEvents').add({
    event: {
      ...match,
      type: 'score_update',
      fixture: { id: match.id }
    },
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    processed: false,
    source: 'webhook'
  });
}

async function handleMatchEnded(match) {
  console.log(`[Webhook] Match terminé: ${match.id}`);

  await admin.firestore()
    .collection('liveMatches')
    .doc(match.id.toString())
    .set({
      matchId: match.id,
      status: 'FT',
      homeScore: match.home_score || 0,
      awayScore: match.away_score || 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'webhook'
    }, { merge: true });

  // Événement pour notifications
  await admin.firestore().collection('liveEvents').add({
    event: {
      ...match,
      type: 'match_end',
      fixture: { id: match.id }
    },
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    processed: false,
    source: 'webhook'
  });
}

async function handlePeriodChange(match) {
  console.log(`[Webhook] Changement de période: ${match.status}`);

  await admin.firestore()
    .collection('liveMatches')
    .doc(match.id.toString())
    .set({
      matchId: match.id,
      status: match.status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'webhook'
    }, { merge: true });
}

// ============================================
// FONCTION 1 : Récupérer les matchs du jour
// ============================================
// NOTE: À utiliser avec parcimonie (compte dans les 1000 requêtes/mois)
exports.getTodayMatches = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const today = new Date().toISOString().split('T')[0];

    // OPTIMISATION 1: Vérifier le cache Firestore d'abord
    const cachedDoc = await admin.firestore()
      .collection('matches')
      .doc(today)
      .get();

    if (cachedDoc.exists) {
      const cacheAge = Date.now() - cachedDoc.data().updatedAt.toMillis();
      // Cache valide pendant 30 minutes
      if (cacheAge < 30 * 60 * 1000) {
        console.log('[Sportradar] Retour depuis cache (0 requête API)');
        return {
          success: true,
          matches: cachedDoc.data().matches,
          fromCache: true
        };
      }
    }

    // Si pas de cache, faire l'appel API
    await trackAPICall('schedule_daily');

    const response = await sportradarAPI.get(`/schedules/${today}/summaries.json`);

    // Adapter le format Sportradar au format attendu par l'app
    const matches = response.data.summaries || [];

    // Sauvegarder dans cache
    await admin.firestore().collection('matches').doc(today).set({
      date: today,
      matches: matches,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      matches: matches,
      fromCache: false
    };
  } catch (error) {
    console.error('[Sportradar] Error fetching today matches:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 2 : Récupérer le classement d'une ligue
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

    // OPTIMISATION: Cache avec TTL de 24h (le classement change rarement)
    const cacheKey = `standings_${leagueId}_${season || 'current'}`;
    const cachedDoc = await admin.firestore()
      .collection('standingsCache')
      .doc(cacheKey)
      .get();

    if (cachedDoc.exists) {
      const cacheAge = Date.now() - cachedDoc.data().updatedAt.toMillis();
      // Cache valide pendant 24 heures
      if (cacheAge < 24 * 60 * 60 * 1000) {
        console.log('[Sportradar] Classement depuis cache (0 requête API)');
        return {
          success: true,
          standings: cachedDoc.data().standings,
          season: cachedDoc.data().season,
          fromCache: true
        };
      }
    }

    // Appel API
    await trackAPICall('standings');

    // Mapper leagueId vers competition_id Sportradar
    const competitionId = mapLeagueIdToSportradar(leagueId);
    const seasonYear = season || new Date().getFullYear();

    const response = await sportradarAPI.get(
      `/competitions/${competitionId}/seasons/${seasonYear}/standings.json`
    );

    const standings = response.data.standings || [];

    // Sauvegarder dans cache
    await admin.firestore().collection('standingsCache').doc(cacheKey).set({
      standings: standings,
      season: seasonYear,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      standings: standings,
      season: seasonYear,
      fromCache: false
    };
  } catch (error) {
    console.error('[Sportradar] Error fetching standings:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 3 : Polling intelligent (backup du webhook)
// ============================================
// IMPORTANT: Seulement quand matchs en cours ET si webhook ne fonctionne pas
exports.pollLiveMatches = functions.pubsub
  .schedule('*/5 * * * *') // Toutes les 5 minutes (au lieu de 1)
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    try {
      // Vérifier s'il y a des matchs en cours dans Firestore
      const liveMatchesSnapshot = await admin.firestore()
        .collection('liveMatches')
        .where('status', 'in', ['1H', '2H', 'HT', 'ET'])
        .get();

      if (liveMatchesSnapshot.empty) {
        console.log('[Polling] Aucun match en cours, skip (0 requête)');
        return null;
      }

      console.log(`[Polling] ${liveMatchesSnapshot.size} match(s) en cours`);

      // Vérifier si le webhook fonctionne
      const recentWebhookEvents = await admin.firestore()
        .collection('liveEvents')
        .where('source', '==', 'webhook')
        .where('receivedAt', '>', new Date(Date.now() - 10 * 60 * 1000)) // 10 dernières minutes
        .limit(1)
        .get();

      if (!recentWebhookEvents.empty) {
        console.log('[Polling] Webhook actif, skip polling (0 requête)');
        return null;
      }

      // Webhook down, faire du polling en backup
      console.log('[Polling] Webhook inactif, polling de backup activé');

      for (const doc of liveMatchesSnapshot.docs) {
        const matchId = doc.data().matchId;

        // Appel API pour ce match
        await trackAPICall('match_summary');
        const response = await sportradarAPI.get(`/matches/${matchId}/summary.json`);

        // Traiter la réponse (même logique que webhook)
        await handleScoreChange(response.data);

        // Attendre 1s entre chaque requête pour ne pas surcharger
        await new Promise(resolve => setTimeout(resolve, 1000));
      }

      return null;
    } catch (error) {
      console.error('[Polling] Erreur:', error);
      return null;
    }
  });

// ============================================
// UTILITAIRES
// ============================================
function mapLeagueIdToSportradar(apiSportsLeagueId) {
  // Mapper les IDs API-Sports vers Sportradar
  const mapping = {
    16: 'sr:competition:123456', // Top 14 (à ajuster avec le vrai ID Sportradar)
    17: 'sr:competition:234567', // Pro D2 (à ajuster)
    // TODO: Ajouter les autres ligues quand on aura les IDs Sportradar
  };

  return mapping[apiSportsLeagueId] || apiSportsLeagueId;
}

// Export pour utilisation dans index.js
module.exports = {
  getTodayMatches: exports.getTodayMatches,
  getLeagueStandings: exports.getLeagueStandings,
  pollLiveMatches: exports.pollLiveMatches,
  sportradarWebhook: exports.sportradarWebhook
};
