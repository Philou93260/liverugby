//
//  LiverugbyApp.swift
//  LiverugbyApp
//
//  Point d'entrée de l'application
//

import SwiftUI
import FirebaseCore

@main
struct LiverugbyApp: App {
    @StateObject private var firebaseService = FirebaseService.shared
    
    init() {
        // Configuration Firebase au démarrage
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(firebaseService)
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    
    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                HomeView()
                    .transition(.opacity)
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
}
