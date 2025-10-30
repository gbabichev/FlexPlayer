//
//  ShowRowView.swift
//  FlexPlayer
//

import SwiftUI
struct ShowRowView: View {
    let show: Show
    
    var body: some View {
        HStack(spacing: 12) {
            if let posterData = show.metadata?.posterData,
               let uiImage = UIImage(data: posterData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
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
                Text(show.metadata?.displayName ?? show.name)
                    .font(.headline)
                Text("\(show.files.count) episode(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let year = show.metadata?.firstAirDate?.prefix(4) {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
