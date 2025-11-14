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
        print("📸 [THUMBNAIL] Starting generation for \(count) thumbnails")

        // IMPORTANT: Update state on main thread
        await MainActor.run {
            isGenerating = true
            thumbnails.removeAll()
        }
        currentAsset = asset

        print("📸 [THUMBNAIL] Loading asset duration...")
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        print("📸 [THUMBNAIL] Asset duration: \(durationSeconds)s")

        guard durationSeconds > 0 else {
            print("❌ [THUMBNAIL] Invalid duration, aborting")
            isGenerating = false
            return
        }

        // Create image generator
        print("📸 [THUMBNAIL] Creating image generator...")
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
        print("📸 [THUMBNAIL] Will generate at times: \(times.map { CMTimeGetSeconds($0) })")

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

                // Update UI periodically - force main thread update
                if generatedThumbnails.count % 3 == 0 {
                    await MainActor.run {
                        thumbnails = generatedThumbnails
                    }
                    print("📸 Generated \(thumbnails.count) thumbnails so far...")
                    print("📸 Published thumbnails array now has \(thumbnails.count) items")
                }
            } catch {
                print("❌ Failed to generate thumbnail at \(CMTimeGetSeconds(time))s: \(error)")
            }
        }

        // Final update - CRITICAL: Must be on main thread
        await MainActor.run {
            thumbnails = generatedThumbnails
            isGenerating = false
            print("✅ All \(thumbnails.count) thumbnails generated!")
            print("📸 Final: thumbnails.count = \(thumbnails.count), isGenerating = \(isGenerating)")
        }

        // Force a tiny delay to ensure UI processes the update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
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
