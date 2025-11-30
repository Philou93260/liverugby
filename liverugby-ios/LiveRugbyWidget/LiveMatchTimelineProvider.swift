//
//  LiveMatchTimelineProvider.swift
//  LiveRugbyWidget
//
//  Timeline provider pour le widget de match en direct
//

import WidgetKit
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct LiveMatchTimelineProvider: TimelineProvider {

    // MARK: - Timeline Provider Methods

    func placeholder(in context: Context) -> LiveMatchEntry {
        LiveMatchEntry(
            date: Date(),
            matchData: createPlaceholderMatch(),
            configuration: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LiveMatchEntry) -> Void) {
        if context.isPreview {
            let entry = LiveMatchEntry(
                date: Date(),
                matchData: createPlaceholderMatch(),
                configuration: nil
            )
            completion(entry)
        } else {
            fetchLiveMatch { matchData in
                let entry = LiveMatchEntry(
                    date: Date(),
                    matchData: matchData,
                    configuration: getFavoriteTeamConfiguration()
                )
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LiveMatchEntry>) -> Void) {
        fetchLiveMatch { matchData in
            let currentDate = Date()
            let entry = LiveMatchEntry(
                date: currentDate,
                matchData: matchData,
                configuration: getFavoriteTeamConfiguration()
            )

            // Déterminer la prochaine mise à jour en fonction du statut du match
            let nextUpdateDate: Date
            if let match = matchData, match.status.isLive {
                // Si le match est en cours, mise à jour toutes les 2 minutes
                nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 2, to: currentDate)!
            } else {
                // Sinon, mise à jour toutes les 15 minutes
                nextUpdateDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            }

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
            completion(timeline)
        }
    }

    // MARK: - Data Fetching

    private func fetchLiveMatch(completion: @escaping (WidgetMatchData?) -> Void) {
        // Récupérer la configuration de l'équipe favorite
        guard let favoriteTeam = getFavoriteTeamConfiguration() else {
            completion(nil)
            return
        }

        let db = Firestore.firestore()
        let today = Calendar.current.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: today)

        // Chercher le match du jour pour l'équipe favorite
        db.collection("matches")
            .document(todayString)
            .getDocument { snapshot, error in
                guard let data = snapshot?.data(),
                      let matchesArray = data["matches"] as? [[String: Any]] else {
                    completion(nil)
                    return
                }

                // Trouver le match de l'équipe favorite
                let favoriteMatch = matchesArray.first { matchDict in
                    guard let homeTeam = matchDict["home"] as? [String: Any],
                          let awayTeam = matchDict["away"] as? [String: Any],
                          let homeId = homeTeam["id"] as? Int,
                          let awayId = awayTeam["id"] as? Int else {
                        return false
                    }
                    return homeId == favoriteTeam.teamId || awayId == favoriteTeam.teamId
                }

                if let matchDict = favoriteMatch {
                    let matchData = parseMatchData(matchDict, favoriteTeamId: favoriteTeam.teamId)
                    completion(matchData)
                } else {
                    completion(nil)
                }
            }
    }

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

    // MARK: - Configuration

    private func getFavoriteTeamConfiguration() -> FavoriteTeamConfiguration? {
        // Récupérer l'équipe favorite depuis UserDefaults (App Group)
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

    // MARK: - Placeholder Data

    private func createPlaceholderMatch() -> WidgetMatchData {
        return WidgetMatchData(
            matchId: 0,
            league: "Top 14",
            leagueLogo: "",
            date: Date(),
            status: .firstHalf,
            homeTeam: TeamData(id: 1, name: "Toulouse", logo: "", score: 21),
            awayTeam: TeamData(id: 2, name: "La Rochelle", logo: "", score: 14),
            venue: "Stade Ernest-Wallon",
            elapsed: 35
        )
    }
}
