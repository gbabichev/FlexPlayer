//
//  Item.swift (or Models.swift)
//  FlexPlayer
//

import Foundation
import SwiftData

@Model
final class VideoProgress {
    var relativePath: String
    var fileName: String
    var currentTime: Double
    var duration: Double
    var lastPlayed: Date
    var watched: Bool

    init(relativePath: String, fileName: String, currentTime: Double = 0, duration: Double = 0, watched: Bool = false) {
        self.relativePath = relativePath
        self.fileName = fileName
        self.currentTime = currentTime
        self.duration = duration
        self.lastPlayed = Date()
        self.watched = watched
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1.0)
    }

    var isCompleted: Bool {
        watched || progress > 0.95
    }
}

// External video reference (not in app container)
@Model
final class ExternalVideo {
    var fileName: String
    var bookmarkData: Data // Security-scoped bookmark
    var dateAdded: Date
    var lastPlayed: Date?

    // Metadata linkage - only one of these will be populated
    var showName: String? // For TV episodes - links to show
    var seasonNumber: Int? // For TV episodes
    var episodeNumber: Int? // For TV episodes
    var movieTmdbId: Int? // For movies - direct TMDB ID

    init(fileName: String, bookmarkData: Data) {
        self.fileName = fileName
        self.bookmarkData = bookmarkData
        self.dateAdded = Date()
    }
}

// TMDB Metadata Models for TV Shows
@Model
final class ShowMetadata {
    var showName: String // Local folder name
    var tmdbId: Int
    var displayName: String // Name from TMDB
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var posterData: Data? // Cached poster image
    var firstAirDate: String?
    var lastUpdated: Date
    
    @Relationship(deleteRule: .cascade) var episodes: [EpisodeMetadata]?
    
    init(showName: String, tmdbId: Int, displayName: String, overview: String? = nil, posterPath: String? = nil, backdropPath: String? = nil, firstAirDate: String? = nil) {
        self.showName = showName
        self.tmdbId = tmdbId
        self.displayName = displayName
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.firstAirDate = firstAirDate
        self.lastUpdated = Date()
    }
}

@Model
final class EpisodeMetadata {
    // Composite key: showName + season + episode (path-independent)
    var showName: String // Links to show folder name
    var seasonNumber: Int
    var episodeNumber: Int
    
    // TMDB metadata
    var tmdbId: Int
    var showTmdbId: Int
    var displayName: String // Episode name from TMDB
    var overview: String?
    var stillPath: String? // Episode thumbnail URL
    var stillData: Data? // Cached thumbnail
    var airDate: String?
    var lastUpdated: Date
    
    init(showName: String, seasonNumber: Int, episodeNumber: Int, tmdbId: Int, showTmdbId: Int, displayName: String, overview: String? = nil, stillPath: String? = nil, airDate: String? = nil) {
        self.showName = showName
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.tmdbId = tmdbId
        self.showTmdbId = showTmdbId
        self.displayName = displayName
        self.overview = overview
        self.stillPath = stillPath
        self.airDate = airDate
        self.lastUpdated = Date()
    }
}

// New Movie Metadata Model
@Model
final class MovieMetadata {
    var fileName: String // Original filename for lookup
    var tmdbId: Int
    var displayName: String // Movie title from TMDB
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var posterData: Data? // Cached poster image
    var releaseDate: String?
    var runtime: Int?
    var lastUpdated: Date
    
    init(fileName: String, tmdbId: Int, displayName: String, overview: String? = nil, posterPath: String? = nil, backdropPath: String? = nil, releaseDate: String? = nil, runtime: Int? = nil) {
        self.fileName = fileName
        self.tmdbId = tmdbId
        self.displayName = displayName
        self.overview = overview
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.releaseDate = releaseDate
        self.runtime = runtime
        self.lastUpdated = Date()
    }
}
