//
//  PushNotificationManager.swift
//  LiveRugby
//
//  Gestionnaire des notifications push et abonnements aux matchs
//

import Foundation
import FirebaseAuth
import FirebaseFunctions
import FirebaseMessaging
import UIKit

@MainActor
class PushNotificationManager: ObservableObject {
    static let shared = PushNotificationManager()

    @Published var isRegistered = false
    @Published var currentToken: String?

    private let functions: Functions
    private var tokenObserver: NSObjectProtocol?

    private init() {
        // Utiliser la région europe-west1 configurée dans le backend
        functions = Functions.functions(region: "europe-west1")

        // Observer les changements de token
        setupTokenObserver()

        // Récupérer le token actuel si disponible
        if let savedToken = UserDefaults.standard.string(forKey: "fcmToken") {
            currentToken = savedToken
        }
    }

    // MARK: - Token Management

    private func setupTokenObserver() {
        tokenObserver = NotificationCenter.default.addObserver(
            forName: .fcmTokenRefreshed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.userInfo?["token"] as? String else { return }
            self?.currentToken = token
            Task {
                await self?.registerToken(token)
            }
        }
    }

    /// Enregistrer le token FCM auprès du backend
    func registerToken(_ token: String? = nil) async {
        // Utiliser le token fourni ou le token actuel
        let fcmToken = token ?? currentToken ?? UserDefaults.standard.string(forKey: "fcmToken")

        guard let fcmToken = fcmToken else {
            print("⚠️ Aucun token FCM disponible")
            return
        }

        // Vérifier que l'utilisateur est connecté
        guard Auth.auth().currentUser != nil else {
            print("⚠️ Utilisateur non connecté, enregistrement du token différé")
            return
        }

        do {
            print("📤 Enregistrement du token FCM...")

            let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? ""

            let result = try await functions.httpsCallable("registerFCMToken").call([
                "token": fcmToken,
                "platform": "ios",
                "deviceId": deviceId
            ])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                isRegistered = true
                currentToken = fcmToken
                print("✅ Token FCM enregistré avec succès")
            } else {
                print("❌ Échec d'enregistrement du token")
            }
        } catch {
            print("❌ Erreur lors de l'enregistrement du token: \(error.localizedDescription)")
        }
    }

    /// Désactiver le token FCM
    func unregisterToken() async {
        guard let fcmToken = currentToken else {
            print("⚠️ Aucun token à désactiver")
            return
        }

        do {
            print("📤 Désactivation du token FCM...")

            let result = try await functions.httpsCallable("unregisterFCMToken").call([
                "token": fcmToken
            ])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                isRegistered = false
                print("✅ Token FCM désactivé avec succès")
            }
        } catch {
            print("❌ Erreur lors de la désactivation du token: \(error.localizedDescription)")
        }
    }

    // MARK: - Match Subscriptions

    /// S'abonner aux notifications d'un match
    func subscribeToMatch(
        matchId: Int,
        eventTypes: [String]? = nil
    ) async throws {
        let defaultEventTypes = eventTypes ?? [
            "match_starting",
            "match_started",
            "score_update",
            "halftime",
            "match_ended"
        ]

        do {
            print("📤 Abonnement au match \(matchId)...")

            let result = try await functions.httpsCallable("subscribeToMatch").call([
                "matchId": matchId,
                "eventTypes": defaultEventTypes
            ])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                print("✅ Abonné au match \(matchId)")
            } else {
                throw PushNotificationError.subscriptionFailed
            }
        } catch {
            print("❌ Erreur abonnement match: \(error.localizedDescription)")
            throw error
        }
    }

    /// Se désabonner des notifications d'un match
    func unsubscribeFromMatch(matchId: Int) async throws {
        do {
            print("📤 Désabonnement du match \(matchId)...")

            let result = try await functions.httpsCallable("unsubscribeFromMatch").call([
                "matchId": matchId
            ])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                print("✅ Désabonné du match \(matchId)")
            } else {
                throw PushNotificationError.unsubscriptionFailed
            }
        } catch {
            print("❌ Erreur désabonnement match: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Favorite Teams

    /// Ajouter une équipe aux favoris avec notifications
    func addFavoriteTeam(
        teamId: Int,
        teamName: String,
        teamLogo: String? = nil,
        notifyMatches: Bool = true
    ) async throws {
        do {
            print("📤 Ajout équipe favorite: \(teamName)...")

            let result = try await functions.httpsCallable("addFavoriteTeam").call([
                "teamId": teamId,
                "teamName": teamName,
                "teamLogo": teamLogo ?? "",
                "notifyMatches": notifyMatches
            ])

            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                print("✅ Équipe favorite ajoutée: \(teamName)")
            } else {
                throw PushNotificationError.favoriteFailed
            }
        } catch {
            print("❌ Erreur ajout favori: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Permissions

    /// Vérifier le statut des permissions de notification
    func checkNotificationPermission() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// Demander les permissions de notification
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            if granted {
                print("✅ Permission notifications accordée")
                await UIApplication.shared.registerForRemoteNotifications()
            } else {
                print("❌ Permission notifications refusée")
            }

            return granted
        } catch {
            print("❌ Erreur demande permission: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Badge Management

    /// Mettre à jour le badge de l'app
    func updateBadge(count: Int) async {
        await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    /// Réinitialiser le badge
    func resetBadge() async {
        await UNUserNotificationCenter.current().setBadgeCount(0)
    }

    deinit {
        if let observer = tokenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Errors

enum PushNotificationError: LocalizedError {
    case tokenNotAvailable
    case subscriptionFailed
    case unsubscriptionFailed
    case favoriteFailed

    var errorDescription: String? {
        switch self {
        case .tokenNotAvailable:
            return "Token FCM non disponible"
        case .subscriptionFailed:
            return "Échec de l'abonnement"
        case .unsubscriptionFailed:
            return "Échec du désabonnement"
        case .favoriteFailed:
            return "Échec de l'ajout aux favoris"
        }
    }
}

// MARK: - UIApplication Extension

extension UIApplication {
    @MainActor
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
