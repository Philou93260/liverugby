//
//  LiveMatchListener.swift
//  LiveRugby
//
//  Listener pour les mises à jour en temps réel des matchs via Firestore
//  VERSION AMÉLIORÉE avec parsing complet des events, eventsSummary, timer, elapsed
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Match Event Models

/// Événement d'un match (essai, carton, pénalité, etc.)
struct MatchEvent: Codable, Identifiable {
    let type: String        // "try", "conversion", "penalty", "yellowcard", "redcard", "substitution"
    let time: String        // "23'" par exemple
    let team: String        // "home" ou "away"
    let player: EventPlayer?
    let detail: String?

    var id: String { "\(time)-\(type)-\(team)" }

    struct EventPlayer: Codable {
        let id: Int?
        let name: String
    }

    /// Emoji pour l'événement
    var emoji: String {
        switch type.lowercased() {
        case "try": return "⭐"
        case "conversion": return "✅"
        case "penalty": return "🎯"
        case "yellowcard": return "🟨"
        case "redcard": return "🟥"
        case "substitution": return "🔄"
        default: return "📌"
        }
    }

    /// Description lisible
    var description: String {
        let playerName = player?.name ?? "Inconnu"
        switch type.lowercased() {
        case "try": return "\(emoji) Essai de \(playerName) (\(time))"
        case "conversion": return "\(emoji) Transformation réussie par \(playerName) (\(time))"
        case "penalty": return "\(emoji) Pénalité réussie par \(playerName) (\(time))"
        case "yellowcard": return "\(emoji) Carton jaune pour \(playerName) (\(time))"
        case "redcard": return "\(emoji) Carton rouge pour \(playerName) (\(time))"
        case "substitution": return "\(emoji) Remplacement: \(playerName) (\(time))"
        default: return "\(emoji) \(type) - \(playerName) (\(time))"
        }
    }
}

/// Résumé des événements d'un match
struct EventsSummary: Codable {
    let tries: Int
    let conversions: Int
    let penalties: Int
    let yellowCards: Int
    let redCards: Int
    let substitutions: Int

    var isEmpty: Bool {
        tries == 0 && conversions == 0 && penalties == 0 &&
        yellowCards == 0 && redCards == 0 && substitutions == 0
    }
}

/// Temps et chronomètre du match
struct MatchTime: Codable {
    let date: String?
    let timestamp: Int?
    let timer: String?      // "12:34" - Chronomètre actuel
    let elapsed: Int?       // Minutes écoulées
}

// MARK: - Notification Names

extension Notification.Name {
    static let liveMatchUpdated = Notification.Name("LiveMatchUpdated")
    static let todayMatchesUpdated = Notification.Name("TodayMatchesUpdated")
    static let matchEventReceived = Notification.Name("MatchEventReceived")
}

@MainActor
class LiveMatchListener: ObservableObject {
    static let shared = LiveMatchListener()

    @Published var liveMatches: [String: Match] = [:]
    @Published var matchEvents: [String: [MatchEvent]] = [:]  // Events par matchId
    @Published var lastUpdate: Date?

    // Lazy pour s'assurer que Firebase est configuré avant l'accès
    private lazy var db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    private var eventListeners: [String: ListenerRegistration] = [:]

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
                        print("   Score: \(match.homeTeamName) \(match.homeScore ?? 0) - \(match.awayScore ?? 0) \(match.awayTeamName)")
                        print("   Status: \(match.status)")

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

        // ✅ Démarrer aussi l'écoute des événements
        startListeningToEvents(for: matchId)
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

