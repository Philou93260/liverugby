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

  console.log('📊 Résultat de l\'API (saison 2025):\n');
  console.log(`   Résultats: ${data.results}`);

  if (data.results === 0 || (data.response && data.response.length === 1 && !data.response[0].team?.name)) {
    console.log('❌ Classement vide ou incomplet pour 2025');
    console.log('\n🔄 Essayons avec season: 2024...\n');

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

  // Logger la structure du premier élément pour debug
  if (standings.length > 0) {
    console.log('\n📋 Structure du premier élément:');
    console.log(JSON.stringify(standings[0], null, 2));
    console.log('\n─'.repeat(80));
  }

  standings.forEach((standing, index) => {
    const team = standing.team;
    const stats = standing;

    // Logger toutes les clés disponibles
    if (index === 0) {
      console.log('\n🔑 Clés disponibles:', Object.keys(standing).join(', '));
      console.log('─'.repeat(80) + '\n');
    }

    const position = standing.position || index + 1;
    const teamName = team?.name || 'Unknown';
    const points = standing.points || stats.all?.points || 0;
    const played = stats.games?.played || stats.all?.played || 0;
    const win = stats.games?.win || stats.all?.win || 0;
    const draw = stats.games?.draw || stats.all?.draw || 0;
    const lose = stats.games?.lose || stats.all?.lose || 0;

    console.log(`${position}. ${teamName}`);
    console.log(`   Points: ${points} | J: ${played} | V: ${win} | N: ${draw} | D: ${lose}`);
  });

  console.log('\n✅ Classement récupéré avec succès');
  console.log(`   Total équipes: ${standings.length}`);
  console.log(`   Saison: ${result.data?.parameters?.season || 'inconnue'}`);
})
.catch(error => {
  console.error('❌ Erreur:', error.response?.data || error.message);
});
