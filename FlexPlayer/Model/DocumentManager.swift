//
//  DocumentManager.swift
//  FlexPlayer
//

import Foundation
import SwiftData
import Combine

struct LibrarySortResult: Sendable {
    let scannedFiles: Int
    let movedFiles: Int
    let alreadySortedFiles: Int
    let unclassifiedFiles: [String]
    let failedMoves: [String]

    var unclassifiedCount: Int { unclassifiedFiles.count }
    var failedCount: Int { failedMoves.count }

    var isClean: Bool {
        movedFiles == 0 && unclassifiedFiles.isEmpty && failedMoves.isEmpty
    }
}

class DocumentManager: ObservableObject {
    @Published var shows: [Show] = []
    @Published var movies: [Movie] = []
    @Published var isLoadingMetadata = false
    @Published var isSortingLibrary = false
    @Published var lastSortResult: LibrarySortResult?
    @Published var sortErrorMessage: String?
    private var cachedModelContextForSort: ModelContext?

    func loadDocuments(modelContext: ModelContext, completion: (() -> Void)? = nil) {
        print("\n📚 ========== LOADING DOCUMENTS ==========")

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not access documents directory")
            DispatchQueue.main.async {
                completion?()
            }
            return
        }

        print("📂 Documents path: \(documentsURL.path)")

