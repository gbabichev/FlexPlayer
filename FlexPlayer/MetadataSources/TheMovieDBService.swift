//
//  TMDBService.swift
//  FlexPlayer
//

import Foundation

struct TMDBShow: Codable {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case firstAirDate = "first_air_date"
    }
}

struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, overview, runtime
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
    }
}

struct TMDBEpisode: Codable {
    let id: Int
    let name: String
    let overview: String?
    let stillPath: String?
    let airDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case stillPath = "still_path"
        case airDate = "air_date"
    }
}

struct TMDBSearchResponse: Codable {
    let results: [TMDBShow]
}

struct TMDBMovieSearchResponse: Codable {
    let results: [TMDBMovie]
}

class TMDBService {
    static let shared = TMDBService()
    private let apiKey: String
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p/w500"
    
    private init() {
        self.apiKey = APIKeys.tmdbAPIKey
    }
    
    // Search for a TV show by name
    func searchShow(name: String) async throws -> TMDBShow? {
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlString = "\(baseURL)/search/tv?api_key=\(apiKey)&query=\(query)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        
        return response.results.first
    }
    
    // Search for a movie by title (returns first result)
    func searchMovie(title: String) async throws -> TMDBMovie? {
        let query = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(query)"

        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBMovieSearchResponse.self, from: data)

        // Get the first result and fetch full details including runtime
        guard let movie = response.results.first else {
            return nil
        }

        // Fetch full movie details to get runtime
        return try await getMovieDetails(movieId: movie.id)
    }

    // Search for movies by title (returns multiple results)
    func searchMovies(title: String, limit: Int = 10) async throws -> [TMDBMovie] {
        let query = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(query)"

        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBMovieSearchResponse.self, from: data)

        // Fetch full details for each result (up to limit)
        var movies: [TMDBMovie] = []
        for movie in response.results.prefix(limit) {
            if let fullMovie = try? await getMovieDetails(movieId: movie.id) {
                movies.append(fullMovie)
            }
        }

        return movies
    }
    
    // Get full movie details including runtime
    func getMovieDetails(movieId: Int) async throws -> TMDBMovie? {
        let urlString = "\(baseURL)/movie/\(movieId)?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let movie = try JSONDecoder().decode(TMDBMovie.self, from: data)
        
        return movie
    }
    
    // Get episode details for a specific season and episode
    func getEpisode(showId: Int, season: Int, episode: Int) async throws -> TMDBEpisode? {
        let urlString = "\(baseURL)/tv/\(showId)/season/\(season)/episode/\(episode)?api_key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let episodeData = try JSONDecoder().decode(TMDBEpisode.self, from: data)

        return episodeData
    }

    // Build full poster URL
    func posterURL(for path: String) -> URL? {
        URL(string: "\(imageBaseURL)\(path)")
    }
    
    // Download and cache poster image
    func downloadPoster(path: String) async throws -> Data {
        guard let url = posterURL(for: path) else {
            throw TMDBError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    // Build full still/thumbnail URL
    func stillURL(for path: String) -> URL? {
        URL(string: "\(imageBaseURL)\(path)")
    }

    // Download and cache episode still/thumbnail image
    func downloadStill(path: String) async throws -> Data {
        guard let url = stillURL(for: path) else {
            throw TMDBError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
}

enum TMDBError: Error {
    case invalidURL
}

// Helper to parse your filename format: "Episode Name - S01E01.mp4"
struct EpisodeParser {
    static func parse(filename: String) -> (title: String, season: Int, episode: Int)? {
        // Remove file extension
        let nameWithoutExt = (filename as NSString).deletingPathExtension
        
        // Pattern: "Episode Name - S01E01"
        let pattern = #"^(.+?)\s*-\s*S(\d+)E(\d+)$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: nameWithoutExt, options: [], range: NSRange(nameWithoutExt.startIndex..., in: nameWithoutExt)) else {
            return nil
        }
        
        guard match.numberOfRanges == 4,
              let titleRange = Range(match.range(at: 1), in: nameWithoutExt),
              let seasonRange = Range(match.range(at: 2), in: nameWithoutExt),
              let episodeRange = Range(match.range(at: 3), in: nameWithoutExt) else {
            return nil
        }
        
        let title = String(nameWithoutExt[titleRange]).trimmingCharacters(in: .whitespaces)
        guard let season = Int(nameWithoutExt[seasonRange]),
              let episode = Int(nameWithoutExt[episodeRange]) else {
            return nil
        }
        
        return (title, season, episode)
    }
}
