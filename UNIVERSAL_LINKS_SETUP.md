# Configuration Universal Links (Alternative à Dynamic Links)

## 🎯 Objectif
Remplacer Firebase Dynamic Links par Universal Links pour l'authentification email.

## 📋 Étapes

### 1. Configurer un domaine personnalisé dans Firebase

**Firebase Console → Authentication → Settings → Authorized domains**
- Ajoutez votre domaine : `liverugby.com`

### 2. Créer le fichier apple-app-site-association

**Hébergez ce fichier sur :** `https://liverugby.com/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.votre.bundle.id",
        "paths": [
          "/verify-email/*",
          "/reset-password/*",
          "/auth/*"
        ]
      }
    ]
  }
}
```

### 3. Configurer Xcode

**Dans votre projet Xcode :**

1. **Capabilities → Associated Domains**
   - Ajoutez : `applinks:liverugby.com`

2. **Info.plist**
   ```xml
   <key>FirebaseAppDelegateProxyEnabled</key>
   <false/>
   ```

### 4. Gérer les liens dans SwiftUI

```swift
import SwiftUI
import FirebaseAuth

@main
struct LiveRugbyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        print("📱 URL reçue: \(url)")

        // Vérifier si c'est un lien de vérification d'email
        if url.path.contains("verify-email") {
            handleEmailVerification(url: url)
        }
        // Autres liens...
    }

    private func handleEmailVerification(url: URL) {
        guard let user = Auth.auth().currentUser else { return }

        Task {
            do {
                try await user.reload()
                if user.isEmailVerified {
                    print("✅ Email vérifié !")
                    // Naviguer vers l'écran principal
                }
            } catch {
                print("❌ Erreur:", error)
            }
        }
    }
}
```

### 5. Configurer les templates Firebase

**Firebase Console → Authentication → Templates → Email address verification**

1. Cliquez sur **Customize action URL**
2. Entrez : `https://liverugby.com/verify-email`
3. Sauvegardez

## ⚠️ Important

- **Hébergez le fichier apple-app-site-association sur HTTPS**
- **Le fichier doit être accessible publiquement**
- **Pas d'extension de fichier**
- **Content-Type: application/json**

## 🧪 Test

```bash
# Vérifier que le fichier est accessible
curl https://liverugby.com/.well-known/apple-app-site-association

# Tester avec l'outil Apple
https://search.developer.apple.com/appsearch-validation-tool/
```

## 💰 Alternative simple : Netlify/Vercel

Si vous n'avez pas de serveur, utilisez Netlify ou Vercel (gratuit) :

1. Créez un repo avec juste le fichier `apple-app-site-association`
2. Déployez sur Netlify
3. Utilisez le domaine Netlify dans Firebase
