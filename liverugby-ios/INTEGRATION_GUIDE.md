# 🚀 Guide d'intégration Firebase - LiveRugby iOS

Guide complet pour intégrer les notifications push et le temps réel dans votre app LiveRugby.

---

## 📦 Fichiers créés

✅ **AppDelegate.swift** - Gestion FCM et notifications
✅ **PushNotificationManager.swift** - Service notifications push
✅ **LiveMatchListener.swift** - Écoute temps réel Firestore
✅ **LiverugbyApp_Updated.swift** - App avec AppDelegate
✅ **RugbyService.swift** (modifié) - Région corrigée `europe-west1`

---

## 🔧 Étape 1 : Remplacer LiverugbyApp.swift

### Remplacez le contenu de `LiverugbyApp.swift`

```swift
// AVANT : Votre fichier actuel
// APRÈS : Utilisez le contenu de LiverugbyApp_Updated.swift
```

**Ou copiez ce code :**

```swift
import SwiftUI
import FirebaseCore

@main
struct LiverugbyApp: App {
    // 🆕 Injecter l'AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var firebaseService = FirebaseService.shared
    // 🆕 Managers pour notifications et temps réel
    @StateObject private var pushNotificationManager = PushNotificationManager.shared
    @StateObject private var liveMatchListener = LiveMatchListener.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(firebaseService)
                .environmentObject(pushNotificationManager)  // 🆕
                .environmentObject(liveMatchListener)        // 🆕
        }
    }
}
```

---

## 🔧 Étape 2 : Ajouter Firebase Messaging au projet

### Via Swift Package Manager

1. **Ouvrez Xcode**
2. **File > Add Package Dependencies...**
3. **URL** : `https://github.com/firebase/firebase-ios-sdk.git`
4. **Version** : 10.0.0 ou plus récent
5. **Ajoutez ces produits** :
   - ✅ FirebaseAuth (déjà présent)
   - ✅ FirebaseFirestore (déjà présent)
   - ✅ FirebaseFunctions (déjà présent)
   - ✅ **FirebaseMessaging** 🆕
   - ✅ FirebaseStorage (déjà présent)

---

## 🔧 Étape 3 : Configurer les Capabilities dans Xcode

### Push Notifications

1. **Sélectionnez votre Target** (LiveRugby)
2. **Signing & Capabilities**
3. **+ Capability**
4. **Ajoutez** : `Push Notifications`

### Background Modes

1. **+ Capability**
2. **Ajoutez** : `Background Modes`
3. **Cochez** : `Remote notifications`

---

## 🔧 Étape 4 : Info.plist (si nécessaire)

Ajoutez (si pas déjà présent) :

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

---

## 📱 Utilisation dans vos Views

### 1. S'abonner aux notifications d'un match

```swift
import SwiftUI

struct MatchDetailView: View {
    @EnvironmentObject var pushManager: PushNotificationManager
    let match: Match
    @State private var isSubscribed = false

    var body: some View {
        VStack {
            // Détails du match

            Button(action: {
                Task {
                    if isSubscribed {
                        try? await pushManager.unsubscribeFromMatch(matchId: match.id)
                        isSubscribed = false
                    } else {
                        try? await pushManager.subscribeToMatch(matchId: match.id)
                        isSubscribed = true
                    }
                }
            }) {
                Label(
                    isSubscribed ? "🔕 Désactiver notifications" : "🔔 Activer notifications",
                    systemImage: isSubscribed ? "bell.fill" : "bell"
                )
            }
        }
    }
}
```

### 2. Écouter un match en temps réel

