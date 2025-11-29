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

    // Déterminer la saison en cours
    // Pour Top 14 : saison 2024-2025 = "2024" dans l'API
    let currentSeason = season;
    if (!currentSeason) {
      const now = new Date();
      const year = now.getFullYear();
      const month = now.getMonth() + 1; // 1-12

      // Si on est avant juillet, on est dans la saison précédente
      // Exemple : En janvier 2025, on est en saison 2024-2025 = "2024"
      currentSeason = (month < 7) ? year - 1 : year;
    }

    console.log(`[Standings] Récupération classement - League: ${leagueId}, Season: ${currentSeason}`);

    const response = await rugbyAPI.get('/standings', {
      params: {
        league: leagueId,
        season: currentSeason
      }
    });

    // Gérer le cas où l'API peut retourner un tableau simple ou un tableau de tableaux
    let standings = response.data.response || [];

    // Si c'est un tableau de tableaux, prendre le premier élément
    if (standings.length > 0 && Array.isArray(standings[0])) {
      standings = standings[0];
    }

    console.log(`[Standings] ${standings.length} équipe(s) récupérée(s)`);

    return {
      success: true,
      standings: standings,
      season: currentSeason
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
// FONCTION 8 : Polling intelligent des matchs en cours (toutes les 1 minute)
// ============================================
exports.pollLiveMatches = functions.pubsub
  .schedule('*/1 * * * *') // Toutes les 1 minute (latence réduite)
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    try {
      const today = new Date().toISOString().split('T')[0];

      console.log(`[Polling] Vérification des matchs en cours - ${today}`);

      // Récupérer TOUS les matchs du jour depuis l'API
      // Note: L'API Rugby ne supporte pas le paramètre 'live', on récupère tous les matchs du jour
      const response = await rugbyAPI.get('/games', {
        params: {
          date: today,
          timezone: 'Europe/Paris'
        }
      });

      const allMatches = response.data.response || [];

      console.log(`[Polling] ${allMatches.length} match(s) trouvé(s) aujourd'hui`);

      // Logger tous les statuts pour debug
      if (allMatches.length > 0) {
        allMatches.forEach((match, index) => {
          console.log(`[Polling] Match ${index + 1}: ${match.teams?.home?.name} vs ${match.teams?.away?.name} - Statut: ${match.status?.short || 'UNKNOWN'} (${match.status?.long || 'UNKNOWN'})`);
        });
      }

      // ============================================
      // STRATÉGIE : Traiter les matchs actifs + matchs récemment terminés
      // ============================================

      // 1. Filtrer les matchs actifs (en cours ou à venir)
      const activeMatches = allMatches.filter(match => {
        const status = match.status?.short;
        const inactiveStatuses = ['FT', 'AET', 'PEN', 'CANC', 'PST', 'ABD', 'AWD', 'WO'];
        return status && !inactiveStatuses.includes(status);
      });

      // 2. Récupérer les matchs dans Firestore qui sont en cours mais peut-être terminés dans l'API
      const firestoreActiveMatches = await admin.firestore()
        .collection('liveMatches')
        .where('status', 'in', ['NS', '1H', 'HT', '2H', 'ET', 'BT', 'PT'])
        .get();

      // 3. Pour chaque match Firestore "en cours", vérifier s'il est terminé dans l'API
      const matchesToUpdate = new Set(activeMatches.map(m => m.id));

      firestoreActiveMatches.docs.forEach(doc => {
        const firestoreMatchId = parseInt(doc.data().matchId);
        // Chercher ce match dans l'API (même s'il est FT)
        const apiMatch = allMatches.find(m => m.id === firestoreMatchId);
        if (apiMatch) {
          matchesToUpdate.add(apiMatch.id);
        }
      });

      // Convertir le Set en array de matchs complets
      const matchesToProcess = allMatches.filter(m => matchesToUpdate.has(m.id));

      console.log(`[Polling] ${activeMatches.length} match(s) actifs dans l'API`);
      console.log(`[Polling] ${firestoreActiveMatches.size} match(s) actifs dans Firestore`);
      console.log(`[Polling] ${matchesToProcess.length} match(s) à traiter au total`);

      if (matchesToProcess.length === 0) {
        console.log('[Polling] Aucun match à traiter');
        return null;
      }

      // Traiter chaque match (actifs + récemment terminés)
      for (const match of matchesToProcess) {
        const matchId = match.id;
        const matchDocRef = admin.firestore().collection('liveMatches').doc(matchId.toString());

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

        // Si changement détecté, créer un événement dans liveEvents
        if (hasChanged) {
          try {
            const eventDoc = await admin.firestore().collection('liveEvents').add({
              event: {
                ...match,
                type: eventType,
                fixture: { id: matchId }
              },
              receivedAt: admin.firestore.FieldValue.serverTimestamp(),
              processed: false,
              source: 'polling'
            });

            console.log(`[Polling] ✅ Événement créé dans liveEvents: ${eventType} pour match ${matchId} (ID: ${eventDoc.id})`);
          } catch (error) {
            console.error(`[Polling] ❌ Erreur création événement pour match ${matchId}:`, error);
          }
        } else {
          console.log(`[Polling] ℹ️ Aucun changement détecté pour match ${matchId} - Statut: ${currentStatus}`);
        }

        // Logger les nouveaux événements intéressants
        const currentEvents = match.events || [];
        const previousEvents = previousData?.events || [];

        if (currentEvents.length > previousEvents.length) {
          const newEvents = currentEvents.slice(previousEvents.length);
          newEvents.forEach(event => {
            const eventLog = {
              type: event.type,
              team: event.team,
              player: event.player?.name || 'Inconnu',
              time: event.time,
              detail: event.detail || ''
            };

            switch(event.type) {
              case 'try':
                console.log(`[Polling] ⭐ ESSAI marqué par ${eventLog.player} (${eventLog.team}) à ${eventLog.time}`);
                break;
              case 'yellowcard':
                console.log(`[Polling] 🟨 CARTON JAUNE pour ${eventLog.player} (${eventLog.team}) à ${eventLog.time}`);
                break;
              case 'redcard':
                console.log(`[Polling] 🟥 CARTON ROUGE pour ${eventLog.player} (${eventLog.team}) à ${eventLog.time}`);
                break;
              case 'penalty':
                console.log(`[Polling] 🎯 PÉNALITÉ réussie par ${eventLog.player} (${eventLog.team}) à ${eventLog.time}`);
                break;
              case 'conversion':
                console.log(`[Polling] ✅ TRANSFORMATION réussie par ${eventLog.player} (${eventLog.team}) à ${eventLog.time}`);
                break;
              default:
                console.log(`[Polling] 📌 ${event.type} par ${eventLog.player} à ${eventLog.time}`);
            }
          });
        }

        // Mettre à jour l'état du match dans Firestore avec TOUTES les infos
        // Ceci se fait TOUJOURS, même sans changement
        try {
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

          console.log(`[Polling] 💾 Match ${matchId} stocké dans liveMatches: ${match.teams?.home?.name} vs ${match.teams?.away?.name} (${currentStatus})`);
        } catch (error) {
          console.error(`[Polling] ❌ Erreur stockage match ${matchId} dans Firestore:`, error);
        }
      }

      // Nettoyer les anciens matchs terminés (plus de 24h)
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);

      const oldMatchesSnapshot = await admin.firestore()
        .collection('liveMatches')
        .where('lastUpdated', '<', yesterday)
        .get();

      const batch = admin.firestore().batch();
      oldMatchesSnapshot.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();

      console.log(`[Polling] ${oldMatchesSnapshot.size} ancien(s) match(s) nettoyé(s)`);
      console.log(`[Polling] ✅ Vérification terminée - ${activeMatches.length} match(s) traité(s)`);

      return null;
    } catch (error) {
      console.error('[Polling] Erreur:', error);
      return null;
    }
  });

