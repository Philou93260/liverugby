const functionsBase = require('firebase-functions');
const functions = functionsBase.region('europe-west1');
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
// FONCTION 8 : Polling intelligent des matchs en cours (toutes les 3 minutes)
// ============================================
exports.pollLiveMatches = functions.pubsub
  .schedule('*/3 * * * *') // Toutes les 3 minutes
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    try {
      const today = new Date().toISOString().split('T')[0];

      console.log(`[Polling] Vérification des matchs en cours - ${today}`);

      // Récupérer les matchs du jour depuis l'API
      const response = await rugbyAPI.get('/games', {
        params: {
          date: today,
          timezone: 'Europe/Paris',
          live: 'all' // Récupérer tous les matchs live
        }
      });

      const liveMatches = response.data.response || [];

      // Filtrer uniquement les matchs en cours
      const activeMatches = liveMatches.filter(match => {
        const status = match.status?.short;
        return ['1H', '2H', 'LIVE', 'HT'].includes(status);
      });

      console.log(`[Polling] ${activeMatches.length} match(s) en cours`);

      if (activeMatches.length === 0) {
        console.log('[Polling] Aucun match en cours, pas de notification à envoyer');
        return null;
      }

      // Traiter chaque match actif
      for (const match of activeMatches) {
        const matchId = match.id;
        const matchDocRef = admin.firestore().collection('live-matches').doc(matchId.toString());

        // Récupérer l'état précédent du match
        const matchDoc = await matchDocRef.get();
        const previousData = matchDoc.exists ? matchDoc.data() : null;

        // Données actuelles du match
        const currentStatus = match.status?.short;
        const currentHomeScore = match.scores?.home || 0;
        const currentAwayScore = match.scores?.away || 0;

        let hasChanged = false;
        let eventType = null;

        if (!previousData) {
          // Premier polling de ce match - match vient de commencer
          hasChanged = true;
          eventType = 'match_start';
          console.log(`[Polling] Nouveau match détecté: ${match.teams?.home?.name} vs ${match.teams?.away?.name}`);
        } else {
          // Vérifier les changements
          const previousStatus = previousData.status;
          const previousHomeScore = previousData.homeScore || 0;
          const previousAwayScore = previousData.awayScore || 0;

          // Changement de statut (1H -> HT -> 2H)
          if (currentStatus !== previousStatus) {
            hasChanged = true;
            eventType = 'status_change';
            console.log(`[Polling] Changement de statut: ${previousStatus} -> ${currentStatus}`);
          }

          // Changement de score
          if (currentHomeScore !== previousHomeScore || currentAwayScore !== previousAwayScore) {
            hasChanged = true;
            eventType = 'score_update';
            console.log(`[Polling] Score changé: ${previousHomeScore}-${previousAwayScore} -> ${currentHomeScore}-${currentAwayScore}`);
          }

          // Match terminé
          if (['FT', 'AET', 'PEN'].includes(currentStatus) && !['FT', 'AET', 'PEN'].includes(previousStatus)) {
            hasChanged = true;
            eventType = 'match_end';
            console.log(`[Polling] Match terminé: ${match.teams?.home?.name} vs ${match.teams?.away?.name}`);
          }
        }

        // Si changement détecté, créer un événement
        if (hasChanged) {
          await admin.firestore().collection('live-events').add({
            event: {
              ...match,
              type: eventType,
              fixture: { id: matchId }
            },
            receivedAt: admin.firestore.FieldValue.serverTimestamp(),
            processed: false,
            source: 'polling'
          });

          console.log(`[Polling] Événement créé: ${eventType} pour match ${matchId}`);
        }

        // Mettre à jour l'état du match dans Firestore
        await matchDocRef.set({
          matchId,
          status: currentStatus,
          homeScore: currentHomeScore,
          awayScore: currentAwayScore,
          homeTeam: match.teams?.home?.name,
          awayTeam: match.teams?.away?.name,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          fullData: match
        });
      }

      // Nettoyer les anciens matchs terminés (plus de 24h)
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);

      const oldMatchesSnapshot = await admin.firestore()
        .collection('live-matches')
        .where('lastUpdated', '<', yesterday)
        .get();

      const batch = admin.firestore().batch();
      oldMatchesSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();

      console.log(`[Polling] ${oldMatchesSnapshot.size} ancien(s) match(s) nettoyé(s)`);
      console.log('[Polling] Vérification terminée');

      return null;
    } catch (error) {
      console.error('[Polling] Erreur:', error);
      return null;
    }
  });

// ============================================
// FONCTION 9 : Webhook pour mises à jour en temps réel (optionnel)
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
      processed: false,
      source: 'webhook'
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
