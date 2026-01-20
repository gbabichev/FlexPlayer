//
//  MetadataService.swift
//  FlexPlayer
//

import Foundation

enum MetadataSource: String, CaseIterable, Codable {
    case tmdb = "TheMovieDB"
    case tvdb = "TheTVDB"
    
    var displayName: String {
        return rawValue
    }
}

// Unified metadata structures
struct UnifiedShow {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let firstAirDate: String?
}

struct UnifiedEpisode {
    let id: Int
    let name: String
    let overview: String?
    let stillPath: String?
    let airDate: String?
}

struct UnifiedMovie {
    let id: Int
    let title: String
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let runtime: Int?
}

class MetadataService {
    static let shared = MetadataService()
    
    private let userDefaultsKey = "selectedMetadataSource"
    
    var selectedSource: MetadataSource {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey),
               let source = MetadataSource(rawValue: rawValue) {
                return source
            }
            return .tmdb // Default to TMDB
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }
    
    private init() {}
    
    // Search for a show
    func searchShow(name: String) async throws -> UnifiedShow? {
        switch selectedSource {
        case .tmdb:
            guard let show = try await TMDBService.shared.searchShow(name: name) else {
                return nil
            }
            return UnifiedShow(
                id: show.id,
                name: show.name,
                overview: show.overview,
                posterPath: show.posterPath,
                backdropPath: show.backdropPath,
                firstAirDate: show.firstAirDate
            )
            
        case .tvdb:
            guard let show = try await TheTVDBService.shared.searchShow(name: name) else {
                return nil
            }
            return UnifiedShow(
                id: show.id,
                name: show.name,
                overview: show.overview,
                posterPath: show.image,
                backdropPath: show.backdrop,
                firstAirDate: show.firstAired
            )
        }
    }

    // Search for shows (returns multiple results)
    func searchShows(name: String, limit: Int = 10) async throws -> [UnifiedShow] {
        switch selectedSource {
        case .tmdb:
            let shows = try await TMDBService.shared.searchShows(name: name, limit: limit)
            return shows.map { show in
                UnifiedShow(
                    id: show.id,
                    name: show.name,
                    overview: show.overview,
                    posterPath: show.posterPath,
                    backdropPath: show.backdropPath,
                    firstAirDate: show.firstAirDate
                )
            }
        case .tvdb:
            let shows = try await TheTVDBService.shared.searchShows(name: name, limit: limit)
            return shows.map { show in
                UnifiedShow(
                    id: show.id,
                    name: show.name,
                    overview: show.overview,
                    posterPath: show.image,
                    backdropPath: show.backdrop,
                    firstAirDate: show.firstAired
                )
            }
        }
    }
    
    // Search for a movie (returns first result)
    func searchMovie(title: String) async throws -> UnifiedMovie? {
        switch selectedSource {
        case .tmdb:
            guard let movie = try await TMDBService.shared.searchMovie(title: title) else {
                return nil
            }
            return UnifiedMovie(
                id: movie.id,
                title: movie.title,
                overview: movie.overview,
                posterPath: movie.posterPath,
                backdropPath: movie.backdropPath,
                releaseDate: movie.releaseDate,
                runtime: movie.runtime
            )

        case .tvdb:
            // TVDB doesn't have great movie support, fallback to TMDB
            guard let movie = try await TMDBService.shared.searchMovie(title: title) else {
                return nil
            }
            return UnifiedMovie(
                id: movie.id,
                title: movie.title,
                overview: movie.overview,
                posterPath: movie.posterPath,
                backdropPath: movie.backdropPath,
                releaseDate: movie.releaseDate,
                runtime: movie.runtime
            )
        }
    }

    // Search for movies (returns multiple results)
    func searchMovies(title: String, limit: Int = 10) async throws -> [UnifiedMovie] {
        // Always use TMDB for movie search
        let movies = try await TMDBService.shared.searchMovies(title: title, limit: limit)
        return movies.map { movie in
            UnifiedMovie(
                id: movie.id,
                title: movie.title,
                overview: movie.overview,
                posterPath: movie.posterPath,
                backdropPath: movie.backdropPath,
                releaseDate: movie.releaseDate,
                runtime: movie.runtime
            )
        }
    }
    
    // Get episode details
    func getEpisode(showId: Int, season: Int, episode: Int) async throws -> UnifiedEpisode? {
        switch selectedSource {
        case .tmdb:
            guard let ep = try await TMDBService.shared.getEpisode(showId: showId, season: season, episode: episode) else {
                return nil
            }
            return UnifiedEpisode(
                id: ep.id,
                name: ep.name,
                overview: ep.overview,
                stillPath: ep.stillPath,
                airDate: ep.airDate
            )
            
        case .tvdb:
            guard let ep = try await TheTVDBService.shared.getEpisode(showId: showId, season: season, episode: episode) else {
                return nil
            }
            return UnifiedEpisode(
                id: ep.id,
                name: ep.name,
                overview: ep.overview,
                stillPath: ep.image,
                airDate: ep.aired
            )
        }
    }
    
    // Download poster
    func downloadPoster(path: String) async throws -> Data {
        switch selectedSource {
        case .tmdb:
            return try await TMDBService.shared.downloadPoster(path: path)
        case .tvdb:
            return try await TheTVDBService.shared.downloadImage(path: path)
        }
    }
    
    // Download episode still/thumbnail
    func downloadStill(path: String) async throws -> Data {
        switch selectedSource {
        case .tmdb:
            return try await TMDBService.shared.downloadStill(path: path)
        case .tvdb:
            return try await TheTVDBService.shared.downloadImage(path: path)
        }
    }
}
