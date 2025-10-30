//
//  URLExtensions.swift
//  FlexPlayer
//

import Foundation
import AVKit

// MARK: - Formatting Helpers

extension URL {
    var fileSize: String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func loadDuration() async -> String? {
        let asset = AVURLAsset(url: self)
        guard let duration = try? await asset.load(.duration) else { return nil }
        guard duration.isValid, duration.seconds > 0 else { return nil }

        let totalSeconds = Int(duration.seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
