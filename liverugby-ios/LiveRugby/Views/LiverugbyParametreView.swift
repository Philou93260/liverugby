//
//  LiverugbyParametreView.swift
//  LiverugbyApp
//
//  Page de paramètres de l'application
//

import SwiftUI
import ActivityKit
import UserNotifications

struct LiverugbyParametreView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseService = FirebaseService.shared
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showingSignOutAlert = false
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingNotificationSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Liste des paramètres
                    List {
                        // Section Compte
                        Section {
                            HStack {
                                Text("Email")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(firebaseService.currentUser?.email ?? "")
                                    .foregroundColor(.primary)
                                    .font(.body)
                            }
                            .background(Color(.systemBackground))
                        } header: {
                            Text("Compte")
                                .background(Color(.secondarySystemBackground))
                        }
                        
                        // Section Notifications
                        Section {
                            // Toggle Notifications générales
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: $notificationsEnabled) {
                                    HStack {
                                        Image(systemName: "bell.fill")
                                            .foregroundColor(.orange)
                                            .frame(width: 24)
                                        Text("Notifications")
                                    }
                                }
                                .tint(.green)
                                .onChange(of: notificationsEnabled) { _, newValue in
                                    handleNotificationToggle(newValue)
                                }
                                
                                // Statut des autorisations système
                                notificationStatusView
                            }
                            .background(Color(.systemBackground))
                            
                            // Toggle Live Activities
                            Toggle(isOn: $liveActivitiesEnabled) {
                                HStack {
                                    Image(systemName: "app.badge")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("Live Activities")
                                }
                            }
                            .tint(.green)
                            .disabled(!notificationsEnabled)
                            .opacity(notificationsEnabled ? 1.0 : 0.5)
                        } header: {
                            Text("Notifications")
                                .background(Color(.secondarySystemBackground))
                        } footer: {
                            Text("Recevez des notifications pour les matchs en direct, les résultats et les actualités. Les Live Activities permettent de suivre les scores en temps réel sur votre écran verrouillé.")
                                .background(Color(.secondarySystemBackground))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    
                    // Bouton de déconnexion en bas
                    VStack(spacing: 16) {
                        Button {
                            showingSignOutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.headline)
                                Text("Se déconnecter")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.red)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Paramètres")
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
            .alert("Déconnexion", isPresented: $showingSignOutAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Se déconnecter", role: .destructive) {
                    Task {
                        try? firebaseService.signOut()
                    }
                }
            } message: {
                Text("Êtes-vous sûr de vouloir vous déconnecter ?")
            }
            .alert("Notifications désactivées", isPresented: $showingNotificationSettings) {
                Button("Ouvrir Réglages", role: .none) {
                    openNotificationSettings()
                }
                Button("Annuler", role: .cancel) {
                    notificationsEnabled = false
                }
            } message: {
                Text("Les notifications sont désactivées dans les réglages de votre iPhone. Voulez-vous ouvrir les réglages pour les activer ?")
            }
            .task {
                await checkNotificationStatus()
            }
        }
    }
    
    // MARK: - Notification Status View
    
    @ViewBuilder
    private var notificationStatusView: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.caption2)
                .foregroundColor(statusColor)
            
            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
            
            if notificationAuthorizationStatus == .denied {
                Button {
                    openNotificationSettings()
                } label: {
                    Text("Ouvrir Réglages")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
    
    private var statusIcon: String {
        switch notificationAuthorizationStatus {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .provisional:
            return "checkmark.circle"
        case .ephemeral:
            return "checkmark.circle"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    private var statusText: String {
        switch notificationAuthorizationStatus {
        case .authorized:
            return "Autorisées dans les réglages système"
        case .denied:
            return "Désactivées dans les réglages système"
        case .notDetermined:
            return "Autorisation non demandée"
        case .provisional:
            return "Autorisées (provisoires)"
        case .ephemeral:
            return "Autorisées (temporaires)"
        @unknown default:
            return "Statut inconnu"
        }
    }
    
    // MARK: - Helper Methods
    
    /// Vérifie le statut des autorisations de notifications
    private func checkNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        notificationAuthorizationStatus = settings.authorizationStatus
        
        // Synchroniser le toggle avec le statut système
        if settings.authorizationStatus == .denied {
            notificationsEnabled = false
        }
    }
    
    /// Gère le changement du toggle de notifications
    private func handleNotificationToggle(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                // Demander l'autorisation si pas encore fait
                await requestNotificationAuthorization()
            } else {
                // L'utilisateur désactive les notifications dans l'app
                // Note: On ne peut pas désactiver les notifications système depuis l'app
                print("📱 Notifications désactivées dans l'app")
            }
        }
    }
    
    /// Demande l'autorisation pour les notifications
    private func requestNotificationAuthorization() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            // Mettre à jour le statut
            await checkNotificationStatus()
            
            if !granted {
                // L'utilisateur a refusé
                await MainActor.run {
                    notificationsEnabled = false
                    showingNotificationSettings = true
                }
            } else {
                print("✅ Notifications autorisées")
            }
        } catch {
            print("❌ Erreur lors de la demande d'autorisation: \(error)")
            await MainActor.run {
                notificationsEnabled = false
            }
        }
    }
    
    /// Ouvre les réglages système pour les notifications
    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Task { @MainActor in
                await UIApplication.shared.open(url)
            }
        }
    }
}

#Preview {
    LiverugbyParametreView()
}
