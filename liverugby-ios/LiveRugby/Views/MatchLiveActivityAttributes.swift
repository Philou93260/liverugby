//
//  MatchLiveActivityAttributes.swift
//  LiverugbyApp
//
//  Définit les données statiques et dynamiques pour les Live Activities
//

import ActivityKit
import Foundation

/// Attributs pour suivre un match en direct via Live Activities
struct MatchLiveActivityAttributes: ActivityAttributes {
    
    // MARK: - Static Content (ne change jamais pendant la durée de l'activité)
    
    public struct ContentState: Codable, Hashable {
        // Scores en temps réel
        var homeScore: Int
        var awayScore: Int
        
        // Statut du match (1H, HT, 2H, FT, etc.)
        var status: String
        
        // Minute de jeu (optionnel)
        var minute: String?
        
        // Progression du match (0.0 à 1.0)
        var matchProgress: Double?
        
        // Dernière action importante
        var lastAction: String?
        var lastActionTime: String?
        
        // Quelle équipe vient de marquer (pour animation)
        var lastScoringTeam: String? // "home" ou "away"
        
        // Dernière mise à jour
        var lastUpdate: Date
    }
    
    // Données statiques du match (ne changent pas)
    var matchId: Int
    var homeTeamName: String
    var homeTeamLogo: String?
    var awayTeamName: String
    var awayTeamLogo: String?
    var leagueName: String?
    var venue: String?
}

extension MatchLiveActivityAttributes {
    /// Crée une activité à partir d'un match
    static func from(match: Match) -> (attributes: MatchLiveActivityAttributes, state: ContentState) {
        let attributes = MatchLiveActivityAttributes(
            matchId: match.id,
            homeTeamName: match.homeTeamName,
            homeTeamLogo: match.homeTeamLogo,
            awayTeamName: match.awayTeamName,
            awayTeamLogo: match.awayTeamLogo,
            leagueName: match.leagueName,
            venue: match.venue
        )
        
        // Calculer la progression du match (approximation basée sur le statut)
        let progress: Double? = {
            if match.status.contains("1H") || match.status.contains("1st Half") {
                return 0.25 // Premier quart
            } else if match.status.contains("HT") || match.status.contains("Half Time") {
                return 0.5 // Mi-temps
            } else if match.status.contains("2H") || match.status.contains("2nd Half") {
                return 0.75 // Trois quarts
            } else if match.isFinished {
                return 1.0 // Terminé
            }
            return nil
        }()
        
        let state = ContentState(
            homeScore: match.homeScore ?? 0,
            awayScore: match.awayScore ?? 0,
            status: match.status,
            minute: nil,
            matchProgress: progress,
            lastAction: nil,
            lastActionTime: nil,
            lastScoringTeam: nil,
            lastUpdate: Date()
        )
        
        return (attributes, state)
    }
}
