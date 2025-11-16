//
//  Team.swift
//  LiverugbyApp
//
//  Modèle pour une équipe de rugby
//

import Foundation

struct Team: Identifiable, Codable {
    let id: Int
    let name: String
    let logo: String?
    let country: String?
    let founded: Int?
    let national: Bool
    
    let venueName: String?
    let venueCapacity: Int?
    let venueLocation: String?
    
    // MARK: - Initialisation depuis l'API
    
    init(from dict: [String: Any]) {
        self.id = dict["id"] as? Int ?? 0
        self.name = dict["name"] as? String ?? "Unknown"
        self.logo = dict["logo"] as? String
        self.national = dict["national"] as? Bool ?? false
        self.founded = dict["founded"] as? Int
        
        // Country
        if let countryDict = dict["country"] as? [String: Any] {
            self.country = countryDict["name"] as? String
        } else {
            self.country = nil
        }
        
        // Venue
        if let venueDict = dict["arena"] as? [String: Any] {
            self.venueName = venueDict["name"] as? String
            self.venueCapacity = venueDict["capacity"] as? Int
            self.venueLocation = venueDict["location"] as? String
        } else {
            self.venueName = nil
            self.venueCapacity = nil
            self.venueLocation = nil
        }
    }
    
    // MARK: - Initialisation manuelle (pour tests)
    
    init(
        id: Int,
        name: String,
        logo: String? = nil,
        country: String? = nil,
        founded: Int? = nil,
        national: Bool = false,
        venueName: String? = nil,
        venueCapacity: Int? = nil,
        venueLocation: String? = nil
    ) {
        self.id = id
        self.name = name
        self.logo = logo
        self.country = country
        self.founded = founded
        self.national = national
        self.venueName = venueName
        self.venueCapacity = venueCapacity
        self.venueLocation = venueLocation
    }
}

// MARK: - Mock Data

extension Team {
    static var sampleTeams: [Team] {
        [
            Team(
                id: 107,
                name: "Stade Toulousain",
                logo: "https://media.api-sports.io/rugby/teams/107.png",
                country: "France",
                founded: 1907,
                venueName: "Stade Ernest-Wallon",
                venueCapacity: 19500,
                venueLocation: "Toulouse, France"
            ),
            Team(
                id: 100,
                name: "Stade Rochelais",
                logo: "https://media.api-sports.io/rugby/teams/100.png",
                country: "France",
                founded: 1898,
                venueName: "Stade Marcel Deflandre",
                venueCapacity: 16000,
                venueLocation: "La Rochelle, France"
            ),
            Team(
                id: 96,
                name: "Bordeaux Bègles",
                logo: "https://media.api-sports.io/rugby/teams/96.png",
                country: "France",
                founded: 2006,
                venueName: "Stade Chaban-Delmas",
                venueCapacity: 34694,
                venueLocation: "Bordeaux, France"
            )
        ]
    }
}
