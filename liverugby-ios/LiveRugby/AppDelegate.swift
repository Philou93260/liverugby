//
//  AppDelegate.swift
//  LiveRugby
//
//  Configuration Firebase Cloud Messaging et Notifications Push
//

import UIKit
import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        // Configurer Firebase (déjà fait dans LiverugbyApp.swift mais on s'assure)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Configurer les notifications
        setupPushNotifications(application)

        return true
    }

    // MARK: - Push Notifications Setup

    private func setupPushNotifications(_ application: UIApplication) {
        // Configurer les delegates
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Demander les permissions
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                print("✅ Notifications: Permission accordée")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("❌ Notifications: Erreur permission - \(error.localizedDescription)")
            } else {
                print("⚠️ Notifications: Permission refusée par l'utilisateur")
            }
        }
    }

    // MARK: - APNs Token Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("✅ APNs: Token device reçu")

        // Passer le token APNs à Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs: Échec d'enregistrement - \(error.localizedDescription)")
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("⚠️ FCM: Token nil")
            return
        }

        print("🔑 FCM Token reçu: \(fcmToken.prefix(20))...")

        // Sauvegarder le token localement
        UserDefaults.standard.set(fcmToken, forKey: "fcmToken")

        // Notifier que le token est disponible
        NotificationCenter.default.post(
            name: Notification.Name("FCMTokenRefreshed"),
            object: nil,
            userInfo: ["token": fcmToken]
        )

        // Enregistrer le token auprès du backend si l'utilisateur est connecté
        Task {
            await PushNotificationManager.shared.registerToken(fcmToken)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Notification reçue en foreground (app ouverte)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        print("📬 Notification reçue (foreground):")
        print(userInfo)

        // Extraire les données du match si présentes
        if let matchId = userInfo["matchId"] as? String {
            print("🏉 Match ID: \(matchId)")

            // Notifier l'app pour rafraîchir les données
            NotificationCenter.default.post(
                name: Notification.Name("MatchUpdated"),
                object: nil,
                userInfo: ["matchId": matchId]
            )
        }

        // Afficher la notification même si l'app est ouverte
        completionHandler([.banner, .sound, .badge])
    }

    // Notification cliquée par l'utilisateur
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        print("👆 Notification cliquée:")
        print(userInfo)

        // Gérer l'action selon le type de notification
        if let matchId = userInfo["matchId"] as? String {
            handleMatchNotificationTap(matchId: matchId, userInfo: userInfo)
        } else if let type = userInfo["type"] as? String {
            handleGeneralNotificationTap(type: type, userInfo: userInfo)
        }

        completionHandler()
    }

    // MARK: - Notification Handlers

    private func handleMatchNotificationTap(matchId: String, userInfo: [AnyHashable: Any]) {
        print("🏉 Navigation vers le match: \(matchId)")

        // Publier une notification pour naviguer vers les détails du match
        NotificationCenter.default.post(
            name: Notification.Name("OpenMatchDetails"),
            object: nil,
            userInfo: [
                "matchId": matchId,
                "eventType": userInfo["eventType"] as? String ?? "",
                "homeTeam": userInfo["homeTeam"] as? String ?? "",
                "awayTeam": userInfo["awayTeam"] as? String ?? ""
            ]
        )
    }

    private func handleGeneralNotificationTap(type: String, userInfo: [AnyHashable: Any]) {
        print("📱 Navigation générale: \(type)")

        NotificationCenter.default.post(
            name: Notification.Name("HandleNotification"),
            object: nil,
            userInfo: ["type": type, "data": userInfo]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let fcmTokenRefreshed = Notification.Name("FCMTokenRefreshed")
    static let matchUpdated = Notification.Name("MatchUpdated")
    static let openMatchDetails = Notification.Name("OpenMatchDetails")
    static let handleNotification = Notification.Name("HandleNotification")
}
