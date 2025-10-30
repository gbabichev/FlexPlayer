//
//  MovieRowView.swift
//  FlexPlayer
//

import SwiftUI
struct MovieRowView: View {
    let movie: Movie
    let progress: VideoProgress?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let posterData = movie.metadata?.posterData,
               let uiImage = UIImage(data: posterData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 150)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 150)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                            .font(.title)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.metadata?.displayName ?? movie.name)
                    .font(.headline)
                    .lineLimit(2)

                Group {
                    let year = movie.metadata?.releaseDate.map { String($0.prefix(4)) } ?? ""
                    let runtime = movie.metadata?.runtime?.runtimeFormatted ?? ""
                    let fileSize = movie.url.fileSize ?? ""
                    let details = [year, runtime, fileSize].filter { !$0.isEmpty }.joined(separator: " • ")

                    if !details.isEmpty {
                        Text(details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let overview = movie.metadata?.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
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
    }
}
