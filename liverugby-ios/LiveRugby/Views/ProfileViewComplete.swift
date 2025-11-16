//
//  ProfileViewComplete.swift
//  LiverugbyApp
//
//  Version complète et commentée de ProfileView avec toutes les fonctionnalités
//

import SwiftUI
import FirebaseAuth

// MARK: - Vue Profil principale

struct ProfileViewComplete: View {
    // MARK: - Properties
    
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    private enum ActiveSheet: Identifiable {
        case settings, favorites, notifications, about
        var id: Int {
            switch self {
            case .settings: return 0
            case .favorites: return 1
            case .notifications: return 2
            case .about: return 3
            }
        }
    }
    @State private var activeSheet: ActiveSheet?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fond de l'écran
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - Photo de profil
                        profileImage
                            .padding(.top, 20)
                        
                        // MARK: - Informations utilisateur
                        userInfo
                        
                        // MARK: - Séparateur
                        Divider()
                            .padding(.horizontal, 40)
                            .padding(.vertical, 8)
                        
                        // MARK: - Menu items
                        menuItems
                            .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Profil")
            
            // MARK: - Sheet (modal) unique avec enum
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .settings:
                    LiverugbyParametreView()
                case .favorites:
                    FavoriteTeamsViewPlaceholder()
                case .notifications:
                    NotificationsSettingsPlaceholder()
                case .about:
                    AboutViewPlaceholder()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    /// Photo de profil avec émoji
    private var profileImage: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
            Text("👤")
                .font(.system(size: 60))
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Photo de profil")
    }
    
    /// Informations de l'utilisateur
    private var userInfo: some View {
        VStack(spacing: 8) {
            // Nickname (nom d'affichage)
            Text(firebaseService.currentUser?.displayName ?? "Utilisateur")
                .font(.title)
                .fontWeight(.bold)
            
            // Email masqué
            if let email = firebaseService.currentUser?.email {
                Text(maskEmail(email))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Menu items du profil
    private var menuItems: some View {
        VStack(spacing: 12) {
            // Paramètres
            Button {
                activeSheet = .settings
            } label: {
                ProfileMenuItem(
                    icon: "gear",
                    title: "Paramètres",
                    color: .gray
                )
                .accessibilityLabel("Paramètres")
            }
            .profileMenuStyle()
            
            // Équipes favorites
            Button {
                activeSheet = .favorites
            } label: {
                ProfileMenuItem(
                    icon: "star.fill",
                    title: "Mes équipes favorites",
                    color: .orange
                )
                .accessibilityLabel("Mes équipes favorites")
            }
            .profileMenuStyle()
            
            // Notifications
            Button {
                activeSheet = .notifications
            } label: {
                ProfileMenuItem(
                    icon: "bell.fill",
                    title: "Notifications",
                    color: .blue
                )
                .accessibilityLabel("Notifications")
            }
            .profileMenuStyle()
            
            // À propos
            Button {
                activeSheet = .about
            } label: {
                ProfileMenuItem(
                    icon: "info.circle",
                    title: "À propos",
                    color: .green
                )
                .accessibilityLabel("À propos")
            }
            .profileMenuStyle()
        }
    }
    
    // MARK: - Helper Functions
    
    /// Masque l'email pour la confidentialité
    /// Exemple: john.doe@gmail.com → joh***@gmail.com
    private func maskEmail(_ email: String) -> String {
        let components = email.split(separator: "@")
        guard components.count == 2 else { return email }
        
        let username = String(components[0])
        let domain = String(components[1])
        
        if username.count <= 3 {
            return "\(username.prefix(1))***@\(domain)"
        } else {
            let visibleChars = username.prefix(3)
            return "\(visibleChars)***@\(domain)"
        }
    }
}

// MARK: - Placeholder Views (à implémenter)

struct FavoriteTeamsViewPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Mes équipes favorites")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Cette fonctionnalité sera bientôt disponible !")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Équipes favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                }
            }
        }
    }
}

struct NotificationsSettingsPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Paramètres de notifications")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Cette fonctionnalité sera bientôt disponible !")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                }
            }
        }
    }
}

