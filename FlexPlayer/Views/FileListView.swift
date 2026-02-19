//
//  FileListView.swift
//  FlexPlayer
//

import SwiftUI
import SwiftData
struct FileListView: View {
    let show: Show
    @Binding var selectedVideoURL: URL?
    @Environment(\.modelContext) private var modelContext
    @Query private var allProgress: [VideoProgress]
    var onRefresh: () -> Void
    
    private var sortedFiles: [VideoFile] {
        show.files.sorted { file1, file2 in
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
        }
    }
    
    var body: some View {
        List {
            ForEach(sortedFiles) { file in
                FileRowView(file: file, progress: getProgress(for: file))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("🎯 Tapped file: \(file.name)")
                        selectedVideoURL = nil
                        DispatchQueue.main.async {
                            selectedVideoURL = file.url
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteFile(file)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        if let progress = getProgress(for: file), progress.progress > 0 {
                            Button {
                                resetProgress(for: file)
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                            }
                            .tint(.orange)
                        }

                        Button {
                            markAsWatched(for: file)
                        } label: {
                            Label("Watched", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
                    .contextMenu {
                        if let progress = getProgress(for: file), progress.progress > 0 {
                            Button(role: .destructive) {
                                resetProgress(for: file)
                            } label: {
                                Label("Reset Progress", systemImage: "arrow.counterclockwise")
                            }
                        }
                        
                        Button(role: .destructive) {
                            deleteFile(file)
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
        .navigationTitle(show.metadata?.displayName ?? show.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func getProgress(for file: VideoFile) -> VideoProgress? {
        let relativePath = getRelativePath(for: file.url)
        return allProgress.first { $0.relativePath == relativePath }
    }
    
    private func resetProgress(for file: VideoFile) {
        guard let progress = getProgress(for: file) else { return }

        modelContext.delete(progress)

        do {
            try modelContext.save()
            print("✅ Reset progress for: \(file.name)")
        } catch {
            print("⚠️ Failed to reset progress: \(error)")
        }
    }

    private func markAsWatched(for file: VideoFile) {
        let relativePath = getRelativePath(for: file.url)

        if let progress = getProgress(for: file) {
            progress.watched = true
            progress.lastPlayed = Date()
        } else {
            let newProgress = VideoProgress(relativePath: relativePath, fileName: file.name, watched: true)
            modelContext.insert(newProgress)
        }

        do {
            try modelContext.save()
            print("✅ Marked as watched: \(file.name)")
        } catch {
            print("⚠️ Failed to mark as watched: \(error)")
        }
    }

    private func deleteFile(_ file: VideoFile) {
        do {
            try FileManager.default.removeItem(at: file.url)
            print("✅ Deleted file: \(file.name)")
            
            if let progress = getProgress(for: file) {
                modelContext.delete(progress)
            }
            
            if let metadata = file.metadata {
                modelContext.delete(metadata)
            }
            
            try modelContext.save()
            
            onRefresh()
            
        } catch {
            print("⚠️ Failed to delete file: \(error)")
        }
    }
}
