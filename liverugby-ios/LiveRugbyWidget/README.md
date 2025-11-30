# Widget Live Rugby - Match en Direct

Widget iOS pour afficher le match en direct de votre équipe favorite de rugby.

## 📱 Fonctionnalités

- **Match en Direct** : Affiche le match en cours ou à venir de votre équipe favorite
- **Statuts de Match** :
  - `NS` - Not Started (À venir)
  - `1H` - Première Mi-temps
  - `HT` - Mi-temps
  - `2H` - Deuxième Mi-temps
  - `FT` - Full Time (Terminé)
- **Informations Affichées** :
  - Logos des équipes
  - Score en temps réel
  - Temps écoulé pendant le match
  - Nom de la compétition
  - Stade (sur widget large)
- **Mise à Jour Automatique** :
  - Toutes les 2 minutes pendant les matchs en direct
  - Toutes les 15 minutes pour les matchs à venir ou terminés

## 🏗️ Structure du Projet

```
LiveRugbyWidget/
├── LiveRugbyWidgetBundle.swift          # Point d'entrée principal
├── LiveMatchWidgetModels.swift          # Modèles de données
├── LiveMatchTimelineProvider.swift      # Provider de timeline
├── LiveMatchWidgetView.swift            # Vue du widget
├── FavoriteTeamConfigurationView.swift  # Interface de configuration
├── WidgetDataService.swift              # Service de données Firestore
├── Info.plist                           # Configuration du widget
└── README.md                            # Cette documentation
```

## 🚀 Installation

### 1. Ajouter le Widget Extension à Xcode

1. Ouvrez votre projet Xcode
2. File → New → Target
3. Sélectionnez **Widget Extension**
4. Nommez-le `LiveRugbyWidget`
5. Ne cochez PAS "Include Configuration Intent"

### 2. Configuration du Bundle Identifier

Le Bundle Identifier du widget doit être :
```
com.liverugby.app.LiveRugbyWidget
```

### 3. Ajouter les Fichiers

Copiez tous les fichiers Swift de ce dossier dans votre target Widget Extension :

- `LiveRugbyWidgetBundle.swift`
- `LiveMatchWidgetModels.swift`
- `LiveMatchTimelineProvider.swift`
- `LiveMatchWidgetView.swift`
- `FavoriteTeamConfigurationView.swift`
- `WidgetDataService.swift`

### 4. Configuration des Capabilities

#### App Group (OBLIGATOIRE)

Les App Groups permettent le partage de données entre l'app principale et le widget.

1. Sélectionnez la **target principale** de l'app
2. Allez dans **Signing & Capabilities**
3. Cliquez sur **+ Capability**
4. Ajoutez **App Groups**
5. Créez un groupe : `group.com.liverugby.app`

6. Répétez pour la **target du widget** :
   - Sélectionnez `LiveRugbyWidget`
   - Ajoutez la capability **App Groups**
   - Cochez le même groupe : `group.com.liverugby.app`

### 5. Dépendances Firebase

Le widget utilise Firebase. Assurez-vous que les frameworks suivants sont ajoutés au widget target :

Dans Xcode :
1. Sélectionnez le target `LiveRugbyWidget`
2. Allez dans **General → Frameworks and Libraries**
3. Ajoutez :
   - `FirebaseCore`
   - `FirebaseFirestore`
   - `FirebaseAuth`

OU dans votre `Package.swift` / `Podfile`, assurez-vous que ces dépendances sont disponibles pour le widget.

### 6. Configuration Firebase

Copiez `GoogleService-Info.plist` dans le target du widget :

1. Sélectionnez `GoogleService-Info.plist` dans Xcode
2. Dans le panneau de droite, cochez **Target Membership** pour `LiveRugbyWidget`

### 7. Build Settings

Assurez-vous que les Build Settings suivants sont configurés :

- **iOS Deployment Target** : 16.0 minimum
- **Swift Language Version** : Swift 5

## 🎨 Tailles de Widget Supportées

Le widget est disponible en 3 tailles :

### Small (Petit)
- Logos des équipes
- Scores
- Statut du match

### Medium (Moyen)
- Logos des équipes
- Scores
- Statut du match
- Temps écoulé ou heure du match
- Nom de la compétition

### Large (Grand)
- Tout ce qui est dans Medium
- Nom du stade

## ⚙️ Configuration de l'Équipe Favorite

### Dans l'Application Principale

Ajoutez ce code pour permettre à l'utilisateur de configurer son équipe favorite pour le widget :

