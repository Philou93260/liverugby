//
//  MatchLiveActivityAttributes.swift
//  LiveRugby
//
//  Définit les données affichées dans les Live Activities
//

import Foundation
import ActivityKit

/// Attributs de la Live Activity pour un match de rugby
struct MatchLiveActivityAttributes: ActivityAttributes {

    // MARK: - Static Content (ne change jamais pendant l'activité)

    public struct ContentState: Codable, Hashable {
        /// Score de l'équipe à domicile
        var homeScore: Int

        /// Score de l'équipe extérieure
        var awayScore: Int

        /// Statut du match ("1H", "HT", "2H", "FT", etc.)
        var status: String

        /// Temps écoulé dans le match (optionnel)
        var elapsed: Int?

        /// Dernière mise à jour
        var lastUpdate: Date

        /// Événement récent (optionnel) - ex: "Essai!", "Pénalité", etc.
        var recentEvent: String?
    }

    // MARK: - Dynamic Content (peut changer)

    /// ID du match
    let matchId: Int

    /// Nom de l'équipe à domicile
    let homeTeamName: String

    /// Logo de l'équipe à domicile (URL)
    let homeTeamLogo: String?

    /// Nom de l'équipe extérieure
    let awayTeamName: String

    /// Logo de l'équipe extérieure (URL)
    let awayTeamLogo: String?

    /// Nom de la compétition
    let leagueName: String?

    /// Date/heure du match
    let matchDateTime: Date
}

// MARK: - Helper Extensions

extension MatchLiveActivityAttributes.ContentState {

    /// Score formaté pour l'affichage
    var scoreText: String {
        return "\(homeScore) - \(awayScore)"
    }

    /// Libellé du statut en français
    var statusLabel: String {
        switch status {
        case "1H": return "1ère mi-temps"
        case "HT": return "Mi-temps"
        case "2H": return "2ème mi-temps"
        case "FT": return "Terminé"
        case "LIVE": return "En direct"
        default: return status
        }
    }

    /// Indique si le match est terminé
    var isFinished: Bool {
        return status == "FT" || status == "Finished"
    }
}
