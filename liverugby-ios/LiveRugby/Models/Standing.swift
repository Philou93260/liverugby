//
//  Standing.swift
//  LiverugbyApp
//
//  Modèle pour le classement d'une équipe
//

import Foundation
import SwiftUI

struct Standing: Identifiable, Codable {
    let id: String
    let position: Int
    let teamId: Int
    let teamName: String
    let teamLogo: String?
    
    let played: Int
    let won: Int
    let draw: Int
    let lost: Int
    
    let goalsFor: Int?
    let goalsAgainst: Int?
    let goalsDiff: Int?
    
    let points: Int
    
    let form: String?
    let description: String?
    
    // MARK: - Computed Properties
    
    var winRate: Double {
        guard played > 0 else { return 0 }
        return Double(won) / Double(played) * 100
    }
    
    var positionEmoji: String {
        switch position {
        case 1:
            return "🥇"
        case 2:
            return "🥈"
        case 3:
            return "🥉"
        default:
            return ""
        }
    }
    
    var qualificationStatus: String {
        switch position {
        case 1...6:
            return "Qualifié pour les phases finales"
        case 7...12:
            return "Milieu de tableau"
        case 13...14:
            return "Zone de relégation"
        default:
            return ""
        }
    }
    
    // MARK: - Initialisation depuis l'API (dictionnaire)
    
    /// Initialise un Standing depuis un dictionnaire JSON brut renvoyé par l'API.
    init(from dict: [String: Any]) {
        // Debug: afficher la structure reçue (utile temporairement)
        print("📊 Standing dict keys: \(dict.keys.sorted())")
        
        // Afficher le contenu de chaque clé importante
        if let team = dict["team"] as? [String: Any] {
            print("   └─ team: \(team)")
        }
        if let all = dict["all"] as? [String: Any] {
            print("   └─ all: \(all)")
        }
        if let home = dict["home"] as? [String: Any] {
            print("   └─ home: \(home)")
        }
        if let away = dict["away"] as? [String: Any] {
            print("   └─ away: \(away)")
        }
        print("   └─ position: \(dict["position"] ?? "nil")")
        print("   └─ points: \(dict["points"] ?? "nil")")
        print("   └─ played (direct): \(dict["played"] ?? "nil")")
        print("   └─ win (direct): \(dict["win"] ?? "nil")")
        
        self.position = dict["position"] as? Int ?? 0
        
        // Récupérer les infos de l'équipe depuis l'objet "team"
        if let team = dict["team"] as? [String: Any] {
            self.teamId = team["id"] as? Int ?? 0
            self.teamName = team["name"] as? String ?? "Unknown"
            self.teamLogo = team["logo"] as? String
        } else {
            // Fallback sur l'ancienne structure
            self.teamId = dict["team_id"] as? Int ?? 0
            self.teamName = dict["team_name"] as? String ?? "Unknown"
            self.teamLogo = dict["team_logo"] as? String
        }
        
        self.id = "\(self.position)-\(self.teamId)"
        
        // Statistiques - l'API rugby peut renvoyer les stats de plusieurs façons :
        // 1. Dans un objet "games" avec des sous-objets { total, percentage }
        // 2. Dans un objet "all" (all.played, all.win, all.draw, all.lose)
        // 3. Directement au niveau racine (played, win, draw, lose, points)
        
        var played = 0
        var won = 0
        var draw = 0
        var lost = 0
        var points = 0
        
        // PRIORITÉ 1 : Essayer l'objet "games" (format actuel de l'API)
        if let games = dict["games"] as? [String: Any] {
            played = games["played"] as? Int ?? 0
            
            // win, draw, lose sont des objets avec "total" et "percentage"
            if let winObj = games["win"] as? [String: Any] {
                won = winObj["total"] as? Int ?? 0
            }
            if let drawObj = games["draw"] as? [String: Any] {
                draw = drawObj["total"] as? Int ?? 0
            }
            if let loseObj = games["lose"] as? [String: Any] {
                lost = loseObj["total"] as? Int ?? 0
            }
            
            print("   ✅ Parsed from 'games': J=\(played) V=\(won) N=\(draw) D=\(lost)")
        }
        // PRIORITÉ 2 : Essayer l'objet "all" (autre format possible)
        else if let all = dict["all"] as? [String: Any] {
            played = all["played"] as? Int ?? 0
            won = all["win"] as? Int ?? all["won"] as? Int ?? 0
            draw = all["draw"] as? Int ?? all["draws"] as? Int ?? 0
            lost = all["lose"] as? Int ?? all["lost"] as? Int ?? all["losses"] as? Int ?? 0
            
            print("   ✅ Parsed from 'all': J=\(played) V=\(won) N=\(draw) D=\(lost)")
        }
        // PRIORITÉ 3 : Fallback sur le niveau racine
        else {
            played = dict["played"] as? Int ?? 0
            won = dict["win"] as? Int ?? dict["won"] as? Int ?? 0
            draw = dict["draw"] as? Int ?? dict["draws"] as? Int ?? 0
            lost = dict["lose"] as? Int ?? dict["lost"] as? Int ?? dict["losses"] as? Int ?? 0
            
            print("   ⚠️ Parsed from root level: J=\(played) V=\(won) N=\(draw) D=\(lost)")
        }
        
        // Points toujours au niveau racine
        points = dict["points"] as? Int ?? 0
        
        self.played = played
        self.won = won
        self.draw = draw
        self.lost = lost
        self.points = points
        
        // Buts (goals) - peuvent être dans "all" ou "goals" ou au niveau racine
        var goalsFor: Int?
        var goalsAgainst: Int?
        
        // D'abord essayer dans l'objet "all"
        if let all = dict["all"] as? [String: Any],
           let goals = all["goals"] as? [String: Any] {
            goalsFor = goals["for"] as? Int
            goalsAgainst = goals["against"] as? Int
        } 
        // Sinon essayer l'objet "goals" au niveau racine
        else if let goals = dict["goals"] as? [String: Any] {
            goalsFor = goals["for"] as? Int
            goalsAgainst = goals["against"] as? Int
        } 
        // Dernier recours : champs directs
        else {
            goalsFor = dict["goals_for"] as? Int ?? dict["for"] as? Int
            goalsAgainst = dict["goals_against"] as? Int ?? dict["against"] as? Int
        }
        
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        
        if let gf = self.goalsFor, let ga = self.goalsAgainst {
            self.goalsDiff = gf - ga
        } else {
            self.goalsDiff = dict["goals_diff"] as? Int ?? dict["diff"] as? Int
        }
        
        self.form = dict["form"] as? String
        self.description = dict["description"] as? String
        
        // Debug - résumé succinct (active seulement pendant le debug)
        print("🏉 \(teamName): Pos \(position), J=\(played) V=\(won) N=\(draw) D=\(lost), Pts=\(points), Diff=\(goalsDiff ?? 0)")
    }
    
