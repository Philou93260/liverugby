//
//  FavoriteTeamConfigurationView.swift
//  LiveRugbyWidget
//
//  Interface de configuration pour sélectionner l'équipe favorite du widget
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct Team: Identifiable, Codable {
    let id: Int
    let name: String
    let logo: String
    let country: String?

    var displayName: String {
        if let country = country {
            return "\(name) (\(country))"
        }
        return name
    }
}

struct FavoriteTeamConfigurationView: View {
    @StateObject private var viewModel = FavoriteTeamViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.teams.isEmpty {
                    emptyStateView
                } else {
                    teamListView
                }
            }
            .navigationTitle("Équipe Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadFavoriteTeams()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Chargement...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Aucune équipe favorite")
                .font(.headline)

            Text("Ajoutez d'abord des équipes favorites dans l'application principale")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Team List

    private var teamListView: some View {
        List {
            Section {
                ForEach(viewModel.teams) { team in
                    TeamRow(
                        team: team,
                        isSelected: viewModel.selectedTeamId == team.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectTeam(team)
                    }
                }
            } header: {
                Text("Sélectionnez votre équipe")
            } footer: {
                if viewModel.selectedTeamId != nil {
                    Text("Le widget affichera le prochain match ou le match en cours de cette équipe")
                        .font(.caption)
                }
            }
        }
    }
}

// MARK: - Team Row

struct TeamRow: View {
    let team: Team
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Logo de l'équipe
            AsyncImage(url: URL(string: team.logo)) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            // Nom de l'équipe
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .font(.body)
                    .fontWeight(.medium)

                if let country = team.country {
                    Text(country)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Indicateur de sélection
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Model

class FavoriteTeamViewModel: ObservableObject {
    @Published var teams: [Team] = []
    @Published var selectedTeamId: Int?
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.liverugby.app")

    init() {
        loadSelectedTeam()
    }

    // MARK: - Load Data

    func loadFavoriteTeams() {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }

        isLoading = true

        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    print("Erreur lors du chargement des équipes favorites: \(error)")
                    return
                }

                guard let data = snapshot?.data(),
                      let favoriteTeamIds = data["favoriteTeams"] as? [Int],
                      !favoriteTeamIds.isEmpty else {
                    return
                }

                // Charger les détails des équipes
                self.fetchTeamDetails(teamIds: favoriteTeamIds)
            }
        }
    }

    private func fetchTeamDetails(teamIds: [Int]) {
        isLoading = true

        // Créer un groupe pour attendre toutes les requêtes
        let group = DispatchGroup()
        var fetchedTeams: [Team] = []

        for teamId in teamIds {
            group.enter()

            // Chercher l'équipe dans le cache Firestore
            db.collectionGroup("teams")
                .whereField("id", isEqualTo: teamId)
                .limit(to: 1)
                .getDocuments { snapshot, error in
                    defer { group.leave() }

                    if let document = snapshot?.documents.first,
                       let teamData = document.data() as? [String: Any],
                       let id = teamData["id"] as? Int,
                       let name = teamData["name"] as? String,
                       let logo = teamData["logo"] as? String {

                        let country = teamData["country"] as? String
                        let team = Team(id: id, name: name, logo: logo, country: country)
                        fetchedTeams.append(team)
                    }
                }
        }

        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            self?.teams = fetchedTeams.sorted { $0.name < $1.name }
        }
    }

    // MARK: - Selection

    private func loadSelectedTeam() {
        if let teamId = sharedDefaults?.integer(forKey: "favoriteTeamId"), teamId != 0 {
            selectedTeamId = teamId
        }
    }

    func selectTeam(_ team: Team) {
        selectedTeamId = team.id

        // Sauvegarder dans UserDefaults partagés
        sharedDefaults?.set(team.id, forKey: "favoriteTeamId")
        sharedDefaults?.set(team.name, forKey: "favoriteTeamName")
        sharedDefaults?.set(team.logo, forKey: "favoriteTeamLogo")

        // Rafraîchir le widget
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Preview

#Preview {
    FavoriteTeamConfigurationView()
}
