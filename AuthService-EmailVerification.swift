import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Service d'authentification avec nickname et email de confirmation

class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isEmailVerified: Bool = false

    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    init() {
        // Vérifier l'utilisateur courant
        self.user = auth.currentUser
        self.isEmailVerified = auth.currentUser?.isEmailVerified ?? false
    }

    /// Inscription avec nickname, email et mot de passe
    func signUp(email: String, password: String, nickname: String) async throws {
        do {
            // 1. Créer le compte Firebase Auth
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let user = authResult.user

            print("✅ Compte créé: \(user.uid)")

            // 2. Mettre à jour le displayName (nickname)
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = nickname
            try await changeRequest.commitChanges()

            print("✅ Nickname défini: \(nickname)")

            // 3. Envoyer l'email de vérification
            try await user.sendEmailVerification()

            print("✅ Email de vérification envoyé à: \(email)")

            // 4. Mettre à jour le profil Firestore (sera fait automatiquement par le trigger createUserProfile)
            // Mais on peut forcer le nickname ici si besoin
            try await db.collection("users").document(user.uid).setData([
                "uid": user.uid,
                "email": email,
                "displayName": nickname,
                "emailVerified": false,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)

            self.user = user
            self.isEmailVerified = false

        } catch {
            print("❌ Erreur inscription: \(error.localizedDescription)")
            throw error
        }
    }

    /// Connexion classique
    func signIn(email: String, password: String) async throws {
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            self.user = authResult.user
            self.isEmailVerified = authResult.user.isEmailVerified

            // Mettre à jour le statut de vérification dans Firestore
            if authResult.user.isEmailVerified {
                try await db.collection("users").document(authResult.user.uid).updateData([
                    "emailVerified": true
                ])
            }

            print("✅ Connexion réussie: \(authResult.user.email ?? "")")
            print("   Email vérifié: \(authResult.user.isEmailVerified)")

        } catch {
            print("❌ Erreur connexion: \(error.localizedDescription)")
            throw error
        }
    }

    /// Renvoyer l'email de vérification
    func resendVerificationEmail() async throws {
        guard let user = auth.currentUser else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Aucun utilisateur connecté"])
        }

        try await user.sendEmailVerification()
        print("✅ Email de vérification renvoyé")
    }

    /// Vérifier si l'email a été vérifié
    func checkEmailVerification() async throws {
        guard let user = auth.currentUser else { return }

        // Recharger les données de l'utilisateur depuis Firebase
        try await user.reload()

        self.isEmailVerified = user.isEmailVerified

        if user.isEmailVerified {
            // Mettre à jour Firestore
            try await db.collection("users").document(user.uid).updateData([
                "emailVerified": true
            ])
            print("✅ Email vérifié !")
        }
    }

    /// Déconnexion
    func signOut() throws {
        try auth.signOut()
        self.user = nil
        self.isEmailVerified = false
        print("✅ Déconnexion réussie")
    }
}

// MARK: - Vue d'inscription

struct SignUpView: View {
    @StateObject private var authService = AuthService()

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var nickname = ""

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showEmailVerification = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Inscription")
                .font(.largeTitle)
                .bold()

            // Nickname
            TextField("Pseudo", text: $nickname)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)

            // Email
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            // Mot de passe
            SecureField("Mot de passe", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            // Confirmation mot de passe
            SecureField("Confirmer le mot de passe", text: $confirmPassword)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            // Bouton inscription
            Button(action: handleSignUp) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("S'inscrire")
                        .bold()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isLoading || !isFormValid)

            Spacer()
        }
        .padding()
        .alert("Inscription", isPresented: $showAlert) {
            Button("OK") {
                if showEmailVerification {
                    // Afficher la vue de vérification d'email
                }
            }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showEmailVerification) {
            EmailVerificationView(authService: authService, email: email)
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !nickname.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        email.contains("@")
    }

    private func handleSignUp() {
        guard isFormValid else { return }

        isLoading = true

        Task {
            do {
                try await authService.signUp(email: email, password: password, nickname: nickname)

                await MainActor.run {
                    isLoading = false
                    alertMessage = "Compte créé avec succès ! Un email de vérification a été envoyé à \(email). Veuillez vérifier votre boîte mail."
                    showAlert = true
                    showEmailVerification = true
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Erreur : \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Vue de vérification d'email

struct EmailVerificationView: View {
    @ObservedObject var authService: AuthService
    let email: String

    @State private var isChecking = false
    @State private var showResendButton = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.blue)

            Text("Vérifiez votre email")
                .font(.title)
                .bold()

            Text("Un email de vérification a été envoyé à :")
                .multilineTextAlignment(.center)

            Text(email)
                .bold()
                .foregroundColor(.blue)

            Text("Cliquez sur le lien dans l'email pour activer votre compte.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()

            // Bouton vérifier
            Button(action: checkVerification) {
                if isChecking {
                    ProgressView()
                } else {
                    Text("J'ai vérifié mon email")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isChecking)

            // Bouton renvoyer
            if showResendButton {
                Button(action: resendEmail) {
                    Text("Renvoyer l'email")
                        .foregroundColor(.blue)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func checkVerification() {
        isChecking = true

        Task {
            do {
                try await authService.checkEmailVerification()

                await MainActor.run {
                    isChecking = false

                    if authService.isEmailVerified {
                        // Email vérifié, fermer la vue
                        dismiss()
                    } else {
                        // Pas encore vérifié
                        // Afficher un message
                    }
                }

            } catch {
                await MainActor.run {
                    isChecking = false
                }
            }
        }
    }

    private func resendEmail() {
        Task {
            do {
                try await authService.resendVerificationEmail()

                await MainActor.run {
                    showResendButton = false

                    // Réactiver après 60 secondes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                        showResendButton = true
                    }
                }

            } catch {
                print("Erreur renvoi email:", error)
            }
        }
    }
}
