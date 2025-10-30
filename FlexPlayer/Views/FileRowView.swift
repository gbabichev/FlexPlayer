//
//  FileRowView.swift
//  FlexPlayer
//

import SwiftUI
struct FileRowView: View {
    let file: VideoFile
    let progress: VideoProgress?
    @State private var duration: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let stillData = file.metadata?.stillData,
               let uiImage = UIImage(data: stillData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 90)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 160, height: 90)
                    .overlay {
                        Image(systemName: "play.rectangle.fill")
                            .foregroundColor(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let (season, episode) = file.episodeInfo {
                    let episodeInfo = "S\(season)E\(String(format: "%02d", episode))"
                    let fileSize = file.url.fileSize ?? ""
                    let details = [episodeInfo, duration, fileSize].filter { !$0.isEmpty }.joined(separator: " • ")

                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(file.metadata?.displayName ?? file.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let overview = file.metadata?.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
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
            duration = await file.url.loadDuration() ?? ""
        }
    }
}
