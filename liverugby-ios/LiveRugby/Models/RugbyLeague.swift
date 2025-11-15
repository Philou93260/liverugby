//
//  RugbyLeague.swift
//  LiverugbyApp
//
//  Modèle pour les différentes ligues de rugby
//

import Foundation

enum RugbyLeague: Int, CaseIterable, Hashable {
    case top14 = 16           // Top 14 (France)
    case france = 1           // Équipe de France
    case premiership = 13     // Premiership (Angleterre)
    case urc = 76             // United Rugby Championship (multi-nations)
    case sixNations = 51      // Tournoi des 6 Nations
    case pro14 = 17           // Pro14 (ancien nom URC)
    case superRugby = 18      // Super Rugby
    case rugbyChampionship = 19 // Rugby Championship
    
    var name: String {
        switch self {
        case .top14:
            return "Top 14"
        case .france:
            return "Équipe de France"
        case .premiership:
            return "Gallagher Premiership"
        case .urc:
            return "United Rugby Championship"
        case .sixNations:
            return "Tournoi des 6 Nations"
        case .pro14:
            return "Pro14"
        case .superRugby:
            return "Super Rugby"
        case .rugbyChampionship:
            return "Rugby Championship"
        }
    }
    
    var shortName: String {
        switch self {
        case .top14:
            return "Top 14"
        case .france:
            return "France"
        case .premiership:
            return "Premiership"
        case .urc:
            return "URC"
        case .sixNations:
            return "6 Nations"
        case .pro14:
            return "Pro14"
        case .superRugby:
            return "Super Rugby"
        case .rugbyChampionship:
            return "TRC"
        }
    }
    
    var country: String {
        switch self {
        case .top14:
            return "France"
        case .france:
            return "France"
        case .premiership:
            return "Angleterre"
        case .urc:
            return "Multi-nations"
        case .sixNations:
            return "Europe"
        case .pro14:
            return "Multi-nations"
        case .superRugby:
            return "Hémisphère Sud"
        case .rugbyChampionship:
            return "Hémisphère Sud"
        }
    }
    
    var icon: String {
        switch self {
        case .top14:
            return "flag.fill"
        case .france:
            return "person.3.fill"
        case .premiership:
            return "crown.fill"
        case .urc:
            return "globe.europe.africa.fill"
        case .sixNations:
            return "6.circle.fill"
        case .pro14:
            return "globe.europe.africa"
        case .superRugby:
            return "globe.asia.australia.fill"
        case .rugbyChampionship:
            return "trophy.fill"
        }
    }
    
    var flagEmoji: String {
        switch self {
        case .top14:
            return "🇫🇷"
        case .france:
            return "🇫🇷"
        case .premiership:
            return "🏴󠁧󠁢󠁥󠁮󠁧󠁿"
        case .urc:
            return "🌍"
        case .sixNations:
            return "🏆"
        case .pro14:
            return "🌍"
        case .superRugby:
            return "🌏"
        case .rugbyChampionship:
            return "🏉"
        }
    }
}
