//
//  FlexPlayerApp.swift
//  FlexPlayer
//
//  Created by George Babichev on 9/29/25.
//

import SwiftUI
import SwiftData

@main
struct FlexPlayerApp: App {
    @StateObject private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VideoProgress.self,
            ShowMetadata.self,
            EpisodeMetadata.self,
            MovieMetadata.self,
            ExternalVideo.self  // Added external video
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $appState.showTutorial) {
                    TutorialView(isPresented: $appState.showTutorial)
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .environmentObject(appState)
#if DEBUG
        .overlay(alignment: .bottomTrailing) {
            BetaTag()
                .padding(12)
        }
#endif
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleIncomingURL(_ url: URL) {
        print("📥 Received URL to play: \(url)")

        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("⚠️ Failed to access security scoped resource")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            // Create a security-scoped bookmark for future access
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            // Save to database
            let context = sharedModelContainer.mainContext
            let fileName = url.lastPathComponent

            // Check if already exists
            let descriptor = FetchDescriptor<ExternalVideo>(
                predicate: #Predicate { video in
                    video.fileName == fileName
                }
            )

            if let existing = try? context.fetch(descriptor).first {
                print("📝 Updating existing external video")
                existing.bookmarkData = bookmarkData
                existing.lastPlayed = Date()
            } else {
                print("➕ Adding new external video")
                let externalVideo = ExternalVideo(fileName: fileName, bookmarkData: bookmarkData)
                context.insert(externalVideo)
            }

            try context.save()
            print("✅ Saved external video reference")

            // Post notification to play the video
            NotificationCenter.default.post(
                name: NSNotification.Name("PlayExternalVideo"),
                object: nil,
                userInfo: ["url": url]
            )

        } catch {
            print("⚠️ Failed to create bookmark: \(error)")
        }
    }
}
