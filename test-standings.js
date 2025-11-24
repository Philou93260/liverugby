#!/usr/bin/env node

/**
 * Script de test pour récupérer le classement Top 14
 */

const axios = require('axios');

const API_KEY = process.env.API_SPORTS_KEY || 'VOTRE_CLE_API';
const API_BASE_URL = 'https://v1.rugby.api-sports.io';

console.log('🏆 Récupération du classement Top 14...\n');

axios.get(`${API_BASE_URL}/standings`, {
  params: {
    league: 16,      // Top 14
    season: 2025
  },
  headers: {
    'x-apisports-key': API_KEY
  }
})
.then(response => {
  const data = response.data;

  console.log('📊 Résultat de l\'API:\n');
  console.log(`   Résultats: ${data.results}`);

  if (data.results === 0) {
    console.log('❌ Aucun classement trouvé');
    console.log('\nEssayons avec season: 2024...');

    return axios.get(`${API_BASE_URL}/standings`, {
      params: {
        league: 16,
        season: 2024
      },
      headers: {
        'x-apisports-key': API_KEY
      }
    });
  }

  return { data };
})
.then(result => {
  const data = result.data;
  const standings = data.response;

  if (!standings || standings.length === 0) {
    console.log('❌ Pas de données de classement');
    return;
  }

  console.log('\n🏉 Classement Top 14:');
  console.log('─'.repeat(80));

  standings.forEach((standing, index) => {
    const team = standing.team;
    const stats = standing;

    console.log(`${index + 1}. ${team?.name || 'Unknown'}`);
    console.log(`   Points: ${stats.points || 0} | J: ${stats.games?.played || 0} | V: ${stats.games?.win || 0} | N: ${stats.games?.draw || 0} | D: ${stats.games?.lose || 0}`);
  });

  console.log('\n✅ Classement récupéré avec succès');
  console.log(`   Total équipes: ${standings.length}`);
})
.catch(error => {
  console.error('❌ Erreur:', error.response?.data || error.message);
});