    // MARK: - Initialisation manuelle (pour tests / mock data)
    
    init(
        position: Int,
        teamId: Int,
        teamName: String,
        teamLogo: String? = nil,
        played: Int,
        won: Int,
        draw: Int,
        lost: Int,
        points: Int,
        goalsFor: Int? = nil,
        goalsAgainst: Int? = nil,
        form: String? = nil
    ) {
        self.id = "\(position)-\(teamId)"
        self.position = position
        self.teamId = teamId
        self.teamName = teamName
        self.teamLogo = teamLogo
        self.played = played
        self.won = won
        self.draw = draw
        self.lost = lost
        self.points = points
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.goalsDiff = (goalsFor ?? 0) - (goalsAgainst ?? 0)
        self.form = form
        self.description = nil
    }
}

// MARK: - Mock Data (pour preview)

extension Standing {
    static var sampleStandings: [Standing] {
        [
            Standing(
                position: 1,
                teamId: 107,
                teamName: "Stade Toulousain",
                teamLogo: "https://media.api-sports.io/rugby/teams/107.png",
                played: 10,
                won: 8,
                draw: 1,
                lost: 1,
                points: 42,
                goalsFor: 285,
                goalsAgainst: 180,
                form: "WWWDW"
            ),
            Standing(
                position: 2,
                teamId: 100,
                teamName: "Stade Rochelais",
                teamLogo: "https://media.api-sports.io/rugby/teams/100.png",
                played: 10,
                won: 7,
                draw: 2,
                lost: 1,
                points: 38,
                goalsFor: 260,
                goalsAgainst: 195,
                form: "WWDLW"
            ),
            Standing(
                position: 3,
                teamId: 96,
                teamName: "Bordeaux Bègles",
                teamLogo: "https://media.api-sports.io/rugby/teams/96.png",
                played: 10,
                won: 7,
                draw: 0,
                lost: 3,
                points: 35,
                goalsFor: 245,
                goalsAgainst: 210,
                form: "WWLWL"
            )
            // ... ajoute d'autres mocks si besoin
        ]
    }
}
