# 📱 Guide d'intégration des notifications push iOS - LiveRugby

Guide complet pour intégrer les notifications push en temps réel dans votre application iOS LiveRugby.

---

## 📋 Table des matières

1. [Configuration Firebase](#1-configuration-firebase)
2. [Configuration Xcode](#2-configuration-xcode)
3. [Intégration dans l'application iOS](#3-intégration-dans-lapplication-ios)
4. [Utilisation des fonctions Cloud](#4-utilisation-des-fonctions-cloud)
5. [Gestion des notifications](#5-gestion-des-notifications)
6. [Types d'événements](#6-types-dévénements)
7. [Exemples de code Swift](#7-exemples-de-code-swift)
8. [Dépannage](#8-dépannage)

---

## 1. Configuration Firebase

### 1.1 Télécharger GoogleService-Info.plist

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionnez votre projet **liverugby-6f075**
3. Allez dans **Paramètres du projet** > **Applications iOS**
4. Téléchargez **GoogleService-Info.plist**
5. Ajoutez ce fichier à la racine de votre projet Xcode

### 1.2 Configurer APNs (Apple Push Notification service)

1. Dans Firebase Console, allez dans **Paramètres du projet** > **Cloud Messaging**
2. Section **iOS app configuration**
3. Téléchargez votre **clé d'authentification APNs** (.p8) depuis Apple Developer
   - Connectez-vous à [Apple Developer](https://developer.apple.com/account/)
   - Allez dans **Certificates, IDs & Profiles** > **Keys**
   - Créez une nouvelle clé avec **Apple Push Notifications service (APNs)**
   - Téléchargez le fichier .p8 (⚠️ Une seule fois !)
4. Dans Firebase Console, uploadez le fichier .p8
5. Entrez votre **Key ID** et **Team ID** (disponibles sur Apple Developer)

---

## 2. Configuration Xcode

### 2.1 Activer les Capabilities

Dans votre projet Xcode :

1. Sélectionnez votre **Target**
2. Allez dans **Signing & Capabilities**
3. Cliquez sur **+ Capability**
4. Ajoutez :
   - ✅ **Push Notifications**
   - ✅ **Background Modes** > Cochez **Remote notifications**

### 2.2 Installer Firebase SDK via CocoaPods

**Podfile :**

```ruby
platform :ios, '13.0'
use_frameworks!

target 'LiveRugby' do
  # Firebase Core
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Messaging'
  pod 'Firebase/Functions'

  # Autres dépendances...
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

Installez les dépendances :

```bash
cd ios
pod install
```

### 2.3 Configurer Info.plist

Ajoutez la permission pour les notifications :

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

---

## 3. Intégration dans l'application iOS

### 3.1 AppDelegate.swift

```swift
import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Initialiser Firebase
        FirebaseApp.configure()

        // Configurer les notifications
        setupPushNotifications(application)

        return true
    }

    // MARK: - Push Notifications Setup

    func setupPushNotifications(_ application: UIApplication) {
        // Configurer le delegate
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Demander la permission
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("❌ Notification permission error:", error)
            }
        }
    }

    // Succès de l'enregistrement APNs
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ APNs device token received")

        // Passer le token à Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }

    // Échec de l'enregistrement APNs
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications:", error)
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    // Recevoir le token FCM
    func messaging(_ messaging: Messaging,
                   didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }

        print("🔑 FCM Token received:", fcmToken)

        // Sauvegarder le token localement
        UserDefaults.standard.set(fcmToken, forKey: "fcmToken")

        // Envoyer le token au backend Firebase
        registerTokenWithBackend(fcmToken)
    }

    func registerTokenWithBackend(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ User not authenticated, token will be registered after login")
            return
        }

        let functions = Functions.functions()
        let registerToken = functions.httpsCallable("registerFCMToken")

        registerToken([
            "token": token,
            "platform": "ios",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? ""
        ]) { result, error in
            if let error = error {
                print("❌ Error registering token:", error)
            } else {
                print("✅ Token registered successfully")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Notification reçue en foreground (app ouverte)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        let userInfo = notification.request.content.userInfo
        print("📬 Notification received (foreground):", userInfo)

        // Afficher la notification même si l'app est ouverte
        completionHandler([.banner, .sound, .badge])
    }

    // Notification cliquée par l'utilisateur
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo
        print("👆 Notification tapped:", userInfo)

        // Gérer l'action de la notification
        if let matchId = userInfo["matchId"] as? String {
            // Naviguer vers les détails du match
            navigateToMatchDetails(matchId: matchId)
        }

        completionHandler()
    }

    func navigateToMatchDetails(matchId: String) {
        // Implémenter la navigation vers les détails du match
        NotificationCenter.default.post(
            name: Notification.Name("OpenMatchDetails"),
            object: nil,
            userInfo: ["matchId": matchId]
        )
    }
}
```

---

## 4. Utilisation des fonctions Cloud

### 4.1 Enregistrer le token FCM après connexion

```swift
import Firebase
import FirebaseFunctions

class AuthManager {

    func registerFCMTokenAfterLogin() {
        guard let fcmToken = UserDefaults.standard.string(forKey: "fcmToken") else {
            print("⚠️ No FCM token available")
            return
        }

        let functions = Functions.functions()
        let registerToken = functions.httpsCallable("registerFCMToken")

        registerToken([
            "token": fcmToken,
            "platform": "ios",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? ""
        ]) { result, error in
            if let error = error as NSError? {
                print("❌ Error:", error.localizedDescription)
            } else if let data = result?.data as? [String: Any] {
                print("✅ Token registered:", data["message"] ?? "")
            }
        }
    }
}
```

### 4.2 S'abonner aux notifications d'un match

```swift
class MatchNotificationManager {

    func subscribeToMatch(matchId: String) {
        let functions = Functions.functions()
        let subscribe = functions.httpsCallable("subscribeToMatch")

        subscribe([
            "matchId": matchId,
            "eventTypes": [
                "match_starting",
                "match_started",
                "score_update",
                "match_ended"
            ]
        ]) { result, error in
            if let error = error {
                print("❌ Error subscribing:", error)
            } else {
                print("✅ Subscribed to match notifications")
            }
        }
    }

    func unsubscribeFromMatch(matchId: String) {
        let functions = Functions.functions()
        let unsubscribe = functions.httpsCallable("unsubscribeFromMatch")

        unsubscribe(["matchId": matchId]) { result, error in
            if let error = error {
                print("❌ Error unsubscribing:", error)
            } else {
                print("✅ Unsubscribed from match")
            }
        }
    }
}
```

### 4.3 Ajouter une équipe favorite

```swift
class FavoriteTeamsManager {

    func addFavoriteTeam(teamId: Int, teamName: String, teamLogo: String) {
        let functions = Functions.functions()
        let addFavorite = functions.httpsCallable("addFavoriteTeam")

        addFavorite([
            "teamId": teamId,
            "teamName": teamName,
            "teamLogo": teamLogo,
            "notifyMatches": true
        ]) { result, error in
            if let error = error {
                print("❌ Error adding favorite:", error)
            } else {
                print("✅ Favorite team added")
            }
        }
    }
}
```

---

## 5. Gestion des notifications

### 5.1 Listener pour les notifications en temps réel

```swift
import FirebaseFirestore

class LiveMatchObserver {

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func observeMatch(matchId: String, completion: @escaping (MatchData) -> Void) {
        listener = db.collection("liveMatches")
            .document(matchId)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error!)")
                    return
                }

                guard let data = document.data() else {
                    print("Document data was empty.")
                    return
                }

                if let matchData = try? Firestore.Decoder().decode(MatchData.self, from: data) {
                    completion(matchData)
                }
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }
}

struct MatchData: Codable {
    let id: Int
    let teams: Teams
    let scores: Scores?
    let status: Status

    struct Teams: Codable {
        let home: Team
        let away: Team
    }

    struct Team: Codable {
        let id: Int
        let name: String
        let logo: String?
    }

    struct Scores: Codable {
        let home: Int
        let away: Int
    }

    struct Status: Codable {
        let short: String
        let long: String?
    }
}
```

### 5.2 Badge management

```swift
extension AppDelegate {

    func updateBadgeCount() {
        // Récupérer le nombre de notifications non lues
        let badgeCount = 0 // À implémenter selon votre logique

        UNUserNotificationCenter.current().setBadgeCount(badgeCount) { error in
            if let error = error {
                print("Error setting badge:", error)
            }
        }
    }

    func resetBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}
```

---

## 6. Types d'événements

Le backend envoie différents types de notifications :

| Type d'événement | Description | Données incluses |
|---|---|---|
| `match_starting` | Match commence dans 30 min | `minutesUntilStart` |
| `match_started` | Match a commencé | - |
| `score_update` | Score mis à jour | `homeScore`, `awayScore` |
| `halftime` | Mi-temps | `homeScore`, `awayScore` |
| `match_ended` | Match terminé | `homeScore`, `awayScore`, `winner` |
| `favorite_team_playing` | Équipe favorite joue aujourd'hui | `matchCount` |

---

## 7. Exemples de code Swift

### 7.1 ViewModel complet pour un match

```swift
import SwiftUI
import Firebase
import FirebaseFunctions

class MatchViewModel: ObservableObject {
    @Published var match: MatchData?
    @Published var isSubscribed = false

    private let functions = Functions.functions()
    private let observer = LiveMatchObserver()

    func loadMatch(matchId: String) {
        // Observer les mises à jour en temps réel
        observer.observeMatch(matchId: matchId) { [weak self] matchData in
            self?.match = matchData
        }
    }

    func toggleSubscription(matchId: String) {
        if isSubscribed {
            unsubscribe(matchId: matchId)
        } else {
            subscribe(matchId: matchId)
        }
    }

    private func subscribe(matchId: String) {
        let subscribe = functions.httpsCallable("subscribeToMatch")

        subscribe(["matchId": matchId]) { [weak self] result, error in
            if error == nil {
                self?.isSubscribed = true
            }
        }
    }

    private func unsubscribe(matchId: String) {
        let unsubscribe = functions.httpsCallable("unsubscribeFromMatch")

        unsubscribe(["matchId": matchId]) { [weak self] result, error in
            if error == nil {
                self?.isSubscribed = false
            }
        }
    }

    deinit {
        observer.stopObserving()
    }
}
```

### 7.2 Vue SwiftUI avec notifications

```swift
import SwiftUI

struct MatchDetailView: View {
    @StateObject private var viewModel = MatchViewModel()
    let matchId: String

    var body: some View {
        VStack {
            if let match = viewModel.match {
                VStack(spacing: 20) {
                    Text("\(match.teams.home.name) vs \(match.teams.away.name)")
                        .font(.title)

                    if let scores = match.scores {
                        HStack(spacing: 40) {
                            Text("\(scores.home)")
                                .font(.system(size: 48, weight: .bold))
                            Text("-")
                            Text("\(scores.away)")
                                .font(.system(size: 48, weight: .bold))
                        }
                    }

                    Text(match.status.short)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: {
                        viewModel.toggleSubscription(matchId: matchId)
                    }) {
                        Label(
                            viewModel.isSubscribed ? "Désactiver les notifications" : "Activer les notifications",
                            systemImage: viewModel.isSubscribed ? "bell.fill" : "bell"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView()
            }
        }
        .padding()
        .onAppear {
            viewModel.loadMatch(matchId: matchId)
        }
    }
}
```

---

## 8. Dépannage

### Problème : Les notifications ne s'affichent pas

**Solutions :**

1. ✅ Vérifier que les permissions sont accordées :
```swift
UNUserNotificationCenter.current().getNotificationSettings { settings in
    print("Notification status:", settings.authorizationStatus)
}
```

2. ✅ Vérifier que le token FCM est enregistré :
```swift
print("FCM Token:", Messaging.messaging().fcmToken ?? "None")
```

3. ✅ Vérifier que l'APNs token est configuré :
```swift
print("APNs Token:", Messaging.messaging().apnsToken ?? "None")
```

4. ✅ Tester avec une notification manuelle depuis Firebase Console

### Problème : Token non enregistré

**Solution :** S'assurer d'appeler `registerFCMTokenAfterLogin()` après l'authentification :

```swift
Auth.auth().signIn(withEmail: email, password: password) { result, error in
    if error == nil {
        AuthManager().registerFCMTokenAfterLogin()
    }
}
```

### Problème : Notifications reçues mais pas affichées en foreground

**Solution :** Vérifier le delegate :

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            willPresent notification: UNNotification,
                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    // iOS 14+
    completionHandler([.banner, .sound, .badge])
}
```

### Tester les notifications

**1. Utiliser la console Firebase :**
- Firebase Console > Cloud Messaging > Send test message
- Entrez votre token FCM
- Envoyez

**2. Logs backend :**
```bash
firebase functions:log --only monitorLiveMatches
```

**3. Vérifier Firestore :**
- Collection `sentNotifications` pour voir les notifications envoyées
- Collection `fcmTokens` pour vérifier que le token est actif

---

## 📚 Ressources

- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [Firebase Cloud Messaging iOS](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Apple Push Notifications](https://developer.apple.com/documentation/usernotifications)
- [Backend Functions](./README.md)

---

## ✅ Checklist de déploiement

Avant de publier votre app :

- [ ] GoogleService-Info.plist ajouté
- [ ] APNs configuré dans Firebase Console
- [ ] Push Notifications capability activée
- [ ] Background Modes > Remote notifications activé
- [ ] Token FCM enregistré après login
- [ ] Gestion des notifications en foreground
- [ ] Gestion des notifications en background
- [ ] Navigation vers les détails du match
- [ ] Tests sur device physique (pas simulateur !)
- [ ] Icône de l'app avec badge configuré

---

**Version :** 1.0.0
**Dernière mise à jour :** 2025-11-14
**Project ID :** liverugby-6f075
