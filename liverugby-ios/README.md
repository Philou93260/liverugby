# 📱 LiveRugby iOS App

Application iOS SwiftUI pour suivre les matchs de rugby en temps réel.

## 🏗️ Structure du projet

```
LiveRugby/
├── Services/           # Services Firebase et API
│   └── FirebaseService.swift
├── Models/            # Modèles de données
│   └── Match.swift
├── ViewModels/        # ViewModels MVVM
│   └── MatchesViewModel.swift
└── Views/             # Vues SwiftUI
    └── (vos vues)
```

## 📦 Dépendances (Swift Package Manager)

- **Firebase iOS SDK**
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseMessaging
  - FirebaseFunctions

## 🔒 Configuration (Local uniquement - PAS dans Git)

### GoogleService-Info.plist

**⚠️ Ce fichier NE doit JAMAIS être commité sur Git !**

**Où le placer :**
- Téléchargez depuis [Firebase Console](https://console.firebase.google.com/project/liverugby-6f075/settings/general)
- Placez-le à la racine de votre projet Xcode
- Il est déjà dans `.gitignore`, donc sûr

**Le fichier contient :**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>API_KEY</key>
    <string>VOTRE_CLE_API</string>
    <!-- Autres clés Firebase -->
</dict>
</plist>
```

## 🚀 Comment ajouter vos fichiers

### 1. Copiez vos fichiers Swift existants

```bash
# Depuis votre projet Xcode actuel
cp /chemin/vers/votre/projet/FirebaseService.swift liverugby-ios/LiveRugby/Services/
cp /chemin/vers/votre/projet/Match.swift liverugby-ios/LiveRugby/Models/
cp /chemin/vers/votre/projet/MatchesViewModel.swift liverugby-ios/LiveRugby/ViewModels/
```

### 2. Vérifiez que les secrets ne sont pas trackés

```bash
cd liverugby-ios
git status
```

**Vous devriez voir :**
- ✅ Fichiers .swift
- ✅ .gitignore
- ❌ PAS GoogleService-Info.plist
- ❌ PAS de fichiers .p8/.p12

### 3. Commitez

```bash
git add .
git commit -m "Add iOS app Swift files"
git push
```

## 📚 Intégration Firebase

Documentation complète : [../liverugby-backend/IOS_PUSH_NOTIFICATIONS.md](../liverugby-backend/IOS_PUSH_NOTIFICATIONS.md)

### Configuration minimale requise

**Package.swift ou SPM dans Xcode :**
```swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
]
```

**Produits à ajouter :**
- FirebaseAuth
- FirebaseFirestore
- FirebaseMessaging
- FirebaseFunctions

### Configuration App

```swift
import SwiftUI
import Firebase

@main
struct LiveRugbyApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## ⚙️ Prérequis

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- Firebase iOS SDK 10.0+

## 🔔 Notifications Push

### Capabilities requises dans Xcode

1. **Push Notifications**
2. **Background Modes** > Remote notifications

### Configuration APNs

Voir le guide backend : [DEPLOY_GUIDE.md](../liverugby-backend/DEPLOY_GUIDE.md)

## 🧪 Backend Firebase

Le backend est dans `../liverugby-backend/`

**Fonctions Cloud disponibles :**
- `getTodayMatches` - Récupère les matchs du jour
- `subscribeToMatch` - S'abonner aux notifications d'un match
- `addFavoriteTeam` - Ajouter une équipe favorite
- `registerFCMToken` - Enregistrer le token pour notifications

## 📖 Documentation

- [Backend README](../liverugby-backend/README.md)
- [Guide Push Notifications iOS](../liverugby-backend/IOS_PUSH_NOTIFICATIONS.md)
- [Guide Déploiement](../liverugby-backend/DEPLOY_GUIDE.md)

## 🛡️ Sécurité

**Fichiers protégés (dans .gitignore) :**
- ✅ GoogleService-Info.plist
- ✅ Certificats (.p8, .p12)
- ✅ Fichiers de configuration
- ✅ Clés API

**En cas d'erreur :**

Si vous avez accidentellement commité un secret :
```bash
# Supprimer du git mais garder le fichier local
git rm --cached GoogleService-Info.plist
git commit -m "Remove secret file"
git push
```

## 🆘 Support

En cas de problème, consultez :
1. Les logs Xcode
2. La Firebase Console
3. Les guides dans `liverugby-backend/`

---

**Version :** 1.0.0
**Plateforme :** iOS 16+
**Architecture :** SwiftUI + MVVM
**Backend :** Firebase (liverugby-6f075)
