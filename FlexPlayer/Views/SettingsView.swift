//
//  SettingsView.swift
//  FlexPlayer
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var documentManager: DocumentManager
    let hasLibraryContent: Bool
    let onFetchMetadata: () -> Void
    let onClearMetadata: () -> Void
    let onSortLibrary: () -> Void

    @AppStorage("nextEpisodeCountdownSeconds") private var countdownSeconds = 10
    @AppStorage("gesturesEnabled") private var gesturesEnabled = true
    @AppStorage("swipeControlsAreSwapped") private var swipeControlsAreSwapped = false
    @AppStorage("autoSortEnabled") private var autoSortEnabled = false
    @Query private var allShowMetadata: [ShowMetadata]
    @Query private var allMovieMetadata: [MovieMetadata]

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Version \(shortVersion) (\(buildNumber))"
    }

    private var showsWithMetadataCount: Int {
        let metadataNames = Set(allShowMetadata.map(\.showName))
        return documentManager.shows.filter { metadataNames.contains($0.name) }.count
    }

    private var moviesWithMetadataCount: Int {
        let metadataFileNames = Set(allMovieMetadata.map(\.fileName))
        return documentManager.movies.filter { metadataFileNames.contains($0.name) }.count
    }

    private var totalShows: Int {
        documentManager.shows.count
    }

    private var totalMovies: Int {
        documentManager.movies.count
    }

    private var showsWithoutMetadataCount: Int {
        max(totalShows - showsWithMetadataCount, 0)
    }

    private var moviesWithoutMetadataCount: Int {
        max(totalMovies - moviesWithMetadataCount, 0)
    }

    private var hasAnyTrackableItems: Bool {
        (totalShows + totalMovies) > 0
    }

    private var allItemsHaveMetadata: Bool {
        hasAnyTrackableItems && showsWithoutMetadataCount == 0 && moviesWithoutMetadataCount == 0
    }

    var body: some View {
        Form {
            Section("Playback") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Next Episode Countdown", selection: $countdownSeconds) {
                        Text("3 seconds").tag(3)
                        Text("5 seconds").tag(5)
                        Text("10 seconds").tag(10)
                    }
                    .pickerStyle(.segmented)

                    Text("How long the Next Episode overlay waits before auto-playing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section("Gestures") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable gestures", isOn: $gesturesEnabled)
                    Text("Use vertical swipes on the player to control brightness and volume.")
                        .font(.caption)
                        .foregroundColor(gesturesEnabled ? .secondary : Color(.tertiaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Swap left/right for brightness and volume", isOn: $swipeControlsAreSwapped)
                    Text(swipeControlsAreSwapped ? "Left: Volume • Right: Brightness" : "Left: Brightness • Right: Volume")
                        .font(.caption)
                        .foregroundColor(gesturesEnabled ? .secondary : Color(.tertiaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!gesturesEnabled)
            }

            Section("Metadata") {
                Text("Fetches from TheMovieDB and TheTVDB.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    onFetchMetadata()
                } label: {
                    Label("Fetch Metadata", systemImage: "arrow.down.circle")
                }
                .disabled(documentManager.isLoadingMetadata || !hasLibraryContent)

                Button(role: .destructive) {
                    onClearMetadata()
                } label: {
                    Label("Clear All Metadata", systemImage: "trash")
                }
                .disabled(!hasLibraryContent || documentManager.isLoadingMetadata)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Shows: \(showsWithMetadataCount)/\(totalShows) with metadata")
                    Text("Movies: \(moviesWithMetadataCount)/\(totalMovies) with metadata")

                    if hasAnyTrackableItems {
                        if allItemsHaveMetadata {
                            Text("All items have metadata.")
                        } else {
                            let missingTotal = showsWithoutMetadataCount + moviesWithoutMetadataCount
                            Text("\(missingTotal) item(s) still missing metadata.")
                        }
                    } else {
                        Text("Add content to your library to track metadata coverage.")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if documentManager.isLoadingMetadata {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView()
                        Text("Scanning TheMovieDB + TheTVDB...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Library Organization") {
                Text("Scans your Flex Player folder and moves files into Movies or Shows based on filename patterns. Helpful if you don't want to manually move files to the right folders!")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Automatically sort on app launch", isOn: $autoSortEnabled)

                Button {
                    onSortLibrary()
                } label: {
                    Label("Sort Library Now", systemImage: "arrow.triangle.branch")
                }
                .disabled(documentManager.isSortingLibrary)

                if documentManager.isSortingLibrary {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView()
                        Text("Sorting files into Movies/Shows...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let result = documentManager.lastSortResult {
                    VStack(alignment: .leading, spacing: 4) {
                        if result.isClean {
                            Text("Library is already sorted.")
                        } else {
                            Text("Sorting complete.")
                        }

                        Text("Scanned: \(result.scannedFiles)")
                        Text("Moved: \(result.movedFiles)")
                        Text("Already sorted: \(result.alreadySortedFiles)")
                        Text("Unclassified: \(result.unclassifiedCount)")
                        Text("Failed moves: \(result.failedCount)")

                        if !result.unclassifiedFiles.isEmpty {
                            let sample = result.unclassifiedFiles.prefix(3).joined(separator: ", ")
                            Text("Sample unclassified: \(sample)")
                        }

                        if !result.failedMoves.isEmpty {
                            let sample = result.failedMoves.prefix(2).joined(separator: " | ")
                            Text("Sample failures: \(sample)")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                if let errorMessage = documentManager.sortErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text(appVersionText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
