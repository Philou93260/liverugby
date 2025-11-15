//
//  HomeView.swift
//  LiverugbyApp
//
//  Vue principale avec 4 onglets redesignés
//

import SwiftUI

// MARK: - Tabs (HomeView)
struct HomeView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    var body: some View {
        TabView {
            LiveMatchesView()
                .tabItem {
                    Label("En direct", systemImage: "dot.radiowaves.left.and.right")
                }
            
            UpcomingMatchesView()
                .tabItem {
                    Label("Calendrier", systemImage: "calendar")
                }
            
            StandingsView()
                .tabItem {
                    Label("Classement", systemImage: "chart.bar.fill")
                }
            
            ProfileViewComplete()
                .tabItem {
                    Label("Profil", systemImage: "person.circle")
                }
        }
        .accentColor(.blue)
    }
}

// MARK: - Tab 1: En direct

struct LiveMatchesView: View {
    @StateObject private var rugbyService = RugbyService.shared
    @State private var matches: [Match] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLeague: RugbyLeague = .top14
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    LeagueSelector(selectedLeague: $selectedLeague)
                        .padding(.vertical, 12)
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Chargement...")
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        ErrorView(message: error) {
                            Task { await loadMatches() }
                        }
                        Spacer()
                    } else if matches.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "antenna.radiowaves.left.and.right.slash",
                            title: "Aucun match en direct",
                            subtitle: "Consultez le calendrier des prochains matchs"
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(matches) { match in
                                    LiveMatchCard(match: match)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                        .refreshable {
                            await loadMatches()
                        }
                    }
                }
            }
            .navigationTitle("En direct 🔴")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadMatches() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadMatches()
            }
            .task(id: selectedLeague) {
                await loadMatches()
            }
        }
    }
    
    func loadMatches() async {
        isLoading = true
        errorMessage = nil
        
        do {
            if selectedLeague == .france {
                let allMatches = try await rugbyService.getTeamMatches(teamId: selectedLeague.rawValue)
                let today = Date()
                let calendar = Calendar.current
                matches = allMatches.filter { match in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    var matchDate = formatter.date(from: match.date)
                    
                    if matchDate == nil {
                        formatter.dateFormat = "yyyy-MM-dd"
                        matchDate = formatter.date(from: match.date)
                    }
                    
                    if let matchDate = matchDate {
                        return calendar.isDate(matchDate, inSameDayAs: today)
                    }
                    return false
                }
            } else {
                matches = try await rugbyService.getLeagueMatchesToday(leagueId: selectedLeague.rawValue)
            }
            print("✅ Loaded \(matches.count) live matches for \(selectedLeague.name)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error loading live matches: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Tab 2: Calendrier

struct UpcomingMatchesView: View {
    @StateObject private var rugbyService = RugbyService.shared
    @State private var matches: [Match] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedLeague: RugbyLeague = .top14
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    LeagueSelector(selectedLeague: $selectedLeague)
                        .padding(.vertical, 12)
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Chargement...")
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        ErrorView(message: error) {
                            Task { await loadMatches() }
                        }
                        Spacer()
                    } else if matches.isEmpty {
                        Spacer()
                        EmptyStateView(
                            icon: "calendar.badge.exclamationmark",
                            title: "Aucun match à venir",
                            subtitle: selectedLeague == .sixNations 
                                ? "Pas de match prévu pour \(selectedLeague.name) (prochaine édition en 2026)"
                                : "Pas de match prévu pour \(selectedLeague.name)"
                        )
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(matches) { match in
                                    CalendarMatchCard(match: match)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                        .refreshable {
                            await loadMatches()
                        }
                    }
                }
            }
            .navigationTitle(selectedLeague == .sixNations ? "Calendrier 2026 📅" : "Calendrier 📅")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadMatches() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadMatches()
            }
            .task(id: selectedLeague) {
                await loadMatches()
            }
        }
    }
    
    func loadMatches() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let now = Date()
            let calendar = Calendar.current
            
            let allMatches: [Match]
            
            if selectedLeague == .france {
                let currentYear = calendar.component(.year, from: now)
                let seasonsToFetch = [currentYear, currentYear + 1]
                var fetched: [Match] = []
                for season in seasonsToFetch {
                    let seasonMatches = try await rugbyService.getTeamMatches(
                        teamId: 387,
                        season: season
                    )
                    fetched.append(contentsOf: seasonMatches)
                }
                allMatches = fetched
            } else if selectedLeague == .sixNations {
                allMatches = try await rugbyService.getLeagueMatches(
                    leagueId: selectedLeague.rawValue,
                    season: 2026
                )
            } else {
                let currentYear = calendar.component(.year, from: now)
                allMatches = try await rugbyService.getLeagueMatches(
                    leagueId: selectedLeague.rawValue,
                    season: currentYear
                )
            }
            
            matches = allMatches.filter { match in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                var matchDate = formatter.date(from: match.date)
                
                if matchDate == nil {
                    formatter.dateFormat = "yyyy-MM-dd"
                    matchDate = formatter.date(from: match.date)
                }
                
                if let matchDate = matchDate {
                    return matchDate >= now.addingTimeInterval(-86400)
                }
                
                return false
            }
            
            print("✅ Loaded \(matches.count) upcoming matches (filtered from \(allMatches.count) total) for \(selectedLeague.name)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error loading upcoming matches: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Tab 3: Classement

struct StandingsView: View {
    @StateObject private var rugbyService = RugbyService.shared
    @State private var standings: [Standing] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Chargement...")
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        Task { await loadStandings() }
                    }
                } else if standings.isEmpty {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "Classement indisponible",
                        subtitle: "Le classement 2025 n'est pas encore disponible"
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            Top14StandingHeader()
                            ForEach(standings) { standing in
                                Top14StandingRow(standing: standing)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                    .refreshable {
                        await loadStandings()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text("Classement")
                            .font(.headline)
                            .fontWeight(.bold)
                        Image("top14_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 45, height: 45)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadStandings() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadStandings()
            }
        }
    }
    
    func loadStandings() async {
        isLoading = true
        errorMessage = nil
        
        do {
            standings = try await rugbyService.getLeagueStandings(leagueId: 16, season: 2025)
            print("✅ Loaded \(standings.count) standings for Top 14 2025")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error loading standings: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Components: Match Cards

struct LiveMatchCard: View {
    let match: Match
    @State private var showError = false
    @State private var errorMessage = ""
    
    var isActivityActive: Bool {
        if #available(iOS 16.2, *) {
            return LiveActivityManager.shared.isActivityActive(for: match.id)
        }
        return false
    }
    
    var body: some View {
        LiverugbyCard {
            VStack(spacing: 10) {
                // Badge LIVE avec bouton Live Activity
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("EN DIRECT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    // Bouton Live Activity
                    Button {
                        toggleLiveActivity()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isActivityActive ? "bell.fill" : "bell.badge")
                                .font(.system(size: 14))
                            Text(isActivityActive ? "Actif" : "Suivre")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isActivityActive ? Color.orange : Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Text(match.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Équipes et score
                HStack(spacing: 16) {
                    TeamDisplay(
                        name: match.homeTeamName,
                        logoURL: match.homeTeamLogo,
                        alignment: .leading
                    )
                    
                    Spacer()
                    
                    Text(match.scoreText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    TeamDisplay(
                        name: match.awayTeamName,
                        logoURL: match.awayTeamLogo,
                        alignment: .trailing
                    )
                }
            }
            .padding(12)
        }
        .alert("Erreur Live Activity", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func toggleLiveActivity() {
        Task {
            do {
                if #available(iOS 16.2, *) {
                    try await LiveActivityManager.shared.toggleActivity(for: match)
                } else {
                    errorMessage = "Les Live Activities nécessitent iOS 16.2 ou supérieur"
                    showError = true
                }
            } catch {
                errorMessage = "Impossible de démarrer la Live Activity: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}

struct CalendarMatchCard: View {
    let match: Match
    
    var body: some View {
        LiverugbyCard {
            HStack(spacing: 12) {
                // Équipe à domicile (gauche)
                VStack(spacing: 6) {
                    TeamLogo(logoURL: match.homeTeamLogo, size: 50)
                    Text(match.homeTeamName)
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(width: 85)
                }
                .frame(maxWidth: .infinity)
                
                // Date et heure (centre)
                VStack(spacing: 6) {
                    // Date au format Sam 22 Nov
                    Text(formattedDateShort(from: match.date))
                        .font(.system(size: 14))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    // Heure (convertie au fuseau horaire français)
                    if match.time != nil {
                        Text(match.localTime)
                            .font(.system(size: 14))
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    } else {
                        Text("vs")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 90)
                
                // Équipe extérieure (droite)
                VStack(spacing: 6) {
                    TeamLogo(logoURL: match.awayTeamLogo, size: 50)
                    Text(match.awayTeamName)
                        .font(.system(size: 9))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(width: 85)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(10)
        }
    }
    
    // Format: Sam 22 Nov
    func formattedDateShort(from dateString: String) -> String {
        let formatter = DateFormatter()
        
        // Essayer ISO 8601 complet
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        var date = formatter.date(from: dateString)
        
        // Fallback format simple
        if date == nil {
            formatter.dateFormat = "yyyy-MM-dd"
            date = formatter.date(from: dateString)
        }
        
        guard let validDate = date else { return dateString }
        
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE dd MMM"
        let result = formatter.string(from: validDate)
        
        // Capitaliser la première lettre du jour
        return result.prefix(1).uppercased() + result.dropFirst()
    }
}

// MARK: - Components: Standings

struct Top14StandingHeader: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("#")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 30)
            
            Spacer()
                .frame(width: 40) // Espace pour le logo
            
            Text("Équipe")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("J")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 25)
            
            Text("V")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 25)
            
            Text("N")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 25)
            
            Text("D")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 25)
            
            Text("+/-")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 35)
            
            Text("Pts")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 35)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct Top14StandingRow: View {
    let standing: Standing
    
    var body: some View {
        HStack(spacing: 4) {
            // Position
            Text("\(standing.position)")
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(positionColor(standing.position))
                .frame(width: 30)
            
            // Logo du club
            TeamLogo(logoURL: standing.teamLogo, size: 32)
                .frame(width: 40)
            
            // Nom de l'équipe
            Text(standing.teamName)
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Statistiques
            Text("\(standing.played)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 25)
            
            Text("\(standing.won)")
                .font(.caption)
                .foregroundColor(.green)
                .fontWeight(.semibold)
                .frame(width: 25)
            
            Text("\(standing.draw)")
                .font(.caption)
                .foregroundColor(.orange)
                .frame(width: 25)
            
            Text("\(standing.lost)")
                .font(.caption)
                .foregroundColor(.red)
                .fontWeight(.semibold)
                .frame(width: 25)
            
            // Différence de points (+/-)
            if let diff = standing.goalsDiff {
                Text(diff >= 0 ? "+\(diff)" : "\(diff)")
                    .font(.caption)
                    .foregroundColor(diff >= 0 ? .green : .red)
                    .fontWeight(.medium)
                    .frame(width: 35)
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 35)
            }
            
            Text("\(standing.points)")
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(width: 35)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    func positionColor(_ position: Int) -> Color {
        switch position {
        case 1...6:
            return .green
        case 7...12:
            return .blue
        default:
            return .red
        }
    }
}
 
// MARK: - Components: Utilities

struct TeamDisplay: View {
    let name: String
    let logoURL: String?
    let alignment: HorizontalAlignment
    
    var body: some View {
        VStack(spacing: 6) {
            TeamLogo(logoURL: logoURL, size: 50)
            
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 100)
        }
    }
}

struct TeamLogo: View {
    let logoURL: String?
    let size: CGFloat
    
    var body: some View {
        if let logoURL = logoURL, let url = URL(string: logoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                case .failure:
                    Image(systemName: "shield.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Image(systemName: "shield.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(.gray)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Erreur")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Réessayer") {
                retry()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ProfileMenuItem: View {
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
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - About

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo et titre de l'app
                        VStack(spacing: 16) {
                            // Logo rugby
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                
                                Text("🏉")
                                    .font(.system(size: 50))
                            }
                            .padding(.top, 20)
                            
                            // Nom de l'app
                            Text("Live Rugby")
                                .font(.system(size: 32, weight: .bold))
                            
                            // Version
                            Text("Version 1.5")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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

// MARK: - Components: FeatureRow

struct FeatureRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview("HomeView - Production") {
    HomeView()
}