// ============================================
// FONCTION 9 : Récupérer les détails complets d'un match en cours
// ============================================
exports.getLiveMatchDetails = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { matchId } = data;
    if (!matchId) {
      throw new functions.https.HttpsError('invalid-argument', 'matchId requis');
    }

    // Récupérer depuis Firestore
    const matchDoc = await admin.firestore()
      .collection('liveMatches')
      .doc(matchId.toString())
      .get();

    if (!matchDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Match non trouvé');
    }

    const matchData = matchDoc.data();

    return {
      success: true,
      match: {
        id: matchData.matchId,
        status: matchData.status,

        // Scores
        homeScore: matchData.homeScore,
        awayScore: matchData.awayScore,

        // Équipes avec logos
        homeTeam: matchData.homeTeam,
        awayTeam: matchData.awayTeam,

        // Ligue avec logo
        league: matchData.league,

        // Temps
        time: matchData.time,

        // Événements (essais, cartons, pénalités)
        events: matchData.events || [],

        // Résumé des événements
        summary: matchData.eventsSummary || {
          tries: 0,
          conversions: 0,
          penalties: 0,
          yellowCards: 0,
          redCards: 0,
          substitutions: 0
        },

        // Stade
        venue: matchData.venue,

        // Statistiques
        statistics: matchData.statistics || [],

        lastUpdated: matchData.lastUpdated
      }
    };

  } catch (error) {
    console.error('Erreur getLiveMatchDetails:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 10 : Webhook pour mises à jour en temps réel (optionnel)
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
    const eventDoc = await admin.firestore().collection('liveEvents').add({
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
