# 🏉 Configuration Sportradar - Top 14

## 📋 IDs de référence

### Top 14 (Saison 2024-2025)

**Competition ID:** `sr:competition:420`
**Season ID:** `sr:season:132054`

### Mapping avec API-Sports

| Ligue | API-Sports ID | Sportradar Competition ID |
|-------|---------------|---------------------------|
| Top 14 | 16 | sr:competition:420 |
| Pro D2 | 17 | ❌ À déterminer |

## 📊 Couverture des données

### ✅ FULL COVERAGE (données complètes)

- **Live** - Matchs en direct
- **Planifié** - Calendrier des matchs
- **Results** - Résultats des matchs
- **Scoring events** - Événements de score (essais, transformations, etc.)
- **Squads** - Compositions d'équipes
- **Competitor profile** - Profils des équipes
- **Head2Head** - Historique des confrontations
- **Push (Webhook)** ⭐ - Notifications en temps réel

### ⚠️ PARTIAL COVERAGE (données limitées)

- **Standings** - Classements
- **Live standings** - Classements en direct

> Note: Les classements peuvent ne pas être aussi détaillés qu'avec API-Sports.
> À vérifier lors des tests.

### ❌ NO COVERAGE (pas disponible)

- **Boxscore** - Score détaillé par période
- **Match clock** - Horloge du match en temps réel

## 🎯 Impact sur l'application

### Ce qui fonctionne parfaitement avec Sportradar :

✅ **Matchs en direct** (FULL) - Via webhook, mieux qu'API-Sports !
✅ **Calendrier des matchs** (FULL) - Aucun problème
✅ **Résultats** (FULL) - Complets
✅ **Événements de score** (FULL) - Essais, drops, pénalités, etc.
✅ **Compositions d'équipes** (FULL) - Si besoin
✅ **Webhook push** (FULL) - La clé pour économiser les requêtes !

### Ce qui peut être limité :

⚠️ **Classements** (PARTIAL) - À tester, pourrait manquer certaines statistiques
⚠️ **Classements live** (PARTIAL) - Mise à jour peut être moins fréquente

### Ce qu'on ne pourra pas avoir :

❌ **Score par période** - Pas de boxscore détaillé
❌ **Chronomètre du match** - Pas d'horloge en temps réel

## 💡 Recommandations

### 1. Pour le classement (PARTIAL coverage)

**Option A - Continuer avec API-Sports pour le classement uniquement :**
```javascript
// Dans index.js
exports.getLeagueStandings = rugbyAPI.getLeagueStandings; // API-Sports
exports.getTodayMatches = sportradarAPI.getTodayMatches;  // Sportradar
```

**Avantages :**
- Classement complet et détaillé
- Coût API-Sports : ~30 requêtes/mois (classement seulement)
- Sportradar pour le live : ~70 requêtes/mois
- Total : ~100 requêtes sur 2 APIs

**Option B - Tout migrer vers Sportradar :**
- Tester d'abord la qualité du classement Sportradar
- Si suffisant, migrer complètement
- Économie d'un abonnement API

**Recommandation : Option A au départ**, puis tester Option B quand tout est stable.

### 2. Pour le live (FULL coverage)

✅ **Utiliser Sportradar avec webhook** :
- Couverture complète
- 0 requête API grâce au webhook
- Événements de score détaillés
- Meilleur que API-Sports !

### 3. Pour le match clock (NO coverage)

**Alternative** - Calculer le temps approximatif :
```javascript
// Quand le match commence
const kickoffTime = new Date();

// En 1ère mi-temps
const elapsed = Math.floor((Date.now() - kickoffTime) / 60000); // minutes

// Afficher "14' - 1ère mi-temps"
```

C'est approximatif mais suffisant si vous n'avez pas besoin de précision à la seconde.

## 🔗 Endpoints Sportradar à utiliser

### Pour les matchs du jour
```
GET /schedules/{date}/summaries.json
```

### Pour le classement
```
GET /seasons/sr:season:132054/standings.json
```

### Pour un match spécifique
```
GET /sport_events/sr:match:XXXXX/summary.json
```

### Pour les événements de score
```
GET /sport_events/sr:match:XXXXX/timeline.json
```

### Webhook (automatique)
```
POST https://us-central1-liverugby-6f075.cloudfunctions.net/sportradarWebhook
```

Événements à configurer :
- `match_started`
- `score_change`
- `match_ended`
- `period_start`
- `period_end`

## 🧪 Tests à faire demain

### 1. Tester le classement (PARTIAL)

```bash
firebase functions:shell
> testSportradarStandings({leagueId: 16})
```

**Vérifier :**
- [ ] Nombre d'équipes (devrait être 14)
- [ ] Ordre du classement
- [ ] Points, victoires, défaites
- [ ] Statistiques détaillées (essais marqués, etc.)

**Comparer avec API-Sports :**
- Si les données essentielles sont là → OK pour Sportradar
- Si des stats importantes manquent → Garder API-Sports pour le classement

### 2. Tester les matchs (FULL)

```bash
> testSportradarMatches({})
```

**Vérifier :**
- [ ] Liste des matchs du jour
- [ ] Horaires corrects
- [ ] Noms des équipes
- [ ] Scores (si matchs en cours)

### 3. Tester le webhook (FULL)

```bash
> testWebhookSimulation({})
```

**Vérifier dans Firestore :**
- [ ] Collection `liveEvents` → événement créé
- [ ] Collection `liveMatches` → match créé
- [ ] Fonction `onMatchUpdate` déclenchée (logs)

## 📅 Planning de migration

### Jour 1 - Configuration et tests
- [ ] Configurer clé API : `firebase functions:config:set sportradar.key="..."`
- [ ] Déployer fonctions de test
- [ ] Tester classement, matchs, webhook
- [ ] Analyser les résultats

### Jour 2-3 - Migration progressive si tests OK
- [ ] Migrer les matchs du jour → Sportradar
- [ ] Tester pendant 24h
- [ ] Si OK, configurer le webhook

### Jour 4-5 - Activation webhook
- [ ] Configurer webhook sur dashboard Sportradar
- [ ] Tester réception événements
- [ ] Désactiver polling API-Sports

### Jour 6-7 - Décision pour classement
- [ ] Si classement Sportradar OK → migrer
- [ ] Sinon → garder API-Sports pour classement uniquement

### Jour 8+ - Stabilisation
- [ ] Monitorer usage API
- [ ] Ajuster cache si nécessaire
- [ ] Supprimer API-Sports si migration 100%

## 🎯 Objectif final

**Scénario idéal (tout sur Sportradar) :**
- 0 requête pour le live (webhook)
- ~30 requêtes/mois pour classement
- ~60 requêtes/mois pour matchs du jour
- **Total : ~90 requêtes/mois** ✅

**Scénario hybride (si classement insuffisant) :**
- Sportradar : ~70 requêtes/mois (matchs + webhook)
- API-Sports : ~30 requêtes/mois (classement uniquement)
- **Total : ~100 requêtes sur 2 APIs** ✅
- Coût : 2 abonnements mais consommation très basse

Les deux scénarios sont largement sous les limites !
