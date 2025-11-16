//
//  LiveActivityManager.swift
//  LiverugbyApp
//
//  Gère le cycle de vie des Live Activities
//

import ActivityKit
import Foundation
import Combine

@available(iOS 16.2, *)
@MainActor
class LiveActivityManager: ObservableObject {
    
    static let shared = LiveActivityManager()
    
    @Published private(set) var activeActivities: [Int: Activity<MatchLiveActivityAttributes>] = [:]
    
    private init() {
        // Récupérer les activités déjà en cours au lancement de l'app
        loadActiveActivities()
    }
    
    // MARK: - Public Methods
    
    /// Démarre une Live Activity pour un match
    func startActivity(for match: Match) async throws {
        // Vérifier si une activité existe déjà pour ce match
        if activeActivities[match.id] != nil {
            print("⚠️ Une Live Activity existe déjà pour le match \(match.id)")
            return
        }
        
        // Créer les attributs et l'état initial
        let (attributes, initialState) = MatchLiveActivityAttributes.from(match: match)
        
        // Créer le contenu de l'activité
        let content = ActivityContent(
            state: initialState,
            staleDate: Calendar.current.date(byAdding: .minute, value: 5, to: Date())
        )
        
        do {
            // Démarrer l'activité
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil // Peut être .token si vous utilisez les push notifications
            )
            
            activeActivities[match.id] = activity
            print("✅ Live Activity démarrée pour le match \(match.homeTeamName) vs \(match.awayTeamName)")
            
        } catch {
            print("❌ Erreur lors du démarrage de la Live Activity: \(error)")
            throw error
        }
    }
    
    /// Met à jour une Live Activity existante
    func updateActivity(for match: Match) async {
        guard let activity = activeActivities[match.id] else {
            print("⚠️ Aucune Live Activity trouvée pour le match \(match.id)")
            return
        }
        
        // Déterminer quelle équipe vient de marquer (si le score a changé)
        let currentState = activity.content.state
        var lastScoringTeam: String? = nil
        
        if let newHomeScore = match.homeScore, newHomeScore > currentState.homeScore {
            lastScoringTeam = "home"
        } else if let newAwayScore = match.awayScore, newAwayScore > currentState.awayScore {
            lastScoringTeam = "away"
        }
        
        // Calculer la progression du match
        let progress: Double? = {
            if match.status.contains("1H") || match.status.contains("1st Half") {
                return 0.25
            } else if match.status.contains("HT") || match.status.contains("Half Time") {
                return 0.5
            } else if match.status.contains("2H") || match.status.contains("2nd Half") {
                return 0.75
            } else if match.isFinished {
                return 1.0
            }
            return currentState.matchProgress
        }()
        
        let newState = MatchLiveActivityAttributes.ContentState(
            homeScore: match.homeScore ?? 0,
            awayScore: match.awayScore ?? 0,
            status: match.status,
            minute: nil,
            matchProgress: progress,
            lastAction: lastScoringTeam != nil ? "Essai marqué !" : currentState.lastAction,
            lastActionTime: lastScoringTeam != nil ? Date().formatted(date: .omitted, time: .shortened) : currentState.lastActionTime,
            lastScoringTeam: lastScoringTeam,
            lastUpdate: Date()
        )
        
        let content = ActivityContent(
            state: newState,
            staleDate: Calendar.current.date(byAdding: .minute, value: 5, to: Date())
        )
        
        await activity.update(content)
        print("🔄 Live Activity mise à jour pour le match \(match.id)")
        
        // Si une équipe vient de marquer, log spécial
        if lastScoringTeam != nil {
            print("🎉 Essai marqué ! Score: \(newState.homeScore) - \(newState.awayScore)")
        }
    }
    
    /// Arrête une Live Activity
    func stopActivity(for matchId: Int, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        guard let activity = activeActivities[matchId] else {
            print("⚠️ Aucune Live Activity trouvée pour le match \(matchId)")
            return
        }
        
        await activity.end(nil, dismissalPolicy: dismissalPolicy)
        activeActivities.removeValue(forKey: matchId)
        print("⏹️ Live Activity arrêtée pour le match \(matchId)")
    }
    
    /// Arrête toutes les Live Activities
    func stopAllActivities() async {
        for (matchId, activity) in activeActivities {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("⏹️ Live Activity arrêtée pour le match \(matchId)")
        }
        activeActivities.removeAll()
    }
    
    /// Vérifie si une activité est active pour un match
    func isActivityActive(for matchId: Int) -> Bool {
        return activeActivities[matchId] != nil
    }
    
    // MARK: - Private Methods
    
    private func loadActiveActivities() {
        // Récupérer toutes les activités en cours
        let activities = Activity<MatchLiveActivityAttributes>.activities
        
        for activity in activities {
            activeActivities[activity.attributes.matchId] = activity
        }
        
        print("📱 \(activities.count) Live Activity(ies) récupérée(s)")
    }
}

// MARK: - Extensions

extension LiveActivityManager {
    /// Démarre ou arrête une activité (toggle)
    func toggleActivity(for match: Match) async throws {
        if isActivityActive(for: match.id) {
            await stopActivity(for: match.id)
        } else {
            try await startActivity(for: match)
        }
    }
}

// MARK: - Fallback pour iOS < 16.2

/// Version fallback pour les versions iOS qui ne supportent pas Live Activities
@MainActor
class LiveActivityManagerLegacy: ObservableObject {
    static let shared = LiveActivityManagerLegacy()
    
    func startActivity(for match: Match) async throws {
        print("⚠️ Live Activities non disponibles sur iOS < 16.2")
    }
    
    func stopActivity(for matchId: Int) async {
        print("⚠️ Live Activities non disponibles sur iOS < 16.2")
    }
    
    func isActivityActive(for matchId: Int) -> Bool {
        return false
    }
    
    func toggleActivity(for match: Match) async throws {
        print("⚠️ Live Activities non disponibles sur iOS < 16.2")
    }
}
