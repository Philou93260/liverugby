//
//  ProfilePreview.swift
//  LiverugbyApp
//
//  Prévisualisation de l'onglet Profil et des Paramètres
//

import SwiftUI

#Preview("Profil complet") {
    NavigationStack {
        ProfileView_Mock()
    }
}

#Preview("Paramètres") {
    LiverugbyParametreView()
}

// MARK: - Mock Views pour tester sans Firebase

struct ProfileView_Mock: View {
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Photo de profil avec émoji
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
                        }
                        .padding(.top, 20)
                        
                        // Nom d'utilisateur (nickname)
                        VStack(spacing: 8) {
                            Text("Jean Dupont")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("jea***@gmail.com")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .padding(.horizontal, 40)
                            .padding(.vertical, 8)
                        
                        // Options du profil
                        VStack(spacing: 12) {
                            Button {
                                showingSettings = true
                            } label: {
                                ProfileMenuItem_Mock(
                                    icon: "gear",
                                    title: "Paramètres",
                                    color: .gray
                                )
                            }
                            
                            ProfileMenuItem_Mock(
                                icon: "star.fill",
                                title: "Mes équipes favorites",
                                color: .orange
                            )
                            
                            ProfileMenuItem_Mock(
                                icon: "bell.fill",
                                title: "Notifications",
                                color: .blue
                            )
                            
                            ProfileMenuItem_Mock(
                                icon: "info.circle",
                                title: "À propos",
                                color: .green
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Profil")
            .sheet(isPresented: $showingSettings) {
                LiverugbyParametreView_Mock()
            }
        }
    }
}

struct ProfileMenuItem_Mock: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct LiverugbyParametreView_Mock: View {
    @Environment(\.dismiss) private var dismiss
    @State private var liveActivitiesEnabled = true
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.97)
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
                                Text("jean.dupont@gmail.com")
                                    .foregroundColor(.primary)
                                    .font(.body)
                            }
                        } header: {
                            Text("Compte")
                        }
                        
                        // Section Notifications
                        Section {
                            Toggle(isOn: $liveActivitiesEnabled) {
                                HStack {
                                    Image(systemName: "app.badge")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("Live Activities")
                                }
                            }
                            .tint(.green)
                        } header: {
                            Text("Notifications")
                        } footer: {
                            Text("Activez les Live Activities pour suivre les scores en temps réel sur votre écran verrouillé et dans la Dynamic Island.")
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
                    // Action de déconnexion
                    dismiss()
                }
            } message: {
                Text("Êtes-vous sûr de vouloir vous déconnecter ?")
            }
        }
    }
}

#Preview("Profil (Mock)") {
    ProfileView_Mock()
}

#Preview("Paramètres (Mock)") {
    LiverugbyParametreView_Mock()
}
