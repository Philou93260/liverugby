const functionsBase = require('firebase-functions');
const functions = functionsBase.region('us-central1');
const admin = require('firebase-admin');
const axios = require('axios');

// ============================================
// CONFIGURATION SPORTRADAR
// ============================================

// Récupérer la clé API depuis la config Firebase
const SPORTRADAR_API_KEY = functionsBase.config().sportradar?.key || process.env.SPORTRADAR_API_KEY;

// URL de base SportRadar Rugby Union API
// Format: https://api.sportradar.com/rugby-union/trial/v3/en/
const SPORTRADAR_BASE_URL = process.env.SPORTRADAR_BASE_URL || 'https://api.sportradar.com/rugby-union/trial/v3/en';

// Configuration axios pour SportRadar
const sportradarAPI = axios.create({
  baseURL: SPORTRADAR_BASE_URL,
  timeout: 10000, // 10 secondes
  params: {
    api_key: SPORTRADAR_API_KEY
  }
});

// ============================================
// HELPERS - Mapping des données SportRadar vers format unifié
// ============================================

/**
 * Convertir un match SportRadar vers le format unifié de l'application
 */
function mapSportradarMatch(sportEvent) {
  const homeCompetitor = sportEvent.competitors?.find(c => c.qualifier === 'home');
  const awayCompetitor = sportEvent.competitors?.find(c => c.qualifier === 'away');

  return {
    id: sportEvent.id || sportEvent.sport_event?.id,
    date: sportEvent.scheduled || sportEvent.sport_event?.scheduled,
    timestamp: sportEvent.scheduled ? new Date(sportEvent.scheduled).getTime() / 1000 : null,

    // Statut du match
    status: {
      short: mapSportradarStatus(sportEvent.sport_event_status?.status),
      long: sportEvent.sport_event_status?.status || 'Unknown',
      elapsed: sportEvent.sport_event_status?.period_scores?.length || 0,
      timer: null
    },

    // Équipes
    teams: {
      home: {
        id: homeCompetitor?.id,
        name: homeCompetitor?.name,
        logo: homeCompetitor?.country_code ?
          `https://flagcdn.com/w160/${homeCompetitor.country_code.toLowerCase()}.png` : null
      },
      away: {
        id: awayCompetitor?.id,
        name: awayCompetitor?.name,
        logo: awayCompetitor?.country_code ?
          `https://flagcdn.com/w160/${awayCompetitor.country_code.toLowerCase()}.png` : null
      }
    },

    // Scores
    scores: {
      home: sportEvent.sport_event_status?.home_score || 0,
      away: sportEvent.sport_event_status?.away_score || 0
    },

    // Ligue/Compétition
    league: {
      id: sportEvent.sport_event?.tournament?.id || sportEvent.tournament?.id,
      name: sportEvent.sport_event?.tournament?.name || sportEvent.tournament?.name,
      country: sportEvent.sport_event?.tournament?.category?.name || null,
      logo: null
    },

    // Stade
    venue: sportEvent.sport_event?.venue ? {
      id: sportEvent.sport_event.venue.id,
      name: sportEvent.sport_event.venue.name,
      city: sportEvent.sport_event.venue.city_name,
      country: sportEvent.sport_event.venue.country_name
    } : null,

    // Événements et statistiques (remplis par les détails du match)
    events: [],
    statistics: []
  };
}

/**
 * Mapper le statut SportRadar vers notre format court
 */
function mapSportradarStatus(status) {
  const statusMap = {
    'not_started': 'NS',
    'live': 'LIVE',
    'ended': 'FT',
    'closed': 'FT',
    'cancelled': 'CANC',
    'postponed': 'PST',
    'delayed': 'DELAY',
    'abandoned': 'ABD'
  };

  return statusMap[status] || 'NS';
}

/**
 * Extraire les événements d'un match (timeline SportRadar)
 */
