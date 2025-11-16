# Guide d'Intégration - Live Activities

Ce guide explique comment intégrer les **Live Activities** dans votre application LiveRugby iOS pour afficher les scores de matchs de rugby en temps réel sur l'écran de verrouillage et la Dynamic Island.

## 📋 Table des matières

1. [Prérequis](#prérequis)
2. [Configuration Xcode](#configuration-xcode)
3. [Intégration des fichiers](#intégration-des-fichiers)
4. [Configuration APNs](#configuration-apns)
5. [Utilisation dans l'app](#utilisation-dans-lapp)
6. [Test et débogage](#test-et-débogage)
7. [Limitations](#limitations)

---

## 🔧 Prérequis

### Versions requises
- **iOS 16.2+** (Live Activities disponibles à partir de cette version)
- **Xcode 14.1+**
- **iPhone physique** (les Live Activities ne fonctionnent PAS sur simulateur)
- **Dynamic Island** : iPhone 14 Pro ou plus récent (optionnel)

### Backend
- Les nouvelles Cloud Functions doivent être déployées :
  - `registerActivityPushToken`
  - `unregisterActivityPushToken`
  - Modification de `monitorLiveMatches` pour les updates APNs

---

## ⚙️ Configuration Xcode

### Étape 1 : Créer le Widget Extension

1. **Dans Xcode**, cliquez sur `File` → `New` → `Target...`
2. Sélectionnez **Widget Extension**
3. Configurez :
   - **Product Name** : `LiveRugbyWidgetExtension`
   - **Include Live Activity** : ✅ Cochez cette case
   - **Include Configuration Intent** : ❌ Décochez
4. Cliquez sur **Finish**
5. Si demandé, cliquez sur **Activate** pour activer le scheme

### Étape 2 : Configurer les Capabilities

#### Pour la cible principale (LiveRugby)

1. Sélectionnez le **projet** dans le navigateur
2. Sélectionnez la cible **LiveRugby**
3. Allez dans l'onglet **Signing & Capabilities**
4. Vérifiez que ces capabilities sont activées :
   - ✅ **Push Notifications** (déjà ajouté)
   - ✅ **Background Modes** → ✅ Remote notifications (déjà ajouté)

#### Pour le Widget Extension (LiveRugbyWidgetExtension)

1. Sélectionnez la cible **LiveRugbyWidgetExtension**
2. Allez dans l'onglet **Signing & Capabilities**
3. Cliquez sur **+ Capability**
4. Ajoutez :
   - ✅ **Push Notifications**
5. Configurez le même **Team** et **Bundle ID** : `com.votre-domaine.LiveRugby.LiveRugbyWidgetExtension`

### Étape 3 : Configurer Info.plist

#### Dans LiveRugbyWidgetExtension/Info.plist

Assurez-vous que ces clés existent :

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

Si elles n'existent pas, ajoutez-les manuellement.

---

## 📂 Intégration des fichiers

### Fichiers à télécharger depuis GitHub

Depuis `liverugby-ios/LiveRugby/` :

1. **LiveActivity/MatchLiveActivityAttributes.swift** → Nouveau fichier
2. **Services/LiveActivityManager.swift** → Nouveau fichier

Depuis `liverugby-ios/LiveRugbyWidgetExtension/` :

3. **MatchLiveActivityWidget.swift** → Nouveau fichier
4. **LiveRugbyWidgetExtensionBundle.swift** → Nouveau fichier

### Intégration dans Xcode

#### 1. Fichiers pour la cible principale (LiveRugby)

**a) Créer le dossier LiveActivity**

1. Faites un clic droit sur le dossier `LiveRugby`
2. Sélectionnez `New Group`
3. Nommez-le `LiveActivity`

**b) Ajouter MatchLiveActivityAttributes.swift**

1. Faites un clic droit sur le dossier `LiveActivity`
2. Sélectionnez `Add Files to "LiveRugby"...`
3. Sélectionnez `MatchLiveActivityAttributes.swift`
4. ⚠️ **IMPORTANT** : Cochez **DEUX cibles** :
   - ✅ LiveRugby
   - ✅ LiveRugbyWidgetExtension
5. Cliquez sur `Add`

**c) Ajouter LiveActivityManager.swift**

1. Faites un clic droit sur le dossier `Services`
2. Sélectionnez `Add Files to "LiveRugby"...`
3. Sélectionnez `LiveActivityManager.swift`
4. Cochez uniquement :
   - ✅ LiveRugby
   - ❌ LiveRugbyWidgetExtension
5. Cliquez sur `Add`

#### 2. Fichiers pour le Widget Extension

**a) Remplacer les fichiers générés automatiquement**

Xcode a créé des fichiers par défaut. Il faut les remplacer :

1. **Supprimer** les fichiers générés :
   - `LiveRugbyWidgetExtensionBundle.swift` (s'il existe)
   - `LiveRugbyWidgetExtensionLiveActivity.swift` (s'il existe)
   - `LiveRugbyWidgetExtension.swift` (s'il existe)

2. **Ajouter** vos fichiers :
   - Faites un clic droit sur le dossier `LiveRugbyWidgetExtension`
   - `Add Files to "LiveRugby"...`
   - Sélectionnez `MatchLiveActivityWidget.swift` et `LiveRugbyWidgetExtensionBundle.swift`
   - Cochez uniquement :
     - ❌ LiveRugby
     - ✅ LiveRugbyWidgetExtension
   - Cliquez sur `Add`

### Vérification des targets

Pour vérifier que les fichiers sont bien assignés aux bonnes cibles :

1. Sélectionnez un fichier dans le navigateur
2. Ouvrez l'**inspecteur de fichier** (panneau de droite)
3. Section **Target Membership** :
   - `MatchLiveActivityAttributes.swift` → ✅ LiveRugby + ✅ LiveRugbyWidgetExtension
   - `LiveActivityManager.swift` → ✅ LiveRugby seulement
   - `MatchLiveActivityWidget.swift` → ✅ LiveRugbyWidgetExtension seulement
   - `LiveRugbyWidgetExtensionBundle.swift` → ✅ LiveRugbyWidgetExtension seulement

---

## 🔐 Configuration APNs

### Étape 1 : Créer une clé APNs (si pas déjà fait)

1. Allez sur [Apple Developer Portal](https://developer.apple.com/account/)
2. **Certificates, Identifiers & Profiles** → **Keys**
3. Cliquez sur **+** pour créer une nouvelle clé
4. Nom : `LiveRugby APNs Key` (ou autre nom descriptif)
5. Cochez **Apple Push Notifications service (APNs)**
6. Cliquez sur **Continue** puis **Register**
7. **Téléchargez la clé** (.p8) → ⚠️ Vous ne pourrez la télécharger qu'une seule fois !
8. Notez le **Key ID** (par ex: `AB12CD34EF`)
9. Notez votre **Team ID** (visible en haut à droite)

### Étape 2 : Configurer APNs dans Firebase Console

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionnez votre projet **liverugby-6f075**
3. **⚙️ Paramètres du projet** → **Cloud Messaging**
4. Faites défiler jusqu'à **APNs Authentication Key**
5. Cliquez sur **Upload**
6. Remplissez :
   - **APNs auth key** : Uploadez le fichier `.p8`
   - **Key ID** : Votre Key ID (ex: `AB12CD34EF`)
   - **Team ID** : Votre Team ID (ex: `XYZ123456`)
7. Cliquez sur **Upload**

✅ APNs est maintenant configuré !

---

## 🚀 Utilisation dans l'app

### 1. Mettre à jour LiverugbyApp.swift

Si vous n'avez pas encore intégré les modifications précédentes :

```swift
import SwiftUI
import FirebaseCore
import ActivityKit

@main
struct LiverugbyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var pushNotificationManager = PushNotificationManager.shared
    @StateObject private var liveMatchListener = LiveMatchListener.shared

    // Ajouter le LiveActivityManager
    @StateObject private var liveActivityManager: LiveActivityManager = {
        if #available(iOS 16.2, *) {
            return LiveActivityManager.shared
        } else {
            // Placeholder pour iOS < 16.2 (ne sera pas utilisé)
            return LiveActivityManager.shared
        }
    }()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(firebaseService)
                .environmentObject(pushNotificationManager)
                .environmentObject(liveMatchListener)
                .environmentObject(liveActivityManager)
        }
    }
}
```

### 2. Démarrer une Live Activity pour un match

Dans votre vue de détail de match (par exemple `MatchDetailView.swift`) :

```swift
import SwiftUI

struct MatchDetailView: View {
    let match: Match

    @EnvironmentObject var liveActivityManager: LiveActivityManager
    @EnvironmentObject var pushNotificationManager: PushNotificationManager

    @State private var hasLiveActivity = false

    var body: some View {
        VStack {
            // ... Votre UI existante ...

            if #available(iOS 16.2, *) {
                // Bouton pour démarrer/arrêter la Live Activity
                if match.isLive {
                    Button(action: {
                        if hasLiveActivity {
                            Task {
                                await liveActivityManager.endActivity(
                                    matchId: match.id,
                                    finalHomeScore: match.homeScore ?? 0,
                                    finalAwayScore: match.awayScore ?? 0
                                )
                                hasLiveActivity = false
                            }
                        } else {
                            Task {
                                let success = await liveActivityManager.startActivity(for: match)
                                if success {
                                    hasLiveActivity = true
                                    // S'abonner aux notifications push pour ce match
                                    try? await pushNotificationManager.subscribeToMatch(matchId: match.id)
                                }
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: hasLiveActivity ? "stop.circle.fill" : "play.circle.fill")
                            Text(hasLiveActivity ? "Arrêter Live Activity" : "Suivre en direct")
                        }
                        .padding()
                        .background(hasLiveActivity ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .onAppear {
            if #available(iOS 16.2, *) {
                // Vérifier si une Live Activity est déjà active pour ce match
                hasLiveActivity = liveActivityManager.activeActivities[match.id] != nil
            }
        }
    }
}
```

### 3. Exemple d'utilisation simple

```swift
// Démarrer une Live Activity
if #available(iOS 16.2, *) {
    Task {
        let success = await LiveActivityManager.shared.startActivity(for: match)
        if success {
            print("✅ Live Activity démarrée !")
        }
    }
}

// Le backend mettra automatiquement à jour la Live Activity toutes les minutes
// via les push notifications APNs

// Terminer manuellement une Live Activity
if #available(iOS 16.2, *) {
    Task {
        await LiveActivityManager.shared.endActivity(
            matchId: match.id,
            finalHomeScore: 24,
            finalAwayScore: 17
        )
    }
}
```

---

## 🧪 Test et débogage

### Prérequis pour tester

⚠️ **IMPORTANT** : Les Live Activities ne fonctionnent **QUE** sur un **iPhone physique**.

- ✅ iPhone avec iOS 16.2+
- ✅ Certificat de développement valide
- ✅ APNs configuré dans Firebase
- ✅ Backend déployé avec les nouvelles fonctions

### Processus de test

#### 1. Build et installation

```bash
# Dans Xcode
1. Sélectionnez votre iPhone physique comme destination
2. Sélectionnez le scheme "LiveRugby"
3. Cliquez sur Run (⌘R)
4. Acceptez les permissions de notifications si demandé
```

#### 2. Activer une Live Activity

1. Ouvrez l'application
2. Naviguez vers un match en direct
3. Appuyez sur "Suivre en direct"
4. **Verrouillez votre iPhone**
5. Vous devriez voir la Live Activity sur l'écran de verrouillage

#### 3. Vérifier les mises à jour

1. Attendez 1-2 minutes (le backend vérifie toutes les minutes)
2. Si le score change, la Live Activity devrait se mettre à jour automatiquement
3. Vous verrez une petite animation + éventuellement un son

#### 4. Tester sur Dynamic Island (iPhone 14 Pro+)

1. Déverrouillez votre iPhone
2. La Live Activity devrait apparaître dans la Dynamic Island
3. Touchez longuement pour voir la vue étendue (expanded)

### Débogage

#### Logs dans Xcode

Filtrez les logs pour voir les messages de la Live Activity :

```
🔑 Activity Push Token reçu pour match ...
✅ Live Activity créée pour le match ...
✅ Live Activity mise à jour pour le match ...
```

#### Logs dans Firebase Console

1. Firebase Console → **Functions** → **Logs**
2. Recherchez :
   ```
   Activity Push Token registered
   Live Activity update sent
   Live Activity ended
   ```

#### Problèmes courants

**❌ La Live Activity ne se crée pas**
- Vérifiez que l'iPhone est iOS 16.2+
- Vérifiez les permissions dans Réglages → Notifications → LiveRugby
- Vérifiez que "Live Activities" est activé dans les réglages iOS

**❌ Pas de mises à jour**
- Vérifiez que le backend est déployé
- Vérifiez que APNs est configuré correctement
- Vérifiez les logs Firebase pour voir si les updates sont envoyées

**❌ L'app crash au démarrage**
- Vérifiez que `MatchLiveActivityAttributes.swift` est bien dans les deux cibles
- Vérifiez qu'il n'y a pas de conflits de noms avec les fichiers générés automatiquement

---

## ⚠️ Limitations

### Limitations iOS

1. **Nombre maximum** : 2 Live Activities simultanées par app
2. **Durée de vie** : Max 8 heures
3. **Fréquence des updates** : Apple limite le taux d'updates (généralement ~1/minute est OK)
4. **Simulateur** : Les Live Activities ne fonctionnent PAS sur simulateur

### Limitations de l'implémentation

1. **Matchs uniquement** : Actuellement, une Live Activity = un match
2. **Pas de média** : Pas de vidéos/GIFs dans les Live Activities
3. **Taille limitée** : Attention à ne pas afficher trop de texte

### Bonnes pratiques

1. **Terminer les activités** : Toujours terminer une Live Activity quand le match est fini
2. **Gérer l'état** : Vérifier si une activité existe déjà avant d'en créer une nouvelle
3. **Fallback** : Prévoir une UI alternative pour iOS < 16.2

---

## 📚 Ressources

### Documentation Apple

- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [Live Activities Guide](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Dynamic Island Guide](https://developer.apple.com/documentation/activitykit/displaying-live-data-on-the-dynamic-island)

### Documentation Firebase

- [Cloud Messaging for iOS](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [APNs Configuration](https://firebase.google.com/docs/cloud-messaging/ios/certs)

---

## 🎉 Félicitations !

Vous avez maintenant intégré les **Live Activities** dans votre application LiveRugby ! 🏉

Les utilisateurs peuvent maintenant suivre leurs matchs préférés directement sur l'écran de verrouillage et la Dynamic Island, avec des mises à jour en temps réel du score.

Pour toute question ou problème, consultez les logs Xcode et Firebase pour déboguer.

Bon match ! 🏉🔥
