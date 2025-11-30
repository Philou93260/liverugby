# 📱 Guide d'Installation Rapide - Widget Match en Direct

Ce guide vous aidera à intégrer le widget de match en direct dans votre application iOS Live Rugby.

## 🎯 Vue d'ensemble

Le widget affiche :
- ✅ Le match en cours de votre équipe favorite
- ✅ Les logos des équipes et les scores
- ✅ Le statut du match (NS, 1H, HT, 2H, FT)
- ✅ Le temps écoulé pendant le match
- ✅ Le nom de la compétition

## 📋 Prérequis

- Xcode 15 ou supérieur
- iOS 16.0 minimum
- Projet avec Firebase déjà configuré
- Application Live Rugby existante

## 🚀 Installation en 5 Étapes

### Étape 1 : Créer le Widget Extension

1. Dans Xcode, ouvrez votre projet Live Rugby
2. Menu **File** → **New** → **Target...**
3. Sélectionnez **Widget Extension**
4. Configurez :
   - **Product Name** : `LiveRugbyWidget`
   - **Bundle Identifier** : `com.liverugby.app.LiveRugbyWidget`
   - **Include Configuration Intent** : ❌ NON (décochez)
5. Cliquez sur **Finish**

### Étape 2 : Copier les Fichiers du Widget

Copiez tous les fichiers depuis `liverugby-ios/LiveRugbyWidget/` dans le nouveau target :

```
LiveRugbyWidget/
├── LiveRugbyWidgetBundle.swift
├── LiveMatchWidgetModels.swift
├── LiveMatchTimelineProvider.swift
├── LiveMatchWidgetView.swift
├── FavoriteTeamConfigurationView.swift
├── WidgetDataService.swift
└── Info.plist
```

**Important** : Quand Xcode vous demande, assurez-vous de cocher **uniquement** le target `LiveRugbyWidget`.

### Étape 3 : Configurer App Groups

Les App Groups permettent le partage de données entre l'app et le widget.

#### 3.1 - Pour l'Application Principale

1. Sélectionnez le target de l'**app principale**
2. Onglet **Signing & Capabilities**
3. Cliquez sur **+ Capability**
4. Ajoutez **App Groups**
5. Cliquez sur **+** et créez : `group.com.liverugby.app`

#### 3.2 - Pour le Widget

1. Sélectionnez le target **LiveRugbyWidget**
2. Onglet **Signing & Capabilities**
3. Cliquez sur **+ Capability**
4. Ajoutez **App Groups**
5. Cochez le groupe existant : `group.com.liverugby.app`

### Étape 4 : Ajouter les Dépendances Firebase

Le widget a besoin d'accéder à Firebase.

#### Si vous utilisez Swift Package Manager :

1. Sélectionnez le target **LiveRugbyWidget**
2. Onglet **General** → section **Frameworks and Libraries**
3. Cliquez sur **+**
4. Ajoutez :
   - `FirebaseCore`
   - `FirebaseFirestore`
   - `FirebaseAuth`

#### Si vous utilisez CocoaPods :

Dans votre `Podfile`, ajoutez :

```ruby
target 'LiveRugbyWidget' do
  use_frameworks!

  pod 'Firebase/Core'
  pod 'Firebase/Firestore'
  pod 'Firebase/Auth'
end
```

Puis exécutez :
```bash
pod install
```

### Étape 5 : Ajouter GoogleService-Info.plist au Widget

1. Dans le navigateur de projet, sélectionnez `GoogleService-Info.plist`
2. Dans le panneau de droite (**File Inspector**)
3. Section **Target Membership**
4. Cochez **LiveRugbyWidget** ✅

## ✅ Vérification

### Checklist de Configuration

Vérifiez que tout est en place :

- [ ] Widget Extension créé avec le bon Bundle Identifier
- [ ] Tous les fichiers Swift copiés dans le target Widget
- [ ] App Groups configuré pour l'app ET le widget
- [ ] Firebase ajouté au target Widget
- [ ] GoogleService-Info.plist inclus dans le target Widget
- [ ] Le projet compile sans erreur

### Test Rapide