function extractMatchEvents(timeline) {
  if (!timeline || !timeline.timeline) return [];

  return timeline.timeline.map(event => ({
    time: event.time,
    type: event.type,
    team: event.competitor,
    player: event.player ? {
      id: event.player.id,
      name: event.player.name
    } : null,
    detail: event.description || '',
    score: event.home_score && event.away_score ? {
      home: event.home_score,
      away: event.away_score
    } : null
  }));
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

    console.log(`[SportRadar] Récupération des matchs du ${today}`);

    // SportRadar : Récupérer le calendrier pour la date du jour
    // Note: Il faut connaître le tournament_id à l'avance
    // Pour l'instant, on fait une requête sur les principaux tournois
    const tournaments = data.tournaments || [
      'sr:tournament:22', // Six Nations
      'sr:tournament:23', // Rugby Championship
      'sr:tournament:24'  // Top 14
    ];

    let allMatches = [];

    for (const tournamentId of tournaments) {
      try {
        const response = await sportradarAPI.get(`/tournaments/${tournamentId}/schedule.json`);

        if (response.data && response.data.sport_events) {
          // Filtrer les matchs du jour
          const todayMatches = response.data.sport_events
            .filter(event => {
              const eventDate = event.scheduled?.split('T')[0];
              return eventDate === today;
            })
            .map(event => mapSportradarMatch(event));

          allMatches = [...allMatches, ...todayMatches];
        }
      } catch (error) {
        console.error(`[SportRadar] Erreur pour le tournoi ${tournamentId}:`, error.message);
      }
    }

    // Sauvegarder dans Firestore (cache)
    await admin.firestore().collection('matches').doc(today).set({
      date: today,
      matches: allMatches,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'sportradar'
    });

    console.log(`[SportRadar] ${allMatches.length} match(s) trouvé(s) pour le ${today}`);

    return {
      success: true,
      matches: allMatches
    };
  } catch (error) {
    console.error('[SportRadar] Error fetching today matches:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 2 : Récupérer les matchs d'un tournoi/ligue
// ============================================
exports.getLeagueMatches = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { tournamentId, season } = data;

    if (!tournamentId) {
      throw new functions.https.HttpsError('invalid-argument', 'tournamentId requis');
    }

    console.log(`[SportRadar] Récupération des matchs - Tournoi: ${tournamentId}, Saison: ${season || 'current'}`);

    // Récupérer le calendrier du tournoi
    const endpoint = season
      ? `/seasons/${season}/schedules.json`
      : `/tournaments/${tournamentId}/schedule.json`;

    const response = await sportradarAPI.get(endpoint);

    const matches = response.data.sport_events
      ? response.data.sport_events.map(event => mapSportradarMatch(event))
      : [];

    console.log(`[SportRadar] ${matches.length} match(s) trouvé(s)`);

    return {
      success: true,
      matches: matches
    };
  } catch (error) {
    console.error('[SportRadar] Error fetching league matches:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 3 : Récupérer les matchs d'une équipe
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

    console.log(`[SportRadar] Récupération des matchs - Équipe: ${teamId}`);

    // Récupérer les résultats de l'équipe
    const response = await sportradarAPI.get(`/competitors/${teamId}/results.json`);

    const matches = response.data.results
      ? response.data.results.map(result => mapSportradarMatch(result))
      : [];

    return {
      success: true,
      matches: matches
    };
  } catch (error) {
    console.error('[SportRadar] Error fetching team matches:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 4 : Récupérer les équipes d'un tournoi
// ============================================
exports.getLeagueTeams = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { tournamentId, season } = data;

    if (!tournamentId) {
      throw new functions.https.HttpsError('invalid-argument', 'tournamentId requis');
    }

    console.log(`[SportRadar] Récupération des équipes - Tournoi: ${tournamentId}`);

    // Récupérer les informations du tournoi qui contiennent les équipes
    const response = await sportradarAPI.get(`/tournaments/${tournamentId}/info.json`);

    const teams = response.data.groups
      ? response.data.groups.flatMap(group =>
          group.competitors?.map(competitor => ({
            id: competitor.id,
            name: competitor.name,
            abbreviation: competitor.abbreviation,
            country: competitor.country,
            countryCode: competitor.country_code,
            logo: competitor.country_code ?
              `https://flagcdn.com/w160/${competitor.country_code.toLowerCase()}.png` : null
          })) || []
        )
      : [];

    // Mettre en cache dans Firestore
    await admin.firestore().collection('leagues').doc(tournamentId.toString()).set({
      tournamentId,
      teams: teams,
      season: season || new Date().getFullYear(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'sportradar'
    }, { merge: true });

    return {
      success: true,
      teams: teams
    };
  } catch (error) {
    console.error('[SportRadar] Error fetching league teams:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 5 : Récupérer le classement d'un tournoi
// ============================================
exports.getLeagueStandings = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { tournamentId, season } = data;

    if (!tournamentId) {
      throw new functions.https.HttpsError('invalid-argument', 'tournamentId requis');
    }

    // Déterminer la saison en cours (même logique que l'ancien système)
    let currentSeason = season;
    if (!currentSeason) {
      const now = new Date();
      const year = now.getFullYear();
      const month = now.getMonth() + 1;
      currentSeason = (month < 7) ? year - 1 : year;
    }

    console.log(`[SportRadar] Récupération classement - Tournoi: ${tournamentId}, Saison: ${currentSeason}`);

    // Récupérer le classement du tournoi
    const response = await sportradarAPI.get(`/tournaments/${tournamentId}/standings.json`);

    // Extraire les classements
    const standings = response.data.standings
      ? response.data.standings.flatMap(standing =>
          standing.groups?.flatMap(group =>
            group.team_standings?.map(teamStanding => ({
              rank: teamStanding.rank,
              team: {
                id: teamStanding.competitor.id,
                name: teamStanding.competitor.name,
                logo: teamStanding.competitor.country_code ?
                  `https://flagcdn.com/w160/${teamStanding.competitor.country_code.toLowerCase()}.png` : null
              },
              played: teamStanding.played,
              won: teamStanding.win,
              draw: teamStanding.draw,
              lost: teamStanding.loss,
              pointsFor: teamStanding.points_for,
              pointsAgainst: teamStanding.points_against,
              pointsDiff: teamStanding.point_difference,
              points: teamStanding.points,
              form: teamStanding.current_outcome || null
            })) || []
          ) || []
        )
      : [];

    console.log(`[SportRadar] ${standings.length} équipe(s) au classement`);

    return {
      success: true,
      standings: standings,
      season: currentSeason
    };
  } catch (error) {
    console.error('[SportRadar] Error fetching standings:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 6 : Rechercher des équipes
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

    console.log(`[SportRadar] Recherche d'équipe: ${teamName}`);

    // SportRadar n'a pas d'endpoint de recherche directe
    // On va chercher dans notre cache Firestore
    const leaguesSnapshot = await admin.firestore()
      .collection('leagues')
      .where('source', '==', 'sportradar')
      .get();

    const teams = [];
    leaguesSnapshot.forEach(doc => {
      const leagueData = doc.data();
      if (leagueData.teams) {
        const matchingTeams = leagueData.teams.filter(team =>
          team.name.toLowerCase().includes(teamName.toLowerCase())
        );
        teams.push(...matchingTeams);
      }
    });

    // Dédupliquer par ID
    const uniqueTeams = Array.from(
      new Map(teams.map(team => [team.id, team])).values()
    );

    console.log(`[SportRadar] ${uniqueTeams.length} équipe(s) trouvée(s)`);

    return {
      success: true,
      teams: uniqueTeams
    };
  } catch (error) {
    console.error('[SportRadar] Error searching teams:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 7 : Récupérer les détails d'un match
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

    console.log(`[SportRadar] Récupération des détails du match: ${matchId}`);

    // Récupérer le résumé complet du match
    const response = await sportradarAPI.get(`/sport_events/${matchId}/summary.json`);

    const match = mapSportradarMatch(response.data);

    // Récupérer la timeline pour les événements détaillés
    try {
      const timelineResponse = await sportradarAPI.get(`/sport_events/${matchId}/timeline.json`);
      match.events = extractMatchEvents(timelineResponse.data);
    } catch (error) {
      console.error('[SportRadar] Erreur récupération timeline:', error.message);
      match.events = [];
    }

    // Ajouter les statistiques si disponibles
    if (response.data.statistics) {
      match.statistics = response.data.statistics;
    }

    return {
      success: true,
      match: match
    };
  } catch (error) {
    console.error('[SportRadar] Error fetching match details:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 8 : Récupérer les détails d'un match en cours (live)
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

    // Récupérer depuis Firestore (mis à jour par le polling)
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
        homeScore: matchData.homeScore,
        awayScore: matchData.awayScore,
        homeTeam: matchData.homeTeam,
        awayTeam: matchData.awayTeam,
        league: matchData.league,
        time: matchData.time,
        events: matchData.events || [],
        summary: matchData.eventsSummary || {
          tries: 0,
          conversions: 0,
          penalties: 0,
          yellowCards: 0,
          redCards: 0,
          substitutions: 0
        },
        venue: matchData.venue,
        statistics: matchData.statistics || [],
        lastUpdated: matchData.lastUpdated
      }
    };

  } catch (error) {
    console.error('[SportRadar] Erreur getLiveMatchDetails:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION 9 : Mise à jour automatique des matchs (Scheduled)
// ============================================
exports.updateMatchesDaily = functions.pubsub
  .schedule('0 6 * * *') // Tous les jours à 6h du matin
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    try {
      const today = new Date().toISOString().split('T')[0];

      console.log(`[SportRadar] Mise à jour automatique des matchs - ${today}`);

      // Liste des tournois à surveiller
      const tournaments = [
        'sr:tournament:22', // Six Nations
        'sr:tournament:23', // Rugby Championship
        'sr:tournament:24', // Top 14
        'sr:tournament:25'  // Premiership
      ];

      let allMatches = [];

      for (const tournamentId of tournaments) {
        try {
          const response = await sportradarAPI.get(`/tournaments/${tournamentId}/schedule.json`);

          if (response.data && response.data.sport_events) {
            const todayMatches = response.data.sport_events
              .filter(event => {
                const eventDate = event.scheduled?.split('T')[0];
                return eventDate === today;
              })
              .map(event => mapSportradarMatch(event));

            allMatches = [...allMatches, ...todayMatches];
          }
        } catch (error) {
          console.error(`[SportRadar] Erreur pour le tournoi ${tournamentId}:`, error.message);
        }
      }

      // Sauvegarder dans Firestore
      await admin.firestore().collection('matches').doc(today).set({
        date: today,
        matches: allMatches,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        autoUpdated: true,
        source: 'sportradar'
      });

      console.log(`[SportRadar] ${allMatches.length} match(s) mis à jour pour ${today}`);
      return null;
    } catch (error) {
      console.error('[SportRadar] Erreur mise à jour automatique:', error);
      return null;
    }
  });

// ============================================
// FONCTION 10 : Polling des matchs en cours (toutes les 1 minute)
// ============================================
exports.pollLiveMatches = functions.pubsub
  .schedule('*/1 * * * *') // Toutes les 1 minute
  .timeZone('Europe/Paris')
  .onRun(async (context) => {
    try {
      const today = new Date().toISOString().split('T')[0];

      console.log(`[SportRadar] Polling des matchs en cours - ${today}`);

      // Récupérer les matchs du jour depuis Firestore
      const matchesDoc = await admin.firestore()
        .collection('matches')
        .doc(today)
        .get();

      if (!matchesDoc.exists) {
        console.log('[SportRadar] Aucun match prévu aujourd\'hui');
        return null;
      }

      const todayMatches = matchesDoc.data().matches || [];

      // Filtrer les matchs en cours ou à venir
      const activeMatches = todayMatches.filter(match => {
        const status = match.status?.short;
        const inactiveStatuses = ['FT', 'CANC', 'PST', 'ABD'];
        return status && !inactiveStatuses.includes(status);
      });

      console.log(`[SportRadar] ${activeMatches.length} match(s) actif(s) à vérifier`);

      if (activeMatches.length === 0) {
        return null;
      }

      // Traiter chaque match actif
      for (const match of activeMatches) {
        const matchId = match.id;

        try {
          // Récupérer les données en temps réel depuis SportRadar
          const response = await sportradarAPI.get(`/sport_events/${matchId}/summary.json`);
          const updatedMatch = mapSportradarMatch(response.data);

          // Récupérer l'état précédent du match
          const matchDocRef = admin.firestore().collection('liveMatches').doc(matchId.toString());
          const matchDoc = await matchDocRef.get();
          const previousData = matchDoc.exists ? matchDoc.data() : null;

          let hasChanged = false;
          let eventType = null;

          if (!previousData) {
            hasChanged = true;
            eventType = 'match_start';
            console.log(`[SportRadar] Nouveau match en cours: ${updatedMatch.teams.home.name} vs ${updatedMatch.teams.away.name}`);
          } else {
            // Vérifier les changements
            const previousStatus = previousData.status;
            const previousHomeScore = previousData.homeScore || 0;
            const previousAwayScore = previousData.awayScore || 0;
            const currentStatus = updatedMatch.status.short;
            const currentHomeScore = updatedMatch.scores.home;
            const currentAwayScore = updatedMatch.scores.away;

            if (currentStatus !== previousStatus) {
              hasChanged = true;
              eventType = 'status_change';
              console.log(`[SportRadar] Changement de statut: ${previousStatus} -> ${currentStatus}`);
            }

            if (currentHomeScore !== previousHomeScore || currentAwayScore !== previousAwayScore) {
              hasChanged = true;
              eventType = 'score_update';
              console.log(`[SportRadar] Score changé: ${previousHomeScore}-${previousAwayScore} -> ${currentHomeScore}-${currentAwayScore}`);
            }

            if (['FT'].includes(currentStatus) && !['FT'].includes(previousStatus)) {
              hasChanged = true;
              eventType = 'match_end';
              console.log(`[SportRadar] Match terminé: ${updatedMatch.teams.home.name} vs ${updatedMatch.teams.away.name}`);
            }
          }

          // Si changement détecté, créer un événement
          if (hasChanged) {
            try {
              const eventDoc = await admin.firestore().collection('liveEvents').add({
                event: {
                  ...updatedMatch,
                  type: eventType,
                  fixture: { id: matchId }
                },
                receivedAt: admin.firestore.FieldValue.serverTimestamp(),
                processed: false,
                source: 'polling_sportradar'
              });

              console.log(`[SportRadar] ✅ Événement créé: ${eventType} pour match ${matchId}`);
            } catch (error) {
              console.error(`[SportRadar] ❌ Erreur création événement pour match ${matchId}:`, error);
            }
          }

          // Mettre à jour l'état du match dans Firestore
          await matchDocRef.set({
            matchId,
            status: updatedMatch.status.short,
            homeScore: updatedMatch.scores.home,
            awayScore: updatedMatch.scores.away,
            homeTeam: updatedMatch.teams.home,
            awayTeam: updatedMatch.teams.away,
            league: updatedMatch.league,
            time: {
              date: updatedMatch.date,
              timestamp: updatedMatch.timestamp
            },
            events: updatedMatch.events || [],
            eventsSummary: {
              tries: (updatedMatch.events || []).filter(e => e.type === 'try').length,
              conversions: (updatedMatch.events || []).filter(e => e.type === 'conversion').length,
              penalties: (updatedMatch.events || []).filter(e => e.type === 'penalty').length,
              yellowCards: (updatedMatch.events || []).filter(e => e.type === 'yellow_card').length,
              redCards: (updatedMatch.events || []).filter(e => e.type === 'red_card').length,
              substitutions: (updatedMatch.events || []).filter(e => e.type === 'substitution').length
            },
            venue: updatedMatch.venue,
            statistics: updatedMatch.statistics || [],
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            fullData: updatedMatch
          });

          console.log(`[SportRadar] 💾 Match ${matchId} mis à jour dans liveMatches`);

        } catch (error) {
          console.error(`[SportRadar] Erreur pour match ${matchId}:`, error.message);
        }
      }

      // Nettoyer les anciens matchs (> 24h)
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

      console.log(`[SportRadar] ${oldMatchesSnapshot.size} ancien(s) match(s) nettoyé(s)`);
      console.log(`[SportRadar] ✅ Polling terminé`);

      return null;
    } catch (error) {
      console.error('[SportRadar] Erreur polling:', error);
      return null;
    }
  });

// ============================================
// FONCTION 11 : Webhook SportRadar (optionnel si configuré)
// ============================================
exports.sportradarWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Vérifier la signature/authentification SportRadar
    const apiKey = req.headers['x-api-key'];
    if (apiKey !== SPORTRADAR_API_KEY) {
      return res.status(401).send('Unauthorized');
    }

    const eventData = req.body;

    console.log(`[SportRadar] Webhook reçu:`, JSON.stringify(eventData).substring(0, 200));

    // Traiter l'événement
    const eventDoc = await admin.firestore().collection('liveEvents').add({
      event: eventData,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
      source: 'webhook_sportradar'
    });

    console.log(`[SportRadar] Événement webhook enregistré: ${eventDoc.id}`);

    res.status(200).send('OK');
  } catch (error) {
    console.error('[SportRadar] Webhook error:', error);
    res.status(500).send('Error');
  }
});