```swift
struct LiveMatchView: View {
    @EnvironmentObject var liveListener: LiveMatchListener
    let matchId: Int

    @State private var liveMatch: Match?

    var body: some View {
        VStack {
            if let match = liveMatch {
                // Afficher le match avec score en temps réel
                Text("\(match.homeTeam?.name ?? "") \(match.homeScore ?? 0) - \(match.awayScore ?? 0) \(match.awayTeam?.name ?? "")")
                    .font(.title)

                Text("Status: \(match.status ?? "")")
                    .foregroundColor(.secondary)
            } else {
                ProgressView("Chargement...")
            }
        }
        .onAppear {
            // Commencer à écouter
            liveListener.startListening(to: matchId)
            liveMatch = liveListener.getMatch(matchId)
        }
        .onDisappear {
            // Arrêter d'écouter quand la vue disparaît
            liveListener.stopListening(to: matchId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .liveMatchUpdated)) { notification in
            // Mettre à jour quand le match change
            if let updatedMatchId = notification.userInfo?["matchId"] as? String,
               updatedMatchId == String(matchId) {
                liveMatch = liveListener.getMatch(matchId)
            }
        }
    }
}
```

### 3. Ajouter une équipe favorite

```swift
struct TeamView: View {
    @EnvironmentObject var pushManager: PushNotificationManager
    let team: Team

    var body: some View {
        Button("⭐ Ajouter aux favoris") {
            Task {
                try? await pushManager.addFavoriteTeam(
                    teamId: team.id,
                    teamName: team.name,
                    teamLogo: team.logo,
                    notifyMatches: true
                )
            }
        }
    }
}
```

### 4. Demander les permissions notifications

```swift
struct SettingsView: View {
    @EnvironmentObject var pushManager: PushNotificationManager
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        VStack {
            if permissionStatus == .authorized {
                Text("✅ Notifications activées")
            } else {
                Button("Activer les notifications") {
                    Task {
                        let granted = await pushManager.requestNotificationPermission()
                        if granted {
                            permissionStatus = .authorized
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                permissionStatus = await pushManager.checkNotificationPermission()
            }
        }
    }
}
```

---

## 🎯 Fonctionnalités disponibles

### PushNotificationManager

```swift
// Gestion du token
await pushManager.registerToken()
await pushManager.unregisterToken()

// Abonnements matchs
try await pushManager.subscribeToMatch(matchId: 123)
try await pushManager.unsubscribeFromMatch(matchId: 123)

// Équipes favorites
try await pushManager.addFavoriteTeam(
    teamId: 1,
    teamName: "Stade Français",
    teamLogo: "https://...",
    notifyMatches: true
)

// Permissions
let status = await pushManager.checkNotificationPermission()
let granted = await pushManager.requestNotificationPermission()

// Badge
await pushManager.updateBadge(count: 5)
await pushManager.resetBadge()
```

### LiveMatchListener

```swift
// Écouter un match
liveListener.startListening(to: matchId)
liveListener.stopListening(to: matchId)

// Récupérer un match
let match = liveListener.getMatch(matchId)

// Écouter tous les matchs du jour
liveListener.listenToTodayMatches()
liveListener.stopListeningToTodayMatches()

// Arrêter tous les listeners
liveListener.stopAllListeners()
```

---

## 🔔 Types d'événements notifiés

Le backend envoie automatiquement ces notifications :

- 🏉 **match_starting** - Match commence dans 30 min
- 🏉 **match_started** - Match a commencé
- 🎯 **score_update** - Score mis à jour
- ⏸️ **halftime** - Mi-temps
- 🏁 **match_ended** - Match terminé
- ⭐ **favorite_team_playing** - Équipe favorite joue aujourd'hui

---

## 📲 Gestion des notifications

### Navigation depuis une notification

Ajoutez dans votre vue principale :

```swift
struct HomeView: View {
    @State private var selectedMatchId: String?
    @State private var showMatchDetails = false

    var body: some View {
        NavigationStack {
            // Votre contenu
        }
        .sheet(isPresented: $showMatchDetails) {
            if let matchId = selectedMatchId {
                MatchDetailView(matchId: Int(matchId) ?? 0)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openMatchDetails)) { notification in
            if let matchId = notification.userInfo?["matchId"] as? String {
                selectedMatchId = matchId
                showMatchDetails = true
            }
        }
    }
}
```

