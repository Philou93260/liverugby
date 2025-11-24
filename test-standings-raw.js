#!/usr/bin/env node

/**
 * Script ultra-simple pour voir la structure brute de l'API Standings
 */

const axios = require('axios');

const API_KEY = process.env.API_SPORTS_KEY || 'VOTRE_CLE_API';

console.log('🔍 Interrogation API Standings - Saison 2025\n');

axios.get('https://v1.rugby.api-sports.io/standings', {
  params: {
    league: 16,
    season: 2025
  },
  headers: {
    'x-apisports-key': API_KEY
  }
})
.then(response => {
  const data = response.data;

  console.log('📦 RÉPONSE COMPLÈTE (2025):');
  console.log('═'.repeat(80));
  console.log(JSON.stringify(data, null, 2));
  console.log('═'.repeat(80));

  console.log('\n🔄 Maintenant avec saison 2024...\n');

  return axios.get('https://v1.rugby.api-sports.io/standings', {
    params: {
      league: 16,
      season: 2024
    },
    headers: {
      'x-apisports-key': API_KEY
    }
  });
})
.then(response => {
  const data = response.data;

  console.log('📦 RÉPONSE COMPLÈTE (2024):');
  console.log('═'.repeat(80));
  console.log(JSON.stringify(data, null, 2));
  console.log('═'.repeat(80));
})
.catch(error => {
  console.error('❌ Erreur:', error.response?.data || error.message);
});