```swift
import SwiftUI
import WidgetKit

struct WidgetSettingsView: View {
    @State private var showTeamSelection = false

    var body: some View {
        List {
            Section {
                Button("Configurer l'équipe du widget") {
                    showTeamSelection = true
                }
            } header: {
                Text("Widget Match en Direct")
            } footer: {
                Text("Sélectionnez l'équipe dont vous voulez suivre les matchs dans le widget")
            }
        }
        .navigationTitle("Réglages Widget")
        .sheet(isPresented: $showTeamSelection) {
            FavoriteTeamConfigurationView()
        }
    }
}
```

### Depuis le Widget

L'utilisateur peut également appuyer longuement sur le widget, puis "Modifier le widget" pour accéder aux réglages.

## 📊 Données Affichées

Le widget affiche automatiquement :

1. **Match en cours** (si disponible)
2. **Prochain match du jour** (si pas de match en cours)
3. **Prochain match dans les 7 jours** (si pas de match aujourd'hui)

### Priorité d'Affichage

1. Match en direct (`1H`, `2H`, `ET`)
2. Match à venir (`NS`)
3. Match terminé le plus récent (`FT`)

## 🔄 Mise à Jour des Données

### Fréquence de Rafraîchissement

- **Match en direct** : Toutes les 2 minutes
- **Match à venir** : Toutes les 15 minutes
- **Pas de match** : Toutes les 15 minutes

### Rafraîchissement Manuel

Le widget se rafraîchit automatiquement lorsque :
- L'utilisateur change d'équipe favorite
- L'app principale est ouverte
- Le système iOS décide de rafraîchir

## 🎯 Utilisation dans l'App

### Ajouter un Bouton pour Ouvrir les Réglages

```swift
import WidgetKit

Button("Rafraîchir le widget") {
    WidgetCenter.shared.reloadAllTimelines()
}
```

### Sauvegarder l'Équipe Favorite

```swift
import WidgetKit

func saveFavoriteTeam(teamId: Int, name: String, logo: String) {
    let sharedDefaults = UserDefaults(suiteName: "group.com.liverugby.app")
    sharedDefaults?.set(teamId, forKey: "favoriteTeamId")
    sharedDefaults?.set(name, forKey: "favoriteTeamName")
    sharedDefaults?.set(logo, forKey: "favoriteTeamLogo")

    // Rafraîchir le widget
    WidgetCenter.shared.reloadAllTimelines()
}
```

## 🐛 Résolution de Problèmes

### Le widget affiche "Aucun match"

1. Vérifiez que l'équipe favorite est bien configurée
2. Vérifiez que l'équipe a un match dans les 7 prochains jours
3. Vérifiez que Firebase est correctement initialisé
4. Vérifiez les App Groups

### Le widget ne se met pas à jour

1. Vérifiez les App Groups
2. Vérifiez que Firebase est accessible depuis le widget
3. Testez le rafraîchissement manuel : `WidgetCenter.shared.reloadAllTimelines()`

### Erreur de compilation Firebase

1. Assurez-vous que Firebase est ajouté au target du widget
2. Vérifiez que `GoogleService-Info.plist` est dans le target du widget
3. Nettoyez le build : Product → Clean Build Folder

### Les logos ne s'affichent pas

1. Vérifiez la connexion internet
2. Vérifiez que les URLs des logos sont valides
3. Les images peuvent prendre quelques secondes à charger

## 📝 Checklist de Déploiement

Avant de soumettre à l'App Store :

- [ ] App Groups configurés pour l'app et le widget
- [ ] Firebase configuré dans le widget
- [ ] GoogleService-Info.plist inclus dans le widget target
- [ ] Toutes les dépendances Firebase ajoutées
- [ ] Tests sur différentes tailles de widget (Small, Medium, Large)
- [ ] Tests avec et sans match disponible
- [ ] Tests de l'interface de configuration
- [ ] Vérification des screenshots pour l'App Store

## 🎨 Personnalisation

### Changer les Couleurs

Dans `LiveMatchWidgetView.swift`, vous pouvez modifier :

```swift
.foregroundColor(.blue)  // Couleur pour l'équipe favorite
.foregroundColor(.red)   // Couleur pour les matchs en direct
```

### Changer la Fréquence de Mise à Jour

Dans `LiveMatchTimelineProvider.swift` :

```swift
// Pour les matchs en direct (actuellement 2 minutes)
nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 2, to: currentDate)!

// Pour les autres (actuellement 15 minutes)
nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
```

## 📄 Licence

Ce widget fait partie de l'application Live Rugby.

## 🆘 Support

Pour toute question ou problème, contactez l'équipe de développement.

---

**Version** : 1.0
**iOS Minimum** : 16.0
**Dernière mise à jour** : 2025
