//
//  LiveActivityIntegration.swift
//  LiverugbyApp
//
//  Extension pour intégrer le toggle des paramètres avec LiveActivityManager
//

import SwiftUI
import ActivityKit
import Combine

// MARK: - Extension LiveActivityManager pour vérifier les préférences

@available(iOS 16.2, *)
extension LiveActivityManager {
    
    /// Vérifie si l'utilisateur a activé les Live Activities dans les paramètres
    static func isEnabledInSettings() -> Bool {
        UserDefaults.standard.bool(forKey: "liveActivitiesEnabled")
    }
    
    /// Démarre une Live Activity si les paramètres le permettent
    func startActivityIfEnabled(for match: Match) async throws {
        // Vérifier les préférences utilisateur
        guard Self.isEnabledInSettings() else {
            print("⚠️ Live Activities désactivées dans les paramètres")
            return
        }
        
        // Démarrer l'activité
        try await startActivity(for: match)
    }
    
    /// Arrête toutes les activités si l'utilisateur désactive le toggle
    func handleSettingsDisabled() async {
        guard !Self.isEnabledInSettings() else { return }
        
        print("🛑 Live Activities désactivées, arrêt de toutes les activités...")
        await stopAllActivities()
    }
}

// MARK: - Observable ViewModel pour les paramètres

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var liveActivitiesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(liveActivitiesEnabled, forKey: "liveActivitiesEnabled")
            handleLiveActivitiesToggle()
        }
    }
    
    init() {
        // Charger la valeur sauvegardée (true par défaut)
        self.liveActivitiesEnabled = UserDefaults.standard.object(forKey: "liveActivitiesEnabled") as? Bool ?? true
    }
    
    private func handleLiveActivitiesToggle() {
        guard #available(iOS 16.2, *) else { return }
        
        if !liveActivitiesEnabled {
            // Si désactivé, arrêter toutes les activités en cours
            Task {
                await LiveActivityManager.shared.stopAllActivities()
            }
        }
    }
}
