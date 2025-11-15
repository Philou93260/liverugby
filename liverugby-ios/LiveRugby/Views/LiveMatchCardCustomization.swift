//
//  LiveMatchCardCustomization.swift
//  LiverugbyApp
//
//  Exemples de personnalisation pour LiveMatchCard
//  Copiez et adaptez ces variantes selon vos besoins
//

import SwiftUI

// MARK: - Variante 1 : Card Compacte

struct LiveMatchCardCompact: View {
    let match: Match
    
    var body: some View {
        LiverugbyCard {
            HStack(spacing: 12) {
                // Badge LIVE compact
                HStack(spacing: 3) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                    Text("LIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                // Équipe domicile
                HStack(spacing: 6) {
                    TeamLogo(logoURL: match.homeTeamLogo, size: 30)
                    Text(match.homeTeamName)
                        .font(.caption)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Score
                Text(match.scoreText)
                    .font(.system(size: 14))
                    .fontWeight(.bold)
                
                // Équipe extérieure
                HStack(spacing: 6) {
                    Text(match.awayTeamName)
                        .font(.caption)
                        .lineLimit(1)
                    TeamLogo(logoURL: match.awayTeamLogo, size: 30)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(10)
        }
    }
}

// MARK: - Variante 2 : Card avec Statut détaillé

struct LiveMatchCardDetailed: View {
    let match: Match
    
    var body: some View {
        LiverugbyCard {
            VStack(spacing: 12) {
                // En-tête avec statut
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
                    
                    // État du match (1H, HT, 2H, etc.)
                    Text(match.status)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
                
                // Équipes et score
                HStack(spacing: 16) {
                    TeamDisplay(
                        name: match.homeTeamName,
                        logoURL: match.homeTeamLogo,
                        alignment: .leading
                    )
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(match.scoreText)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if let time = match.time {
                            Text(time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
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
    }
}

// MARK: - Variante 3 : Card Minimaliste

struct LiveMatchCardMinimal: View {
    let match: Match
    
    var body: some View {
        VStack(spacing: 8) {
            // Badge
            HStack {
                Circle()
                    .fill(.red)
                    .frame(width: 6, height: 6)
                Text("LIVE")
                    .font(.caption2)
                    .foregroundColor(.red)
                Spacer()
            }
            
            // Matchup
            HStack(spacing: 8) {
                // Domicile
                VStack(spacing: 4) {
                    TeamLogo(logoURL: match.homeTeamLogo, size: 40)
                    Text(match.homeTeamName)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                
                // Score
                Text(match.scoreText)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Extérieur
                VStack(spacing: 4) {
                    TeamLogo(logoURL: match.awayTeamLogo, size: 40)
                    Text(match.awayTeamName)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Variante 4 : Card avec Progression

struct LiveMatchCardWithProgress: View {
    let match: Match
    
    var body: some View {
        LiverugbyCard {
            VStack(spacing: 10) {
                // En-tête
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
                    
                    Text(match.status)
                        .font(.caption)
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
                
                // Barre de progression (exemple basé sur le statut)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geometry.size.width * matchProgress, height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
            }
            .padding(12)
        }
    }
    
    private var matchProgress: CGFloat {
        switch match.status {
        case "1H": return 0.25
        case "HT": return 0.5
        case "2H": return 0.75
        case "FT": return 1.0
        default: return 0
        }
    }
}

// MARK: - Variante 5 : Card Large (Style iPad)

struct LiveMatchCardLarge: View {
    let match: Match
    
    var body: some View {
        LiverugbyCard {
            HStack(spacing: 24) {
                // Équipe domicile (élargie)
                VStack(spacing: 8) {
                    TeamLogo(logoURL: match.homeTeamLogo, size: 80)
                    Text(match.homeTeamName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    if let score = match.homeScore {
                        Text("\(score)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Séparateur
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("LIVE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    
                    Text("VS")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text(match.status)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                
                // Équipe extérieure (élargie)
                VStack(spacing: 8) {
                    TeamLogo(logoURL: match.awayTeamLogo, size: 80)
                    Text(match.awayTeamName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    if let score = match.awayScore {
                        Text("\(score)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }
}

// MARK: - Variante 6 : Card Sombre (Mode nuit)

struct LiveMatchCardDark: View {
    let match: Match
    
    var body: some View {
        VStack(spacing: 10) {
            // Badge LIVE
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
                
                Text(match.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.gray)
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
                    .foregroundColor(.white)
                
                Spacer()
                
                TeamDisplay(
                    name: match.awayTeamName,
                    logoURL: match.awayTeamLogo,
                    alignment: .trailing
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview de toutes les variantes

#Preview("Variantes de Cards") {
    ScrollView {
        VStack(spacing: 20) {
            Text("Standard")
                .font(.headline)
            LiveMatchCard(match: sampleMatch)
                .padding(.horizontal)
            
            Text("Compacte")
                .font(.headline)
            LiveMatchCardCompact(match: sampleMatch)
                .padding(.horizontal)
            
            Text("Détaillée")
                .font(.headline)
            LiveMatchCardDetailed(match: sampleMatch)
                .padding(.horizontal)
            
            Text("Minimaliste")
                .font(.headline)
            LiveMatchCardMinimal(match: sampleMatch)
                .padding(.horizontal)
            
            Text("Avec Progression")
                .font(.headline)
            LiveMatchCardWithProgress(match: sampleMatch)
                .padding(.horizontal)
            
            Text("Large (iPad)")
                .font(.headline)
            LiveMatchCardLarge(match: sampleMatch)
                .padding(.horizontal)
            
            Text("Sombre")
                .font(.headline)
            LiveMatchCardDark(match: sampleMatch)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}

// Match d'exemple pour les previews
private let sampleMatch = Match(
    id: 1,
    date: ISO8601DateFormatter().string(from: Date()),
    time: "15:00",
    status: "1H",
    homeTeamId: 463,
    homeTeamName: "Stade Toulousain",
    homeTeamLogo: "https://media.api-sports.io/rugby/teams/463.png",
    homeScore: 21,
    awayTeamId: 464,
    awayTeamName: "Racing 92",
    awayTeamLogo: "https://media.api-sports.io/rugby/teams/464.png",
    awayScore: 18,
    leagueId: 16,
    leagueName: "Top 14"
)
