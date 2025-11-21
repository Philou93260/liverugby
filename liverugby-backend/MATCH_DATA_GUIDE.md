# Guide des données de match en temps réel

Ce guide explique comment toutes les informations des matchs remontent automatiquement dans Firebase.

## 📊 Données stockées automatiquement

Toutes les **3 minutes**, le système vérifie les matchs en cours et stocke :

### ✅ Informations de base
- **Début du match** - Statut "1H", "2H", "LIVE"
- **Mi-temps** - Statut "HT"
- **Fin du match** - Statut "FT", "AET", "PEN"
- **Temps écoulé** - Timer et timestamp

### ✅ Équipes
- **Nom** de l'équipe
- **Logo** (URL complète)
- **Score** actuel

### ✅ Ligue/Compétition
- **Nom** de la compétition
- **Logo** (URL complète)
- **Pays**

### ✅ Événements du match
- **Essais** (tries) - Joueur, équipe, temps
- **Cartons jaunes** - Joueur, équipe, temps
- **Cartons rouges** - Joueur, équipe, temps
- **Pénalités** - Joueur, équipe, temps
- **Conversions** - Joueur, équipe, temps
- **Remplacements** - Joueur entrant/sortant, temps

### ✅ Statistiques
- Nombre total d'essais
- Nombre total de cartons jaunes
- Nombre total de cartons rouges
- Nombre total de pénalités
- Nombre total de conversions
- Nombre total de remplacements

---

## 🗄️ Structure dans Firestore

### Collection : `live-matches`

Chaque match en cours a un document avec cet ID : `{matchId}`

```javascript
{
  matchId: 12345,
  status: "1H",  // 1H, HT, 2H, FT
  homeScore: 14,
  awayScore: 7,

  // Équipes avec logos
  homeTeam: {
    id: 100,
    name: "France",
    logo: "https://media.api-sports.io/rugby/teams/100.png"
  },
  awayTeam: {
    id: 101,
    name: "Angleterre",
    logo: "https://media.api-sports.io/rugby/teams/101.png"
  },

  // Ligue avec logo
  league: {
    id: 1,
    name: "Six Nations",
    logo: "https://media.api-sports.io/rugby/leagues/1.png",
    country: "International"
  },

  // Temps
  time: {
    date: "2025-11-21T15:00:00+00:00",
    timestamp: 1732197600,
    timer: "25:34",
    elapsed: 25
  },

  // TOUS les événements du match
  events: [
    {
      type: "try",
      team: "home",
      player: {
        id: 500,
        name: "Dupont Antoine"
      },
      time: "15'",
      detail: "Essai après une percée"
    },
    {
      type: "conversion",
      team: "home",
      player: {
        id: 501,
        name: "Ntamack Romain"
      },
      time: "16'",
      detail: "Transformation réussie"
    },
    {
      type: "yellowcard",
      team: "away",
      player: {
        id: 600,
        name: "Smith Marcus"
      },
      time: "23'",
      detail: "Jeu dangereux"
    },
    {
      type: "penalty",
      team: "away",
      player: {
        id: 601,
        name: "Farrell Owen"
      },
      time: "25'",
      detail: "Pénalité réussie"
    }
  ],

  // Résumé automatique
  eventsSummary: {
    tries: 2,
    conversions: 2,
    penalties: 3,
    yellowCards: 1,
    redCards: 0,
    substitutions: 4
  },

  // Stade
  venue: {
    name: "Stade de France",
    city: "Paris"
  },

  // Statistiques complètes
  statistics: [...],

  lastUpdated: Timestamp,
  fullData: {...}  // Données brutes complètes de l'API
}
```

---

## 📱 Utiliser dans votre app

### 1. Écouter les changements d'un match en temps réel

```javascript
import { doc, onSnapshot } from 'firebase/firestore';

const matchId = 12345;
const matchRef = doc(db, 'live-matches', matchId.toString());

const unsubscribe = onSnapshot(matchRef, (doc) => {
  if (doc.exists()) {
    const match = doc.data();

    console.log('Score:', `${match.homeScore} - ${match.awayScore}`);
    console.log('Statut:', match.status);
    console.log('Temps:', match.time.timer);

    // Afficher les logos
    console.log('Logo équipe domicile:', match.homeTeam.logo);
    console.log('Logo équipe extérieure:', match.awayTeam.logo);
    console.log('Logo ligue:', match.league.logo);

    // Afficher les événements
    match.events.forEach(event => {
      console.log(`${event.time} - ${event.type} par ${event.player.name}`);
    });

    // Résumé
    console.log('Essais:', match.eventsSummary.tries);
    console.log('Cartons jaunes:', match.eventsSummary.yellowCards);
    console.log('Cartons rouges:', match.eventsSummary.redCards);
  }
});
```

### 2. Récupérer via une fonction Cloud

```javascript
import { getFunctions, httpsCallable } from 'firebase/functions';

const functions = getFunctions();
const getLiveMatch = httpsCallable(functions, 'getLiveMatchDetails');

const result = await getLiveMatch({ matchId: 12345 });
const match = result.data.match;

console.log('Match:', match.homeTeam.name, 'vs', match.awayTeam.name);
console.log('Score:', match.homeScore, '-', match.awayScore);
console.log('Essais:', match.summary.tries);
console.log('Cartons:', match.summary.yellowCards, 'jaunes,', match.summary.redCards, 'rouges');
```

