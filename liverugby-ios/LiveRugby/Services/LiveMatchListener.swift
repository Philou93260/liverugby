//
//  LiveMatchListener.swift
//  LiveRugby
//
//  Listener pour les mises à jour en temps réel des matchs via Firestore
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class LiveMatchListener: ObservableObject {
    static let shared = LiveMatchListener()

    @Published var liveMatches: [String: Match] = [:]
    @Published var lastUpdate: Date?

    private var db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Listen to Live Match

    /// Commencer à écouter les mises à jour d'un match en temps réel
    func startListening(to matchId: Int) {
        let matchIdString = String(matchId)

        // Ne pas créer de listener en double
        if listeners[matchIdString] != nil {
            print("⚠️ Listener déjà actif pour le match \(matchId)")
            return
        }

        print("👂 Démarrage écoute temps réel: match \(matchId)")

        let listener = db.collection("liveMatches")
            .document(matchIdString)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Erreur listener match \(matchId): \(error.localizedDescription)")
                    return
                }

                guard let document = documentSnapshot else {
                    print("⚠️ Document nil pour match \(matchId)")
                    return
                }

                guard document.exists else {
                    print("⚠️ Match \(matchId) n'existe pas dans liveMatches")
                    return
                }

                // Convertir les données Firestore en Match
                if let data = document.data(),
                   let match = self.parseMatchFromFirestore(data: data, matchId: matchId) {

                    Task { @MainActor in
                        self.liveMatches[matchIdString] = match
                        self.lastUpdate = Date()

                        print("✅ Match \(matchId) mis à jour en temps réel")
                        print("   Score: \(match.homeTeam?.name ?? "?") \(match.homeScore ?? 0) - \(match.awayScore ?? 0) \(match.awayTeam?.name ?? "?")")
                        print("   Status: \(match.status ?? "?")")

                        // Publier une notification pour rafraîchir l'UI
                        NotificationCenter.default.post(
                            name: .liveMatchUpdated,
                            object: nil,
                            userInfo: ["matchId": matchIdString, "match": match]
                        )
                    }
                } else {
                    print("❌ Impossible de parser le match \(matchId)")
                }
            }

        listeners[matchIdString] = listener
    }

    /// Arrêter d'écouter un match spécifique
    func stopListening(to matchId: Int) {
        let matchIdString = String(matchId)

        if let listener = listeners[matchIdString] {
            listener.remove()
            listeners.removeValue(forKey: matchIdString)
            liveMatches.removeValue(forKey: matchIdString)
            print("🛑 Écoute arrêtée pour le match \(matchId)")
        }
    }

    /// Arrêter tous les listeners
    func stopAllListeners() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
        liveMatches.removeAll()
        print("🛑 Tous les listeners arrêtés")
    }

    /// Obtenir un match en temps réel
    func getMatch(_ matchId: Int) -> Match? {
        return liveMatches[String(matchId)]
    }

    // MARK: - Listen to Today's Matches

    /// Écouter tous les matchs du jour
    func listenToTodayMatches() {
        let today = formatDate(Date())

        print("👂 Démarrage écoute matchs du jour: \(today)")

        let listener = db.collection("matches")
            .document(today)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Erreur listener matchs du jour: \(error.localizedDescription)")
                    return
                }

                guard let document = documentSnapshot,
                      document.exists,
                      let data = document.data(),
                      let matchesData = data["matches"] as? [[String: Any]] else {
                    print("⚠️ Pas de matchs pour aujourd'hui")
                    return
                }

                Task { @MainActor in
                    print("✅ \(matchesData.count) matchs mis à jour")

                    // Publier une notification globale
                    NotificationCenter.default.post(
                        name: .todayMatchesUpdated,
                        object: nil,
                        userInfo: ["count": matchesData.count]
                    )
                }
            }

        listeners["todayMatches"] = listener
    }

    /// Arrêter d'écouter les matchs du jour
    func stopListeningToTodayMatches() {
        if let listener = listeners["todayMatches"] {
            listener.remove()
            listeners.removeValue(forKey: "todayMatches")
            print("🛑 Écoute arrêtée pour les matchs du jour")
        }
    }

    // MARK: - Helpers

    private func parseMatchFromFirestore(data: [String: Any], matchId: Int) -> Match? {
        // Convertir les données Firestore en format Match
        // La structure Firestore suit le format de l'API Rugby

        var matchData = data
        matchData["id"] = matchId

        return Match(from: matchData)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    deinit {
        stopAllListeners()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let liveMatchUpdated = Notification.Name("LiveMatchUpdated")
    static let todayMatchesUpdated = Notification.Name("TodayMatchesUpdated")
}
