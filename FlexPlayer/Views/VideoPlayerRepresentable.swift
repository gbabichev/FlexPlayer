//
//  VideoPlayerRepresentable.swift
//  FlexPlayer
//

import SwiftUI
import SwiftData
import AVKit
import Combine
struct VideoPlayerRepresentable: UIViewControllerRepresentable {
    let url: URL
    let playlistURLs: [URL]
    @Binding var currentURL: URL?
    @Binding var showCountdown: Bool
    @Binding var nextVideoURL: URL?
    @Binding var nextVideoTitle: String?
    @Binding var nextVideoImage: Data?
    let modelContext: ModelContext

    private func getVideoTitle(for url: URL, modelContext: ModelContext) -> String? {
        // Try to find metadata for this video

        // Check if it's an episode
        let episodeDescriptor = FetchDescriptor<EpisodeMetadata>()
        if let allEpisodes = try? modelContext.fetch(episodeDescriptor) {
            for episode in allEpisodes {
                // Match by show name and episode info
                if let episodeInfo = EpisodeParser.parse(filename: url.lastPathComponent) {
                    if episode.showName == episodeInfo.title &&
                       episode.seasonNumber == episodeInfo.season &&
                       episode.episodeNumber == episodeInfo.episode {
                        return "S\(episode.seasonNumber)E\(String(format: "%02d", episode.episodeNumber)) - \(episode.displayName)"
                    }
                }
            }
        }

        // Check if it's a movie
        let movieDescriptor = FetchDescriptor<MovieMetadata>()
        if let allMovies = try? modelContext.fetch(movieDescriptor),
           let movie = allMovies.first(where: { $0.fileName == url.lastPathComponent }) {
            return movie.displayName
        }

        // Fallback to filename
        return url.lastPathComponent
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        // Start accessing security-scoped resource for external files
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        if isSecurityScoped {
            print("✅ Started accessing security-scoped resource")
            context.coordinator.isSecurityScoped = true
            context.coordinator.securityScopedURL = url
        }

        // Fetch existing progress
        let relativePath = getRelativePath(for: url)
        let descriptor = FetchDescriptor<VideoProgress>(
            predicate: #Predicate { progress in
                progress.relativePath == relativePath
            }
        )
        let existingProgress = try? modelContext.fetch(descriptor).first

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("AVAudioSession setup failed: \(error)")
        }

        let vc = AVPlayerViewController()
        let playerItem = AVPlayerItem(url: url)

        // Set metadata for the video
        if let title = getVideoTitle(for: url, modelContext: modelContext) {
            let titleMetadata = AVMutableMetadataItem()
            titleMetadata.identifier = .commonIdentifierTitle
            titleMetadata.value = title as NSString
            titleMetadata.extendedLanguageTag = "und"
            playerItem.externalMetadata = [titleMetadata]
        }

        let player = AVPlayer(playerItem: playerItem)
        vc.player = player
        vc.showsPlaybackControls = true
        vc.allowsPictureInPicturePlayback = true
        player.allowsExternalPlayback = true
        
        if let progress = existingProgress, progress.currentTime > 0 && !progress.isCompleted {
            let time = CMTime(seconds: progress.currentTime, preferredTimescale: 600)
            player.seek(to: time)
            print("▶️ Resuming from \(Int(progress.currentTime))s")
        }
        
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        let coordinator = context.coordinator
        coordinator.modelContext = modelContext
        coordinator.existingProgress = existingProgress
        coordinator.playlistURLs = playlistURLs
        coordinator.videoURL = url

        let observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak player, weak coordinator] time in
            guard let player = player, let coordinator = coordinator else { return }
            Task { @MainActor in
                coordinator.updateProgress(currentTime: time.seconds, player: player, url: url)
            }
        }
        coordinator.timeObserver = observer

        // Observe when video ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak coordinator] _ in
            Task { @MainActor in
                coordinator?.playNextVideo()
            }
        }

        player.play()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        // Check if URL changed (for auto-play next episode)
        if context.coordinator.videoURL != url {
            print("🔄 Switching to new video: \(url.lastPathComponent)")

            // Stop accessing previous security-scoped resource
            if context.coordinator.isSecurityScoped, let oldURL = context.coordinator.securityScopedURL {
                oldURL.stopAccessingSecurityScopedResource()
            }

            // Start accessing new security-scoped resource if needed
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            context.coordinator.isSecurityScoped = isSecurityScoped
            context.coordinator.securityScopedURL = isSecurityScoped ? url : nil
            context.coordinator.videoURL = url

            // Fetch progress for new video
            let relativePath = getRelativePath(for: url)
            let descriptor = FetchDescriptor<VideoProgress>(
                predicate: #Predicate { progress in
                    progress.relativePath == relativePath
                }
            )
            let existingProgress = try? modelContext.fetch(descriptor).first
            context.coordinator.existingProgress = existingProgress

            // Create new player item
            let newPlayerItem = AVPlayerItem(url: url)

            // Set metadata for the new video
            if let title = getVideoTitle(for: url, modelContext: modelContext) {
                let titleMetadata = AVMutableMetadataItem()
                titleMetadata.identifier = .commonIdentifierTitle
                titleMetadata.value = title as NSString
                titleMetadata.extendedLanguageTag = "und"
                newPlayerItem.externalMetadata = [titleMetadata]
            }

            let newPlayer = AVPlayer(playerItem: newPlayerItem)
            newPlayer.allowsExternalPlayback = true

            // Seek to saved progress if exists
            if let progress = existingProgress, progress.currentTime > 0 && !progress.isCompleted {
                let time = CMTime(seconds: progress.currentTime, preferredTimescale: 600)
                newPlayer.seek(to: time)
                print("▶️ Resuming from \(Int(progress.currentTime))s")
            }

            // Remove old time observer
            if let observer = context.coordinator.timeObserver, let oldPlayer = vc.player {
                oldPlayer.removeTimeObserver(observer)
            }

            // Set new player
            vc.player = newPlayer

            // Add new time observer
            let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
            let observer = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak newPlayer, weak coordinator = context.coordinator] time in
                guard let player = newPlayer, let coordinator = coordinator else { return }
                Task { @MainActor in
                    coordinator.updateProgress(currentTime: time.seconds, player: player, url: url)
                }
            }
            context.coordinator.timeObserver = observer

            // Observe when new video ends
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { [weak coordinator = context.coordinator] _ in
                Task { @MainActor in
                    coordinator?.playNextVideo()
                }
            }

            // Play the new video
            newPlayer.play()
            print("▶️ Auto-playing next video")
        }
    }

    static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
        if let observer = coordinator.timeObserver {
            vc.player?.removeTimeObserver(observer)
        }
        vc.player?.pause()

        // Stop accessing security-scoped resource
        if coordinator.isSecurityScoped, let url = coordinator.securityScopedURL {
            url.stopAccessingSecurityScopedResource()
            print("✅ Stopped accessing security-scoped resource")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            showCountdown: $showCountdown,
            nextVideoURL: $nextVideoURL,
            nextVideoTitle: $nextVideoTitle,
            nextVideoImage: $nextVideoImage
        )
    }

    class Coordinator {
        var timeObserver: Any?
        var modelContext: ModelContext?
        var existingProgress: VideoProgress?
        var isSecurityScoped = false
        var securityScopedURL: URL?
        var playlistURLs: [URL] = []
        var videoURL: URL?
        var showCountdownBinding: Binding<Bool>
        var nextVideoURLBinding: Binding<URL?>
        var nextVideoTitleBinding: Binding<String?>
        var nextVideoImageBinding: Binding<Data?>

        init(showCountdown: Binding<Bool>, nextVideoURL: Binding<URL?>, nextVideoTitle: Binding<String?>, nextVideoImage: Binding<Data?>) {
            self.showCountdownBinding = showCountdown
            self.nextVideoURLBinding = nextVideoURL
            self.nextVideoTitleBinding = nextVideoTitle
            self.nextVideoImageBinding = nextVideoImage
        }

        @MainActor
        func playNextVideo() {
            guard let videoURL = videoURL,
                  let currentIndex = playlistURLs.firstIndex(of: videoURL),
                  currentIndex + 1 < playlistURLs.count else {
                print("📺 No next video to play")
                return
            }

            let nextURL = playlistURLs[currentIndex + 1]
            print("📺 Showing countdown for next video: \(nextURL.lastPathComponent)")

            // Get the title and thumbnail for the next video
            guard let modelContext = modelContext else {
                print("⚠️ Model context not available")
                return
            }
            let nextTitle = getVideoTitle(for: nextURL, modelContext: modelContext)
            let nextImage = getVideoThumbnail(for: nextURL, modelContext: modelContext)

            // Trigger countdown UI
            nextVideoURLBinding.wrappedValue = nextURL
            nextVideoTitleBinding.wrappedValue = nextTitle
            nextVideoImageBinding.wrappedValue = nextImage
            showCountdownBinding.wrappedValue = true
        }

        private func getVideoThumbnail(for url: URL, modelContext: ModelContext) -> Data? {
            // Check if it's an episode with a thumbnail
            let episodeDescriptor = FetchDescriptor<EpisodeMetadata>()
            if let allEpisodes = try? modelContext.fetch(episodeDescriptor) {
                for episode in allEpisodes {
                    // Match by show name and episode info
                    if let episodeInfo = EpisodeParser.parse(filename: url.lastPathComponent) {
                        if episode.showName == episodeInfo.title &&
                           episode.seasonNumber == episodeInfo.season &&
                           episode.episodeNumber == episodeInfo.episode {
                            return episode.stillData
                        }
                    }
                }
            }

            // Check if it's a movie with a poster
            let movieDescriptor = FetchDescriptor<MovieMetadata>()
            if let allMovies = try? modelContext.fetch(movieDescriptor),
               let movie = allMovies.first(where: { $0.fileName == url.lastPathComponent }) {
                return movie.posterData
            }

            return nil
        }

        private func getVideoTitle(for url: URL, modelContext: ModelContext) -> String? {
            // Try to find metadata for this video

            // Check if it's an episode
            let episodeDescriptor = FetchDescriptor<EpisodeMetadata>()
            if let allEpisodes = try? modelContext.fetch(episodeDescriptor) {
                for episode in allEpisodes {
                    // Match by show name and episode info
                    if let episodeInfo = EpisodeParser.parse(filename: url.lastPathComponent) {
                        if episode.showName == episodeInfo.title &&
                           episode.seasonNumber == episodeInfo.season &&
                           episode.episodeNumber == episodeInfo.episode {
                            return "S\(episode.seasonNumber)E\(String(format: "%02d", episode.episodeNumber)) - \(episode.displayName)"
                        }
                    }
                }
            }

            // Check if it's a movie
            let movieDescriptor = FetchDescriptor<MovieMetadata>()
            if let allMovies = try? modelContext.fetch(movieDescriptor),
               let movie = allMovies.first(where: { $0.fileName == url.lastPathComponent }) {
                return movie.displayName
            }

            // Fallback to filename
            return url.lastPathComponent
        }

        @MainActor
        func updateProgress(currentTime: Double, player: AVPlayer, url: URL) {
            guard let item = player.currentItem else { return }
            guard let modelContext = modelContext else { return }

            // Use deprecated API to avoid Task ambiguity issues
            let duration = item.duration.seconds
            guard duration.isFinite else { return }

            let relativePath = getRelativePath(for: url)
            let fileName = url.lastPathComponent

            if let existing = existingProgress {
                existing.currentTime = currentTime
                existing.duration = duration
                existing.lastPlayed = Date()
            } else {
                let newProgress = VideoProgress(
                    relativePath: relativePath,
                    fileName: fileName,
                    currentTime: currentTime,
                    duration: duration
                )
                modelContext.insert(newProgress)
                self.existingProgress = newProgress
            }

            try? modelContext.save()
        }
    }
}