        do {
            var loadedShows: [Show] = []
            var loadedMovies: [Movie] = []

            var metadataDescriptor = FetchDescriptor<ShowMetadata>()
            metadataDescriptor.includePendingChanges = false
            let allShowMetadata = (try? modelContext.fetch(metadataDescriptor)) ?? []
            print("💾 Found \(allShowMetadata.count) ShowMetadata records in SwiftData")

            var episodeDescriptor = FetchDescriptor<EpisodeMetadata>()
            episodeDescriptor.includePendingChanges = false
            let allEpisodeMetadata = (try? modelContext.fetch(episodeDescriptor)) ?? []
            print("💾 Found \(allEpisodeMetadata.count) EpisodeMetadata records in SwiftData")

            var movieDescriptor = FetchDescriptor<MovieMetadata>()
            movieDescriptor.includePendingChanges = false
            let allMovieMetadata = (try? modelContext.fetch(movieDescriptor)) ?? []
            print("💾 Found \(allMovieMetadata.count) MovieMetadata records in SwiftData")

            // Load Movies
            let moviesURL = documentsURL.appendingPathComponent("Movies")
            if FileManager.default.fileExists(atPath: moviesURL.path) {
                print("\n🎬 Processing Movies folder")
                let movieFiles = try FileManager.default.contentsOfDirectory(
                    at: moviesURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                for fileURL in movieFiles where isVideoFile(fileURL) {
                    let fileName = fileURL.lastPathComponent
                    let movieMetadata = allMovieMetadata.first { $0.fileName == fileName }

                    if let movieMetadata = movieMetadata {
                        print("   ✅ Found MovieMetadata for '\(fileName)'")
                        print("      - Display Name: \(movieMetadata.displayName)")
                        print("      - Poster Data: \(movieMetadata.posterData?.count ?? 0) bytes")
                    } else {
                        print("   ❌ No MovieMetadata found for '\(fileName)'")
                    }

                    loadedMovies.append(Movie(
                        name: fileName,
                        url: fileURL,
                        metadata: movieMetadata
                    ))
                }

                print("🎬 Added \(loadedMovies.count) movie(s)")
            }

            // Load Shows
            let showsURL = documentsURL.appendingPathComponent("Shows")
            if FileManager.default.fileExists(atPath: showsURL.path) {
                // First, scan for loose files in the Shows root directory
                var looseFilesByShow: [String: [VideoFile]] = [:]

                let showsContents = try FileManager.default.contentsOfDirectory(
                    at: showsURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                print("\n📺 Scanning Shows directory for loose files...")
                for item in showsContents {
                    var isItemDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: item.path, isDirectory: &isItemDirectory)

                    // If it's a video file directly in Shows/
                    if !isItemDirectory.boolValue && isVideoFile(item) {
                        // Try to parse the show name from the filename
                        if let episodeInfo = EpisodeParser.parse(filename: item.lastPathComponent) {
                            let showName = episodeInfo.title
                            print("   📹 Found loose file: \(item.lastPathComponent) -> Show: \(showName)")

                            if looseFilesByShow[showName] == nil {
                                looseFilesByShow[showName] = []
                            }
                            looseFilesByShow[showName]?.append(createVideoFile(from: item, allEpisodeMetadata: allEpisodeMetadata))
                        }
                    }
                }

                // Now process show directories and merge with loose files
                let showDirectories = showsContents.filter { item in
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory)
                    return isDirectory.boolValue
                }

                for directory in showDirectories {
                    let showName = directory.lastPathComponent

                    // Skip the "Imported" folder - it's for external videos
                    if showName == "Imported" {
                        print("\n📺 Skipping 'Imported' folder (used for external videos)")
                        continue
                    }

                    print("\n📺 Processing show folder: \(showName)")

                    let showMetadata = allShowMetadata.first { $0.showName == showName }
                    if let showMetadata = showMetadata {
                        print("   ✅ Found ShowMetadata for '\(showName)'")
                        print("      - Display Name: \(showMetadata.displayName)")
                        print("      - TMDB ID: \(showMetadata.tmdbId)")
                        print("      - Poster Data: \(showMetadata.posterData?.count ?? 0) bytes")
                    } else {
                        print("   ❌ No ShowMetadata found for '\(showName)'")
                    }

                    var files: [VideoFile] = []

                    // Add loose files if any exist for this show
                    if let looseFiles = looseFilesByShow[showName] {
                        print("   📹 Adding \(looseFiles.count) loose file(s) from Shows root")
                        files.append(contentsOf: looseFiles)
                    }

                    let showContents = try FileManager.default.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )

                    for item in showContents {
                        var isItemDirectory: ObjCBool = false
                        FileManager.default.fileExists(atPath: item.path, isDirectory: &isItemDirectory)

                        if isItemDirectory.boolValue {
                            let seasonFiles = try FileManager.default.contentsOfDirectory(
                                at: item,
                                includingPropertiesForKeys: nil,
                                options: [.skipsHiddenFiles]
                            )

                            for fileURL in seasonFiles where isVideoFile(fileURL) {
                                files.append(createVideoFile(from: fileURL, allEpisodeMetadata: allEpisodeMetadata))
                            }
                        } else if isVideoFile(item) {
                            files.append(createVideoFile(from: item, allEpisodeMetadata: allEpisodeMetadata))
                        }
                    }

                    if !files.isEmpty {
                        loadedShows.append(Show(name: showName, files: files, metadata: showMetadata))
                        print("📺 Added show: \(showName) with \(files.count) file(s)")

                        let filesWithMetadata = files.filter { $0.metadata != nil }
                        let filesWithStills = files.filter { $0.metadata?.stillData != nil }
                        print("   - Files with metadata: \(filesWithMetadata.count)/\(files.count)")
                        print("   - Files with thumbnail data: \(filesWithStills.count)/\(files.count)")
                    }
                }

                // Add any loose file shows that don't have a matching directory
                for (showName, files) in looseFilesByShow {
                    // Check if we already processed this show via directory
                    if loadedShows.contains(where: { $0.name == showName }) {
                        continue
                    }

                    print("\n📺 Creating show from loose files only: \(showName)")
                    let showMetadata = allShowMetadata.first { $0.showName == showName }

                    if let showMetadata = showMetadata {
                        print("   ✅ Found ShowMetadata for '\(showName)'")
                        print("      - Display Name: \(showMetadata.displayName)")
                        print("      - TMDB ID: \(showMetadata.tmdbId)")
                        print("      - Poster Data: \(showMetadata.posterData?.count ?? 0) bytes")
                    } else {
                        print("   ❌ No ShowMetadata found for '\(showName)'")
                    }

                    loadedShows.append(Show(name: showName, files: files, metadata: showMetadata))
                    print("📺 Added show: \(showName) with \(files.count) file(s)")

                    let filesWithMetadata = files.filter { $0.metadata != nil }
                    let filesWithStills = files.filter { $0.metadata?.stillData != nil }
                    print("   - Files with metadata: \(filesWithMetadata.count)/\(files.count)")
                    print("   - Files with thumbnail data: \(filesWithStills.count)/\(files.count)")
                }
            }

