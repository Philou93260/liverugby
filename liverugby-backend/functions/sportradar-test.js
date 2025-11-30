const functionsBase = require('firebase-functions');
const functions = functionsBase.region('us-central1');
const admin = require('firebase-admin');

// Importer les deux APIs
const apiSports = require('./rugby-api');
const sportradar = require('./sportradar-api');

// ============================================
// FONCTION TEST 1 : Comparer les matchs du jour
// ============================================
exports.testSportradarMatches = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    console.log('[Test] Comparaison des matchs du jour - API-Sports vs Sportradar');

    const results = {
      timestamp: new Date().toISOString(),
      apiSports: null,
      sportradar: null,
      comparison: null,
      errors: []
    };

    // Test API-Sports
    try {
      const apiSportsResult = await apiSports.getTodayMatches.run({ auth: context.auth });
      results.apiSports = {
        success: true,
        matchCount: apiSportsResult?.matches?.length || 0,
        matches: apiSportsResult?.matches || []
      };
      console.log(`[Test] API-Sports: ${results.apiSports.matchCount} matchs`);
    } catch (error) {
      results.apiSports = { success: false, error: error.message };
      results.errors.push(`API-Sports: ${error.message}`);
    }

    // Test Sportradar
    try {
      const sportradarResult = await sportradar.getTodayMatches.run({ auth: context.auth });
      results.sportradar = {
        success: true,
        matchCount: sportradarResult?.matches?.length || 0,
        matches: sportradarResult?.matches || [],
        fromCache: sportradarResult?.fromCache || false
      };
      console.log(`[Test] Sportradar: ${results.sportradar.matchCount} matchs (cache: ${results.sportradar.fromCache})`);
    } catch (error) {
      results.sportradar = { success: false, error: error.message };
      results.errors.push(`Sportradar: ${error.message}`);
    }

    // Comparaison
    if (results.apiSports.success && results.sportradar.success) {
      results.comparison = {
        matchCountDifference: results.sportradar.matchCount - results.apiSports.matchCount,
        apiSportsOnly: [],
        sportradarOnly: [],
        common: []
      };

      // Comparer les matchs
      const apiSportsTeams = results.apiSports.matches.map(m =>
        `${m.teams?.home?.name} vs ${m.teams?.away?.name}`
      );
      const sportradarTeams = results.sportradar.matches.map(m =>
        `${m.home_team?.name} vs ${m.away_team?.name}`
      );

      results.comparison.apiSportsCount = apiSportsTeams.length;
      results.comparison.sportradarCount = sportradarTeams.length;

      console.log('[Test] Comparaison terminée');
    }

    // Sauvegarder le résultat du test
    await admin.firestore().collection('apiTests').add({
      type: 'matches_comparison',
      results: results,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      results: results,
      recommendation: generateRecommendation(results)
    };

  } catch (error) {
    console.error('[Test] Erreur:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION TEST 2 : Comparer les classements
// ============================================
exports.testSportradarStandings = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const { leagueId } = data;
    if (!leagueId) {
      throw new functions.https.HttpsError('invalid-argument', 'leagueId requis (ex: 16 pour Top 14)');
    }

    console.log(`[Test] Comparaison du classement - League ${leagueId}`);

    const results = {
      timestamp: new Date().toISOString(),
      leagueId: leagueId,
      apiSports: null,
      sportradar: null,
      comparison: null,
      errors: []
    };

    // Test API-Sports
    try {
      const apiSportsResult = await apiSports.getLeagueStandings.run(
        { leagueId },
        { auth: context.auth }
      );
      results.apiSports = {
        success: true,
        teamCount: apiSportsResult?.standings?.length || 0,
        standings: apiSportsResult?.standings || [],
        season: apiSportsResult?.season
      };
      console.log(`[Test] API-Sports: ${results.apiSports.teamCount} équipes`);
    } catch (error) {
      results.apiSports = { success: false, error: error.message };
      results.errors.push(`API-Sports: ${error.message}`);
    }

    // Test Sportradar
    try {
      const sportradarResult = await sportradar.getLeagueStandings.run(
        { leagueId },
        { auth: context.auth }
      );
      results.sportradar = {
        success: true,
        teamCount: sportradarResult?.standings?.length || 0,
        standings: sportradarResult?.standings || [],
        season: sportradarResult?.season,
        fromCache: sportradarResult?.fromCache || false
      };
      console.log(`[Test] Sportradar: ${results.sportradar.teamCount} équipes (cache: ${results.sportradar.fromCache})`);
    } catch (error) {
      results.sportradar = { success: false, error: error.message };
      results.errors.push(`Sportradar: ${error.message}`);
    }

    // Comparaison
    if (results.apiSports.success && results.sportradar.success) {
      results.comparison = {
        teamCountMatch: results.apiSports.teamCount === results.sportradar.teamCount,
        teamCountDifference: results.sportradar.teamCount - results.apiSports.teamCount
      };

      // Comparer les noms d'équipes
      const apiSportsTeams = results.apiSports.standings.map(s => s.team?.name).filter(Boolean);
      const sportradarTeams = results.sportradar.standings.map(s => s.team?.name).filter(Boolean);

      results.comparison.apiSportsTeams = apiSportsTeams;
      results.comparison.sportradarTeams = sportradarTeams;

      console.log('[Test] Comparaison terminée');
    }

    // Sauvegarder le résultat du test
    await admin.firestore().collection('apiTests').add({
      type: 'standings_comparison',
      results: results,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      results: results,
      recommendation: generateRecommendation(results)
    };

  } catch (error) {
    console.error('[Test] Erreur:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION TEST 3 : Simuler un webhook
// ============================================
exports.testWebhookSimulation = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    console.log('[Test] Simulation d\'événement webhook');

    // Créer un événement de test
    const testEvent = {
      event: 'score_change',
      match: {
        id: 'TEST_' + Date.now(),
        home_team: { name: 'Toulouse', id: 'sr:team:1' },
        away_team: { name: 'La Rochelle', id: 'sr:team:2' },
        home_score: 21,
        away_score: 14,
        status: '1H'
      }
    };

    // Simuler le traitement webhook
    const eventRef = await admin.firestore().collection('liveEvents').add({
      event: {
        ...testEvent.match,
        type: 'score_update',
        fixture: { id: testEvent.match.id }
      },
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
      source: 'webhook_test'
    });

    console.log(`[Test] Événement test créé: ${eventRef.id}`);

    // Vérifier dans liveMatches
    const liveMatchRef = admin.firestore()
      .collection('liveMatches')
      .doc(testEvent.match.id.toString());

    await liveMatchRef.set({
      matchId: testEvent.match.id,
      homeTeam: testEvent.match.home_team.name,
      awayTeam: testEvent.match.away_team.name,
      homeScore: testEvent.match.home_score,
      awayScore: testEvent.match.away_score,
      status: testEvent.match.status,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'webhook_test'
    });

    return {
      success: true,
      message: 'Événement webhook simulé avec succès',
      eventId: eventRef.id,
      testEvent: testEvent,
      instructions: [
        '1. Vérifiez Firestore > liveEvents pour voir l\'événement',
        '2. Vérifiez Firestore > liveMatches pour voir le match',
        '3. Vérifiez que onMatchUpdate a été déclenché (logs)',
        '4. Supprimez les données de test après validation'
      ]
    };

  } catch (error) {
    console.error('[Test] Erreur:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// FONCTION TEST 4 : Vérifier l'usage API
// ============================================
exports.checkAPIUsage = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Vous devez être connecté');
    }

    const monthKey = new Date().toISOString().slice(0, 7); // YYYY-MM

    const usageDoc = await admin.firestore()
      .collection('apiUsage')
      .doc('sportradar')
      .collection('monthly')
      .doc(monthKey)
      .get();

    if (!usageDoc.exists) {
      return {
        success: true,
        month: monthKey,
        totalCalls: 0,
        limit: 1000,
        percentage: 0,
        status: 'OK - Aucune requête ce mois'
      };
    }

    const data_usage = usageDoc.data();
    const totalCalls = Object.keys(data_usage)
      .filter(key => key !== 'lastUpdate')
      .reduce((sum, key) => sum + (data_usage[key] || 0), 0);

    const percentage = (totalCalls / 1000) * 100;

    let status = 'OK';
    if (percentage > 95) status = 'CRITIQUE';
    else if (percentage > 80) status = 'ATTENTION';
    else if (percentage > 50) status = 'SURVEILLER';

    return {
      success: true,
      month: monthKey,
      totalCalls: totalCalls,
      limit: 1000,
      remaining: 1000 - totalCalls,
      percentage: percentage.toFixed(1),
      status: status,
      breakdown: data_usage,
      lastUpdate: data_usage.lastUpdate
    };

  } catch (error) {
    console.error('[Test] Erreur:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ============================================
// UTILITAIRES
// ============================================
function generateRecommendation(results) {
  if (results.errors.length > 0) {
    return {
      status: 'ERREUR',
      message: 'Des erreurs sont survenues pendant les tests',
      errors: results.errors
    };
  }

  if (!results.apiSports?.success || !results.sportradar?.success) {
    return {
      status: 'INCOMPLET',
      message: 'Impossible de comparer - une des APIs n\'a pas répondu'
    };
  }

  return {
    status: 'SUCCÈS',
    message: 'Les deux APIs fonctionnent, vous pouvez comparer les résultats',
    nextSteps: [
      '1. Vérifiez que les données Sportradar sont complètes',
      '2. Vérifiez que le format est compatible avec l\'app iOS',
      '3. Si OK, lancez le déploiement progressif'
    ]
  };
}

module.exports = {
  testSportradarMatches: exports.testSportradarMatches,
  testSportradarStandings: exports.testSportradarStandings,
  testWebhookSimulation: exports.testWebhookSimulation,
  checkAPIUsage: exports.checkAPIUsage
};
