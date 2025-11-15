//
//  LeagueSelector.swift
//  LiverugbyApp
//
//  Sélecteur de championnat avec style TabBar
//

import SwiftUI

struct LeagueSelector: View {
    @Binding var selectedLeague: RugbyLeague
    
    let leagues: [RugbyLeague] = [.top14, .france, .sixNations]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(leagues, id: \.self) { league in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedLeague = league
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: league.icon)
                                .font(.system(size: 24, weight: .regular))
                                .foregroundStyle(selectedLeague == league ? Color.blue : Color.gray)
                            
                            Text(league.shortName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(selectedLeague == league ? Color.blue : Color.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
            
            Divider()
        }
    }
}

#Preview {
    LeagueSelector(selectedLeague: .constant(.top14))
}
