//
//  TheTVDBService.swift
//  FlexPlayer
//

import Foundation

struct TVDBShow: Decodable {
    let id: Int
    let name: String
    let overview: String?
    let image: String?
    let backdrop: String?
    let firstAired: String?
    
    enum CodingKeys: String, CodingKey {
        case objectID, tvdbId = "tvdb_id", name, overview
        case image = "image_url"
        case firstAired = "first_air_time"
        case backdrop
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try tvdb_id first (the actual numeric ID)
        if let tvdbId = try? container.decode(Int.self, forKey: .tvdbId) {
            id = tvdbId
        } else if let tvdbIdString = try? container.decode(String.self, forKey: .tvdbId),
                  let tvdbIdInt = Int(tvdbIdString) {
            id = tvdbIdInt
        } else if let objectId = try? container.decode(String.self, forKey: .objectID) {
            // Extract numeric ID from "series-440284" format
            let numericPart = objectId.replacingOccurrences(of: "series-", with: "")
            if let numericId = Int(numericPart) {
                id = numericId
            } else {
                throw DecodingError.dataCorruptedError(forKey: .objectID, in: container,
                    debugDescription: "Could not extract numeric ID from: \(objectId)")
            }
        } else {
            throw DecodingError.dataCorruptedError(forKey: .tvdbId, in: container,
                debugDescription: "Could not find valid ID field")
        }
        
        name = try container.decode(String.self, forKey: .name)
        overview = try? container.decode(String.self, forKey: .overview)
        image = try? container.decode(String.self, forKey: .image)
        backdrop = try? container.decode(String.self, forKey: .backdrop)
        firstAired = try? container.decode(String.self, forKey: .firstAired)
    }
}

struct TVDBEpisode: Decodable {
    let id: Int
    let name: String
    let overview: String?
    let image: String?
    let episodeNumber: Int
    let aired: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview, image, aired
        case episodeNumber = "number"
        case seriesId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle id as Int or String
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = idInt
        } else if let idString = try? container.decode(String.self, forKey: .id),
                  let idInt = Int(idString) {
            id = idInt
        } else {
            throw DecodingError.typeMismatch(Int.self, DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Could not decode id as Int or String convertible to Int"
            ))
        }
        
        name = try container.decode(String.self, forKey: .name)
        overview = try? container.decode(String.self, forKey: .overview)
        image = try? container.decode(String.self, forKey: .image)
        
        // Handle episodeNumber - might be missing or null
        episodeNumber = (try? container.decode(Int.self, forKey: .episodeNumber)) ?? 0
        
        aired = try? container.decode(String.self, forKey: .aired)
    }
}

struct TVDBSearchResponse: Decodable {
    let data: [TVDBShow]
}

struct TVDBTokenResponse: Codable {
    let data: TokenData
    
    struct TokenData: Codable {
        let token: String
    }
}

class TheTVDBService {
    static let shared = TheTVDBService()
    private let apiKey: String
    private let baseURL = "https://api4.thetvdb.com/v4"
    private var authToken: String?
    private var tokenExpiry: Date?
    
    private init() {
        self.apiKey = APIKeys.tvdbAPIKey
    }
    
    // Authenticate and get token
    private func authenticate() async throws {
        // Check if we have a valid token
        if let tokenExpiry, tokenExpiry > Date(), authToken != nil {
            return
        }
        
        let urlString = "\(baseURL)/login"
        guard let url = URL(string: urlString) else {
            throw TVDBError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["apikey": apiKey]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TVDBTokenResponse.self, from: data)
        
        self.authToken = response.data.token
        // Token typically lasts 24 hours
        self.tokenExpiry = Date().addingTimeInterval(24 * 60 * 60)
    }
    
    // Get authenticated request
    private func authenticatedRequest(url: URL) async throws -> URLRequest {
        try await authenticate()
        
        var request = URLRequest(url: url)
        if let authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    
    // Search for a TV show by name
    func searchShow(name: String) async throws -> TVDBShow? {
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlString = "\(baseURL)/search?query=\(query)&type=series"
        
        guard let url = URL(string: urlString) else {
            throw TVDBError.invalidURL
        }
        
        let request = try await authenticatedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let response = try JSONDecoder().decode(TVDBSearchResponse.self, from: data)
        
        return response.data.first
    }

    // Search for TV shows by name (returns multiple results)
    func searchShows(name: String, limit: Int = 10) async throws -> [TVDBShow] {
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlString = "\(baseURL)/search?query=\(query)&type=series"

        guard let url = URL(string: urlString) else {
            throw TVDBError.invalidURL
        }

        let request = try await authenticatedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)

        let response = try JSONDecoder().decode(TVDBSearchResponse.self, from: data)

        return Array(response.data.prefix(limit))
    }

    // Get episode details for a specific season and episode
    func getEpisode(showId: Int, season: Int, episode: Int) async throws -> TVDBEpisode? {
        // First get all episodes for the show
        let urlString = "\(baseURL)/series/\(showId)/episodes/default?season=\(season)"
        
        guard let url = URL(string: urlString) else {
            throw TVDBError.invalidURL
        }
        
        let request = try await authenticatedRequest(url: url)
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct EpisodesResponse: Decodable {
            let data: Episodes
            struct Episodes: Decodable {
                let episodes: [TVDBEpisode]
            }
        }
        
        let response = try JSONDecoder().decode(EpisodesResponse.self, from: data)
        
        let matchedEpisode = response.data.episodes.first { $0.episodeNumber == episode }
        
        return matchedEpisode
    }
    
    // Download image from TVDB
    func downloadImage(path: String) async throws -> Data {
        guard let url = URL(string: path) else {
            throw TVDBError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

enum TVDBError: Error {
    case invalidURL
}
