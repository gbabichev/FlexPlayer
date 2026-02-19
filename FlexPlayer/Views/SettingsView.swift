//
//  SettingsView.swift
//  FlexPlayer
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var documentManager: DocumentManager
    let hasLibraryContent: Bool
    let onFetchMetadata: () -> Void
    let onClearMetadata: () -> Void

    @AppStorage("nextEpisodeCountdownSeconds") private var countdownSeconds = 10
    @AppStorage("gesturesEnabled") private var gesturesEnabled = true
    @AppStorage("swipeControlsAreSwapped") private var swipeControlsAreSwapped = false
    @AppStorage("selectedMetadataSource") private var selectedMetadataSourceRaw = MetadataSource.tmdb.rawValue

    @State private var showClearMetadataAlert = false

    private var selectedSourceBinding: Binding<MetadataSource> {
        Binding(
            get: { MetadataSource(rawValue: selectedMetadataSourceRaw) ?? .tmdb },
            set: { newValue in
                selectedMetadataSourceRaw = newValue.rawValue
                documentManager.selectedSource = newValue
                MetadataService.shared.selectedSource = newValue
            }
        )
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "Version \(shortVersion) (\(buildNumber))"
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
                Picker("Metadata Source", selection: selectedSourceBinding) {
                    ForEach(MetadataSource.allCases, id: \.self) { source in
                        Text(source.displayName)
                            .tag(source)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    onFetchMetadata()
                } label: {
                    Label("Fetch Metadata", systemImage: "arrow.down.circle")
                }
                .disabled(documentManager.isLoadingMetadata || !hasLibraryContent)

                Button(role: .destructive) {
                    showClearMetadataAlert = true
                } label: {
                    Label("Clear All Metadata", systemImage: "trash")
                }
                .disabled(!hasLibraryContent)

                if documentManager.isLoadingMetadata {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView()
                        Text("Fetching metadata from \(documentManager.selectedSource.displayName)...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
        .alert("Clear All Metadata?", isPresented: $showClearMetadataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                onClearMetadata()
            }
        } message: {
            Text("This will remove all show posters, episode thumbnails, movie posters, titles, and descriptions. Your video files and watch progress will not be affected.")
        }
        .onAppear {
            let source = MetadataSource(rawValue: selectedMetadataSourceRaw) ?? .tmdb
            documentManager.selectedSource = source
            MetadataService.shared.selectedSource = source
        }
    }
}
