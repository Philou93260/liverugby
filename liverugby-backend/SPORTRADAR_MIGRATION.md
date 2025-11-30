# 📊 Migration vers Sportradar

## 🎯 Objectif

Migrer de **API-Sports** vers **Sportradar** pour avoir des données rugby plus fiables et à jour.

## ⚠️ Contrainte importante

**Plan gratuit Sportradar : 1000 requêtes/mois**
- ≈ 33 requêtes/jour
- Il faut donc optimiser au maximum !

## 🚀 Stratégie : WEBHOOK FIRST

### Pourquoi le webhook est la clé ?

**Avec polling (API-Sports actuel) :**
- ❌ Polling toutes les 1 minute = 1440 requêtes/jour = 43,200/mois
- ❌ Impossible avec 1000 requêtes/mois !

**Avec webhook (Sportradar) :**
- ✅ Sportradar nous envoie les updates automatiquement
- ✅ **0 requête API consommée** pour les matchs en direct !
- ✅ On économise 99% des requêtes

### Comment ça marche ?

```
┌─────────────┐           ┌──────────────┐           ┌─────────────┐
│  Sportradar │  webhook  │   Firebase   │  realtime │     App     │
│     API     │ ────────> │  Functions   │ ────────> │     iOS     │
└─────────────┘           └──────────────┘           └─────────────┘
     (0 requête)         (traitement gratuit)      (mise à jour live)
```

## 📋 Plan de migration

### Phase 1 : Configuration (Aujourd'hui)

1. **Récupérer la clé API Sportradar**
   ```bash
   firebase functions:config:set sportradar.key="VOTRE_CLE_API"
   ```

2. **Configurer le webhook sur Sportradar**
   - URL du webhook : `https://us-central1-liverugby-6f075.cloudfunctions.net/sportradarWebhook`
   - Événements à écouter :
     - ✅ `match_started`
     - ✅ `score_change`
     - ✅ `match_ended`
     - ✅ `period_start`
     - ✅ `period_end`

### Phase 2 : Test en parallèle (Demain)

**Tester les deux APIs côte à côte sans casser l'existant :**

1. L'app iOS continue d'utiliser `rugby-api.js` (API-Sports)
2. On test `sportradar-api.js` en parallèle via des fonctions de test
3. On compare les résultats

**Fonctions de test créées :**
- ✅ `testSportradarMatches` - Compare les matchs du jour
- ✅ `testSportradarStandings` - Compare les classements
- ✅ `testWebhookSimulation` - Simule un événement webhook

### Phase 3 : Bascule progressive

1. **Classement d'abord** (peu de requêtes)
   - Activer `getLeagueStandings` de Sportradar
   - Tester pendant 1-2 jours

2. **Matchs du jour ensuite**
   - Activer `getTodayMatches` de Sportradar
   - Avec cache de 30 minutes

3. **Webhook pour le live**
   - Activer le webhook
   - Désactiver le polling
   - **Économie massive de requêtes !**

### Phase 4 : Migration complète

Une fois tout validé :
- Supprimer `rugby-api.js`
- Renommer `sportradar-api.js` → `rugby-api.js`
- Supprimer la clé API-Sports

## 💡 Optimisations pour économiser les requêtes

### 1. Cache intelligent

**Classement :**
- Cache de **24 heures** (le classement change rarement)
- 1 requête/jour au lieu de plusieurs centaines

**Matchs du jour :**
- Cache de **30 minutes**
- Maximum 48 requêtes/jour au lieu de 1440

### 2. Polling intelligent (backup uniquement)

Le polling ne se déclenche QUE si :
- ✅ Il y a des matchs en cours DANS Firestore
- ✅ ET le webhook n'a pas envoyé de données depuis 10 minutes

**Résultat :**
- Polling désactivé 95% du temps
- Maximum 12 requêtes/heure quand actif (au lieu de 60)

### 3. Compteur de requêtes

Un compteur Firestore suit l'utilisation :
```
apiUsage/sportradar/monthly/2025-11
  - schedule_daily: 45
  - standings: 12
  - match_summary: 8
  Total: 65/1000 ✅
```

Alerte automatique à 950 requêtes.

## 📊 Estimation de consommation

### Avec la nouvelle architecture :

**Classement :** 1/jour = ~30/mois

**Matchs du jour :** 2/jour (matin + après-midi) = ~60/mois

**Polling backup :** 10/mois (seulement si webhook down)

**Total estimé : ~100 requêtes/mois** ✅
- 10 fois moins que la limite !
- Marge confortable pour imprévus

## 🧪 Comment tester en parallèle ?

### 1. Déployer les fonctions de test

```bash
cd /Users/Philou/Downloads/liverugby/liverugby-backend
git pull origin feature/sportradar-integration
firebase deploy --only functions:testSportradarMatches,functions:testSportradarStandings
```

### 2. Tester depuis Firebase Console

Aller sur : https://console.firebase.google.com/project/liverugby-6f075/functions

Cliquer sur `testSportradarMatches` → Onglet "Tester" → Exécuter

Voir les logs pour comparer avec API-Sports.

### 3. Tester le webhook localement

```bash
# Simuler un événement webhook
curl -X POST https://us-central1-liverugby-6f075.cloudfunctions.net/sportradarWebhook \
  -H "Content-Type: application/json" \
  -d '{
    "event": "score_change",
    "match": {
      "id": "12345",
      "home_team": {"name": "Toulouse"},
      "away_team": {"name": "La Rochelle"},
      "home_score": 21,
      "away_score": 14,
      "status": "1H"
    }
  }'
```

Vérifier dans Firestore que l'événement apparaît dans `liveEvents`.

## 🔄 Rollback si problème

Si Sportradar ne fonctionne pas bien :

```bash
# Revenir sur la branche précédente
git checkout claude/fix-messaging-deployment-01Dzhk7R4TfsnsSz8Mjv55XS

# Redéployer
firebase deploy --only functions
```

L'app continue de fonctionner avec API-Sports.

## 📝 TODO avant la migration

- [ ] Récupérer la clé API Sportradar
- [ ] Trouver les IDs de compétitions Sportradar (Top 14, Pro D2, etc.)
- [ ] Configurer le webhook sur le dashboard Sportradar
- [ ] Tester les fonctions en parallèle
- [ ] Vérifier que le format des données est compatible avec l'app iOS
- [ ] Déployer progressivement (classement → matchs → webhook)

## 🆘 Ressources

- Documentation Sportradar Rugby : https://developer.sportradar.com/rugby-union/reference
- Dashboard Sportradar : https://dashboard.sportradar.com
- Webhooks Sportradar : https://developer.sportradar.com/rugby-union/docs/webhooks
