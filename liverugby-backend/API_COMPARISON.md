# 🏉 Comparaison des APIs Rugby - Top 14

## 📊 Tableau comparatif

| Critère | API-Sports (actuel) | Sportradar (trial) | TheSportsDB |
|---------|---------------------|-------------------|-------------|
| **Prix** | Payant (~$20-50/mois) | Gratuit 30j puis payant | Gratuit (limité) + Patreon |
| **Limite requêtes/mois** | Illimité* | 1000 | ~43,200 (30/min) |
| **Top 14 support** | ✅ Complet | ✅ Complet | ✅ Basique |
| **Live scores** | ✅ Oui | ✅ Oui | ⚠️ Limité/Non |
| **Webhook/Push** | ❌ Non | ❌ Non (trial) / 💰 Payant | ❌ Non |
| **Classements** | ✅ Complet | ⚠️ Partial | ✅ Oui |
| **Événements match** | ✅ Détaillés | ✅ Très détaillés | ⚠️ Basiques |
| **Qualité données** | ⚠️ Parfois pas à jour | ✅ Très fiable | ❓ Communautaire |
| **Polling requis** | Oui (1 min) | Oui (5-10 min) | Oui |

## 🔍 Analyse détaillée

### 1. API-Sports (solution actuelle)

**✅ Avantages :**
- Données complètes et structurées
- Pas de limite stricte de requêtes
- Polling rapide possible (1 minute)
- Vous connaissez déjà l'API
- Fonctionne actuellement

**❌ Inconvénients :**
- Coût mensuel (~$20-50)
- Données parfois pas à jour (votre feedback)
- Pas de webhook (nécessite polling)

**💰 Coût estimé :**
- ~$20-50/mois selon le plan
- Illimité en requêtes

**🎯 Cas d'usage idéal :**
- Besoin de données temps réel (polling 1 min)
- Budget disponible
- Besoin de fiabilité

---

### 2. Sportradar (trial 30 jours)

**✅ Avantages :**
- Données très fiables et officielles
- Trial gratuit 30 jours
- Couverture FULL pour live, résultats, événements
- Système d'invalidation automatique du classement fonctionne

**❌ Inconvénients :**
- SANS webhook Push dans le trial
- Limite stricte : 1000 requêtes/mois
- Après trial : coût élevé
- Classement en "PARTIAL coverage"

**💰 Coût estimé :**
- Gratuit 30 jours
- Puis payant (prix sur demande, généralement élevé)

**📊 Consommation avec polling :**
- Polling 10 min : ~336 req/mois (live)
- Classement : ~30 req/mois
- **Total : ~366 req/mois** (confortable)

**🎯 Cas d'usage idéal :**
- Tester la qualité pendant 30 jours
- Uniquement pour le classement (~30 req/mois = très peu cher après trial)
- Pas pour le live sans webhook

---

### 3. TheSportsDB (gratuit/communautaire)

**✅ Avantages :**
- **GRATUIT** (avec Patreon optionnel)
- 30 requêtes/minute = 43,200/mois (largement suffisant)
- Support Top 14 confirmé
- Communauté active

**❌ Inconvénients :**
- Live scores limités ou absents
- Données communautaires (qualité variable)
- Pas de webhook
- Documentation moins complète
- Peut manquer de détails (événements de match, stats)

**💰 Coût estimé :**
- Gratuit : 30 req/min
- Patreon (optionnel) : $2-10/mois pour supporter le projet

**📊 Limites :**
- 30 requêtes/minute
- Certaines recherches limitées (ex: 2 résultats max)

**🎯 Cas d'usage idéal :**
- Budget très limité
- Pas besoin de live temps réel
- Classement et résultats suffisent

---

## 🎯 Recommandations selon vos besoins

### Scénario A : Budget limité, live temps réel important

**Recommandation : API-Sports**
- Continuer avec l'actuel
- Polling 1 minute = données fraîches
- Coût maîtrisé (~$20-50/mois)

