//
//  MovieListView.swift
//  FlexPlayer
//

import SwiftUI
import SwiftData
struct MovieListView: View {
    let movies: [Movie]
    @Binding var selectedVideoURL: URL?
    @Environment(\.modelContext) private var modelContext
    @Query private var allProgress: [VideoProgress]
    @State private var movieToRematch: MovieToRematch?
    var onRefresh: () -> Void
    
    var body: some View {
        List {
            ForEach(movies) { movie in
                MovieRowView(movie: movie, progress: getProgress(for: movie))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🎯 Tapped movie: \(movie.name)")
                        selectedVideoURL = nil
                        DispatchQueue.main.async {
                            selectedVideoURL = movie.url
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteMovie(movie)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        if let progress = getProgress(for: movie), progress.progress > 0 {
                            Button {
                                resetProgress(for: movie)
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                            }
                            .tint(.orange)
                        }

                        Button {
                            markAsWatched(for: movie)
                        } label: {
                            Label("Watched", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
                    .contextMenu {
                        Button {
                            print("🔍 Re-match tapped for: \(movie.name)")
                            movieToRematch = MovieToRematch(name: movie.name, url: movie.url)
                            print("🔍 movieToRematch set: \(movieToRematch?.name ?? "nil")")
                        } label: {
                            Label("Re-match Metadata", systemImage: "magnifyingglass")
                        }

                        if let progress = getProgress(for: movie), progress.progress > 0 {
                            Button(role: .destructive) {
                                resetProgress(for: movie)
                            } label: {
                                Label("Reset Progress", systemImage: "arrow.counterclockwise")
                            }
                        }

                        Button(role: .destructive) {
                            deleteMovie(movie)
                        } label: {
                            Label("Delete File", systemImage: "trash")
                        }
                    }
            }
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 1_000_000_000 )
            onRefresh()
        }
        .navigationTitle("Movies")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $movieToRematch) { movie in
            MetadataSearchView(movieName: movie.name) { selectedMovie in
                updateMovieMetadataByURL(url: movie.url, with: selectedMovie)
            }
            .onAppear {
                print("🎬 Presenting MetadataSearchView for: \(movie.name)")
            }
        }
    }
    
    private func getProgress(for movie: Movie) -> VideoProgress? {
        let relativePath = getRelativePath(for: movie.url)
        return allProgress.first { $0.relativePath == relativePath }
    }
    
    private func resetProgress(for movie: Movie) {
        guard let progress = getProgress(for: movie) else { return }

        modelContext.delete(progress)

        do {
            try modelContext.save()
            print("✅ Reset progress for: \(movie.name)")
        } catch {
            print("⚠️ Failed to reset progress: \(error)")
        }
    }

    private func markAsWatched(for movie: Movie) {
        let relativePath = getRelativePath(for: movie.url)

        if let progress = getProgress(for: movie) {
            progress.watched = true
            progress.lastPlayed = Date()
        } else {
            let newProgress = VideoProgress(relativePath: relativePath, fileName: movie.name, watched: true)
            modelContext.insert(newProgress)
        }

        do {
            try modelContext.save()
            print("✅ Marked as watched: \(movie.name)")
        } catch {
            print("⚠️ Failed to mark as watched: \(error)")
        }
    }

    private func deleteMovie(_ movie: Movie) {
        do {
            try FileManager.default.removeItem(at: movie.url)
            print("✅ Deleted movie: \(movie.name)")

            if let progress = getProgress(for: movie) {
                modelContext.delete(progress)
            }

            if let metadata = movie.metadata {
                modelContext.delete(metadata)
            }

            try modelContext.save()

            onRefresh()

        } catch {
            print("⚠️ Failed to delete movie: \(error)")
        }
    }

    private func updateMovieMetadataByURL(url: URL, with selectedMovie: UnifiedMovie) {
        let fileName = url.lastPathComponent
        print("🔄 Updating metadata for \(fileName) with \(selectedMovie.title)")

        Task {
            do {
                // Find existing metadata by filename
                let descriptor = FetchDescriptor<MovieMetadata>(
                    predicate: #Predicate { metadata in
                        metadata.fileName == fileName
                    }
                )
                let existingMetadata = try? modelContext.fetch(descriptor).first

                let movieMetadata: MovieMetadata
                if let existing = existingMetadata {
                    print("   🔄 Updating existing MovieMetadata")
                    movieMetadata = existing
                    movieMetadata.tmdbId = selectedMovie.id
                    movieMetadata.displayName = selectedMovie.title
                    movieMetadata.overview = selectedMovie.overview
                    movieMetadata.posterPath = selectedMovie.posterPath
                    movieMetadata.backdropPath = selectedMovie.backdropPath
                    movieMetadata.releaseDate = selectedMovie.releaseDate
                    movieMetadata.runtime = selectedMovie.runtime
                    movieMetadata.lastUpdated = Date()
                } else {
                    print("   ➕ Creating new MovieMetadata")
                    movieMetadata = MovieMetadata(
                        fileName: fileName,
                        tmdbId: selectedMovie.id,
                        displayName: selectedMovie.title,
                        overview: selectedMovie.overview,
                        posterPath: selectedMovie.posterPath,
                        backdropPath: selectedMovie.backdropPath,
                        releaseDate: selectedMovie.releaseDate,
                        runtime: selectedMovie.runtime
                    )
                    modelContext.insert(movieMetadata)
                }

                // Download new poster
                if let posterPath = selectedMovie.posterPath {
                    do {
                        print("   📥 Downloading poster...")
                        let posterData = try await MetadataService.shared.downloadPoster(path: posterPath)
                        movieMetadata.posterData = posterData
                        print("   ✅ Downloaded poster (\(posterData.count) bytes)")
                    } catch {
                        print("   ⚠️ Failed to download poster: \(error)")
                    }
                }

                try modelContext.save()
                print("   ✅ Metadata updated successfully")

                await MainActor.run {
                    onRefresh()
                }
            } catch {
                print("   ⚠️ Failed to update metadata: \(error)")
            }
        }
    }
}
