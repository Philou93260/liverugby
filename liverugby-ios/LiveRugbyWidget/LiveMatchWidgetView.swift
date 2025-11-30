//
//  LiveMatchWidgetView.swift
//  LiveRugbyWidget
//
//  Vue du widget de match en direct
//

import SwiftUI
import WidgetKit

struct LiveMatchWidgetView: View {
    let entry: LiveMatchEntry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        if let matchData = entry.matchData {
            matchView(matchData)
        } else {
            emptyStateView()
        }
    }

    // MARK: - Match View

    @ViewBuilder
    private func matchView(_ match: WidgetMatchData) -> some View {
        VStack(spacing: 0) {
            // En-tête avec la compétition et le statut
            headerView(match)

            Divider()
                .background(Color.gray.opacity(0.3))

            // Vue principale du match
            mainMatchView(match)

            // Pied de page avec l'heure ou le temps écoulé
            if widgetFamily != .systemSmall {
                Divider()
                    .background(Color.gray.opacity(0.3))
                footerView(match)
            }
        }
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }

    // MARK: - Header

    private func headerView(_ match: WidgetMatchData) -> some View {
        HStack(spacing: 4) {
            // Logo de la compétition
            AsyncImage(url: URL(string: match.leagueLogo)) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 16, height: 16)
            .clipShape(Circle())

            // Nom de la compétition
            Text(match.league)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            // Statut du match
            statusBadge(match.status)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func statusBadge(_ status: MatchStatus) -> some View {
        HStack(spacing: 4) {
            if status.isLive {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
            }

            Text(status.rawValue)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(status.isLive ? .red : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(status.isLive ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
        )
    }

    // MARK: - Main Match View

    private func mainMatchView(_ match: WidgetMatchData) -> some View {
        VStack(spacing: widgetFamily == .systemSmall ? 8 : 12) {
            // Équipe domicile
            teamRow(
                team: match.homeTeam,
                isHome: true,
                isFavorite: match.isFavoriteHome
            )

            // Équipe extérieure
            teamRow(
                team: match.awayTeam,
                isHome: false,
                isFavorite: !match.isFavoriteHome
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, widgetFamily == .systemSmall ? 8 : 12)
    }

    private func teamRow(team: TeamData, isHome: Bool, isFavorite: Bool) -> some View {
        HStack(spacing: 8) {
            // Logo de l'équipe
            AsyncImage(url: URL(string: team.logo)) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: widgetFamily == .systemSmall ? 28 : 36,
                   height: widgetFamily == .systemSmall ? 28 : 36)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isFavorite ? Color.blue : Color.clear, lineWidth: 2)
            )

            // Nom de l'équipe
            Text(team.name)
                .font(widgetFamily == .systemSmall ? .caption : .subheadline)
                .fontWeight(isFavorite ? .bold : .regular)
                .lineLimit(1)
                .foregroundColor(isFavorite ? .primary : .secondary)

            Spacer()

            // Score
            Text("\(team.score ?? 0)")
                .font(widgetFamily == .systemSmall ? .title3 : .title2)
                .fontWeight(.bold)
                .foregroundColor(isFavorite ? .blue : .primary)
                .frame(minWidth: 32)
        }
    }

    // MARK: - Footer

    private func footerView(_ match: WidgetMatchData) -> some View {
        HStack {
            // Heure du match ou temps écoulé
            if let elapsed = match.elapsed, match.status.isLive {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("\(elapsed)'")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
            } else if match.status == .notStarted {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(match.displayDate)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
            } else if match.status == .fullTime || match.status == .finished {
                Text("Terminé")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Stade (si disponible et si widget medium ou large)
            if let venue = match.venue, widgetFamily == .systemLarge {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(venue)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Empty State

    private func emptyStateView() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: widgetFamily == .systemSmall ? 32 : 48))
                .foregroundColor(.gray)

            VStack(spacing: 4) {
                Text("Aucun match")
                    .font(widgetFamily == .systemSmall ? .caption : .subheadline)
                    .fontWeight(.semibold)

                if widgetFamily != .systemSmall {
                    Text("Configurez votre équipe favorite")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

// MARK: - Widget Configuration

struct LiveMatchWidget: Widget {
    let kind: String = "LiveMatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LiveMatchTimelineProvider()) { entry in
            LiveMatchWidgetView(entry: entry)
        }
        .configurationDisplayName("Match en Direct")
        .description("Suivez le match en direct de votre équipe favorite")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    LiveMatchWidget()
} timeline: {
    LiveMatchEntry(
        date: Date(),
        matchData: WidgetMatchData(
            matchId: 1,
            league: "Top 14",
            leagueLogo: "",
            date: Date(),
            status: .firstHalf,
            homeTeam: TeamData(id: 1, name: "Toulouse", logo: "", score: 21),
            awayTeam: TeamData(id: 2, name: "La Rochelle", logo: "", score: 14),
            venue: "Stade Ernest-Wallon",
            elapsed: 35
        ),
        configuration: nil
    )
}

#Preview(as: .systemMedium) {
    LiveMatchWidget()
} timeline: {
    LiveMatchEntry(
        date: Date(),
        matchData: WidgetMatchData(
            matchId: 1,
            league: "Top 14",
            leagueLogo: "",
            date: Date(),
            status: .secondHalf,
            homeTeam: TeamData(id: 1, name: "Toulouse", logo: "", score: 28),
            awayTeam: TeamData(id: 2, name: "La Rochelle", logo: "", score: 21),
            venue: "Stade Ernest-Wallon",
            elapsed: 65
        ),
        configuration: nil
    )
}

#Preview(as: .systemLarge) {
    LiveMatchWidget()
} timeline: {
    LiveMatchEntry(
        date: Date(),
        matchData: WidgetMatchData(
            matchId: 1,
            league: "Top 14",
            leagueLogo: "",
            date: Date(),
            status: .fullTime,
            homeTeam: TeamData(id: 1, name: "Toulouse", logo: "", score: 35),
            awayTeam: TeamData(id: 2, name: "La Rochelle", logo: "", score: 28),
            venue: "Stade Ernest-Wallon",
            elapsed: nil
        ),
        configuration: nil
    )
}
