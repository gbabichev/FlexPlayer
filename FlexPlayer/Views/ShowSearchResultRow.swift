//
//  ShowSearchResultRow.swift
//  FlexPlayer
//

import SwiftUI

struct ShowSearchResultRow: View {
    let show: UnifiedShow

    private var posterURL: URL? {
        guard let posterPath = show.posterPath else { return nil }
        if posterPath.hasPrefix("http") {
            return URL(string: posterPath)
        }
        return URL(string: "https://image.tmdb.org/t/p/w185\(posterPath)")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let posterURL {
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
                                Image(systemName: "tv")
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
                        Image(systemName: "tv")
                            .foregroundColor(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(show.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let year = show.firstAirDate?.prefix(4) {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let overview = show.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