struct AboutViewPlaceholder: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo de l'app
                        VStack(spacing: 16) {
                            // Logo de l'application (agrandi)
                            // Option 1: Si vous avez une image "AppLogo" dans vos Assets
                            if let logoImage = UIImage(named: "AppLogo") {
                                Image(uiImage: logoImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 33.33, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 33.33, style: .continuous)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
                                    .padding(.top, 30)
                            } else {
                                // Fallback: Logo temporaire avec emoji
                                ZStack {
                                    RoundedRectangle(cornerRadius: 33.33, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .blue.opacity(0.7)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 150, height: 150)
                                        .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
                                    
                                    Text("🏉")
                                        .font(.system(size: 75))
                                }
                                .padding(.top, 30)
                            }
                            
                            // Version
                            Text("Version 1.5")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        }
                        
                        Divider()
                            .padding(.horizontal, 40)
                        
                        // Description
                        VStack(spacing: 12) {
                            Text("🏉 Suivez tous les matchs de rugby en direct")
                                .font(.body)
                                .multilineTextAlignment(.center)
                            
                            Text("Top 14 • Équipe de France • Tournoi des 6 Nations")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 30)
                        
                        Divider()
                            .padding(.horizontal, 40)
                        
                        // Fonctionnalités
                        VStack(alignment: .leading, spacing: 16) {
                            FeatureRow(icon: "dot.radiowaves.left.and.right", title: "Scores en direct", color: .red)
                            FeatureRow(icon: "calendar", title: "Calendrier des matchs", color: .blue)
                            FeatureRow(icon: "chart.bar.fill", title: "Classements", color: .green)
                            FeatureRow(icon: "bell.badge", title: "Live Activities", color: .orange)
                        }
                        .padding(.horizontal, 30)
                        
                        Divider()
                            .padding(.horizontal, 40)
                        
                        // Copyright
                        VStack(spacing: 8) {
                            Text("© Copyright 2025 Philou93")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            
                            Text("Tous droits réservés")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("À propos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Profil complet") {
    ProfileViewComplete()
}

#Preview("Équipes favorites") {
    FavoriteTeamsViewPlaceholder()
}

#Preview("Notifications") {
    NotificationsSettingsPlaceholder()
}

#Preview("À propos") {
    AboutViewPlaceholder()
}

// MARK: - Extensions utiles

extension View {
    /// Applique un style de bouton personnalisé pour les menu items
    func profileMenuStyle() -> some View {
        self
            .buttonStyle(.plain)
    }
}

// MARK: - Couleurs partagées
extension Color {
    static let appBackground = Color(red: 0.95, green: 0.95, blue: 0.97)
}

// MARK: - UserDefaults Keys

enum UserDefaultsKeys {
    static let liveActivitiesEnabled = "liveActivitiesEnabled"
    static let notificationsEnabled = "notificationsEnabled"
    static let appTheme = "appTheme"
}

// MARK: - Exemple d'utilisation avec UserDefaults

extension ProfileViewComplete {
    /// Récupérer les préférences de l'utilisateur
    static func getUserPreferences() -> [String: Any] {
        return [
            "liveActivitiesEnabled": UserDefaults.standard.bool(forKey: UserDefaultsKeys.liveActivitiesEnabled),
            "notificationsEnabled": UserDefaults.standard.bool(forKey: UserDefaultsKeys.notificationsEnabled),
            "appTheme": UserDefaults.standard.string(forKey: UserDefaultsKeys.appTheme) ?? "auto"
        ]
    }
    
    /// Sauvegarder une préférence
    static func savePreference(key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

// MARK: - Exemple d'intégration avec LiveActivityManager

@available(iOS 16.2, *)
extension ProfileViewComplete {
    /// Vérifie si les Live Activities sont activées dans les préférences utilisateur
    static func canUseLiveActivities() -> Bool {
        // Vérifier les préférences utilisateur
        let notificationsEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.notificationsEnabled)
        let liveActivitiesEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.liveActivitiesEnabled)
        
        return notificationsEnabled && liveActivitiesEnabled
    }
    
    /// Affiche un message d'état des Live Activities
    static func getLiveActivitiesStatus() -> String {
        let notificationsEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.notificationsEnabled)
        let liveActivitiesEnabled = UserDefaults.standard.bool(forKey: UserDefaultsKeys.liveActivitiesEnabled)
        
        if !notificationsEnabled {
            return "❌ Notifications désactivées"
        } else if !liveActivitiesEnabled {
            return "❌ Live Activities désactivées"
        } else {
            return "✅ Activées et prêtes"
        }
    }
}

