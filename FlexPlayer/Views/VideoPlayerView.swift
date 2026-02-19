//
//  VideoPlayerView.swift
//  FlexPlayer
//

import SwiftUI
import SwiftData
import AVKit
struct VideoPlayerView: View {
    let url: URL
    let playlistURLs: [URL]
    @Binding var currentURL: URL?
    let onPictureInPictureStarted: () -> Void
    let onPictureInPictureStopped: () -> Void
    let onPictureInPictureRestoreRequested: (@escaping (Bool) -> Void) -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var showCountdown = false
    @State private var countdownValue = 10
    @State private var nextVideoURL: URL?
    @State private var nextVideoTitle: String?
    @State private var nextVideoImage: Data?
    @State private var countdownTimer: Timer?
    @AppStorage("nextEpisodeCountdownSeconds") private var countdownSeconds = 10
    @AppStorage("gesturesEnabled") private var gesturesEnabled = true
    @AppStorage("swipeControlsAreSwapped") private var swipeControlsAreSwapped = false

    var body: some View {
        ZStack {
            VideoPlayerRepresentable(
                url: url,
                playlistURLs: playlistURLs,
                currentURL: $currentURL,
                showCountdown: $showCountdown,
                nextVideoURL: $nextVideoURL,
                nextVideoTitle: $nextVideoTitle,
                nextVideoImage: $nextVideoImage,
                modelContext: modelContext,
                gesturesEnabled: gesturesEnabled,
                swipeControlsAreSwapped: swipeControlsAreSwapped,
                onPictureInPictureStarted: onPictureInPictureStarted,
                onPictureInPictureStopped: onPictureInPictureStopped,
                onPictureInPictureRestoreRequested: onPictureInPictureRestoreRequested
            )

            if showCountdown, let nextTitle = nextVideoTitle {
                CountdownOverlay(
                    countdownValue: countdownValue,
                    nextVideoTitle: nextTitle,
                    nextVideoImage: nextVideoImage,
                    onCancel: {
                        cancelCountdown()
                    },
                    onPlayNow: {
                        playNextVideoNow()
                    }
                )
            }
        }
        .onChange(of: showCountdown) { oldValue, newValue in
            if newValue {
                startCountdown()
            } else {
                stopCountdown()
            }
        }
    }

    private func startCountdown() {
        countdownValue = max(1, countdownSeconds)
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if self.countdownValue > 0 {
                    self.countdownValue -= 1
                } else {
                    self.stopCountdown()
                    self.playNextVideoNow()
                }
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func cancelCountdown() {
        showCountdown = false
        nextVideoURL = nil
        nextVideoTitle = nil
        nextVideoImage = nil
    }

    private func playNextVideoNow() {
        showCountdown = false
        if let nextURL = nextVideoURL {
            currentURL = nextURL
        }
        nextVideoURL = nil
        nextVideoTitle = nil
        nextVideoImage = nil
    }
}
