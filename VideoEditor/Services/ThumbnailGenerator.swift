//
//  ThumbnailGenerator.swift
//  VideoEditor
//
//  Created on 11.10.25.
//

import SwiftUI
import AVFoundation
import AppKit

@MainActor
class ThumbnailGenerator: ObservableObject {
    @Published var thumbnails: [VideoThumbnail] = []
    @Published var isGenerating = false

    private var imageGenerator: AVAssetImageGenerator?
    private var currentAsset: AVAsset?

    struct VideoThumbnail: Identifiable {
        let id = UUID()
        let image: NSImage
        let time: CMTime
        let timeInSeconds: Double
        let normalizedPosition: Double // 0.0 to 1.0
    }

    /// Generate thumbnails for a video at specified intervals
    /// - Parameters:
    ///   - asset: The video asset to generate thumbnails from
    ///   - count: Number of thumbnails to generate (default: 10)
    func generateThumbnails(for asset: AVAsset, count: Int = 10) async throws {
        isGenerating = true
        thumbnails.removeAll()
        currentAsset = asset

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds > 0 else {
            isGenerating = false
            return
        }

        // Create image generator
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        imageGenerator = generator

        // Calculate time intervals
        let interval = durationSeconds / Double(count)
        var times: [CMTime] = []

        for i in 0..<count {
            let timeInSeconds = interval * Double(i)
            let time = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
            times.append(time)
        }

        // Generate thumbnails
        var generatedThumbnails: [VideoThumbnail] = []

        for (index, time) in times.enumerated() {
            do {
                let cgImage = try await generator.image(at: time).image
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

                let thumbnail = VideoThumbnail(
                    image: nsImage,
                    time: time,
                    timeInSeconds: CMTimeGetSeconds(time),
                    normalizedPosition: Double(index) / Double(count - 1)
                )

                generatedThumbnails.append(thumbnail)

                // Update UI periodically
                if generatedThumbnails.count % 3 == 0 {
                    thumbnails = generatedThumbnails
                    objectWillChange.send()
                    print("📸 Generated \(thumbnails.count) thumbnails so far...")
                }
            } catch {
                print("❌ Failed to generate thumbnail at \(CMTimeGetSeconds(time))s: \(error)")
            }
        }

        // Final update
        thumbnails = generatedThumbnails
        isGenerating = false
        objectWillChange.send()
        print("✅ All \(thumbnails.count) thumbnails generated!")
    }

    /// Generate a single thumbnail at a specific time
    /// - Parameters:
    ///   - time: The exact time to generate thumbnail
    ///   - asset: The video asset
    /// - Returns: NSImage of the frame at that time
    func generateThumbnail(at time: CMTime, for asset: AVAsset) async throws -> NSImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let cgImage = try await generator.image(at: time).image
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Generate thumbnail at normalized position (0.0 to 1.0)
    func generateThumbnail(atPosition position: Double, for asset: AVAsset) async throws -> NSImage {
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let timeInSeconds = position * durationSeconds
        let time = CMTime(seconds: timeInSeconds, preferredTimescale: 600)

        return try await generateThumbnail(at: time, for: asset)
    }

    func clear() {
        thumbnails.removeAll()
        imageGenerator = nil
        currentAsset = nil
    }
}

// MARK: - Image Extension for SwiftUI
extension NSImage {
    var asImage: Image {
        Image(nsImage: self)
    }
}