---

## 🧪 Tester les notifications

### 1. Sur device physique (obligatoire)

⚠️ **Les notifications push NE fonctionnent PAS sur simulateur !**

```
Utilisez un iPhone/iPad réel pour tester
```

### 2. Vérifier le token FCM

Ajoutez dans votre code (temporairement) :

```swift
.onAppear {
    if let token = UserDefaults.standard.string(forKey: "fcmToken") {
        print("🔑 Token FCM: \(token)")
    }
}
```

### 3. Tester avec Firebase Console

1. Allez sur [Firebase Console](https://console.firebase.google.com/project/liverugby-6f075/messaging)
2. **Cloud Messaging** > **Send test message**
3. Collez votre token FCM
4. Envoyez

### 4. Vérifier les logs backend

```bash
firebase functions:log --only monitorLiveMatches --project liverugby-6f075
```

---

## ⚙️ Configuration requise

### GoogleService-Info.plist

⚠️ **Assurez-vous que ce fichier est dans votre projet Xcode**

1. Téléchargez depuis [Firebase Console](https://console.firebase.google.com/project/liverugby-6f075/settings/general)
2. Glissez-le dans Xcode (racine du projet)
3. Vérifiez qu'il est dans **Build Phases** > **Copy Bundle Resources**

### APNs configuré

✅ Clé APNs uploadée dans Firebase Console
✅ Key ID et Team ID configurés

Voir [DEPLOY_GUIDE.md](../../liverugby-backend/DEPLOY_GUIDE.md) pour les détails.

---

## 🔍 Dépannage

### Les notifications ne s'affichent pas

**Checklist :**
- [ ] Test sur device physique (pas simulateur)
- [ ] Permissions accordées
- [ ] GoogleService-Info.plist dans le projet
- [ ] APNs configuré dans Firebase Console
- [ ] Token FCM enregistré (vérifier les logs)
- [ ] Capabilities Push Notifications activée
- [ ] Backend déployé

**Logs à vérifier :**

```swift
// Dans votre code
print("✅ Token FCM:", UserDefaults.standard.string(forKey: "fcmToken") ?? "nil")
print("✅ User connecté:", FirebaseService.shared.isAuthenticated)
print("✅ Token enregistré:", PushNotificationManager.shared.isRegistered)
```

### Token non enregistré

**Solution :**

```swift
// Forcer l'enregistrement
Task {
    await PushNotificationManager.shared.registerToken()
}
```

### Région incorrecte

**Erreur :** `Function not found`

**Solution :** Vérifiez que `RugbyService.swift` utilise `europe-west1` :

```swift
// ✅ Correct
functions = Functions.functions(region: "europe-west1")

// ❌ Incorrect
functions = Functions.functions(region: "us-central1")
```

---

## 📚 Ressources

- [Backend README](../../liverugby-backend/README.md)
- [Guide Notifications iOS](../../liverugby-backend/IOS_PUSH_NOTIFICATIONS.md)
- [Guide Déploiement](../../liverugby-backend/DEPLOY_GUIDE.md)

---

## ✅ Checklist finale

Avant de dire "C'est prêt !" :

- [ ] `LiverugbyApp.swift` mis à jour avec AppDelegate
- [ ] Firebase Messaging ajouté via SPM
- [ ] Capabilities activées (Push Notifications + Background Modes)
- [ ] GoogleService-Info.plist dans le projet
- [ ] APNs configuré sur Firebase Console
- [ ] Région `europe-west1` dans RugbyService
- [ ] Testé sur device physique
- [ ] Token FCM visible dans les logs
- [ ] Au moins 1 notification reçue avec succès

---

**Vous êtes maintenant prêt à recevoir des notifications push en temps réel ! 🎉**

Pour toute question, consultez la documentation backend ou les logs Firebase.
