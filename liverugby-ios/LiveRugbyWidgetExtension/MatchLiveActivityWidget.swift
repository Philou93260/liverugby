//
//  MatchLiveActivityWidget.swift
//  LiveRugbyWidgetExtension
//
//  Widget pour afficher les Live Activities des matchs de rugby
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct MatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchLiveActivityAttributes.self) { context in
            // Vue pour l'écran de verrouillage
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            // Vue pour la Dynamic Island
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    TeamView(
                        teamName: context.attributes.homeTeamName,
                        score: context.state.homeScore,
                        logoURL: context.attributes.homeTeamLogo
                    )
                }

                DynamicIslandExpandedRegion(.trailing) {
                    TeamView(
                        teamName: context.attributes.awayTeamName,
                        score: context.state.awayScore,
                        logoURL: context.attributes.awayTeamLogo
                    )
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.statusLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if let elapsed = context.state.elapsed {
                            Text("\(elapsed)'")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if let event = context.state.recentEvent {
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(event)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } compactLeading: {
                // Vue compacte à gauche
                HStack(spacing: 2) {
                    Text("\(context.state.homeScore)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            } compactTrailing: {
                // Vue compacte à droite
                HStack(spacing: 2) {
                    Text("\(context.state.awayScore)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            } minimal: {
                // Vue minimale (quand plusieurs activités)
                Image(systemName: "sportscourt")
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<MatchLiveActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // En-tête avec le statut et la compétition
            HStack {
                if let league = context.attributes.leagueName {
                    Text(league)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(context.state.statusLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                if let elapsed = context.state.elapsed {
                    Text("(\(elapsed)')")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Score principal
            HStack(spacing: 20) {
                // Équipe à domicile
                VStack(spacing: 8) {
                    if let logoURL = context.attributes.homeTeamLogo,
                       let url = URL(string: logoURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                        }
                    }

                    Text(context.attributes.homeTeamName)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(context.state.homeScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)

                // Séparateur
                Text("-")
                    .font(.title3)
                    .foregroundColor(.secondary)

                // Équipe extérieure
                VStack(spacing: 8) {
                    if let logoURL = context.attributes.awayTeamLogo,
                       let url = URL(string: logoURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 32, height: 32)
                        }
                    }

                    Text(context.attributes.awayTeamName)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(context.state.awayScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
            }

            // Événement récent
            if let event = context.state.recentEvent {
                HStack {
                    Image(systemName: "circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(event)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(12)
        .activityBackgroundTint(Color.black.opacity(0.3))
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Team View (for Dynamic Island)

@available(iOS 16.2, *)
struct TeamView: View {
    let teamName: String
    let score: Int
    let logoURL: String?

    var body: some View {
        VStack(spacing: 4) {
            if let logoURL = logoURL,
               let url = URL(string: logoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                }
            }

            Text(teamName)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text("\(score)")
                .font(.title3)
                .fontWeight(.bold)
        }
    }
}