            DispatchQueue.main.async {
                self.shows = loadedShows.sorted { $0.name < $1.name }
                self.movies = loadedMovies.sorted { ($0.metadata?.displayName ?? $0.name) < ($1.metadata?.displayName ?? $1.name) }
                print("\n✅ ========== LOADED \(self.shows.count) SHOW(S) AND \(self.movies.count) MOVIE(S) ==========\n")
                completion?()
            }

        } catch {
            print("⚠️ Error loading documents: \(error)")
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    func autoSortLibrary(modelContext: ModelContext) {
        cachedModelContextForSort = modelContext
        isSortingLibrary = true
        sortErrorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let result = try LibraryFileSorter.sortLibraryFiles()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.lastSortResult = result
                    guard let refreshContext = self.cachedModelContextForSort else {
                        self.isSortingLibrary = false
                        return
                    }
                    self.loadDocuments(modelContext: refreshContext) { self.isSortingLibrary = false }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.sortErrorMessage = error.localizedDescription
                    self.isSortingLibrary = false
                }
            }
        }
    }

    private func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "m4v", "mov", "avi", "mkv"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }

    private func createVideoFile(from fileURL: URL, allEpisodeMetadata: [EpisodeMetadata]) -> VideoFile {
        let episodeInfo = EpisodeParser.parse(filename: fileURL.lastPathComponent)

        var episodeMetadata: EpisodeMetadata?
        if let info = episodeInfo {
            let season = info.season
            let episode = info.episode
            let parentPath = fileURL.deletingLastPathComponent()
            let grandparentPath = parentPath.deletingLastPathComponent()

            let showName: String
            // Check if this is a loose file in the Shows root directory
            if parentPath.lastPathComponent == "Shows" {
                // Use the show name parsed from the filename
                showName = info.title
            } else if parentPath.lastPathComponent.lowercased().contains("season") {
                // File is in a Season subfolder
                showName = grandparentPath.lastPathComponent
            } else {
                // File is directly in the show folder
                showName = parentPath.lastPathComponent
            }

            episodeMetadata = allEpisodeMetadata.first {
                $0.showName == showName &&
                $0.seasonNumber == season &&
                $0.episodeNumber == episode
            }

            if episodeMetadata != nil {
                print("      ✅ Found EpisodeMetadata for \(fileURL.lastPathComponent)")
            } else {
                print("      ❌ No EpisodeMetadata found for \(fileURL.lastPathComponent)")
            }
        }

        return VideoFile(
            name: fileURL.lastPathComponent,
            url: fileURL,
            episodeInfo: episodeInfo.map { ($0.season, $0.episode) },
            metadata: episodeMetadata
        )
    }

    func clearAllMetadata(modelContext: ModelContext) {
        guard !isLoadingMetadata else {
            print("⚠️ Cannot clear metadata while fetch is in progress")
            return
        }

        print("\n🗑️ ========== CLEARING ALL METADATA ==========")

        do {
            var showDescriptor = FetchDescriptor<ShowMetadata>()
            showDescriptor.includePendingChanges = false
            let allShowMetadata = try modelContext.fetch(showDescriptor)
            print("📊 Found \(allShowMetadata.count) ShowMetadata records to delete")

            var episodeDescriptor = FetchDescriptor<EpisodeMetadata>()
            episodeDescriptor.includePendingChanges = false
            let allEpisodeMetadata = try modelContext.fetch(episodeDescriptor)
            print("📊 Found \(allEpisodeMetadata.count) EpisodeMetadata records to delete")

            var movieDescriptor = FetchDescriptor<MovieMetadata>()
            movieDescriptor.includePendingChanges = false
            let allMovieMetadata = try modelContext.fetch(movieDescriptor)
            print("📊 Found \(allMovieMetadata.count) MovieMetadata records to delete")

            for show in allShowMetadata {
                print("   🗑️ Deleting ShowMetadata: \(show.showName)")
                modelContext.delete(show)
            }

            for episode in allEpisodeMetadata {
                print("   🗑️ Deleting EpisodeMetadata: S\(episode.seasonNumber)E\(episode.episodeNumber)")
                modelContext.delete(episode)
            }

            for movie in allMovieMetadata {
                print("   🗑️ Deleting MovieMetadata: \(movie.displayName)")
                modelContext.delete(movie)
            }

            try modelContext.save()
            modelContext.processPendingChanges()

            // Immediately reflect cleared metadata in the current in-memory view models.
            shows = shows.map { show in
                let filesWithoutMetadata = show.files.map { file in
                    VideoFile(
                        name: file.name,
                        url: file.url,
                        episodeInfo: file.episodeInfo,
                        metadata: nil
                    )
                }
                return Show(name: show.name, files: filesWithoutMetadata, metadata: nil)
            }
            movies = movies.map { movie in
                Movie(name: movie.name, url: movie.url, metadata: nil)
            }

            let remainingShows = (try? modelContext.fetch(showDescriptor).count) ?? -1
            let remainingEpisodes = (try? modelContext.fetch(episodeDescriptor).count) ?? -1
            let remainingMovies = (try? modelContext.fetch(movieDescriptor).count) ?? -1
            print("🧪 Remaining metadata after clear - shows: \(remainingShows), episodes: \(remainingEpisodes), movies: \(remainingMovies)")

            print("✅ Cleared all metadata and saved context")
            print("========================================\n")

            loadDocuments(modelContext: modelContext)

        } catch {
            print("⚠️ Error clearing metadata: \(error)")
        }
    }

    func fetchMetadata(for shows: [Show], movies: [Movie], externalVideos: [ExternalVideo] = [], modelContext: ModelContext) async {
        print("\n🌐 ========== FETCHING METADATA ==========")
        print("📡 Scanning sources: \(MetadataSource.scanOrder.map(\.displayName).joined(separator: ", "))")

        DispatchQueue.main.async {
            self.isLoadingMetadata = true
        }

        // Fetch external video metadata first
        if !externalVideos.isEmpty {
            await fetchMetadataForExternalVideos(externalVideos, modelContext: modelContext)
        }

        // Fetch show metadata
        for show in shows {
            print("\n📺 Processing show: \(show.name)")

            let needsShowMetadata = show.metadata == nil ||
                Date().timeIntervalSince(show.metadata!.lastUpdated) >= 7 * 24 * 60 * 60

            print("   Show metadata needed: \(needsShowMetadata)")

            let needsEpisodeWork = show.files.contains { file in
                guard file.episodeInfo != nil else { return false }

                if file.metadata == nil {
                    return true
                }
                if let metadata = file.metadata {
                    return metadata.stillData == nil ||
                           Date().timeIntervalSince(metadata.lastUpdated) >= 7 * 24 * 60 * 60
                }
                return false
            }

            print("   Episode work needed: \(needsEpisodeWork)")

            if !needsShowMetadata && !needsEpisodeWork {
                print("   ⏭️ Skipping \(show.name) - all metadata current")
                continue
            }

            do {
                print("   🔍 Searching for show across sources...")
                let searchResult = try await MetadataService.shared.searchShowWithSource(name: show.name)

                let unifiedShow: UnifiedShow
                let showSource: MetadataSource

                if let searchResult {
                    unifiedShow = searchResult.show
                    showSource = searchResult.source
                    print("   ✅ Found match: \(unifiedShow.name) (ID: \(unifiedShow.id), Source: \(showSource.displayName))")
                } else if let metadata = show.metadata {
                    unifiedShow = UnifiedShow(
                        id: metadata.tmdbId,
                        name: metadata.displayName,
                        overview: metadata.overview,
                        posterPath: metadata.posterPath,
                        backdropPath: metadata.backdropPath,
                        firstAirDate: metadata.firstAirDate
                    )
                    showSource = .tmdb
                    print("   ⚠️ No source match found. Falling back to cached show metadata.")
                } else {
                    print("   ⚠️ No results for \(show.name)")
                    continue
                }

                if needsShowMetadata {
                    let showMetadata: ShowMetadata
                    if let existing = show.metadata {
                        print("   🔄 Updating existing ShowMetadata")
                        showMetadata = existing
                        showMetadata.displayName = unifiedShow.name
                        showMetadata.overview = unifiedShow.overview
                        showMetadata.posterPath = unifiedShow.posterPath
                        showMetadata.backdropPath = unifiedShow.backdropPath
                        showMetadata.firstAirDate = unifiedShow.firstAirDate
                        showMetadata.lastUpdated = Date()
                    } else {
                        print("   ➕ Creating new ShowMetadata")
                        showMetadata = ShowMetadata(
                            showName: show.name,
                            tmdbId: unifiedShow.id,
                            displayName: unifiedShow.name,
                            overview: unifiedShow.overview,
                            posterPath: unifiedShow.posterPath,
                            backdropPath: unifiedShow.backdropPath,
                            firstAirDate: unifiedShow.firstAirDate
                        )
                        modelContext.insert(showMetadata)
                    }

                    if let posterPath = unifiedShow.posterPath, showMetadata.posterData == nil {
                        do {
                            print("   📥 Downloading poster...")
                            let posterData = try await MetadataService.shared.downloadPoster(path: posterPath, source: showSource)
                            showMetadata.posterData = posterData
                            print("   ✅ Downloaded poster (\(posterData.count) bytes)")
                        } catch {
                            print("   ⚠️ Failed to download poster: \(error)")
                        }
                    }
                } else {
                    print("   ✅ Using cached show metadata, checking episodes...")
                }

                for file in show.files {
                    guard let (season, episode) = file.episodeInfo else { continue }

                    print("   📹 Checking S\(season)E\(episode): \(file.name)")

                    let needsStill = file.metadata?.stillData == nil && file.metadata?.stillPath != nil

                    if let metadata = file.metadata,
                       Date().timeIntervalSince(metadata.lastUpdated) < 7 * 24 * 60 * 60,
                       metadata.stillData != nil {
                        print("      ⏭️ Episode metadata current, skipping")
                        continue
                    }

                    do {
                        if needsStill, let existing = file.metadata {
                            if let stillPath = existing.stillPath {
                                do {
                                    print("      📥 Downloading missing thumbnail...")
                                    let stillData = try await MetadataService.shared.downloadStill(path: stillPath, source: showSource)
                                    existing.stillData = stillData
                                    print("      ✅ Downloaded missing thumbnail (\(stillData.count) bytes)")
                                    continue
                                } catch {
                                    print("      ⚠️ Failed to download thumbnail: \(error)")
                                }
                            }
                        }

                        print("      🔍 Fetching episode details...")
                        guard let unifiedEpisode = try await MetadataService.shared.getEpisode(
                            showId: unifiedShow.id,
                            season: season,
                            episode: episode,
                            source: showSource
                        ) else {
                            print("      ⚠️ No data for S\(season)E\(episode)")
                            continue
                        }

                        let episodeMetadata: EpisodeMetadata
                        if let existing = file.metadata {
                            print("      🔄 Updating existing EpisodeMetadata")
                            episodeMetadata = existing
                            episodeMetadata.displayName = unifiedEpisode.name
                            episodeMetadata.overview = unifiedEpisode.overview
                            episodeMetadata.stillPath = unifiedEpisode.stillPath
                            episodeMetadata.airDate = unifiedEpisode.airDate
                            episodeMetadata.lastUpdated = Date()
                        } else {
                            print("      ➕ Creating new EpisodeMetadata")
                            episodeMetadata = EpisodeMetadata(
                                showName: show.name,
                                seasonNumber: season,
                                episodeNumber: episode,
                                tmdbId: unifiedEpisode.id,
                                showTmdbId: unifiedShow.id,
                                displayName: unifiedEpisode.name,
                                overview: unifiedEpisode.overview,
                                stillPath: unifiedEpisode.stillPath,
                                airDate: unifiedEpisode.airDate
                            )
                            modelContext.insert(episodeMetadata)
                        }

                        if let stillPath = unifiedEpisode.stillPath, episodeMetadata.stillData == nil {
                            do {
                                print("      📥 Downloading thumbnail...")
                                let stillData = try await MetadataService.shared.downloadStill(path: stillPath, source: showSource)
                                episodeMetadata.stillData = stillData
                                print("      ✅ Downloaded thumbnail (\(stillData.count) bytes)")
                            } catch {
                                print("      ⚠️ Failed to download thumbnail: \(error)")
                                await VideoThumbnailGenerator.generateAndStoreThumbnail(
                                    for: file,
                                    in: episodeMetadata,
                                    modelContext: modelContext
                                )
                            }
                        } else if episodeMetadata.stillData == nil {
                            print("      📷 No remote thumbnail available")
                            await VideoThumbnailGenerator.generateAndStoreThumbnail(
                                for: file,
                                in: episodeMetadata,
                                modelContext: modelContext
                            )
                        }

                        print("      ✅ Fetched metadata: \(unifiedEpisode.name)")

                    } catch {
                        print("      ⚠️ Failed to fetch episode S\(season)E\(episode): \(error)")

                        if let existing = file.metadata, existing.stillData == nil {
                            await VideoThumbnailGenerator.generateAndStoreThumbnail(
                                for: file,
                                in: existing,
                                modelContext: modelContext
                            )
                        }
                    }
                }

                print("   💾 Saving context...")
                try? modelContext.save()
                print("   ✅ Context saved")

            } catch {
                print("   ⚠️ Error fetching metadata for \(show.name): \(error)")
            }
        }

        // Fetch movie metadata
        for movie in movies {
            print("\n🎬 Processing movie: \(movie.name)")

            let needsMetadata = movie.metadata == nil ||
                Date().timeIntervalSince(movie.metadata!.lastUpdated) >= 7 * 24 * 60 * 60

            print("   Movie metadata needed: \(needsMetadata)")

            if !needsMetadata, let metadata = movie.metadata, metadata.posterData != nil {
                print("   ⏭️ Skipping \(movie.name) - metadata current")
                continue
            }

            do {
                // Clean up filename for search (remove extension, year, etc.)
                let searchTitle = cleanMovieTitle(movie.name)
                print("   🔍 Searching for movie across sources: \(searchTitle)")

                guard let movieResult = try await MetadataService.shared.searchMovieWithSource(title: searchTitle) else {
                    print("   ⚠️ No results for \(searchTitle)")
                    continue
                }
                let unifiedMovie = movieResult.movie
                let movieSource = movieResult.source

                print("   ✅ Found match: \(unifiedMovie.title) (ID: \(unifiedMovie.id), Source: \(movieSource.displayName))")

                let movieMetadata: MovieMetadata
                var posterPathChanged = false

                if let existing = movie.metadata {
                    print("   🔄 Updating existing MovieMetadata")
                    movieMetadata = existing
                    // Check if poster path is changing
                    posterPathChanged = movieMetadata.posterPath != unifiedMovie.posterPath
                    movieMetadata.displayName = unifiedMovie.title
                    movieMetadata.overview = unifiedMovie.overview
                    movieMetadata.posterPath = unifiedMovie.posterPath
                    movieMetadata.backdropPath = unifiedMovie.backdropPath
                    movieMetadata.releaseDate = unifiedMovie.releaseDate
                    movieMetadata.runtime = unifiedMovie.runtime
                    movieMetadata.lastUpdated = Date()
                } else {
                    print("   ➕ Creating new MovieMetadata")
                    movieMetadata = MovieMetadata(
                        fileName: movie.name,
                        tmdbId: unifiedMovie.id,
                        displayName: unifiedMovie.title,
                        overview: unifiedMovie.overview,
                        posterPath: unifiedMovie.posterPath,
                        backdropPath: unifiedMovie.backdropPath,
                        releaseDate: unifiedMovie.releaseDate,
                        runtime: unifiedMovie.runtime
                    )
                    modelContext.insert(movieMetadata)
                }

                // Download poster if: no poster data exists, OR poster path changed
                if let posterPath = unifiedMovie.posterPath,
                   (movieMetadata.posterData == nil || posterPathChanged) {
                    do {
                        print("   📥 Downloading poster\(posterPathChanged ? " (poster path changed)" : "")...")
                        let posterData = try await MetadataService.shared.downloadPoster(path: posterPath, source: movieSource)
                        movieMetadata.posterData = posterData
                        print("   ✅ Downloaded poster (\(posterData.count) bytes)")
                    } catch {
                        print("   ⚠️ Failed to download poster: \(error)")
                    }
                }

                print("   💾 Saving context...")
                try? modelContext.save()
                print("   ✅ Context saved")

            } catch {
                print("   ⚠️ Error fetching metadata for \(movie.name): \(error)")
            }
        }

        print("\n✅ ========== METADATA FETCH COMPLETE ==========\n")
        self.loadDocuments(modelContext: modelContext) {
            self.isLoadingMetadata = false
        }
    }

    private func cleanMovieTitle(_ filename: String) -> String {
        var title = filename

        // Remove file extension
        if let lastDot = title.lastIndex(of: ".") {
            title = String(title[..<lastDot])
        }

        // Remove year in parentheses or brackets
        title = title.replacingOccurrences(of: #"\s*[\(\[]\d{4}[\)\]]"#, with: "", options: .regularExpression)

        // Remove common quality indicators
        let qualityPatterns = ["1080p", "720p", "2160p", "4K", "BluRay", "WEB-DL", "WEBRip", "HDRip", "BRRip"]
        for pattern in qualityPatterns {
            title = title.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }

        // Replace dots, underscores with spaces
        title = title.replacingOccurrences(of: ".", with: " ")
        title = title.replacingOccurrences(of: "_", with: " ")

        // Trim whitespace
        title = title.trimmingCharacters(in: .whitespaces)

        return title
    }

    func fetchMetadataForExternalVideos(_ externalVideos: [ExternalVideo], modelContext: ModelContext) async {
        print("\n🌐 ========== FETCHING EXTERNAL VIDEO METADATA ==========")

        for video in externalVideos {
            print("\n📹 Processing external video: \(video.fileName)")

            // Check if it's a TV show episode
            if let episodeInfo = EpisodeParser.parse(filename: video.fileName) {
                print("   📺 Detected TV Show: \(episodeInfo.title) S\(episodeInfo.season)E\(episodeInfo.episode)")
                await fetchShowMetadataForExternal(video: video, showTitle: episodeInfo.title, season: episodeInfo.season, episode: episodeInfo.episode, modelContext: modelContext)
            } else {
                // Treat as movie
                print("   🎬 Detected Movie")
                await fetchMovieMetadataForExternal(video: video, modelContext: modelContext)
            }
        }

        print("\n✅ ========== EXTERNAL VIDEO METADATA FETCH COMPLETE ==========\n")
    }

    private func fetchShowMetadataForExternal(video: ExternalVideo, showTitle: String, season: Int, episode: Int, modelContext: ModelContext) async {
        do {
            // Search for the show
            print("   🔍 Searching for show across sources: \(showTitle)")
            guard let showResult = try await MetadataService.shared.searchShowWithSource(name: showTitle) else {
                print("   ⚠️ No results for \(showTitle)")
                return
            }
            let unifiedShow = showResult.show
            let showSource = showResult.source

            print("   ✅ Found match: \(unifiedShow.name) (ID: \(unifiedShow.id), Source: \(showSource.displayName))")

            // Link video to show
            video.showName = showTitle
            video.seasonNumber = season
            video.episodeNumber = episode

            // Check if ShowMetadata exists for this show
            let showDescriptor = FetchDescriptor<ShowMetadata>(
                predicate: #Predicate { metadata in
                    metadata.showName == showTitle
                }
            )

            let showMetadata: ShowMetadata
            if let existing = try? modelContext.fetch(showDescriptor).first {
                print("   🔄 Using existing ShowMetadata")
                showMetadata = existing
            } else {
                print("   ➕ Creating new ShowMetadata")
                showMetadata = ShowMetadata(
                    showName: showTitle,
                    tmdbId: unifiedShow.id,
                    displayName: unifiedShow.name,
                    overview: unifiedShow.overview,
                    posterPath: unifiedShow.posterPath,
                    backdropPath: unifiedShow.backdropPath,
                    firstAirDate: unifiedShow.firstAirDate
                )
                modelContext.insert(showMetadata)

                // Download poster
                if let posterPath = unifiedShow.posterPath {
                    do {
                        print("   📥 Downloading poster...")
                        let posterData = try await MetadataService.shared.downloadPoster(path: posterPath, source: showSource)
                        showMetadata.posterData = posterData
                        print("   ✅ Downloaded poster (\(posterData.count) bytes)")
                    } catch {
                        print("   ⚠️ Failed to download poster: \(error)")
                    }
                }
            }

            // Fetch episode metadata
            print("   🔍 Fetching episode S\(season)E\(episode)...")
            guard let unifiedEpisode = try await MetadataService.shared.getEpisode(
                showId: unifiedShow.id,
                season: season,
                episode: episode,
                source: showSource
            ) else {
                print("   ⚠️ No data for S\(season)E\(episode)")
                try? modelContext.save()
                return
            }

            // Check if EpisodeMetadata exists
            let episodeDescriptor = FetchDescriptor<EpisodeMetadata>(
                predicate: #Predicate { metadata in
                    metadata.showName == showTitle &&
                    metadata.seasonNumber == season &&
                    metadata.episodeNumber == episode
                }
            )

            let episodeMetadata: EpisodeMetadata
            if let existing = try? modelContext.fetch(episodeDescriptor).first {
                print("   🔄 Updating existing EpisodeMetadata")
                episodeMetadata = existing
                episodeMetadata.displayName = unifiedEpisode.name
                episodeMetadata.overview = unifiedEpisode.overview
                episodeMetadata.stillPath = unifiedEpisode.stillPath
                episodeMetadata.airDate = unifiedEpisode.airDate
                episodeMetadata.lastUpdated = Date()
            } else {
                print("   ➕ Creating new EpisodeMetadata")
                episodeMetadata = EpisodeMetadata(
                    showName: showTitle,
                    seasonNumber: season,
                    episodeNumber: episode,
                    tmdbId: unifiedEpisode.id,
                    showTmdbId: unifiedShow.id,
                    displayName: unifiedEpisode.name,
                    overview: unifiedEpisode.overview,
                    stillPath: unifiedEpisode.stillPath,
                    airDate: unifiedEpisode.airDate
                )
                modelContext.insert(episodeMetadata)
            }

            // Download episode still
            if let stillPath = unifiedEpisode.stillPath, episodeMetadata.stillData == nil {
                do {
                    print("   📥 Downloading episode thumbnail...")
                    let stillData = try await MetadataService.shared.downloadStill(path: stillPath, source: showSource)
                    episodeMetadata.stillData = stillData
                    print("   ✅ Downloaded thumbnail (\(stillData.count) bytes)")
                } catch {
                    print("   ⚠️ Failed to download thumbnail: \(error)")
                }
            }

            try? modelContext.save()
            print("   ✅ Saved metadata for external video")

        } catch {
            print("   ⚠️ Error fetching metadata: \(error)")
        }
    }

    private func fetchMovieMetadataForExternal(video: ExternalVideo, modelContext: ModelContext) async {
        do {
            let searchTitle = cleanMovieTitle(video.fileName)
            print("   🔍 Searching for movie across sources: \(searchTitle)")

            guard let movieResult = try await MetadataService.shared.searchMovieWithSource(title: searchTitle) else {
                print("   ⚠️ No results for \(searchTitle)")
                return
            }
            let unifiedMovie = movieResult.movie
            let movieSource = movieResult.source

            print("   ✅ Found match: \(unifiedMovie.title) (ID: \(unifiedMovie.id), Source: \(movieSource.displayName))")

            // Link video to movie
            video.movieTmdbId = unifiedMovie.id

            // Check if MovieMetadata exists
            let movieId = unifiedMovie.id
            let movieDescriptor = FetchDescriptor<MovieMetadata>(
                predicate: #Predicate { metadata in
                    metadata.tmdbId == movieId
                }
            )

            let movieMetadata: MovieMetadata
            if let existing = try? modelContext.fetch(movieDescriptor).first {
                print("   🔄 Using existing MovieMetadata")
                movieMetadata = existing
            } else {
                print("   ➕ Creating new MovieMetadata")
                movieMetadata = MovieMetadata(
                    fileName: video.fileName,
                    tmdbId: unifiedMovie.id,
                    displayName: unifiedMovie.title,
                    overview: unifiedMovie.overview,
                    posterPath: unifiedMovie.posterPath,
                    backdropPath: unifiedMovie.backdropPath,
                    releaseDate: unifiedMovie.releaseDate,
                    runtime: unifiedMovie.runtime
                )
                modelContext.insert(movieMetadata)

                // Download poster
                if let posterPath = unifiedMovie.posterPath {
                    do {
                        print("   📥 Downloading poster...")
                        let posterData = try await MetadataService.shared.downloadPoster(path: posterPath, source: movieSource)
                        movieMetadata.posterData = posterData
                        print("   ✅ Downloaded poster (\(posterData.count) bytes)")
                    } catch {
                        print("   ⚠️ Failed to download poster: \(error)")
                    }
                }
            }

            try? modelContext.save()
            print("   ✅ Saved metadata for external video")

        } catch {
            print("   ⚠️ Error fetching metadata: \(error)")
        }
    }
}

