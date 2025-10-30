//
//  CountdownOverlay.swift
//  FlexPlayer
//

import SwiftUI
struct CountdownOverlay: View {
    let countdownValue: Int
    let nextVideoTitle: String
    let nextVideoImage: Data?
    let onCancel: () -> Void
    let onPlayNow: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("Up Next")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))

                // Episode thumbnail
                if let imageData = nextVideoImage,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 280, height: 158)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                Text(nextVideoTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(2)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Text("\(countdownValue)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }

                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 120, height: 44)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }

                    Button(action: onPlayNow) {
                        Text("Play Now")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(width: 120, height: 44)
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.85))
            )
            .padding(.horizontal, 40)

            Spacer()
        }
        .background(Color.black.opacity(0.4))
    }
}
