//
//  ViewLogic.swift
//  FlexPlayer
//
//  Created by George Babichev on 10/20/25.
//
import SwiftUI
import SwiftData
import Combine
import AVKit

extension ContentView {
    
    func updateSelection() {
        guard let currentItem = selectedItem else { return }
        
        switch currentItem {
        case .show(let show):
            selectedItem = documentManager.shows
                .first { $0.name == show.name }
                .map { .show($0) }
        case .movies:
            if !documentManager.movies.isEmpty {
                selectedItem = .movies
            }
        case .externalVideos:
            if !externalVideos.isEmpty {
                selectedItem = .externalVideos
            }
        }
    }
    
    func refreshAfterDelete() {
        let currentItem = selectedItem
        documentManager.loadDocuments(modelContext: modelContext)
        
        if let item = currentItem {
            switch item {
            case .show(let show):
                selectedItem = documentManager.shows
                    .first { $0.name == show.name }
                    .map { .show($0) }
            case .movies:
                if !documentManager.movies.isEmpty {
                    selectedItem = .movies
                }
            case .externalVideos:
                if !externalVideos.isEmpty {
                    selectedItem = .externalVideos
                }
            }
        }
    }
    
    func selectRandomThumbnails() {
        let randomMovie = documentManager.movies
            .filter({ $0.metadata?.posterData != nil })
            .randomElement()
        selectedMovieThumbnail = randomMovie
        selectedMovieThumbnailFileName = randomMovie?.name

        selectedExternalVideoThumbnail = externalVideos.filter({ video in
            // Include if has episode still
            if let episodeMetadata = getEpisodeMetadataForExternal(video),
               episodeMetadata.stillData != nil {
                return true
            }
            // Include if has movie poster
            if let movieMetadata = getMovieMetadataForExternal(video),
               movieMetadata.posterData != nil {
                return true
            }
            return false
        }).randomElement()
    }
    
    func getEpisodeMetadataForExternal(_ video: ExternalVideo) -> EpisodeMetadata? {
        guard let showName = video.showName,
              let season = video.seasonNumber,
              let episode = video.episodeNumber else { return nil }
        return allEpisodeMetadata.first {
            $0.showName == showName &&
            $0.seasonNumber == season &&
            $0.episodeNumber == episode
        }
    }
    
    func getMovieMetadataForExternal(_ video: ExternalVideo) -> MovieMetadata? {
        guard let tmdbId = video.movieTmdbId else { return nil }
        return allMovieMetadata.first { $0.tmdbId == tmdbId }
    }
    
    func deleteAlertMessage(for item: SidebarItem) -> String {
        switch item {
        case .show(let show):
            return "Are you sure you want to delete all \(show.files.count) episode(s) from \"\(show.metadata?.displayName ?? show.name)\"? This cannot be undone."
        case .movies:
            return "Are you sure you want to delete all \(documentManager.movies.count) movie(s)? This cannot be undone."
        case .externalVideos:
            return "Are you sure you want to delete all \(externalVideos.count) external video reference(s)? The original files will not be deleted."
        }
    }
    
    func deleteAllInItem(_ item: SidebarItem) {
        switch item {
        case .show(let show):
            deleteAllEpisodesInShow(show)
        case .movies:
            deleteAllMovies()
        case .externalVideos:
            deleteAllExternalVideos()
        }
    }
    
    func deleteAllEpisodesInShow(_ show: Show) {
        for file in show.files {
            do {
                try FileManager.default.removeItem(at: file.url)
                print("✅ Deleted file: \(file.name)")
                
                // Delete progress
                let relativePath = getRelativePath(for: file.url)
                let descriptor = FetchDescriptor<VideoProgress>(
                    predicate: #Predicate { progress in
                        progress.relativePath == relativePath
                    }
                )
                if let progress = try? modelContext.fetch(descriptor).first {
                    modelContext.delete(progress)
                }
                
                // Delete metadata
                if let metadata = file.metadata {
                    modelContext.delete(metadata)
                }
            } catch {
                print("⚠️ Failed to delete file: \(error)")
            }
        }
        
