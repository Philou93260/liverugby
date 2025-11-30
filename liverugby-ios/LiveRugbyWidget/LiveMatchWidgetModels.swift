//
//  LiveMatchWidgetModels.swift
//  LiveRugbyWidget
//
//  Modèles de données pour le widget de match en direct
//

import Foundation
import WidgetKit

// MARK: - Widget Configuration
struct FavoriteTeamConfiguration {
    let teamId: Int
    let teamName: String
    let teamLogo: String
}

// MARK: - Match Status
enum MatchStatus: String, Codable {
    case notStarted = "NS"      // Not Started
    case firstHalf = "1H"       // First Half
    case halfTime = "HT"        // Half Time
    case secondHalf = "2H"      // Second Half
    case fullTime = "FT"        // Full Time
    case postponed = "PST"      // Postponed
    case cancelled = "CANC"     // Cancelled
    case abandoned = "ABD"      // Abandoned
    case awaitingExtraTime = "AET" // Awaiting Extra Time
    case extraTime = "ET"       // Extra Time
    case awaitingPenalties = "P"   // Penalties
    case finished = "FIN"       // Finished

    var displayText: String {
        switch self {
        case .notStarted: return "À venir"
        case .firstHalf: return "1ère MT"
        case .halfTime: return "Mi-temps"
        case .secondHalf: return "2ème MT"
        case .fullTime, .finished: return "Terminé"
        case .postponed: return "Reporté"
        case .cancelled: return "Annulé"
        case .abandoned: return "Abandonné"
        case .awaitingExtraTime: return "Prolongations"
        case .extraTime: return "Prol."
        case .awaitingPenalties: return "Tirs au but"
        }
    }

    var isLive: Bool {
        switch self {
        case .firstHalf, .secondHalf, .extraTime:
            return true
        default:
            return false
        }
    }
}

// MARK: - Team Data
struct TeamData: Codable {
    let id: Int
    let name: String
    let logo: String
    let score: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case logo
        case score
    }
}

// MARK: - Match Data for Widget
struct WidgetMatchData: Codable {
    let matchId: Int
    let league: String
    let leagueLogo: String
    let date: Date
    let status: MatchStatus
    let homeTeam: TeamData
    let awayTeam: TeamData
    let venue: String?
    let elapsed: Int?  // Minutes elapsed in match

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    var isFavoriteHome: Bool {
        // This will be set based on user's favorite team selection
        return true
    }
}

// MARK: - Widget Timeline Entry
struct LiveMatchEntry: TimelineEntry {
    let date: Date
    let matchData: WidgetMatchData?
    let configuration: FavoriteTeamConfiguration?

    var isEmpty: Bool {
        return matchData == nil
    }
}

// MARK: - Widget Size Family
enum WidgetSize {
    case small
    case medium
    case large

    var rows: Int {
        switch self {
        case .small: return 1
        case .medium: return 1
        case .large: return 3
        }
    }
}
