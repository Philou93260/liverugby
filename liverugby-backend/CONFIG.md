# Configuration de la clé API-Sports

## 🔑 Clé API configurée

Votre clé API-Sports : `cc235d58ce04e8ed2b057dfe4b169783`

## ⚙️ Configuration en développement local

✅ **DÉJÀ CONFIGURÉ** - Le fichier `functions/.runtimeconfig.json` a été créé avec votre clé API.

Vous pouvez maintenant tester vos fonctions localement avec :

```bash
cd liverugby-backend
firebase emulators:start
```

## 🚀 Configuration en production

### Option 1 : Script automatique (Recommandé)

Exécutez le script de configuration :

```bash
cd liverugby-backend
./configure-api-key.sh
```

### Option 2 : Commande manuelle

Si vous préférez configurer manuellement :

```bash
firebase functions:config:set apisports.key="cc235d58ce04e8ed2b057dfe4b169783" --project liverugby-6f075
```

### Vérifier la configuration

```bash
firebase functions:config:get --project liverugby-6f075
```

Vous devriez voir :

```json
{
  "apisports": {
    "key": "cc235d58ce04e8ed2b057dfe4b169783"
  }
}
```

## 📦 Déploiement

Une fois la clé API configurée, déployez vos fonctions :

```bash
# Déployer toutes les fonctions
firebase deploy --only functions --project liverugby-6f075

# Ou déployer tout (functions + rules)
firebase deploy --project liverugby-6f075
```

## 🧪 Tester la configuration

### Test en local (émulateurs)

```bash
firebase emulators:start
```

Puis testez depuis votre application frontend :

```javascript
const functions = firebase.functions();
const getTodayMatches = functions.httpsCallable('getTodayMatches');

getTodayMatches()
  .then(result => {
    console.log('Matchs récupérés:', result.data);
  })
  .catch(error => {
    console.error('Erreur:', error);
  });
```

### Test en production

Après le déploiement, testez de la même manière mais assurez-vous que votre app Firebase pointe vers la production.

## 🔒 Sécurité

### ✅ Ce qui est sécurisé

- ✅ `.runtimeconfig.json` est dans `.gitignore` (ne sera JAMAIS commité)
- ✅ La clé API en production est stockée de manière chiffrée dans Firebase
- ✅ Seules vos Cloud Functions y ont accès
- ✅ Les utilisateurs ne peuvent pas voir la clé

### ⚠️ Important

**NE JAMAIS** :
- Committer `.runtimeconfig.json` dans git
- Partager votre clé API publiquement
- Coder la clé en dur dans votre code frontend

**La clé API doit TOUJOURS rester côté backend (Cloud Functions).**

## 📊 Quotas API-Sports

Vérifiez vos quotas sur : https://dashboard.api-sports.io/

L'API Rugby gratuite a généralement ces limites :
- 100 requêtes par jour
- 10 requêtes par minute

Le système de cache (5 minutes) dans `getTodayMatches` aide à réduire la consommation.

## 🔄 Mettre à jour la clé API

Si vous devez changer de clé API :

1. **En local** : Modifiez `functions/.runtimeconfig.json`
2. **En production** : Réexécutez la commande config:set avec la nouvelle clé
3. **Redéployez** : `firebase deploy --only functions`

## 📞 Support

En cas de problème :

1. Vérifiez que Firebase CLI est installé : `firebase --version`
2. Vérifiez que vous êtes connecté : `firebase login`
3. Vérifiez la configuration : `firebase functions:config:get`
4. Consultez les logs : `firebase functions:log`

## 📚 Documentation

- [Firebase Functions Config](https://firebase.google.com/docs/functions/config-env)
- [API-Sports Rugby](https://api-sports.io/documentation/rugby/v1)
- [README du projet](./README.md)

---

**Configuration créée le :** 2025-11-14
**Project ID :** liverugby-6f075
**Clé API :** cc235d58ce04e8ed2b057dfe4b169783
