# Guide de test de l'API Rugby

Ce guide vous explique comment tester l'API Rugby et voir exactement quelles données remontent.

## 🔍 Que teste-t-on ?

- ✅ Logos des clubs
- ✅ Essais (tries)
- ✅ Cartons jaunes/rouges
- ✅ Mi-temps
- ✅ Changements de score
- ✅ Statistiques du match
- ✅ Et bien plus...

---

## 📦 Étape 1 : Déployer les fonctions de test

```bash
cd /Users/Philou/Downloads/liverugby/liverugby-backend
git pull origin claude/debug-deployment-data-01MX7QKYfJSVEpikhK2cbvjh
firebase deploy --only functions:testRugbyAPI,functions:getMatchFullDetails
```

---

## 🧪 Étape 2 : Tester l'API

### Option A : Via la console Firebase (recommandé)

1. Allez sur https://console.firebase.google.com
2. **Functions** → Cliquez sur `testRugbyAPI`
3. Onglet **Testing**
4. Entrez les données de test :

```json
{
  "date": "2025-11-21"
}
```

5. Cliquez sur **Run**

### Option B : Via votre application

```javascript
import { getFunctions, httpsCallable } from 'firebase/functions';

const functions = getFunctions();
const testAPI = httpsCallable(functions, 'testRugbyAPI');

// Tester avec la date du jour
const result = await testAPI({
  date: '2025-11-21'  // Format: YYYY-MM-DD
});

console.log('Résultat du test:', result.data);
```

---

## 📊 Résultat attendu

Vous obtiendrez une analyse complète comme ceci :

```json
{
  "success": true,
  "date": "2025-11-21",
  "analysis": {
    "totalMatches": 5,
    "dataStructure": {
      "teams": {
        "homeTeam": {
          "hasLogo": true,
          "name": "France",
          "logo": "https://media.api-sports.io/rugby/teams/123.png"
        },
        "awayTeam": {
          "hasLogo": true,
          "name": "Angleterre",
          "logo": "https://media.api-sports.io/rugby/teams/456.png"
        }
      },
      "league": {
        "hasLogo": true,
        "name": "Six Nations",
        "logo": "https://media.api-sports.io/rugby/leagues/1.png"
      },
      "events": {
        "count": 15,
        "types": ["try", "conversion", "penalty", "yellowcard"],
        "examples": [
          {
            "type": "try",
            "team": "home",
            "player": "Dupont Antoine",
            "time": "25'"
          }
        ]
      }
    }
  }
}
```

---

## 🎯 Données disponibles

### 1. **Logos** ✅

```json
{
  "homeTeamLogo": "URL_du_logo",
  "awayTeamLogo": "URL_du_logo",
  "leagueLogo": "URL_du_logo"
}
```

### 2. **Essais (Tries)** ✅

```json
{
  "type": "try",
  "team": "home",
  "player": {
    "id": 123,
    "name": "Dupont Antoine"
  },
  "time": "25'"
}
```

### 3. **Cartons jaunes** ✅

```json
{
  "type": "yellowcard",
  "team": "away",
  "player": {
    "id": 456,
    "name": "Smith John"
  },
  "time": "42'"
}
```

### 4. **Cartons rouges** ✅

```json
{
  "type": "redcard",
  "team": "home",
  "player": {
    "id": 789,
    "name": "Martin Pierre"
  },
  "time": "68'"
}
```

### 5. **Mi-temps** ✅

```json
{
  "status": {
    "short": "HT",
    "long": "Halftime"
  }
}
```

### 6. **Autres événements disponibles**

- `conversion` - Transformation
- `penalty` - Pénalité
- `drop_goal` - Drop
- `substitution` - Remplacement
- Et plus...

---

## 🔬 Tester un match spécifique

Si vous connaissez l'ID d'un match, vous pouvez obtenir tous les détails :

```javascript
const getDetails = httpsCallable(functions, 'getMatchFullDetails');
const result = await getDetails({
  matchId: 12345
});

console.log('Détails complets:', result.data);
```

Cela retournera :

```json
{
  "success": true,
  "match": { /* Données brutes complètes */ },
  "details": {
    "logos": {
      "homeTeamLogo": "...",
      "awayTeamLogo": "...",
      "leagueLogo": "..."
    },
    "events": [ /* Tous les événements */ ],
    "eventTypes": ["try", "conversion", "yellowcard"],
    "hasTrials": true,
    "hasYellowCards": true,
    "hasRedCards": false,
    "hasHalfTime": true,
    "statistics": [ /* Statistiques du match */ ]
  }
}
```

---

## 📝 Exemples pratiques

### Vérifier si on a des logos

```javascript
const result = await testAPI({ date: '2025-11-21' });

if (result.data.analysis.dataStructure.teams.homeTeam.hasLogo) {
  console.log('✅ Logo équipe domicile disponible');
  console.log('URL:', result.data.analysis.dataStructure.teams.homeTeam.logo);
}
```

### Compter les essais d'un match

```javascript
const result = await getDetails({ matchId: 12345 });
const tries = result.data.details.events.filter(e => e.type === 'try');
console.log(`${tries.length} essai(s) marqué(s)`);
```

### Vérifier les cartons

```javascript
const result = await getDetails({ matchId: 12345 });
console.log('Cartons jaunes:', result.data.details.hasYellowCards);
console.log('Cartons rouges:', result.data.details.hasRedCards);
```

---

## 🚨 Important

Ces fonctions de test **consomment votre quota API** !

Chaque appel = 1 requête API

Utilisez-les avec parcimonie pour :
- Vérifier la structure des données
- Déboguer
- Tester avant d'implémenter

**Ne les appelez PAS en boucle ou trop fréquemment !**

---

## 💡 Conseil

1. **Testez d'abord** avec `testRugbyAPI` pour voir la structure
2. **Notez** les champs disponibles
3. **Implémentez** dans votre app
4. **Désactivez** ou supprimez ces fonctions de test en production

---

## 🗑️ Supprimer les fonctions de test

Une fois vos tests terminés :

```bash
# Supprimer les fonctions de test
firebase functions:delete testRugbyAPI
firebase functions:delete getMatchFullDetails
```

Ou commentez les exports dans `functions/index.js` :

```javascript
// exports.testRugbyAPI = testAPI.testRugbyAPI;
// exports.getMatchFullDetails = testAPI.getMatchFullDetails;
```

Puis redéployez :

```bash
firebase deploy --only functions
```
