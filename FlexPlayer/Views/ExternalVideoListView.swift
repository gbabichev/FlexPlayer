//
//  ExternalVideoListView.swift
//  FlexPlayer
//

import SwiftUI
import SwiftData
struct ExternalVideoListView: View {
    let externalVideos: [ExternalVideo]
    @Binding var selectedVideoURL: URL?
    var onRefresh: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query private var allProgress: [VideoProgress]
    @Query private var allShowMetadata: [ShowMetadata]
    @Query private var allEpisodeMetadata: [EpisodeMetadata]
    @Query private var allMovieMetadata: [MovieMetadata]
    @State private var showDeleteAlert = false
    @State private var videoToDelete: ExternalVideo?

    var body: some View {
        List {
            ForEach(externalVideos) { video in
                ExternalVideoRowView(
                    video: video,
                    progress: getProgress(for: video),
                    showMetadata: getShowMetadata(for: video),
                    episodeMetadata: getEpisodeMetadata(for: video),
                    movieMetadata: getMovieMetadata(for: video)
                )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playExternalVideo(video)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            videoToDelete = video
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        if let progress = getProgress(for: video), progress.progress > 0 {
                            Button {
                                resetProgress(for: video)
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                            }
                            .tint(.orange)
                        }

                        Button {
                            markAsWatched(for: video)
                        } label: {
                            Label("Watched", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
            }
        }
        .refreshable {
            try? await Task.sleep(nanoseconds: 1_000_000_000 )
            onRefresh()
        }
        .navigationTitle("External Videos")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Reference?", isPresented: $showDeleteAlert, presenting: videoToDelete) { video in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteVideo(video)
            }
        } message: { video in
            Text("This will remove the reference to \"\(video.fileName)\". The original file will not be deleted.")
        }
    }

    private func playExternalVideo(_ video: ExternalVideo) {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: video.bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            print("🎬 Playing external video: \(url)")
            video.lastPlayed = Date()
            try? modelContext.save()

            selectedVideoURL = url

        } catch {
            print("⚠️ Failed to resolve bookmark: \(error)")
        }
    }

    private func getProgress(for video: ExternalVideo) -> VideoProgress? {
        return allProgress.first { $0.fileName == video.fileName }
    }

    private func getShowMetadata(for video: ExternalVideo) -> ShowMetadata? {
        guard let showName = video.showName else { return nil }
        return allShowMetadata.first { $0.showName == showName }
    }

    private func getEpisodeMetadata(for video: ExternalVideo) -> EpisodeMetadata? {
        guard let showName = video.showName,
              let season = video.seasonNumber,
              let episode = video.episodeNumber else { return nil }
        return allEpisodeMetadata.first {
            $0.showName == showName &&
            $0.seasonNumber == season &&
            $0.episodeNumber == episode
        }
    }

    private func getMovieMetadata(for video: ExternalVideo) -> MovieMetadata? {
        guard let tmdbId = video.movieTmdbId else { return nil }
        return allMovieMetadata.first { $0.tmdbId == tmdbId }
    }

    private func resetProgress(for video: ExternalVideo) {
        guard let progress = getProgress(for: video) else { return }

        modelContext.delete(progress)

        do {
            try modelContext.save()
            print("✅ Reset progress for: \(video.fileName)")
        } catch {
            print("⚠️ Failed to reset progress: \(error)")
        }
    }

    private func markAsWatched(for video: ExternalVideo) {
        if let progress = getProgress(for: video) {
            progress.watched = true
            progress.lastPlayed = Date()
        } else {
            let newProgress = VideoProgress(relativePath: "", fileName: video.fileName, watched: true)
            modelContext.insert(newProgress)
        }

        do {
            try modelContext.save()
            print("✅ Marked as watched: \(video.fileName)")
        } catch {
            print("⚠️ Failed to mark as watched: \(error)")
        }
    }

    private func deleteVideo(_ video: ExternalVideo) {
        modelContext.delete(video)

        if let progress = getProgress(for: video) {
            modelContext.delete(progress)
        }

        do {
            try modelContext.save()
            print("✅ Deleted external video reference: \(video.fileName)")
        } catch {
            print("⚠️ Failed to delete: \(error)")
        }
    }
}