        // Delete show metadata
        if let metadata = show.metadata {
            modelContext.delete(metadata)
        }
        
        try? modelContext.save()
        
        // Clear selection and refresh
        selectedItem = nil
        documentManager.loadDocuments(modelContext: modelContext)
    }
    
    func deleteAllMovies() {
        for movie in documentManager.movies {
            do {
                try FileManager.default.removeItem(at: movie.url)
                print("✅ Deleted movie: \(movie.name)")
                
                // Delete progress
                let relativePath = getRelativePath(for: movie.url)
                let descriptor = FetchDescriptor<VideoProgress>(
                    predicate: #Predicate { progress in
                        progress.relativePath == relativePath
                    }
                )
                if let progress = try? modelContext.fetch(descriptor).first {
                    modelContext.delete(progress)
                }
                
                // Delete metadata
                if let metadata = movie.metadata {
                    modelContext.delete(metadata)
                }
            } catch {
                print("⚠️ Failed to delete movie: \(error)")
            }
        }
        
        try? modelContext.save()
        
        // Clear selection and refresh
        selectedItem = nil
        documentManager.loadDocuments(modelContext: modelContext)
    }
    
    func deleteAllExternalVideos() {
        for video in externalVideos {
            // Delete progress
            let fileName = video.fileName
            let descriptor = FetchDescriptor<VideoProgress>(
                predicate: #Predicate { progress in
                    progress.fileName == fileName
                }
            )
            if let progress = try? modelContext.fetch(descriptor).first {
                modelContext.delete(progress)
            }
            
            // Delete external video reference
            modelContext.delete(video)
        }
        
        do {
            try modelContext.save()
            print("✅ Deleted all external video references")
        } catch {
            print("⚠️ Failed to delete: \(error)")
        }
        
        // Clear selection and refresh
        selectedItem = nil
        documentManager.loadDocuments(modelContext: modelContext)
    }
    
    func getPlaylistURLs(for currentURL: URL) -> [URL] {
        // Check if this is a show episode
        for show in documentManager.shows {
            if show.files.contains(where: { $0.url == currentURL }) {
                // Return sorted list of URLs from this show
                return show.files.sorted { file1, file2 in
                    switch (file1.episodeInfo, file2.episodeInfo) {
                    case (nil, nil):
                        return file1.name.localizedStandardCompare(file2.name) == .orderedAscending
                    case (nil, .some):
                        return false
                    case (.some, nil):
                        return true
                    case let (.some(ep1), .some(ep2)):
                        if ep1.season != ep2.season {
                            return ep1.season < ep2.season
                        }
                        return ep1.episode < ep2.episode
                    }
                }.map { $0.url }
            }
        }
        
        // If it's a movie or external video, return empty array (no playlist)
        return []
    }
    
    func setupDocumentsDirectory() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        print("📂 Documents path: \(documentsURL.path)")
        
        // Create Movies folder
        let moviesURL = documentsURL.appendingPathComponent("Movies")
        if !fileManager.fileExists(atPath: moviesURL.path) {
            do {
                try fileManager.createDirectory(at: moviesURL, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created Movies folder")
            } catch {
                print("⚠️ Failed to create Movies folder: \(error)")
            }
        } else {
            print("📁 Movies folder already exists")
        }
        
        // Create Shows folder
        let showsURL = documentsURL.appendingPathComponent("Shows")
        if !fileManager.fileExists(atPath: showsURL.path) {
            do {
                try fileManager.createDirectory(at: showsURL, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created Shows folder")
            } catch {
                print("⚠️ Failed to create Shows folder: \(error)")
            }
        } else {
            print("📁 Shows folder already exists")
        }
        
        // Keep the placeholder file for backwards compatibility
        let placeholderURL = documentsURL.appendingPathComponent(".placeholder")
        if !fileManager.fileExists(atPath: placeholderURL.path) {
            try? "FlexPlayer".write(to: placeholderURL, atomically: true, encoding: .utf8)
            print("✅ Created placeholder file")
        }
    }
}
