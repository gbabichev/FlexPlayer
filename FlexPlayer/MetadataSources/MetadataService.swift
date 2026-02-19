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

    static var scanOrder: [MetadataSource] {
        [.tmdb, .tvdb]
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
    
    private init() {}
    
    // Search for a show using a specific source
    func searchShow(name: String, source: MetadataSource) async throws -> UnifiedShow? {
        switch source {
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

    // Search for a show across all enabled sources
    func searchShow(name: String) async throws -> UnifiedShow? {
        try await searchShowWithSource(name: name)?.show
    }

    // Search for a show across all enabled sources and return matched source
    func searchShowWithSource(name: String) async throws -> (show: UnifiedShow, source: MetadataSource)? {
        for source in MetadataSource.scanOrder {
            if let show = try await searchShow(name: name, source: source) {
                return (show, source)
            }
        }
        return nil
    }

    // Search for shows from a specific source (returns multiple results)
    func searchShows(name: String, limit: Int = 10, source: MetadataSource) async throws -> [UnifiedShow] {
        switch source {
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

    // Search for shows (returns merged results from all sources)
    func searchShows(name: String, limit: Int = 10) async throws -> [UnifiedShow] {
        var merged: [UnifiedShow] = []
        var seen: Set<String> = []

        for source in MetadataSource.scanOrder {
            let results = try await searchShows(name: name, limit: limit, source: source)
            for result in results {
                let key = "\(result.name.lowercased())|\(result.firstAirDate ?? "")"
                if seen.insert(key).inserted {
                    merged.append(result)
                    if merged.count >= limit {
                        return merged
                    }
                }
            }
        }

        return merged
    }
    
    // Search for a movie using a specific source (returns first result)
    func searchMovie(title: String, source: MetadataSource) async throws -> UnifiedMovie? {
        switch source {
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
            // TVDB movie search is not currently supported in this app
            return nil
        }
    }

    // Search for a movie across all enabled sources
    func searchMovie(title: String) async throws -> UnifiedMovie? {
        try await searchMovieWithSource(title: title)?.movie
    }

    // Search for a movie across all enabled sources and return matched source
    func searchMovieWithSource(title: String) async throws -> (movie: UnifiedMovie, source: MetadataSource)? {
        for source in MetadataSource.scanOrder {
            if let movie = try await searchMovie(title: title, source: source) {
                return (movie, source)
            }
        }
        return nil
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
    
    // Get episode details from a specific source
    func getEpisode(showId: Int, season: Int, episode: Int, source: MetadataSource) async throws -> UnifiedEpisode? {
        switch source {
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

    // Backwards-compatible overload defaults to TMDB
    func getEpisode(showId: Int, season: Int, episode: Int) async throws -> UnifiedEpisode? {
        try await getEpisode(showId: showId, season: season, episode: episode, source: .tmdb)
    }
    
    // Download poster from a specific source
    func downloadPoster(path: String, source: MetadataSource) async throws -> Data {
        switch source {
        case .tmdb:
            return try await TMDBService.shared.downloadPoster(path: path)
        case .tvdb:
            return try await TheTVDBService.shared.downloadImage(path: path)
        }
    }

    // Backwards-compatible overload defaults to TMDB
    func downloadPoster(path: String) async throws -> Data {
        try await downloadPoster(path: path, source: .tmdb)
    }
    
    // Download episode still/thumbnail from a specific source
    func downloadStill(path: String, source: MetadataSource) async throws -> Data {
        switch source {
        case .tmdb:
            return try await TMDBService.shared.downloadStill(path: path)
        case .tvdb:
            return try await TheTVDBService.shared.downloadImage(path: path)
        }
    }

    // Backwards-compatible overload defaults to TMDB
    func downloadStill(path: String) async throws -> Data {
        try await downloadStill(path: path, source: .tmdb)
    }
}
