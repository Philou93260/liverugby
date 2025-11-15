//
//  MatchLiveActivityWidget-Premium.swift
//  LiverugbyAppWidgets
//
//  Version PREMIUM avec toutes les améliorations
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct MatchLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MatchLiveActivityAttributes.self) { context in
            // Lock Screen / Banner UI - VERSION PREMIUM
            MatchLiveActivityPremiumView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island UI - VERSION PREMIUM
            DynamicIsland {
                // EXPANDED - Vue détaillée complète
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Logo + Nom équipe domicile
                        HStack(spacing: 6) {
                            if let logoURL = context.attributes.homeTeamLogo,
                               let url = URL(string: logoURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    Image(systemName: "shield.fill")
                                        .foregroundColor(.blue)
                                }
                                .frame(width: 32, height: 32)
                            }
                            
                            Text(context.attributes.homeTeamName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .lineLimit(1)
                        }
                        
                        // Score avec animation
                        Text("\(context.state.homeScore)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                    }
                    .padding(.leading, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        // Logo + Nom équipe extérieure
                        HStack(spacing: 6) {
                            Text(context.attributes.awayTeamName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .lineLimit(1)
                            
                            if let logoURL = context.attributes.awayTeamLogo,
                               let url = URL(string: logoURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } placeholder: {
                                    Image(systemName: "shield.fill")
                                        .foregroundColor(.red)
                                }
                                .frame(width: 32, height: 32)
                            }
                        }
                        
                        // Score avec animation
                        Text("\(context.state.awayScore)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                    }
                    .padding(.trailing, 8)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        // Badge LIVE avec animation
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            
                            Text("DIRECT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        
                        Text(context.state.status)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        // Minute de jeu si disponible
                        if let minute = context.state.minute {
                            Text(minute)
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Barre de progression du match
                        if let progress = context.state.matchProgress {
                            ProgressView(value: progress)
                                .tint(.blue)
                                .frame(height: 4)
                        }
                        
                        // Dernière action
                        if let action = context.state.lastAction {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption2)
                                
                                Text(action)
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                
                                if let time = context.state.lastActionTime {
                                    Text("(\(time))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Informations match
                        HStack {
                            if let league = context.attributes.leagueName {
                                HStack(spacing: 3) {
                                    Image(systemName: "trophy.fill")
                                        .font(.caption2)
                                    Text(league)
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let venue = context.attributes.venue {
                                HStack(spacing: 3) {
                                    Image(systemName: "location.fill")
                                        .font(.caption2)
                                    Text(venue)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            } compactLeading: {
                // Compact Leading - Score domicile avec animation
                HStack(spacing: 2) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.blue)
                    
                    Text("\(context.state.homeScore)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
            } compactTrailing: {
                // Compact Trailing - Score extérieur avec animation
                HStack(spacing: 2) {
                    Text("\(context.state.awayScore)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                    
                    Image(systemName: "shield.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                }
            } minimal: {
                // Minimal - Icône rugby avec pulse
                Image(systemName: "sportscourt.fill")
                    .foregroundColor(.blue)
                    .symbolEffect(.pulse)
            }
        }
    }
}

// MARK: - Lock Screen View PREMIUM

struct MatchLiveActivityPremiumView: View {
    let context: ActivityViewContext<MatchLiveActivityAttributes>
    
    // Détermine quelle équipe mène
    private var leadingTeam: String? {
        if context.state.homeScore > context.state.awayScore {
            return "home"
        } else if context.state.awayScore > context.state.homeScore {
            return "away"
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête avec badge LIVE et progression
            headerSection
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Section principale : équipes et scores
            mainScoreSection
            
            // Barre de progression du match
            if let progress = context.state.matchProgress {
                progressSection(progress: progress)
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Footer : infos match + dernière action
            footerSection
        }
        .padding(16)
        .background(
            // Fond avec dégradé selon l'équipe qui mène
            backgroundGradient
        )
        .activitySystemActionForegroundColor(.white)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            // Badge LIVE animé
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: .red, radius: 4)
                
                Text("EN DIRECT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Statut + minute
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.status)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if let minute = context.state.minute {
                    Text(minute)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.bold)
                }
            }
        }
    }
    
    // MARK: - Main Score Section
    
    private var mainScoreSection: some View {
        HStack(spacing: 0) {
            // Équipe domicile
            teamCard(
                name: context.attributes.homeTeamName,
                logoURL: context.attributes.homeTeamLogo,
                score: context.state.homeScore,
                isLeading: leadingTeam == "home",
                justScored: context.state.lastScoringTeam == "home"
            )
            
            // VS central
            Text("VS")
                .font(.caption)
                .fontWeight(.black)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 40)
            
            // Équipe extérieure
            teamCard(
                name: context.attributes.awayTeamName,
                logoURL: context.attributes.awayTeamLogo,
                score: context.state.awayScore,
                isLeading: leadingTeam == "away",
                justScored: context.state.lastScoringTeam == "away"
            )
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Team Card
    
    private func teamCard(
        name: String,
        logoURL: String?,
        score: Int,
        isLeading: Bool,
        justScored: Bool
    ) -> some View {
        VStack(spacing: 8) {
            // Logo
            if let logoURL = logoURL, let url = URL(string: logoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 50, height: 50)
                .shadow(color: justScored ? .yellow : .clear, radius: 10)
            }
            
            // Nom équipe
            Text(name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
            
            // Score avec effet
            ZStack {
                // Halo si équipe mène
                if isLeading {
                    Circle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .blur(radius: 5)
                }
                
                // Score
                Text("\(score)")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
            
            // Indicateur "En tête"
            if isLeading {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8))
                    Text("EN TÊTE")
                        .font(.system(size: 8))
                        .fontWeight(.bold)
                }
                .foregroundColor(.yellow)
            } else {
                Text(" ")
                    .font(.system(size: 8))
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Progress Section
    
    private func progressSection(progress: Double) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fond
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                    
                    // Progression
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
            
            // Pourcentage
            Text("\(Int(progress * 100))% du match")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 6) {
            // Dernière action importante
            if let action = context.state.lastAction {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    
                    Text(action)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if let time = context.state.lastActionTime {
                        Text("(\(time))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Infos match
            HStack(spacing: 12) {
                if let league = context.attributes.leagueName {
                    HStack(spacing: 3) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                        Text(league)
                            .font(.caption2)
                    }
                }
                
                if let venue = context.attributes.venue {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(venue)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
            .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Background Gradient
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var gradientColors: [Color] {
        switch leadingTeam {
        case "home":
            return [Color.blue.opacity(0.8), Color.blue.opacity(0.6), Color.purple.opacity(0.6)]
        case "away":
            return [Color.red.opacity(0.8), Color.red.opacity(0.6), Color.orange.opacity(0.6)]
        default:
            return [Color.gray.opacity(0.8), Color.gray.opacity(0.6), Color.blue.opacity(0.5)]
        }
    }
}