private enum LibraryFileSorter {
    private enum SortTarget {
        case episode(showTitle: String)
        case movie
        case unknown
    }

    private enum SortError: LocalizedError {
        case documentsUnavailable

        var errorDescription: String? {
            switch self {
            case .documentsUnavailable:
                return "Could not access the Documents directory."
            }
        }
    }

    nonisolated static func sortLibraryFiles() throws -> LibrarySortResult {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw SortError.documentsUnavailable
        }

        let moviesURL = documentsURL.appendingPathComponent("Movies")
        let showsURL = documentsURL.appendingPathComponent("Shows")

        try fileManager.createDirectory(at: moviesURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: showsURL, withIntermediateDirectories: true)

        let videoFiles = collectVideoFilesForSorting(in: documentsURL)

        var movedFiles = 0
        var alreadySortedFiles = 0
        var unclassifiedFiles: [String] = []
        var failedMoves: [String] = []

        for fileURL in videoFiles {
            let fileName = fileURL.lastPathComponent
            switch classifySortTarget(for: fileName) {
            case .episode(let showTitle):
                let showFolderName = sanitizeFolderName(showTitle)
                let showFolder = showsURL.appendingPathComponent(showFolderName, isDirectory: true)
                let showPrefix = showFolder.standardizedFileURL.path + "/"

                if fileURL.standardizedFileURL.path.hasPrefix(showPrefix) {
                    alreadySortedFiles += 1
                    continue
                }

                do {
                    try fileManager.createDirectory(at: showFolder, withIntermediateDirectories: true)
                    let destination = uniqueDestinationURL(for: fileURL, in: showFolder)
                    try fileManager.moveItem(at: fileURL, to: destination)
                    movedFiles += 1
                } catch {
                    failedMoves.append("\(fileName): \(error.localizedDescription)")
                }

            case .movie:
                let moviesPrefix = moviesURL.standardizedFileURL.path + "/"

                if fileURL.standardizedFileURL.path.hasPrefix(moviesPrefix) {
                    alreadySortedFiles += 1
                    continue
                }

                do {
                    let destination = uniqueDestinationURL(for: fileURL, in: moviesURL)
                    try fileManager.moveItem(at: fileURL, to: destination)
                    movedFiles += 1
                } catch {
                    failedMoves.append("\(fileName): \(error.localizedDescription)")
                }

            case .unknown:
                unclassifiedFiles.append(fileName)
            }
        }