**OU combiner :**
- TheSportsDB pour classement/résultats (gratuit)
- API-Sports uniquement pour le live (si plan moins cher existe)

---

### Scénario B : Tester la qualité de Sportradar

**Recommandation : Hybride pendant 30 jours**

**Configuration :**
```javascript
// API-Sports pour le live (garder l'existant)
exports.getTodayMatches = rugbyAPI.getTodayMatches;
exports.pollLiveMatches = rugbyAPI.pollLiveMatches;

// Sportradar UNIQUEMENT pour le classement (test)
exports.getLeagueStandings = sportradarAPI.getLeagueStandings;
```

**Pendant 30 jours :**
- Tester si classement Sportradar meilleur qu'API-Sports
- ~30 requêtes/mois = très peu
- Décider à la fin du trial

**Après le trial :**
- Si classement Sportradar excellent → le garder uniquement pour ça
- Sinon → rester 100% API-Sports

---

### Scénario C : Découvrir TheSportsDB

**Recommandation : Tester en parallèle (gratuit)**

**Configuration :**
```javascript
// Créer thesportsdb-api.js
// Tester classement + résultats

// Comparer avec API-Sports
exports.testTheSportsDBStandings = ...
```

**Avantages :**
- 0€ de coût pour tester
- Peut remplacer API-Sports si qualité OK
- Économie importante si ça fonctionne

**Risques :**
- Qualité données incertaine (communautaire)
- Pas de live temps réel
- Peut nécessiter du travail d'adaptation

---

## 💡 Ma recommandation personnelle

**Phase 1 - Test TheSportsDB (2-3 jours, gratuit)**

1. Créer une intégration TheSportsDB
2. Tester qualité classement + résultats
3. Comparer avec API-Sports

**Si TheSportsDB OK :**
- Migration complète vers TheSportsDB
- Économie de $20-50/mois
- Polling confortable (30 req/min)

**Si TheSportsDB insuffisant :**
→ Phase 2

**Phase 2 - Test Sportradar classement (30 jours)**

1. Garder API-Sports pour le live
2. Utiliser Sportradar uniquement pour classement
3. Évaluer la différence de qualité

**Après 30 jours :**
- Si Sportradar classement excellent → le garder uniquement pour ça
- Sinon → 100% API-Sports

**Phase 3 - Décision finale**

Option finale selon résultats tests :
- **Meilleur rapport qualité/prix :** TheSportsDB (si qualité OK)
- **Meilleur qualité :** Sportradar classement + API-Sports live
- **Plus simple :** 100% API-Sports

---

## 🧪 Plan de test

### Semaine 1 : TheSportsDB

```bash
# Créer l'intégration
- thesportsdb-api.js
- testTheSportsDBStandings()
- testTheSportsDBMatches()

# Comparer avec API-Sports actuel
# Tester qualité données
# Décision : OK ou KO
```

**Coût : 0€**

### Semaine 2-5 : Sportradar (si TheSportsDB KO)

```bash
# Déployer Sportradar pour classement seulement
firebase deploy --only functions:getLeagueStandings

# API-Sports continue pour le live
# Évaluer pendant 30 jours
```

**Coût : 0€ pendant trial**

### Fin du trial : Décision finale

- Comparer qualité/prix de chaque solution
- Choisir la meilleure combinaison

---

## 📚 Sources

- [TheSportsDB French Top 14](https://www.thesportsdb.com/league/4430-french-top-14)
- [TheSportsDB Free API Documentation](https://www.thesportsdb.com/free_sports_api)
- [TheSportsDB Pricing](https://www.thesportsdb.com/docs_pricing)
- [Sportradar Rugby Documentation](https://developer.sportradar.com/rugby/reference/rugby-overview)
- [Top Sports APIs 2025](https://highlightly.net/blogs/top-sports-data-apis-in-2025)

---

## 🎯 Prochaine étape suggérée

**Créer une intégration TheSportsDB pour tester (gratuit, 2h de dev)**

Voulez-vous que je crée `thesportsdb-api.js` pour tester ?
