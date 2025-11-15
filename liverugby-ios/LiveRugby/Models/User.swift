//
//  User.swift
//  LiverugbyApp
//
//  Modèle de données utilisateur
//

import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var uid: String
    var email: String
    var displayName: String
    var photoURL: String?
    var createdAt: Date
    var isPublic: Bool
    var settings: UserSettings
    
    struct UserSettings: Codable {
        var notifications: Bool
        var theme: String
        
        init(notifications: Bool = true, theme: String = "auto") {
            self.notifications = notifications
            self.theme = theme
        }
    }
    
    init(uid: String, email: String, displayName: String = "", photoURL: String? = nil) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.createdAt = Date()
        self.isPublic = false
        self.settings = UserSettings()
    }
}