        return LibrarySortResult(
            scannedFiles: videoFiles.count,
            movedFiles: movedFiles,
            alreadySortedFiles: alreadySortedFiles,
            unclassifiedFiles: unclassifiedFiles,
            failedMoves: failedMoves
        )
    }

    nonisolated private static func collectVideoFilesForSorting(in documentsURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: documentsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        let importedPath = documentsURL.appendingPathComponent("Shows/Imported").standardizedFileURL.path

        for case let fileURL as URL in enumerator {
            let standardizedPath = fileURL.standardizedFileURL.path

            if standardizedPath == importedPath || standardizedPath.hasPrefix(importedPath + "/") {
                if (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }

            if isVideoFileForSort(fileURL) {
                files.append(fileURL)
            }
        }

        return files
    }

    nonisolated private static func classifySortTarget(for fileName: String) -> SortTarget {
        if let episodeInfo = EpisodeParser.parse(filename: fileName) {
            return .episode(showTitle: episodeInfo.title)
        }

        let nameWithoutExtension = (fileName as NSString).deletingPathExtension
        let trimmedName = nameWithoutExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let moviePattern = #".+\(\d{4}\)$"#
        if trimmedName.range(of: moviePattern, options: .regularExpression) != nil {
            return .movie
        }

        return .unknown
    }

    nonisolated private static func uniqueDestinationURL(for sourceURL: URL, in destinationDirectory: URL) -> URL {
        let fileManager = FileManager.default
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension

        var candidate = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 1

        while fileManager.fileExists(atPath: candidate.path) {
            let nextName: String
            if ext.isEmpty {
                nextName = "\(baseName) (\(counter))"
            } else {
                nextName = "\(baseName) (\(counter)).\(ext)"
            }
            candidate = destinationDirectory.appendingPathComponent(nextName)
            counter += 1
        }

        return candidate
    }

    nonisolated private static func sanitizeFolderName(_ name: String) -> String {
        let forbiddenCharacters = CharacterSet(charactersIn: "/:\\*?\"<>|")
        let cleaned = name.components(separatedBy: forbiddenCharacters).joined(separator: " ")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown Show" : trimmed
    }

    nonisolated private static func isVideoFileForSort(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "m4v", "mov", "avi", "mkv"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }
}
