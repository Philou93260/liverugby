//
//  RugbyService.swift
//  LiverugbyApp
//
//  Service pour interagir avec l'API Rugby via Firebase Functions
//

import Foundation
import Combine
import FirebaseFunctions

@MainActor
class RugbyService: ObservableObject {
    static let shared = RugbyService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let functions: Functions
    
    private init() {
        // Utiliser europe-west1 (région configurée dans le backend Firebase)
        functions = Functions.functions(region: "europe-west1")
    }
    
    // MARK: - Récupérer les matchs du jour
    
    func getTodayMatches() async throws -> [Match] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await functions.httpsCallable("getTodayMatches").call()
            
            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let matchesData = data["matches"] as? [[String: Any]] else {
                throw RugbyError.invalidResponse
            }
            
            return matchesData.compactMap { Match(from: $0) }
        } catch {
            errorMessage = "Erreur lors du chargement des matchs: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Récupérer les matchs du jour pour une ligue spécifique
    
    func getLeagueMatchesToday(leagueId: Int) async throws -> [Match] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // On récupère tous les matchs du jour, puis on filtre par ligue
            let allMatches = try await getTodayMatches()
            return allMatches.filter { $0.leagueId == leagueId }
        } catch {
            errorMessage = "Erreur lors du chargement des matchs: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Récupérer les matchs d'une ligue
    
    func getLeagueMatches(leagueId: Int, season: Int? = nil) async throws -> [Match] {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: Any] = ["league": leagueId]
        if let season = season {
            params["season"] = season
        }
        
        do {
            let result = try await functions.httpsCallable("getLeagueMatches").call(params)
            
            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let matchesData = data["matches"] as? [[String: Any]] else {
                throw RugbyError.invalidResponse
            }
            
            return matchesData.compactMap { Match(from: $0) }
        } catch {
            errorMessage = "Erreur lors du chargement des matchs de la ligue: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Récupérer les matchs d'une équipe
    
    func getTeamMatches(teamId: Int, season: Int? = nil) async throws -> [Match] {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: Any] = ["teamId": teamId]
        if let season = season {
            params["season"] = season
        }
        
        do {
            let result = try await functions.httpsCallable("getTeamMatches").call(params)
            
            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let matchesData = data["matches"] as? [[String: Any]] else {
                throw RugbyError.invalidResponse
            }
            
            return matchesData.compactMap { Match(from: $0) }
        } catch {
            errorMessage = "Erreur lors du chargement des matchs de l'équipe: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Récupérer les équipes d'une ligue
    
    func getLeagueTeams(leagueId: Int, season: Int? = nil) async throws -> [Team] {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: Any] = ["leagueId": leagueId]
        if let season = season {
            params["season"] = season
        }
        
        do {
            let result = try await functions.httpsCallable("getLeagueTeams").call(params)
            
            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let teamsData = data["teams"] as? [[String: Any]] else {
                throw RugbyError.invalidResponse
            }
            
            return teamsData.compactMap { Team(from: $0) }
        } catch {
            errorMessage = "Erreur lors du chargement des équipes: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Récupérer le classement
    
    func getLeagueStandings(leagueId: Int, season: Int? = nil) async throws -> [Standing] {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: Any] = ["leagueId": leagueId]
        if let season = season {
            params["season"] = season
        }
 
        do {
            let result = try await functions.httpsCallable("getLeagueStandings").call(params)

            // Récupérer le payload renvoyé par la Cloud Function
            guard let data = result.data as? [String: Any] else {
                throw RugbyError.invalidResponse
            }
            
            // Debug : afficher la structure reçue
            print("🔍 getLeagueStandings - Keys received: \(data.keys.sorted())")

            // Si la Cloud Function renvoie un wrapper { success: Bool, ... }
            if let success = data["success"] as? Bool, success {
                // 1) Cas : la function renvoie déjà "standings": [[[String: Any]]]
                if let standingsData = data["standings"] as? [[[String: Any]]] {
                    let allStandings = standingsData.flatMap { $0 }
                    print("✅ Found \(allStandings.count) standings in data['standings']")
                    if let first = allStandings.first {
                        print("🔍 First standing JSON: \(first)")
                    }
                    return allStandings.compactMap { Standing(from: $0) }
                }

                // 2) Cas : la function renvoie le JSON brut de l'API (champ "response")
                if let response = data["response"] as? [[String: Any]],
                   let league = response.first?["league"] as? [String: Any],
                   let standingsNested = league["standings"] as? [[[String: Any]]],
                   let standingsArray = standingsNested.first {
                    print("✅ Found \(standingsArray.count) standings in response[0].league.standings[0]")
                    if let first = standingsArray.first {
                        print("🔍 First standing JSON: \(first)")
                    }
                    return standingsArray.compactMap { Standing(from: $0) }
                }

                // 3) Autre fallback : parfois "response" est un dictionnaire
                if let responseDict = data["response"] as? [String: Any],
                   let league = responseDict["league"] as? [String: Any],
                   let standingsNested = league["standings"] as? [[[String: Any]]],
                   let standingsArray = standingsNested.first {
                    print("✅ Found \(standingsArray.count) standings in response.league.standings[0]")
                    if let first = standingsArray.first {
                        print("🔍 First standing JSON: \(first)")
                    }
                    return standingsArray.compactMap { Standing(from: $0) }
                }

                // Pas de format connu
                print("❌ Success=true but no standings found")
                throw RugbyError.invalidResponse
            }

            // Si pas de wrapper "success", essayer de déplier le payload directement (cas de retour brut)
            if let response = data["response"] as? [[String: Any]],
               let league = response.first?["league"] as? [String: Any],
               let standingsNested = league["standings"] as? [[[String: Any]]],
               let standingsArray = standingsNested.first {
                return standingsArray.compactMap { Standing(from: $0) }
            }

            // Dernier essai : si la Cloud Function renvoie directement "standings" sans wrapper success
            if let standingsData = data["standings"] as? [[[String: Any]]] {
                let allStandings = standingsData.flatMap { $0 }
                return allStandings.compactMap { Standing(from: $0) }
            }

            // Aucune forme reconnue -> erreur
            throw RugbyError.invalidResponse
        } catch {
            errorMessage = "Erreur lors du chargement du classement: \(error.localizedDescription)"
            throw error
        }

 //       do {
 //           let result = try await functions.httpsCallable("getLeagueStandings").call(params)
//
//            guard let data = result.data as? [String: Any],
 //                 let success = data["success"] as? Bool,
//                  success,
//                  let standingsData = data["standings"] as? [[[String: Any]]] else {
//                throw RugbyError.invalidResponse
//            }
    //
   //         // L'API retourne un tableau de groupes
  //      let allStandings = standingsData.flatMap { $0 }
 //           return allStandings.compactMap { Standing(from: $0) }
         catch {
            errorMessage = "Erreur lors du chargement du classement: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Rechercher des équipes
    
    func searchTeams(name: String) async throws -> [Team] {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await functions.httpsCallable("searchTeams")
                .call(["teamName": name])
            
            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let teamsData = data["teams"] as? [[String: Any]] else {
                throw RugbyError.invalidResponse
            }
            
            return teamsData.compactMap { Team(from: $0) }
        } catch {
            errorMessage = "Erreur lors de la recherche: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Récupérer les détails d'un match
    
    func getMatchDetails(matchId: Int) async throws -> Match {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await functions.httpsCallable("getMatchDetails")
                .call(["matchId": matchId])
            
            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success,
                  let matchData = data["match"] as? [String: Any] else {
                throw RugbyError.invalidResponse
            }
            let match = Match(from: matchData)
            
            return match
        } catch {
            errorMessage = "Erreur lors du chargement du match: \(error.localizedDescription)"
            throw error
        }
    }
}

// MARK: - Erreurs

enum RugbyError: LocalizedError {
    case invalidResponse
    case notAuthenticated
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Réponse invalide de l'API"
        case .notAuthenticated:
            return "Vous devez être connecté"
        case .networkError:
            return "Erreur de connexion"
        }
    }
}

