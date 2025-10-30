//
//  MovieSearchResultRow.swift
//  FlexPlayer
//

import SwiftUI
struct MovieSearchResultRow: View {
    let movie: UnifiedMovie

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Poster image
            if let posterPath = movie.posterPath {
                let posterURL = URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)")
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 90)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 90)
                            .cornerRadius(8)
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 90)
                            .overlay {
                                Image(systemName: "film")
                                    .foregroundColor(.gray)
                            }
                    @unknown default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 90)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 90)
                    .overlay {
                        Image(systemName: "film")
                            .foregroundColor(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let year = movie.releaseDate?.prefix(4) {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let overview = movie.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }

                if let runtime = movie.runtime, runtime > 0 {
                    Text("\(runtime) min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
