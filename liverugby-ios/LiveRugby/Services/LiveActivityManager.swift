//
//  LiveActivityManager.swift
//  LiveRugby
//
//  Gère le cycle de vie des Live Activities pour les matchs de rugby
//

import Foundation
import ActivityKit
import FirebaseFunctions

@available(iOS 16.2, *)
@MainActor
class LiveActivityManager: ObservableObject {

    static let shared = LiveActivityManager()

    // MARK: - Published Properties

    /// Activités en cours (matchId -> Activity)
    @Published var activeActivities: [Int: Activity<MatchLiveActivityAttributes>] = [:]

    /// Indique si les Live Activities sont supportées
    @Published var isSupported: Bool = false

    // MARK: - Private Properties

    private let functions: Functions
    private var pushTokenTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        functions = Functions.functions(region: "europe-west1")
        checkSupport()
        observeActivities()
    }

    // MARK: - Public Methods

    /// Démarre une Live Activity pour un match
    /// - Parameters:
    ///   - match: Le match à suivre
    /// - Returns: True si la Live Activity a été créée avec succès
    @discardableResult
    func startActivity(for match: Match) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities non autorisées par l'utilisateur")
            return false
        }

        // Vérifier si une activité existe déjà pour ce match
        if activeActivities[match.id] != nil {
            print("ℹ️ Live Activity déjà active pour le match \(match.id)")
            return true
        }

        let attributes = MatchLiveActivityAttributes(
            matchId: match.id,
            homeTeamName: match.homeTeamName,
            homeTeamLogo: match.homeTeamLogo,
            awayTeamName: match.awayTeamName,
            awayTeamLogo: match.awayTeamLogo,
            leagueName: match.leagueName,
            matchDateTime: Date() // À améliorer avec la vraie date du match
        )

        let initialState = MatchLiveActivityAttributes.ContentState(
            homeScore: match.homeScore ?? 0,
            awayScore: match.awayScore ?? 0,
            status: match.statusShort ?? "NS",
            elapsed: nil,
            lastUpdate: Date(),
            recentEvent: nil
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: .token
            )

            activeActivities[match.id] = activity
            print("✅ Live Activity créée pour le match \(match.id)")

            // Observer le push token pour cette activité
            observePushToken(for: activity, matchId: match.id)

            return true
        } catch {
            print("❌ Erreur création Live Activity: \(error)")
            return false
        }
    }

    /// Met à jour une Live Activity existante
    /// - Parameters:
    ///   - matchId: ID du match
    ///   - homeScore: Nouveau score à domicile
    ///   - awayScore: Nouveau score extérieur
    ///   - status: Nouveau statut
    ///   - elapsed: Temps écoulé (optionnel)
    ///   - recentEvent: Événement récent (optionnel)
    func updateActivity(
        matchId: Int,
        homeScore: Int,
        awayScore: Int,
        status: String,
        elapsed: Int? = nil,
        recentEvent: String? = nil
    ) async {
        guard let activity = activeActivities[matchId] else {
            print("⚠️ Aucune Live Activity active pour le match \(matchId)")
            return
        }

        let newState = MatchLiveActivityAttributes.ContentState(
            homeScore: homeScore,
            awayScore: awayScore,
            status: status,
            elapsed: elapsed,
            lastUpdate: Date(),
            recentEvent: recentEvent
        )

        let alertConfig = AlertConfiguration(
            title: recentEvent ?? "Mise à jour",
            body: "\(homeScore) - \(awayScore)",
            sound: .default
        )

        do {
            await activity.update(
                .init(state: newState, staleDate: nil),
                alertConfiguration: alertConfig
            )
            print("✅ Live Activity mise à jour pour le match \(matchId)")
        } catch {
            print("❌ Erreur mise à jour Live Activity: \(error)")
        }
    }

    /// Termine une Live Activity
    /// - Parameters:
    ///   - matchId: ID du match
    ///   - finalHomeScore: Score final à domicile
    ///   - finalAwayScore: Score final extérieur
    func endActivity(matchId: Int, finalHomeScore: Int, finalAwayScore: Int) async {
        guard let activity = activeActivities[matchId] else {
            print("⚠️ Aucune Live Activity active pour le match \(matchId)")
            return
        }

        let finalState = MatchLiveActivityAttributes.ContentState(
            homeScore: finalHomeScore,
            awayScore: finalAwayScore,
            status: "FT",
            elapsed: nil,
            lastUpdate: Date(),
            recentEvent: "Match terminé"
        )

        do {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 3600) // Reste 1h après la fin
            )
            activeActivities.removeValue(forKey: matchId)
            print("✅ Live Activity terminée pour le match \(matchId)")
        } catch {
            print("❌ Erreur fin Live Activity: \(error)")
        }
    }

    /// Termine toutes les Live Activities
    func endAllActivities() async {
        for (matchId, activity) in activeActivities {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("🛑 Live Activity \(matchId) arrêtée")
        }
        activeActivities.removeAll()
    }

    // MARK: - Private Methods

    /// Vérifie si les Live Activities sont supportées
    private func checkSupport() {
        isSupported = ActivityAuthorizationInfo().areActivitiesEnabled
        print(isSupported ? "✅ Live Activities supportées" : "⚠️ Live Activities non supportées")
    }

    /// Observer les activités en cours
    private func observeActivities() {
        Task {
            for await activity in Activity<MatchLiveActivityAttributes>.activityUpdates {
                if let matchId = activeActivities.first(where: { $0.value.id == activity.id })?.key {
                    activeActivities[matchId] = activity
                }
            }
        }
    }

    /// Observer le push token d'une activité et l'envoyer au backend
    private func observePushToken(for activity: Activity<MatchLiveActivityAttributes>, matchId: Int) {
        pushTokenTask?.cancel()
        pushTokenTask = Task {
            for await pushToken in activity.pushTokenUpdates {
                let tokenString = pushToken.map { String(format: "%02x", $0) }.joined()
                print("🔑 Activity Push Token reçu pour match \(matchId): \(tokenString.prefix(20))...")

                // Envoyer le token au backend
                await registerActivityPushToken(matchId: matchId, token: tokenString)
            }
        }
    }

    /// Enregistre le push token de la Live Activity sur le backend
    private func registerActivityPushToken(matchId: Int, token: String) async {
        do {
            let result = try await functions.httpsCallable("registerActivityPushToken").call([
                "matchId": matchId,
                "token": token,
                "platform": "ios"
            ])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool, success {
                print("✅ Activity Push Token enregistré pour le match \(matchId)")
            }
        } catch {
            print("❌ Erreur enregistrement Activity Push Token: \(error)")
        }
    }
}

// MARK: - Activity State Extension

@available(iOS 16.2, *)
extension Activity<MatchLiveActivityAttributes> {
    /// Indique si l'activité est active
    var isActive: Bool {
        return activityState == .active
    }
}
