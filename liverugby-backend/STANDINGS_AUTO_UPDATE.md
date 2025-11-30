# 🔄 Mise à jour automatique du classement

## 📋 Comment ça fonctionne

### Système d'invalidation automatique du cache

Au lieu d'utiliser un cache avec durée fixe (12h, 24h...), le système invalide automatiquement le cache **quand un match Top 14 se termine**.

## 🎯 Scénario d'utilisation

### Samedi après-midi - Matchs de 14h

```
14:00 - Match Toulouse vs La Rochelle commence
14:05 - Utilisateur ouvre le classement
        → Cache existe → Classement affiché (0 requête)

16:30 - Match se termine (Toulouse gagne)
        → WEBHOOK reçu par Firebase
        → Détection : match Top 14 terminé
        → Cache du classement SUPPRIMÉ
        → Log: "Cache classement invalidé"

16:35 - Utilisateur ouvre le classement
        → Cache n'existe plus
        → Requête API Sportradar (1 requête)
        → Nouveau classement avec Toulouse à jour
        → Cache recréé
```

### Samedi soir - Matchs de 21h

```
21:00 - Match Lyon vs Bordeaux commence
21:05 - Utilisateur ouvre le classement
        → Cache existe (créé à 16:35) → Affiché (0 requête)

23:00 - Match se termine (Lyon gagne)
        → WEBHOOK reçu
        → Cache SUPPRIMÉ
        → Log: "Match Top 14 terminé → Invalidation cache"

23:05 - Utilisateur ouvre le classement
        → Cache supprimé
        → Requête API (1 requête)
        → Classement à jour avec Lyon
```

### Dimanche après-midi - Matchs de 17h

```
17:00 - 2 matchs en simultané
17:05 - Utilisateur ouvre le classement
        → Cache de samedi soir → Affiché (0 requête)

19:00 - Premier match se termine
        → Cache SUPPRIMÉ

19:05 - Utilisateur ouvre le classement
        → Requête API (1 requête)
        → Classement avec 1 match à jour

19:15 - Deuxième match se termine
        → Cache SUPPRIMÉ (déjà supprimé mais peu importe)

19:20 - Utilisateur ouvre le classement
        → Requête API (1 requête)
        → Classement complet du week-end
```

## 📊 Estimation de consommation

### Weekend type (Top 14)

**Samedi :**
- 3-4 matchs → 3-4 invalidations de cache
- Maximum 4 requêtes de classement (si utilisateurs consultent après chaque match)

**Dimanche :**
- 3-4 matchs → 3-4 invalidations
- Maximum 4 requêtes de classement

**Total weekend : ~8 requêtes maximum**

### Sur un mois

- 4 weekends × 8 requêtes = **32 requêtes/mois**

**Bien en-dessous de 1000 requêtes/mois !** ✅

## 🔍 Détails techniques

### 1. Détection de fin de match (Webhook)

```javascript
async function handleMatchEnded(match) {
  // ... sauvegarder le match terminé ...

  // Si c'est un match Top 14, invalider le cache
  if (match.competition?.id === 'sr:competition:420') {
    console.log('[Webhook] Match Top 14 terminé → Invalidation cache classement');

    const cacheKey = `standings_16_current`;
    await admin.firestore()
      .collection('standingsCache')
      .doc(cacheKey)
      .delete();
  }
}
```

### 2. Détection de fin de match (Polling backup)

Si le webhook ne fonctionne pas, le polling détecte aussi les fins de match :

```javascript
const wasLive = ['1H', '2H', 'HT', 'ET'].includes(previousStatus);
const isFinished = ['FT', 'AET', 'PEN'].includes(currentStatus);

if (wasLive && isFinished) {
  await handleMatchEnded(matchData); // Invalide le cache
}
```

### 3. Récupération du classement

```javascript
// Vérifier si le cache existe
const cachedDoc = await admin.firestore()
  .collection('standingsCache')
  .doc('standings_16_current')
  .get();

if (cachedDoc.exists) {
  // Cache existe → Retourner depuis Firestore (0 requête)
  return cachedDoc.data().standings;
}

// Pas de cache → Appel API Sportradar (1 requête)
const response = await sportradarAPI.get(`/seasons/${seasonId}/standings.json`);

// Sauvegarder en cache (jusqu'à la prochaine fin de match)
await admin.firestore()
  .collection('standingsCache')
  .doc('standings_16_current')
  .set({ standings: response.data.standings });
```

## 🛠️ Fonction de rafraîchissement manuel

Si besoin de forcer une mise à jour (ex: après un changement administratif) :

```javascript
// Depuis l'app iOS
let functions = Functions.functions()
let refreshStandings = functions.httpsCallable("refreshStandings")

refreshStandings(["leagueId": 16]) { result, error in
  // Classement rafraîchi (1 requête consommée)
}
```

Ou depuis Firebase Console → Functions → refreshStandings

## ✅ Avantages du système

1. **Économie de requêtes**
   - Pas de rafraîchissement inutile en semaine
   - Mise à jour uniquement quand nécessaire
   - ~32 requêtes/mois vs ~720 avec cache 1h

2. **Données toujours à jour**
   - Classement se met à jour dès la fin d'un match
   - Pas d'attente de 12h ou 24h

3. **0 configuration temporelle**
   - Pas besoin de savoir quand sont les matchs
   - Fonctionne automatiquement

4. **Résilience**
   - Si webhook down → polling backup fait la même chose
   - Si API Sportradar down → cache reste accessible

## 📱 Expérience utilisateur

### Pendant les matchs (16:00)
Utilisateur ouvre l'app → Classement s'affiche instantanément (depuis cache)

### Juste après un match (16:31)
Utilisateur ouvre l'app → Petit délai (~1-2s) → Classement à jour s'affiche

### Entre les matchs (18:00)
Utilisateur ouvre l'app → Classement s'affiche instantanément (depuis cache mis à jour)

### En semaine (mardi)
Utilisateur ouvre l'app → Classement s'affiche instantanément (cache du weekend)

## 🔄 Diagramme de flux

```
Match Top 14 en cours
         ↓
    Match se termine
         ↓
    Webhook reçu
         ↓
   handleMatchEnded()
         ↓
    Détection Top 14 ?
    ├─ Oui → Supprimer cache classement
    └─ Non → Rien (autre compétition)
         ↓
  Prochaine consultation
         ↓
    Cache existe ?
    ├─ Non → API Sportradar (1 req)
    └─ Oui → Firestore (0 req)
         ↓
    Classement à jour !
```

## 🧪 Tests

### Simuler une fin de match

```bash
firebase functions:shell

> testWebhookSimulation({})
# Vérifier que le cache est supprimé dans Firestore

> testSportradarStandings({leagueId: 16})
# Vérifier qu'une requête API est faite (cache absent)

> testSportradarStandings({leagueId: 16})
# Vérifier que le cache est utilisé (0 requête)
```

### Vérifier l'invalidation dans les logs

```bash
firebase functions:log --only sportradarWebhook

# Rechercher :
# "[Webhook] Match Top 14 terminé → Invalidation du cache du classement"
# "[Webhook] Cache classement invalidé → Prochaine requête = classement frais"
```

## 🎯 Résultat final

**Sans optimisation (cache 1h) :**
- ~720 requêtes/mois
- ❌ Impossible avec limite 1000

**Avec invalidation automatique :**
- ~32 requêtes/mois
- ✅ 30x en-dessous de la limite
- ✅ Données toujours à jour
- ✅ Meilleure expérience utilisateur