1. Lancez l'application sur un simulateur ou appareil
2. Allez sur l'écran d'accueil
3. Maintenez appuyé sur l'écran → cliquez sur **+**
4. Cherchez "Live Rugby"
5. Ajoutez le widget **Match en Direct**

## 🎨 Intégration dans l'App

### Ajouter la Configuration de l'Équipe Favorite

Ajoutez ce code dans vos réglages ou dans le profil utilisateur :

```swift
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @State private var showWidgetConfig = false

    var body: some View {
        List {
            Section("Widget") {
                Button(action: {
                    showWidgetConfig = true
                }) {
                    HStack {
                        Image(systemName: "square.stack.3d.up")
                        Text("Configurer le widget")
                    }
                }
            }
        }
        .sheet(isPresented: $showWidgetConfig) {
            FavoriteTeamConfigurationView()
        }
    }
}
```

### Sauvegarder l'Équipe Favorite

Quand l'utilisateur sélectionne une équipe favorite dans votre app :

```swift
import WidgetKit

func saveUserFavoriteTeam(teamId: Int, name: String, logo: String) {
    // Sauvegarder dans Firestore (comme actuellement)
    // ...

    // NOUVEAU : Sauvegarder aussi dans UserDefaults partagés pour le widget
    let sharedDefaults = UserDefaults(suiteName: "group.com.liverugby.app")
    sharedDefaults?.set(teamId, forKey: "favoriteTeamId")
    sharedDefaults?.set(name, forKey: "favoriteTeamName")
    sharedDefaults?.set(logo, forKey: "favoriteTeamLogo")

    // Rafraîchir le widget
    WidgetCenter.shared.reloadAllTimelines()
}
```

## 🔄 Rafraîchissement du Widget

Le widget se rafraîchit automatiquement :
- **Toutes les 2 minutes** pendant un match en direct
- **Toutes les 15 minutes** pour les matchs à venir

Pour forcer un rafraîchissement :

```swift
import WidgetKit

WidgetCenter.shared.reloadAllTimelines()
```

## 🐛 Problèmes Courants

### Le widget affiche "Aucun match"

**Causes possibles :**
- L'équipe favorite n'est pas configurée
- Pas de match dans les 7 prochains jours
- Problème de connexion Firebase

**Solution :**
```swift
// Vérifier dans la console
let sharedDefaults = UserDefaults(suiteName: "group.com.liverugby.app")
print("Team ID:", sharedDefaults?.integer(forKey: "favoriteTeamId") ?? "nil")
```

### Erreur "No such module 'Firebase...'"

**Solution :**
1. Vérifiez que Firebase est bien ajouté au target Widget
2. Nettoyez : Product → Clean Build Folder
3. Rebuild

### Les App Groups ne fonctionnent pas

**Solution :**
1. Vérifiez que le nom du groupe est identique : `group.com.liverugby.app`
2. Vérifiez que c'est coché pour les DEUX targets
3. Vérifiez votre Provisioning Profile

## 📱 Tailles de Widget

Le widget supporte 3 tailles :

| Taille | Affichage |
|--------|-----------|
| **Small** | Logos + Scores + Statut |
| **Medium** | Small + Temps + Compétition |
| **Large** | Medium + Stade |

## 🎯 Prochaines Étapes

Une fois le widget installé :

1. ✅ Testez avec différentes équipes
2. ✅ Testez pendant un match en direct
3. ✅ Testez les 3 tailles de widget
4. ✅ Vérifiez le rafraîchissement automatique
5. ✅ Préparez les screenshots pour l'App Store

## 📞 Support

Si vous rencontrez des problèmes :

1. Vérifiez la checklist ci-dessus
2. Consultez le README.md détaillé
3. Vérifiez les logs Xcode pour les erreurs Firebase

## 🎉 C'est terminé !

Votre widget est maintenant prêt à être utilisé. Les utilisateurs peuvent l'ajouter depuis leur écran d'accueil et suivre les matchs de leur équipe favorite en temps réel !

---

**Besoin d'aide ?** Consultez le [README.md](./LiveRugbyWidget/README.md) pour plus de détails.
