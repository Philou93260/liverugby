# 🚀 Guide de démarrage rapide - Sportradar

## 📋 Ce qui a été préparé

✅ **Nouvelle architecture créée** sur la branche `feature/sportradar-integration` :
- `sportradar-api.js` - API Sportradar avec webhook support
- `sportradar-test.js` - Fonctions pour tester en parallèle
- Documentation complète

✅ **Optimisations pour 1000 requêtes/mois** :
- Cache intelligent (24h pour classement, 30min pour matchs)
- Webhook (0 requête pour le live)
- Polling intelligent (backup uniquement)

✅ **Estimation : ~100 requêtes/mois** (10x moins que la limite)

## 🔑 Étape 1 : Configuration (5 minutes)

### 1.1 Récupérer votre clé API Sportradar

Allez sur https://developer.sportradar.com et récupérez votre clé API.

### 1.2 Configurer la clé dans Firebase

```bash
cd /Users/Philou/Downloads/liverugby/liverugby-backend

firebase functions:config:set sportradar.key="VOTRE_CLE_API_ICI"
```

### 1.3 Trouver les IDs de compétitions

Dans le code `sportradar-api.js`, ligne 282, vous devez mapper les IDs :

```javascript
const mapping = {
  16: 'sr:competition:XXXXX', // Top 14 - À TROUVER
  17: 'sr:competition:YYYYY', // Pro D2 - À TROUVER
};
```

**Comment trouver ces IDs :**
- Documentation Sportradar : https://developer.sportradar.com/rugby-union/reference
- Ou utilisez l'endpoint `/competitions.json` pour lister toutes les compétitions
- Cherchez "Top 14" et "Pro D2" dans les résultats

## 🧪 Étape 2 : Tester en parallèle (10 minutes)

### 2.1 Déployer les fonctions de test

```bash
# Récupérer la branche
git checkout feature/sportradar-integration
git pull origin feature/sportradar-integration

# Déployer UNIQUEMENT les fonctions de test
firebase deploy --only functions:testSportradarMatches,functions:testSportradarStandings,functions:testWebhookSimulation,functions:checkAPIUsage --project liverugby-6f075
```

### 2.2 Tester depuis Firebase Console

1. Aller sur https://console.firebase.google.com/project/liverugby-6f075/functions

2. **Tester les matchs du jour :**
   - Cliquer sur `testSportradarMatches`
   - Onglet "Logs"
   - Voir la comparaison API-Sports vs Sportradar

3. **Tester le classement :**
   - Cliquer sur `testSportradarStandings`
   - Passer `{"leagueId": 16}` en paramètre
   - Voir la comparaison

4. **Vérifier l'usage API :**
   - Cliquer sur `checkAPIUsage`
   - Voir combien de requêtes ont été consommées

### 2.3 Ce qu'il faut vérifier

✅ Les deux APIs retournent des données
✅ Le nombre de matchs/équipes est similaire
✅ Le format des données est compatible
✅ L'usage API reste sous 100 requêtes

## 🔗 Étape 3 : Configurer le webhook (15 minutes)

### 3.1 URL du webhook

```
https://us-central1-liverugby-6f075.cloudfunctions.net/sportradarWebhook
```

### 3.2 Configuration sur Sportradar

1. Aller sur https://dashboard.sportradar.com
2. Section "Webhooks" ou "Push Notifications"
3. Ajouter un nouveau webhook avec l'URL ci-dessus
4. Sélectionner les événements :
   - ✅ `match_started`
   - ✅ `score_change`
   - ✅ `match_ended`
   - ✅ `period_start`
   - ✅ `period_end`

### 3.3 Tester le webhook

```bash
# Déployer d'abord la fonction webhook
firebase deploy --only functions:sportradarWebhook --project liverugby-6f075

# Puis simuler un événement
firebase functions:shell
> testWebhookSimulation({})
```

Vérifier dans Firestore :
- Collection `liveEvents` → un nouvel événement doit apparaître
- Collection `liveMatches` → le match test doit apparaître

## 🔄 Étape 4 : Migration progressive (recommandé)

### Phase 1 : Classement uniquement (Jour 1-2)

```bash
# Modifier index.js pour utiliser Sportradar pour le classement
# Ligne 470, remplacer :
# exports.getLeagueStandings = rugbyAPI.getLeagueStandings;
# par :
# exports.getLeagueStandings = sportradarAPI.getLeagueStandings;

firebase deploy --only functions:getLeagueStandings --project liverugby-6f075
```

Tester dans l'app pendant 1-2 jours. Si OK, passer à la suite.

### Phase 2 : Matchs du jour (Jour 3-4)

```bash
# Modifier index.js
# exports.getTodayMatches = rugbyAPI.getTodayMatches;
# par :
# exports.getTodayMatches = sportradarAPI.getTodayMatches;

firebase deploy --only functions:getTodayMatches --project liverugby-6f075
```

### Phase 3 : Webhook live (Jour 5+)

```bash
# Déployer le polling et webhook
firebase deploy --only functions:pollLiveMatches,functions:sportradarWebhook --project liverugby-6f075
```

**IMPORTANT :** Le polling ne consommera presque pas de requêtes car :
- Il ne s'active QUE si matchs en cours
- Il ne s'active QUE si webhook inactif
- Il tourne toutes les 5 min (au lieu de 1 min)

## 📊 Monitoring

### Vérifier l'usage API régulièrement

```bash
# Via la fonction de test
firebase functions:shell
> checkAPIUsage({})

# Ou directement dans Firestore
# Collection: apiUsage/sportradar/monthly/2025-11
```

### Alertes

Le système affiche automatiquement un warning à 950 requêtes/1000.

Si vous approchez la limite :
- ✅ Augmenter le TTL du cache (30min → 1h pour matchs)
- ✅ Réduire le polling (5min → 10min)
- ✅ Vérifier que le webhook fonctionne bien

## ⚠️ En cas de problème

### Rollback rapide

```bash
# Revenir à API-Sports
git checkout claude/fix-messaging-deployment-01Dzhk7R4TfsnsSz8Mjv55XS
firebase deploy --only functions --project liverugby-6f075
```

### Debug webhook

Vérifier les logs :
```bash
firebase functions:log --only sportradarWebhook --project liverugby-6f075
```

Vérifier Firestore :
```
liveEvents → filtrer par source = 'webhook'
```

Si pas d'événements webhook depuis 30+ minutes :
- Vérifier la config webhook sur Sportradar
- Vérifier l'URL du webhook
- Le polling backup prendra le relais automatiquement

## 📞 Support

- Documentation Sportradar : https://developer.sportradar.com/rugby-union/docs
- Support Sportradar : support@sportradar.com
- Dashboard : https://dashboard.sportradar.com

## ✅ Checklist finale

- [ ] Clé API configurée
- [ ] IDs de compétitions trouvés et mappés
- [ ] Fonctions de test déployées
- [ ] Tests de comparaison OK
- [ ] Webhook configuré sur Sportradar
- [ ] Webhook testé et fonctionnel
- [ ] Migration phase 1 (classement) OK
- [ ] Migration phase 2 (matchs) OK
- [ ] Migration phase 3 (webhook live) OK
- [ ] Monitoring de l'usage API en place
- [ ] App iOS fonctionne correctement