### 3. Afficher les essais

```javascript
const tries = match.events.filter(e => e.type === 'try');

tries.forEach(essai => {
  console.log(`⭐ ${essai.player.name} (${essai.team}) - ${essai.time}`);
});
```

### 4. Afficher les cartons

```javascript
const yellowCards = match.events.filter(e => e.type === 'yellowcard');
const redCards = match.events.filter(e => e.type === 'redcard');

yellowCards.forEach(carton => {
  console.log(`🟨 ${carton.player.name} (${carton.team}) - ${carton.time}`);
});

redCards.forEach(carton => {
  console.log(`🟥 ${carton.player.name} (${carton.team}) - ${carton.time}`);
});
```

### 5. Afficher les pénalités

```javascript
const penalties = match.events.filter(e => e.type === 'penalty');

penalties.forEach(penalite => {
  console.log(`🎯 ${penalite.player.name} (${penalite.team}) - ${penalite.time}`);
});
```

---

## 🔍 Logs dans Firebase Functions

Dans les logs Firebase, vous verrez :

```
[Polling] Vérification des matchs en cours - 2025-11-21
[Polling] 2 match(s) en cours
[Polling] Nouveau match détecté: France vs Angleterre
[Polling] ⭐ ESSAI marqué par Dupont Antoine (home) à 15'
[Polling] ✅ TRANSFORMATION réussie par Ntamack Romain (home) à 16'
[Polling] 🟨 CARTON JAUNE pour Smith Marcus (away) à 23'
[Polling] 🎯 PÉNALITÉ réussie par Farrell Owen (away) à 25'
[Polling] Score changé: 7-0 -> 14-7
[Polling] Événement créé: score_update pour match 12345
```

---

## ⏱️ Fréquence de mise à jour

- **Polling automatique** : Toutes les **3 minutes**
- **Webhook** (si configuré) : **Instantané** (< 5 secondes)

---

## 🎯 Exemple d'utilisation complète

```javascript
// Composant React
import { useEffect, useState } from 'react';
import { doc, onSnapshot } from 'firebase/firestore';
import { db } from './firebase';

function LiveMatch({ matchId }) {
  const [match, setMatch] = useState(null);

  useEffect(() => {
    const matchRef = doc(db, 'live-matches', matchId.toString());

    const unsubscribe = onSnapshot(matchRef, (doc) => {
      if (doc.exists()) {
        setMatch(doc.data());
      }
    });

    return () => unsubscribe();
  }, [matchId]);

  if (!match) return <div>Chargement...</div>;

  return (
    <div className="live-match">
      <h1>{match.league.name}</h1>
      <img src={match.league.logo} alt={match.league.name} />

      <div className="teams">
        <div className="team">
          <img src={match.homeTeam.logo} alt={match.homeTeam.name} />
          <h2>{match.homeTeam.name}</h2>
          <div className="score">{match.homeScore}</div>
        </div>

        <div className="vs">VS</div>

        <div className="team">
          <img src={match.awayTeam.logo} alt={match.awayTeam.name} />
          <h2>{match.awayTeam.name}</h2>
          <div className="score">{match.awayScore}</div>
        </div>
      </div>

      <div className="status">
        {match.status} - {match.time.timer}
      </div>

      <div className="events">
        <h3>Événements du match</h3>

        <h4>Essais ({match.eventsSummary.tries})</h4>
        {match.events.filter(e => e.type === 'try').map((essai, i) => (
          <div key={i}>
            ⭐ {essai.player.name} - {essai.time}
          </div>
        ))}

        <h4>Cartons</h4>
        {match.events.filter(e => e.type === 'yellowcard').map((card, i) => (
          <div key={i}>
            🟨 {card.player.name} - {card.time}
          </div>
        ))}
        {match.events.filter(e => e.type === 'redcard').map((card, i) => (
          <div key={i}>
            🟥 {card.player.name} - {card.time}
          </div>
        ))}

        <h4>Pénalités ({match.eventsSummary.penalties})</h4>
        {match.events.filter(e => e.type === 'penalty').map((pen, i) => (
          <div key={i}>
            🎯 {pen.player.name} - {pen.time}
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

## ✅ Récapitulatif

| Information | Disponible | Mise à jour |
|-------------|------------|-------------|
| **Début match** | ✅ | Toutes les 3 min |
| **Temps** | ✅ | Toutes les 3 min |
| **Mi-temps** | ✅ | Toutes les 3 min |
| **Fin match** | ✅ | Toutes les 3 min |
| **Logos clubs** | ✅ | Toutes les 3 min |
| **Logo ligue** | ✅ | Toutes les 3 min |
| **Essais** | ✅ | Toutes les 3 min |
| **Cartons jaunes** | ✅ | Toutes les 3 min |
| **Cartons rouges** | ✅ | Toutes les 3 min |
| **Pénalités** | ✅ | Toutes les 3 min |
| **Conversions** | ✅ | Toutes les 3 min |
| **Remplacements** | ✅ | Toutes les 3 min |

**Toutes les données sont automatiquement stockées dans Firestore !** 🎉
