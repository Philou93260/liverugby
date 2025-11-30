//
//  WidgetDataService.swift
//  LiveRugbyWidget
//
//  Service pour récupérer les données du widget depuis Firestore
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class WidgetDataService {

    static let shared = WidgetDataService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Fetch Match Data

    /// Récupère le match en cours ou à venir pour une équipe donnée
    func fetchLiveMatchForTeam(
        teamId: Int,
        completion: @escaping (Result<WidgetMatchData?, Error>) -> Void
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: today)

        // Récupérer les matchs du jour
        db.collection("matches")
            .document(todayString)
            .getDocument { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = snapshot?.data(),
                      let matchesArray = data["matches"] as? [[String: Any]] else {
                    completion(.success(nil))
                    return
                }

                // Trouver le match de l'équipe
                let teamMatches = matchesArray.filter { matchDict in
                    guard let homeTeam = matchDict["home"] as? [String: Any],
                          let awayTeam = matchDict["away"] as? [String: Any],
                          let homeId = homeTeam["id"] as? Int,
                          let awayId = awayTeam["id"] as? Int else {
                        return false
                    }
                    return homeId == teamId || awayId == teamId
                }

                // Trouver le match en cours ou le prochain match
                let match = self.findBestMatch(from: teamMatches)

                if let matchDict = match {
                    let matchData = self.parseMatchData(matchDict, favoriteTeamId: teamId)
                    completion(.success(matchData))
                } else {
                    // Pas de match aujourd'hui, chercher le prochain match
                    self.fetchNextMatchForTeam(teamId: teamId, completion: completion)
                }
            }
    }

    /// Trouve le meilleur match à afficher (en cours > à venir > terminé)
    private func findBestMatch(from matches: [[String: Any]]) -> [String: Any]? {
        // Priorité 1: Match en cours
        if let liveMatch = matches.first(where: { matchDict in
            guard let statusDict = matchDict["status"] as? [String: Any],
                  let statusShort = statusDict["short"] as? String else {
                return false
            }
            let status = MatchStatus(rawValue: statusShort) ?? .notStarted
            return status.isLive
        }) {
            return liveMatch
        }

        // Priorité 2: Match à venir (le plus proche)
        let upcomingMatches = matches.filter { matchDict in
            guard let statusDict = matchDict["status"] as? [String: Any],
                  let statusShort = statusDict["short"] as? String else {
                return false
            }
            return statusShort == "NS"
        }.sorted { match1, match2 in
            let timestamp1 = match1["timestamp"] as? TimeInterval ?? 0
            let timestamp2 = match2["timestamp"] as? TimeInterval ?? 0
            return timestamp1 < timestamp2
        }

        if let upcomingMatch = upcomingMatches.first {
            return upcomingMatch
        }

        // Priorité 3: Match terminé (le plus récent)
        let finishedMatches = matches.sorted { match1, match2 in
            let timestamp1 = match1["timestamp"] as? TimeInterval ?? 0
            let timestamp2 = match2["timestamp"] as? TimeInterval ?? 0
            return timestamp1 > timestamp2
        }

        return finishedMatches.first
    }

    /// Récupère le prochain match à venir pour l'équipe
    private func fetchNextMatchForTeam(
        teamId: Int,
        completion: @escaping (Result<WidgetMatchData?, Error>) -> Void
    ) {
        // Chercher dans les 7 prochains jours
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var allMatches: [[String: Any]] = []
        let group = DispatchGroup()

        for dayOffset in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }

            let dateString = dateFormatter.string(from: date)
            group.enter()

            db.collection("matches")
                .document(dateString)
                .getDocument { snapshot, error in
                    defer { group.leave() }

                    guard let data = snapshot?.data(),
                          let matchesArray = data["matches"] as? [[String: Any]] else {
                        return
                    }

                    let teamMatches = matchesArray.filter { matchDict in
                        guard let homeTeam = matchDict["home"] as? [String: Any],
                              let awayTeam = matchDict["away"] as? [String: Any],
                              let homeId = homeTeam["id"] as? Int,
                              let awayId = awayTeam["id"] as? Int else {
                            return false
                        }
                        return homeId == teamId || awayId == teamId
                    }

                    allMatches.append(contentsOf: teamMatches)
                }
        }

        group.notify(queue: .main) {
            // Trier par date et prendre le premier
            let sortedMatches = allMatches.sorted { match1, match2 in
                let timestamp1 = match1["timestamp"] as? TimeInterval ?? 0
                let timestamp2 = match2["timestamp"] as? TimeInterval ?? 0
                return timestamp1 < timestamp2
            }

            if let nextMatch = sortedMatches.first {
                let matchData = self.parseMatchData(nextMatch, favoriteTeamId: teamId)
                completion(.success(matchData))
            } else {
                completion(.success(nil))
            }
        }
    }

    // MARK: - Parse Data

    private func parseMatchData(_ matchDict: [String: Any], favoriteTeamId: Int) -> WidgetMatchData? {
        guard let matchId = matchDict["id"] as? Int,
              let statusDict = matchDict["status"] as? [String: Any],
              let statusShort = statusDict["short"] as? String,
              let homeTeamDict = matchDict["home"] as? [String: Any],
              let awayTeamDict = matchDict["away"] as? [String: Any],
              let leagueDict = matchDict["league"] as? [String: Any],
              let leagueName = leagueDict["name"] as? String,
              let leagueLogo = leagueDict["logo"] as? String else {
            return nil
        }

        // Parse status
        let status = MatchStatus(rawValue: statusShort) ?? .notStarted

        // Parse teams
        guard let homeTeam = parseTeamData(homeTeamDict),
              let awayTeam = parseTeamData(awayTeamDict) else {
            return nil
        }

        // Parse date
        let date: Date
        if let timestamp = matchDict["timestamp"] as? TimeInterval {
            date = Date(timeIntervalSince1970: timestamp)
        } else {
            date = Date()
        }

        // Parse elapsed time
        let elapsed = statusDict["elapsed"] as? Int

        // Parse venue
        let venue = (matchDict["venue"] as? [String: Any])?["name"] as? String

        return WidgetMatchData(
            matchId: matchId,
            league: leagueName,
            leagueLogo: leagueLogo,
            date: date,
            status: status,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            venue: venue,
            elapsed: elapsed
        )
    }

    private func parseTeamData(_ teamDict: [String: Any]) -> TeamData? {
        guard let id = teamDict["id"] as? Int,
              let name = teamDict["name"] as? String,
              let logo = teamDict["logo"] as? String else {
            return nil
        }

        let score = teamDict["score"] as? Int

        return TeamData(id: id, name: name, logo: logo, score: score)
    }

    // MARK: - Favorite Team

    /// Récupère la configuration de l'équipe favorite depuis UserDefaults
    static func getFavoriteTeamConfiguration() -> FavoriteTeamConfiguration? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.liverugby.app")
        guard let teamId = sharedDefaults?.integer(forKey: "favoriteTeamId"),
              teamId != 0,
              let teamName = sharedDefaults?.string(forKey: "favoriteTeamName"),
              let teamLogo = sharedDefaults?.string(forKey: "favoriteTeamLogo") else {
            return nil
        }

        return FavoriteTeamConfiguration(
            teamId: teamId,
            teamName: teamName,
            teamLogo: teamLogo
        )
    }

    /// Sauvegarde la configuration de l'équipe favorite
    static func saveFavoriteTeamConfiguration(_ config: FavoriteTeamConfiguration) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.liverugby.app")
        sharedDefaults?.set(config.teamId, forKey: "favoriteTeamId")
        sharedDefaults?.set(config.teamName, forKey: "favoriteTeamName")
        sharedDefaults?.set(config.teamLogo, forKey: "favoriteTeamLogo")
    }
}
