//
//  VideoThumbnailGenerator.swift
//  FlexPlayer
//

import AVFoundation
import UIKit
import SwiftData

class VideoThumbnailGenerator {
    
    /// Generate a thumbnail from a video at a specific time
    /// - Parameters:
    ///   - url: The video file URL
    ///   - timeInSeconds: Time to capture the frame (default: 20 seconds)
    /// - Returns: Image data as Data, or nil if generation fails
    static func generateThumbnail(from url: URL, at timeInSeconds: Double = 20.0) async -> Data? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Set maximum size for the thumbnail (to match typical episode still dimensions)
        imageGenerator.maximumSize = CGSize(width: 960, height: 540)
        
        do {
            // Get the video duration to ensure we don't go past the end
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)
            
            // Use the requested time, but cap it at duration - 1 second
            let captureTime = min(timeInSeconds, max(durationSeconds - 1, 0))
            let time = CMTime(seconds: captureTime, preferredTimescale: 600)
            
            // Generate the image (async to avoid deprecated APIs on iOS 18)
            let cgImage: CGImage = try await withCheckedThrowingContinuation { continuation in
                imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, actualTime, error in
                    if let cgImage = cgImage {
                        continuation.resume(returning: cgImage)
                    } else {
                        let seconds = CMTimeGetSeconds(actualTime)
                        let err = error ?? NSError(domain: "VideoThumbnailGenerator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate CGImage at time: \(seconds)s"])
                        continuation.resume(throwing: err)
                    }
                }
            }
            let uiImage = UIImage(cgImage: cgImage)
            
            // Convert to JPEG data with good quality
            return uiImage.jpegData(compressionQuality: 0.8)
            
        } catch {
            print("⚠️ Failed to generate thumbnail for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    /// Store generated thumbnail for an episode in the model context
    /// - Parameters:
    ///   - videoFile: The video file to generate thumbnail for
    ///   - episodeMetadata: The episode metadata to store the thumbnail in
    ///   - modelContext: SwiftData model context
    static func generateAndStoreThumbnail(
        for videoFile: VideoFile,
        in episodeMetadata: EpisodeMetadata,
        modelContext: ModelContext
    ) async {
        print("      🎬 Generating thumbnail from video file...")
        
        if let thumbnailData = await generateThumbnail(from: videoFile.url, at: 20.0) {
            episodeMetadata.stillData = thumbnailData
            episodeMetadata.lastUpdated = Date()
            
            do {
                try modelContext.save()
                print("      ✅ Generated and saved video thumbnail (\(thumbnailData.count) bytes)")
            } catch {
                print("      ⚠️ Failed to save thumbnail: \(error)")
            }
        } else {
            print("      ⚠️ Failed to generate video thumbnail")
        }
    }
}