        // ✅ Arrêter aussi l'écoute des événements
        if let eventListener = eventListeners[matchIdString] {
            eventListener.remove()
            eventListeners.removeValue(forKey: matchIdString)
            matchEvents.removeValue(forKey: matchIdString)
            print("🛑 Écoute des événements arrêtée pour le match \(matchId)")
        }
    }

    // MARK: - Listen to Events

    /// Écouter les événements d'un match en temps réel
    func startListeningToEvents(for matchId: Int) {
        let matchIdString = String(matchId)

        // Ne pas créer de listener en double
        if eventListeners[matchIdString] != nil {
            print("⚠️ Event listener déjà actif pour le match \(matchId)")
            return
        }

        print("👂 Démarrage écoute événements: match \(matchId)")

        // ✅ CORRECTION : Écouter avec le bon champ (event.fixture.id)
        // L'index composite doit être créé dans Firebase Console
        let listener = db.collection("liveEvents")
            .whereField("event.fixture.id", isEqualTo: matchId)
            .order(by: "receivedAt", descending: true)
            .limit(to: 10)  // Garder les 10 derniers événements
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("❌ Erreur listener events match \(matchId): \(error.localizedDescription)")
                    return
                }

                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    print("⚠️ Pas d'événements pour match \(matchId)")
                    return
                }

                print("📨 \(documents.count) événement(s) reçu(s) pour match \(matchId)")

                // Traiter chaque événement
                for document in documents {
                    let data = document.data()
                    self.handleNewEvent(data: data, matchId: matchId)
                }
            }

        eventListeners[matchIdString] = listener
    }

    /// Traiter un nouvel événement
    private func handleNewEvent(data: [String: Any], matchId: Int) {
        guard let eventData = data["event"] as? [String: Any],
              let eventType = eventData["type"] as? String else {
            print("⚠️ Event data incomplet")
            return
        }

        let source = data["source"] as? String ?? "unknown"

        print("🎉 Nouvel événement pour match \(matchId):")
        print("   Type: \(eventType)")
        print("   Source: \(source)")

        // Mettre à jour la Live Activity si elle est active
        Task { @MainActor in
            if #available(iOS 16.2, *) {
                // Récupérer le match mis à jour depuis liveMatches
                if let match = self.liveMatches[String(matchId)] {
                    await LiveActivityManager.shared.updateActivity(for: match)
                    print("🔔 Live Activity mise à jour avec nouvel événement")

                    // Envoyer une notification pour ouvrir la Dynamic Island
                    NotificationCenter.default.post(
                        name: .matchEventReceived,
                        object: nil,
                        userInfo: [
                            "matchId": matchId,
                            "eventType": eventType,
                            "eventData": eventData
                        ]
                    )
                }
            }
        }
    }

    /// Arrêter tous les listeners
    func stopAllListeners() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
        liveMatches.removeAll()

        eventListeners.values.forEach { $0.remove() }
        eventListeners.removeAll()
        matchEvents.removeAll()

        print("🛑 Tous les listeners arrêtés")
    }

    /// Obtenir un match en temps réel
    func getMatch(_ matchId: Int) -> Match? {
        return liveMatches[String(matchId)]
    }

    /// Obtenir les événements d'un match
    func getEvents(for matchId: Int) -> [MatchEvent] {
        return matchEvents[String(matchId)] ?? []
    }

    // MARK: - Listen to Today's Matches

    /// Écouter tous les matchs du jour
    func listenToTodayMatches() {
        let today = formatDate(Date())

        print("👂 Démarrage écoute matchs du jour: \(today)")

        let listener = db.collection("matches")
            .document(today)
            .addSnapshotListener { documentSnapshot, error in
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
        print("🔍 Parsing Firestore data for match \(matchId):")
        print("   Keys: \(data.keys.joined(separator: ", "))")

        var matchData: [String: Any] = [:]
        matchData["id"] = matchId

        // ============================================
        // ✅ DATE ET TIME (avec timer et elapsed)
        // ============================================
        if let time = data["time"] as? [String: Any] {
            matchData["date"] = time["date"] as? String ?? ""
            matchData["timestamp"] = time["timestamp"] as? Int
            matchData["timezone"] = "UTC"

            // ✅ NOUVEAU : Parser timer et elapsed
            if let timer = time["timer"] as? String {
                matchData["timer"] = timer
                print("   ⏱️  Timer: \(timer)")
            }

            if let elapsed = time["elapsed"] as? Int {
                matchData["elapsed"] = elapsed
                print("   ⏱️  Elapsed: \(elapsed) min")
            }
        }

        // ============================================
        // ✅ STATUS - Normaliser certains statuts
        // ============================================
        let rawStatus = data["status"] as? String ?? "Unknown"
        let normalizedStatus: String

        if rawStatus.uppercased().contains("FINISHED") ||
           rawStatus.uppercased().contains("FULL TIME") ||
           rawStatus.uppercased() == "TERMINÉ" {
            normalizedStatus = "FT"
        } else {
            normalizedStatus = rawStatus
        }

        matchData["status"] = normalizedStatus
        print("   📊 Status: \(rawStatus) → \(normalizedStatus)")

        // ============================================
        // ✅ HOME TEAM (avec logo)
        // ============================================
        if let homeTeam = data["homeTeam"] as? [String: Any] {
            var teams: [String: Any] = matchData["teams"] as? [String: Any] ?? [:]
            teams["home"] = [
                "id": homeTeam["id"] ?? 0,
                "name": homeTeam["name"] ?? "Unknown",
                "logo": homeTeam["logo"] as Any  // ✅ Logo inclus
            ]
            matchData["teams"] = teams

            if let logo = homeTeam["logo"] as? String {
                print("   🏠 Home: \(homeTeam["name"] ?? "Unknown") (logo: \(logo))")
            } else {
                print("   🏠 Home: \(homeTeam["name"] ?? "Unknown") (pas de logo)")
            }
        }

        // ============================================
        // ✅ AWAY TEAM (avec logo)
        // ============================================
        if let awayTeam = data["awayTeam"] as? [String: Any] {
            var teams: [String: Any] = matchData["teams"] as? [String: Any] ?? [:]
            teams["away"] = [
                "id": awayTeam["id"] ?? 0,
                "name": awayTeam["name"] ?? "Unknown",
                "logo": awayTeam["logo"] as Any  // ✅ Logo inclus
            ]
            matchData["teams"] = teams

            if let logo = awayTeam["logo"] as? String {
                print("   ✈️  Away: \(awayTeam["name"] ?? "Unknown") (logo: \(logo))")
            } else {
                print("   ✈️  Away: \(awayTeam["name"] ?? "Unknown") (pas de logo)")
            }
        }

        // ============================================
        // ✅ SCORES
        // ============================================
        let homeScore = data["homeScore"] as? Int ?? 0
        let awayScore = data["awayScore"] as? Int ?? 0
        matchData["scores"] = [
            "home": homeScore,
            "away": awayScore
        ]
        print("   📊 Score: \(homeScore) - \(awayScore)")

        // ============================================
        // ✅ LEAGUE (avec logo)
        // ============================================
        if let league = data["league"] as? [String: Any] {
            matchData["league"] = [
                "id": league["id"] ?? 0,
                "name": league["name"] ?? "",
                "logo": league["logo"] as Any  // ✅ Logo inclus
            ]

            if let logo = league["logo"] as? String {
                print("   🏆 League: \(league["name"] ?? "Unknown") (logo: \(logo))")
            }
        }

        // ============================================
        // ✅ EVENTS ARRAY (essais, cartons, pénalités)
        // ============================================
        if let eventsArray = data["events"] as? [[String: Any]] {
            print("   📋 Events trouvés: \(eventsArray.count)")

            // Parser chaque événement
            let parsedEvents = eventsArray.compactMap { eventDict -> MatchEvent? in
                guard let type = eventDict["type"] as? String,
                      let time = eventDict["time"] as? String,
                      let team = eventDict["team"] as? String else {
                    return nil
                }

                var player: MatchEvent.EventPlayer?
                if let playerDict = eventDict["player"] as? [String: Any],
                   let playerName = playerDict["name"] as? String {
                    player = MatchEvent.EventPlayer(
                        id: playerDict["id"] as? Int,
                        name: playerName
                    )
                }

                return MatchEvent(
                    type: type,
                    time: time,
                    team: team,
                    player: player,
                    detail: eventDict["detail"] as? String
                )
            }

            // Stocker les événements parsés
            Task { @MainActor in
                self.matchEvents[String(matchId)] = parsedEvents
            }

            // Logger quelques exemples
            for event in parsedEvents.prefix(3) {
                print("      - \(event.description)")
            }

            matchData["events"] = eventsArray
        } else {
            print("   📋 Aucun événement (events vide ou absent)")
            matchData["events"] = []
        }

        // ============================================
        // ✅ EVENTS SUMMARY (compteurs)
        // ============================================
        if let summary = data["eventsSummary"] as? [String: Any] {
            let tries = summary["tries"] as? Int ?? 0
            let conversions = summary["conversions"] as? Int ?? 0
            let penalties = summary["penalties"] as? Int ?? 0
            let yellowCards = summary["yellowCards"] as? Int ?? 0
            let redCards = summary["redCards"] as? Int ?? 0
            let substitutions = summary["substitutions"] as? Int ?? 0

            print("   📊 EventsSummary:")
            print("      Essais: \(tries), Transfo: \(conversions), Pénalités: \(penalties)")
            print("      Cartons jaunes: \(yellowCards), Cartons rouges: \(redCards)")

            matchData["eventsSummary"] = [
                "tries": tries,
                "conversions": conversions,
                "penalties": penalties,
                "yellowCards": yellowCards,
                "redCards": redCards,
                "substitutions": substitutions
            ]
        } else {
            print("   📊 Pas de eventsSummary")
        }

        // ============================================
        // ✅ VENUE
        // ============================================
        if let venue = data["venue"] as? [String: Any] {
            matchData["venue"] = [
                "name": venue["name"] as Any,
                "city": venue["city"] as Any
            ]
        }

        let match = Match(from: matchData)
        print("   ✅ Parsed: \(match.homeTeamName) \(match.homeScore ?? 0) - \(match.awayScore ?? 0) \(match.awayTeamName)")
        print("   Status: \(match.status)")
        return match
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    deinit {
        listeners.values.forEach { $0.remove() }
        eventListeners.values.forEach { $0.remove() }
        print("🛑 LiveMatchListener: Listeners Firestore nettoyés")
    }
}
