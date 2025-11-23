#!/usr/bin/env node

/**
 * Script de test pour interroger l'API Rugby pour un match spécifique
 * Usage: node test-api-match.js <matchId>
 */

const axios = require('axios');

const API_KEY = process.env.API_SPORTS_KEY || 'VOTRE_CLE_API';
const API_BASE_URL = 'https://v1.rugby.api-sports.io';

const matchId = process.argv[2] || '49925'; // Stade Français vs Toulon par défaut

console.log(`🔍 Interrogation de l'API pour le match ${matchId}...\n`);

axios.get(`${API_BASE_URL}/games`, {
  params: {
    id: matchId  // ✅ ID seul, sans date
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
    console.log('❌ Aucun match trouvé pour cet ID');
    return;
  }

  const match = data.response[0];

  console.log('\n🏉 Informations du match:');
  console.log(`   ID: ${match.id}`);
  console.log(`   ${match.teams?.home?.name} vs ${match.teams?.away?.name}`);
  console.log(`   Score: ${match.scores?.home} - ${match.scores?.away}`);
  console.log(`   Status: ${match.status?.short} (${match.status?.long})`);

  console.log('\n📋 Événements (events):');
  console.log(`   Existe: ${!!match.events}`);
  console.log(`   Type: ${typeof match.events}`);
  console.log(`   Est un tableau: ${Array.isArray(match.events)}`);
  console.log(`   Nombre: ${match.events ? match.events.length : 0}`);

  if (match.events && match.events.length > 0) {
    console.log('\n   Types d\'événements:');
    const eventTypes = [...new Set(match.events.map(e => e.type))];
    eventTypes.forEach(type => {
      const count = match.events.filter(e => e.type === type).length;
      console.log(`   - ${type}: ${count}`);
    });

    console.log('\n   Premiers événements:');
    match.events.slice(0, 5).forEach((event, i) => {
      console.log(`   ${i+1}. ${event.type} - ${event.player?.name || 'N/A'} (${event.time})`);
    });
  } else {
    console.log('   ⚠️  Aucun événement retourné par l\'API');
  }

  console.log('\n🔑 Toutes les clés du match:');
  console.log(`   ${Object.keys(match).join(', ')}`);

  console.log('\n📦 Structure complète:');
  console.log(JSON.stringify(match, null, 2));
})
.catch(error => {
  console.error('❌ Erreur:', error.response?.data || error.message);
});
