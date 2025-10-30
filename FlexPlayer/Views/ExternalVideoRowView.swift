//
//  ExternalVideoRowView.swift
//  FlexPlayer
//

import SwiftUI
import SwiftData
struct ExternalVideoRowView: View {
    let video: ExternalVideo
    let progress: VideoProgress?
    let showMetadata: ShowMetadata?
    let episodeMetadata: EpisodeMetadata?
    let movieMetadata: MovieMetadata?
    @State private var duration: String = ""

    private var videoURL: URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: video.bookmarkData,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            if let episodeMetadata = episodeMetadata,
               let stillData = episodeMetadata.stillData,
               let uiImage = UIImage(data: stillData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 90)
                    .cornerRadius(8)
            } else if let movieMetadata = movieMetadata,
                      let posterData = movieMetadata.posterData,
                      let uiImage = UIImage(data: posterData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 150)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 100, height: 150)
                    .overlay {
                        Image(systemName: "link")
                            .foregroundColor(.purple)
                            .font(.title)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // Title
                if let episodeMetadata = episodeMetadata {
                    if let showMetadata = showMetadata, let season = video.seasonNumber, let episode = video.episodeNumber {
                        let episodeInfo = "\(showMetadata.displayName) - S\(season)E\(String(format: "%02d", episode))"
                        let fileSize = videoURL?.fileSize ?? ""
                        let details = [episodeInfo, duration, fileSize].filter { !$0.isEmpty }.joined(separator: " • ")

                        Text(details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(episodeMetadata.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                } else if let movieMetadata = movieMetadata {
                    Text(movieMetadata.displayName)
                        .font(.headline)
                        .lineLimit(2)

                    Group {
                        let year = movieMetadata.releaseDate.map { String($0.prefix(4)) } ?? ""
                        let runtime = movieMetadata.runtime?.runtimeFormatted ?? ""
                        let fileSize = videoURL?.fileSize ?? ""
                        let details = [year, runtime, fileSize].filter { !$0.isEmpty }.joined(separator: " • ")

                        if !details.isEmpty {
                            Text(details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text(video.fileName)
                        .font(.headline)
                        .lineLimit(2)
                    Text("No metadata")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Overview
                if let overview = episodeMetadata?.overview ?? movieMetadata?.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Progress
                HStack {
                    if let progress = progress, progress.progress > 0 {
                        if progress.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            ProgressView(value: progress.progress)
                                .frame(width: 50)
                            Text("\(Int(progress.progress * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            if let videoURL = videoURL {
                duration = await videoURL.loadDuration() ?? ""
            }
        }
    }
}

// MARK: - Metadata Search View
