//
//  WidgetIntegrationExamples.swift
//  LiveRugby
//
//  Exemples d'intégration du widget dans l'application principale
//

import SwiftUI
import WidgetKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Example 1: Settings View avec Configuration Widget

struct WidgetSettingsView: View {
    @State private var showTeamSelection = false
    @State private var selectedTeam: Team?

    var body: some View {
        List {
            Section {
                // Afficher l'équipe actuellement configurée
                if let team = loadCurrentWidgetTeam() {
                    HStack {
                        AsyncImage(url: URL(string: team.logo)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                        VStack(alignment: .leading) {
                            Text(team.name)
                                .font(.headline)
                            Text("Équipe du widget")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Modifier") {
                            showTeamSelection = true
                        }
                    }
                } else {
                    Button(action: {
                        showTeamSelection = true
                    }) {
                        HStack {
                            Image(systemName: "square.stack.3d.up")
                            Text("Configurer le widget")
                        }
                    }
                }
            } header: {
                Text("Widget Match en Direct")
            } footer: {
                Text("Le widget affichera le prochain match ou le match en cours de cette équipe sur votre écran d'accueil")
            }

            Section {
                Button(action: {
                    refreshWidget()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Rafraîchir le widget")
                    }
                }
            } footer: {
                Text("Force le rafraîchissement immédiat du widget")
            }
        }
        .navigationTitle("Widget")
        .sheet(isPresented: $showTeamSelection) {
            FavoriteTeamConfigurationView()
        }
    }

    private func loadCurrentWidgetTeam() -> Team? {
        let sharedDefaults = UserDefaults(suiteName: "group.com.liverugby.app")
        guard let teamId = sharedDefaults?.integer(forKey: "favoriteTeamId"),
              teamId != 0,
              let name = sharedDefaults?.string(forKey: "favoriteTeamName"),
              let logo = sharedDefaults?.string(forKey: "favoriteTeamLogo") else {
            return nil
        }
        return Team(id: teamId, name: name, logo: logo, country: nil)
    }

    private func refreshWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Example 2: Sélection d'Équipe avec Mise à Jour Widget

struct TeamSelectionView: View {
    let teams: [Team]
    @Binding var selectedTeamId: Int?

    var body: some View {
        List(teams) { team in
            Button(action: {
                selectTeamForWidget(team)
            }) {
                HStack {
                    AsyncImage(url: URL(string: team.logo)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    Text(team.name)

                    Spacer()

                    if selectedTeamId == team.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }

    private func selectTeamForWidget(_ team: Team) {
        selectedTeamId = team.id

        // Sauvegarder dans Firestore
        saveToFirestore(team)

        // Sauvegarder dans UserDefaults partagés pour le widget
        saveToSharedDefaults(team)

        // Rafraîchir le widget
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveToFirestore(_ team: Team) {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let db = Firestore.firestore()
        db.collection("users").document(userId).updateData([
            "favoriteTeams": FieldValue.arrayUnion([team.id])
        ])
    }

    private func saveToSharedDefaults(_ team: Team) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.liverugby.app")
        sharedDefaults?.set(team.id, forKey: "favoriteTeamId")
        sharedDefaults?.set(team.name, forKey: "favoriteTeamName")
        sharedDefaults?.set(team.logo, forKey: "favoriteTeamLogo")
    }
}

// MARK: - Example 3: Banner pour Encourager l'Ajout du Widget

struct WidgetPromoBanner: View {
    @State private var showWidgetSetup = false
    @AppStorage("hasConfiguredWidget") private var hasConfiguredWidget = false

    var body: some View {
        if !hasConfiguredWidget {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nouveau Widget !")
                            .font(.headline)
                        Text("Suivez vos matchs sur l'écran d'accueil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Button(action: {
                    showWidgetSetup = true
                }) {
                    Text("Configurer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
            .padding()
            .sheet(isPresented: $showWidgetSetup) {
                WidgetSetupFlow()
            }
        }
    }
}

// MARK: - Example 4: Flow Complet de Configuration

struct WidgetSetupFlow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WidgetSetupViewModel()
    @State private var currentStep = 0

    var body: some View {
        NavigationView {
            VStack {
                if currentStep == 0 {
                    welcomeStep
                } else if currentStep == 1 {
                    teamSelectionStep
                } else {
                    completionStep
                }
            }
            .navigationTitle("Configuration Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }

    // Étape 1: Bienvenue
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Widget Match en Direct")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Suivez les matchs de votre équipe favorite directement depuis votre écran d'accueil")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "sportscourt.fill", text: "Scores en temps réel")
                FeatureRow(icon: "clock.fill", text: "Statut du match (1H, 2H, FT)")
                FeatureRow(icon: "star.fill", text: "Votre équipe favorite")
            }
            .padding()

            Spacer()

            Button(action: {
                withAnimation {
                    currentStep = 1
                }
            }) {
                Text("Commencer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }

    // Étape 2: Sélection d'équipe
    private var teamSelectionStep: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                FavoriteTeamConfigurationView()
            }

            Button(action: {
                withAnimation {
                    currentStep = 2
                }
            }) {
                Text("Continuer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
        .onAppear {
            viewModel.loadTeams()
        }
    }

    // Étape 3: Complétion
    private var completionStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Configuration terminée !")
                .font(.title2)
                .fontWeight(.bold)

            Text("Votre widget est prêt. Ajoutez-le à votre écran d'accueil :")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "Maintenez appuyé sur votre écran d'accueil")
                InstructionRow(number: 2, text: "Touchez le bouton + en haut à gauche")
                InstructionRow(number: 3, text: "Cherchez \"Live Rugby\"")
                InstructionRow(number: 4, text: "Ajoutez le widget Match en Direct")
            }
            .padding()

            Spacer()

            Button(action: {
                UserDefaults.standard.set(true, forKey: "hasConfiguredWidget")
                dismiss()
            }) {
                Text("Terminer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
        .padding()
    }
}

// MARK: - Helper Views

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.blue))

            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - View Model

class WidgetSetupViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var teams: [Team] = []

    func loadTeams() {
        isLoading = true
        // Charger les équipes depuis Firestore
        // (utiliser le même code que FavoriteTeamConfigurationView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
        }
    }
}

// MARK: - Example 5: Deep Link pour Ouvrir la Configuration

extension View {
    func handleWidgetDeepLink() -> some View {
        self.onOpenURL { url in
            if url.scheme == "liverugby" && url.host == "widget" && url.path == "/configure" {
                // Ouvrir la configuration du widget
                NotificationCenter.default.post(name: .openWidgetConfiguration, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let openWidgetConfiguration = Notification.Name("openWidgetConfiguration")
}

// MARK: - Example 6: Widget Preview dans l'App

struct WidgetPreviewView: View {
    let matchData: WidgetMatchData?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aperçu du Widget")
                .font(.headline)

            if let match = matchData {
                // Simuler l'apparence du widget small
                VStack(spacing: 8) {
                    // Header
                    HStack {
                        Text(match.league)
                            .font(.caption)
                        Spacer()
                        Text(match.status.rawValue)
                            .font(.caption)
                            .foregroundColor(match.status.isLive ? .red : .secondary)
                    }

                    // Teams
                    teamPreviewRow(match.homeTeam, isFavorite: true)
                    teamPreviewRow(match.awayTeam, isFavorite: false)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            } else {
                Text("Aucun match à afficher")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func teamPreviewRow(_ team: TeamData, isFavorite: Bool) -> some View {
        HStack {
            AsyncImage(url: URL(string: team.logo)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())

            Text(team.name)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Text("\(team.score ?? 0)")
                .font(.title3)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Preview

#Preview {
    WidgetSettingsView()
}
