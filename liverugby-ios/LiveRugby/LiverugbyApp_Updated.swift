//
//  LiverugbyApp.swift
//  LiverugbyApp
//
//  Point d'entrée de l'application avec support notifications push
//

import SwiftUI
import FirebaseCore

@main
struct LiverugbyApp: App {
    // Injecter l'AppDelegate pour gérer les notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var pushNotificationManager = PushNotificationManager.shared
    @StateObject private var liveMatchListener = LiveMatchListener.shared

    init() {
        // Configuration Firebase au démarrage
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(firebaseService)
                .environmentObject(pushNotificationManager)
                .environmentObject(liveMatchListener)
                .onAppear {
                    // Enregistrer le token FCM après connexion
                    registerTokenIfNeeded()
                }
        }
    }

    // MARK: - Helpers

    private func registerTokenIfNeeded() {
        Task {
            // Vérifier si l'utilisateur est connecté
            if firebaseService.isAuthenticated {
                // Enregistrer le token FCM
                await pushNotificationManager.registerToken()
            }
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var pushNotificationManager: PushNotificationManager

    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                HomeView()
                    .transition(.opacity)
                    .onAppear {
                        // Enregistrer le token FCM après connexion
                        Task {
                            await pushNotificationManager.registerToken()
                        }
                    }
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: firebaseService.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(FirebaseService.shared)
        .environmentObject(PushNotificationManager.shared)
        .environmentObject(LiveMatchListener.shared)
}
