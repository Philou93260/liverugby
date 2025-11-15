//
//  LoginView.swift
//  LiverugbyApp
//
//  Vue de connexion avec effet Liquid Glass
//

import SwiftUI

struct LoginView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSignUpMode = false
    @State private var displayName = ""
    
    var body: some View {
        ZStack {
            // Arrière-plan animé
            AnimatedBackground()
            
            ScrollView {
                VStack(spacing: 30) {
                    Spacer()
                        .frame(height: 60)
                    
                    // Logo et titre
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 20)
                        
                        Text(isSignUpMode ? "Créer un compte" : "Connexion")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.bottom, 20)
                    
                    // Formulaire
                    VStack(spacing: 16) {
                        if isSignUpMode {
                            LiverugbyTextField(
                                placeholder: "Nom d'utilisateur",
                                text: $displayName,
                                icon: "person.fill"
                            )
                        }
                        
                        LiverugbyTextField(
                            placeholder: "Email",
                            text: $email,
                            icon: "envelope.fill"
                        )
                        
                        LiverugbyTextField(
                            placeholder: "Mot de passe",
                            text: $password,
                            isSecure: true,
                            icon: "lock.fill"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Bouton principal
                    VStack(spacing: 16) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.blue)
                        } else {
                            LiverugbyButton(
                                isSignUpMode ? "S'inscrire" : "Se connecter",
                                icon: isSignUpMode ? "person.badge.plus" : "arrow.right"
                            ) {
                                Task {
                                    await handleAuthentication()
                                }
                            }
                        }
                        
                        // Basculer entre connexion et inscription
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isSignUpMode.toggle()
                                errorMessage = ""
                                showError = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isSignUpMode ? "Déjà un compte ?" : "Pas encore de compte ?")
                                    .foregroundColor(.secondary)
                                Text(isSignUpMode ? "Se connecter" : "S'inscrire")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 15))
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func handleAuthentication() async {
        guard !email.isEmpty, !password.isEmpty else {
            showError(message: "Veuillez remplir tous les champs")
            return
        }
        
        if isSignUpMode && displayName.isEmpty {
            showError(message: "Veuillez entrer un nom d'utilisateur")
            return
        }
        
        isLoading = true
        
        do {
            if isSignUpMode {
                try await firebaseService.signUp(
                    email: email,
                    password: password,
                    displayName: displayName
                )
            } else {
                try await firebaseService.signIn(
                    email: email,
                    password: password
                )
            }
        } catch {
            showError(message: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Animated Background

struct AnimatedBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Dégradé de base
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Bulles animées
            ForEach(0..<5) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .blue.opacity(0.3),
                                .purple.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(
                        x: animate ? CGFloat.random(in: -100...100) : CGFloat.random(in: -50...50),
                        y: animate ? CGFloat.random(in: -200...200) : CGFloat.random(in: -100...100)
                    )
                    .blur(radius: 30)
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...6))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.5),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

#Preview {
    LoginView()
}
