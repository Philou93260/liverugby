//
//  Match.swift
//  LiverugbyApp
//
//  Modèle pour un match de rugby
//

import Foundation

struct Match: Identifiable, Codable {
    let id: Int
    let date: String // Format: "2023-09-10"
    let time: String? // Format: "15:00"
    let timestamp: Int?
    let timezone: String?
    
    let status: String
    let statusShort: String?
    
    let homeTeamId: Int
    let homeTeamName: String
    let homeTeamLogo: String?
    let homeScore: Int?
    
    let awayTeamId: Int
    let awayTeamName: String
    let awayTeamLogo: String?
    let awayScore: Int?
    
    let venue: String?
    let city: String?
    let country: String?
    
    let leagueId: Int?
    let leagueName: String?
    let leagueSeason: Int?
    
    // MARK: - Computed Properties
    
    // Date/heure de l'évènement reconstruite depuis les champs de l'API
    private var eventDate: Date? {
        // 1) Si timestamp fourni, c'est la source la plus fiable
        if let ts = timestamp {
            return Date(timeIntervalSince1970: TimeInterval(ts))
        }
        
        // 2) Si pas d'heure séparée, tenter ISO 8601 dans `date`
        if time == nil {
            let iso = DateFormatter()
            iso.locale = Locale(identifier: "en_US_POSIX")
            iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let d = iso.date(from: date) {
                return d
            }
        }
        
        // 3) Cas général: `date` + `time` avec timezone de l'API
        guard let time = time else { return nil }
        let full = "\(date) \(time)"
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd HH:mm"
        if let tzId = timezone, let tz = TimeZone(identifier: tzId) {
            input.timeZone = tz
        } else {
            input.timeZone = TimeZone(secondsFromGMT: 0) // UTC fallback
        }
        return input.date(from: full)
    }
    
    var scoreText: String {
        if let home = homeScore, let away = awayScore {
            return "\(home) - \(away)"
        }
        return "- : -"
    }
    
    var formattedDate: String {
        guard let d = eventDate else { return date }
        let out = DateFormatter()
        out.locale = Locale(identifier: "fr_FR")
        out.timeZone = TimeZone.current
        out.dateFormat = "EEE d MMM yyyy"
        return out.string(from: d)
    }
    
    var formattedDateTime: String {
        if let d = eventDate {
            let out = DateFormatter()
            out.locale = Locale(identifier: "fr_FR")
            out.timeZone = TimeZone.current
            out.dateFormat = "EEE d MMM yyyy à HH:mm"
            return out.string(from: d)
        }
        if let _ = time {
            return "\(formattedDate) à \(localTime)"
        }
        return formattedDate
    }
    
    /// Convertit l'heure UTC en heure locale française (Europe/Paris)
    /// Gère automatiquement l'heure d'été (UTC+2) et l'heure d'hiver (UTC+1)
    var localTime: String {
        if let d = eventDate {
            let out = DateFormatter()
            out.locale = Locale(identifier: "fr_FR")
            out.timeZone = TimeZone.current
            out.dateFormat = "HH:mm"
            return out.string(from: d)
        }
        return time ?? ""
    }
    
    var isLive: Bool {
        return status.contains("Live") || 
               status.contains("En cours") || 
               status.contains("1st Half") || 
               status.contains("2nd Half") ||
               status.contains("Half Time")
    }
    
    var isFinished: Bool {
        return status.contains("Finished") || 
               status.contains("Terminé") || 
               status.contains("Full Time") ||
               status.contains("FT")
    }
    
    var isUpcoming: Bool {
        return status.contains("Not Started") || 
               status.contains("NS") || 
               status.contains("À venir") ||
               status.contains("Scheduled")
    }
    
    // MARK: - Initialisation depuis l'API
    
    init(from dict: [String: Any]) {
        self.id = dict["id"] as? Int ?? 0
        self.date = dict["date"] as? String ?? ""
        self.time = dict["time"] as? String
        self.timestamp = dict["timestamp"] as? Int
        self.timezone = dict["timezone"] as? String
        
        self.status = dict["status"] as? String ?? "Unknown"
        self.statusShort = dict["status_short"] as? String
        
        // Home team
        if let teams = dict["teams"] as? [String: Any],
           let home = teams["home"] as? [String: Any] {
            self.homeTeamId = home["id"] as? Int ?? 0
            self.homeTeamName = home["name"] as? String ?? "Unknown"
            self.homeTeamLogo = home["logo"] as? String
        } else {
            self.homeTeamId = 0
            self.homeTeamName = "Unknown"
            self.homeTeamLogo = nil
        }
        
        // Away team
        if let teams = dict["teams"] as? [String: Any],
           let away = teams["away"] as? [String: Any] {
            self.awayTeamId = away["id"] as? Int ?? 0
            self.awayTeamName = away["name"] as? String ?? "Unknown"
            self.awayTeamLogo = away["logo"] as? String
        } else {
            self.awayTeamId = 0
            self.awayTeamName = "Unknown"
            self.awayTeamLogo = nil
        }
        
        // Scores
        if let scores = dict["scores"] as? [String: Any],
           let home = scores["home"] as? Int,
           let away = scores["away"] as? Int {
            self.homeScore = home
            self.awayScore = away
        } else {
            self.homeScore = nil
            self.awayScore = nil
        }
        
        // Venue
        if let venueDict = dict["venue"] as? [String: Any] {
            self.venue = venueDict["name"] as? String
            self.city = venueDict["city"] as? String
        } else {
            self.venue = nil
            self.city = nil
        }
        
        self.country = dict["country"] as? String
        
        // League
        if let league = dict["league"] as? [String: Any] {
            self.leagueId = league["id"] as? Int
            self.leagueName = league["name"] as? String
            self.leagueSeason = league["season"] as? Int
        } else {
            self.leagueId = nil
            self.leagueName = nil
            self.leagueSeason = nil
        }
    }
    
    // MARK: - Initialisation manuelle (pour tests)
    
    init(
        id: Int,
        date: String,
        time: String? = nil,
        status: String,
        homeTeamId: Int,
        homeTeamName: String,
        homeTeamLogo: String? = nil,
        homeScore: Int? = nil,
        awayTeamId: Int,
        awayTeamName: String,
        awayTeamLogo: String? = nil,
        awayScore: Int? = nil,
        venue: String? = nil,
        leagueId: Int? = nil,
        leagueName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.time = time
        self.timestamp = nil
        self.timezone = nil
        self.status = status
        self.statusShort = nil
        self.homeTeamId = homeTeamId
        self.homeTeamName = homeTeamName
        self.homeTeamLogo = homeTeamLogo
        self.homeScore = homeScore
        self.awayTeamId = awayTeamId
        self.awayTeamName = awayTeamName
        self.awayTeamLogo = awayTeamLogo
        self.awayScore = awayScore
        self.venue = venue
        self.city = nil
        self.country = nil
        self.leagueId = leagueId
        self.leagueName = leagueName
        self.leagueSeason = nil
    }
}

