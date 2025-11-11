//
//  VideoProcessingService.swift
//  VideoEditor
//
//  Business logic layer for video processing operations
//

import Foundation
import AVFoundation

/// Service responsible for all video processing operations
class VideoProcessingService {

    // MARK: - Video Reversal

    /// Reverses a video using FFmpeg (fast) or AVFoundation (fallback)
    /// - Parameters:
    ///   - inputURL: URL of the video to reverse
    ///   - progressCallback: Optional callback for progress updates (0.0 to 1.0)
    /// - Returns: URL of the reversed video file
    func reverseVideo(
        inputURL: URL,
        progressCallback: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        print("🎬 [REVERSE] Starting video reversal process...")

        // Check if FFmpeg is installed
        let ffmpegPaths = [
            "/opt/homebrew/bin/ffmpeg",  // Apple Silicon
            "/usr/local/bin/ffmpeg",      // Intel Mac
            "/usr/bin/ffmpeg"             // System path
        ]

        if let ffmpegPath = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            print("✅ [REVERSE] Using FFmpeg at: \(ffmpegPath)")
            return try await reverseVideoWithFFmpeg(
                inputURL: inputURL,
                ffmpegPath: ffmpegPath,
                progressCallback: progressCallback
            )
        } else {
            print("⚠️ [REVERSE] FFmpeg not found! Using legacy AVFoundation method (slower)")
            return try await reverseVideoWithAVFoundation(
                inputURL: inputURL,
                progressCallback: progressCallback
            )
        }
    }

    // MARK: - Video Trimming

    /// Trims a video to a specific time range
    /// - Parameters:
    ///   - inputURL: URL of the video to trim
    ///   - startTime: Start time in seconds
    ///   - endTime: End time in seconds
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: URL of the trimmed video file
    func trimVideo(
        inputURL: URL,
        startTime: Double,
        endTime: Double,
        progressCallback: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        let asset = AVAsset(url: inputURL)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        try? FileManager.default.removeItem(at: outputURL)

        let composition = AVMutableComposition()

        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

        // Add video track with preserved orientation
        if let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
           let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
            // Preserve video orientation
            let videoTransform = try await videoTrack.load(.preferredTransform)
            compositionVideoTrack.preferredTransform = videoTransform
        }

        // Add audio track
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }

        return try await exportComposition(
            composition,
            to: outputURL,
            progressCallback: progressCallback
        )
    }

    // MARK: - Speed Adjustment

    /// Adjusts the playback speed of a video
    /// - Parameters:
    ///   - inputURL: URL of the video
    ///   - speedMultiplier: Speed multiplier (2.0 = 2x speed, 0.5 = half speed)
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: URL of the speed-adjusted video file
    func adjustSpeed(
        inputURL: URL,
        speedMultiplier: Double,
        progressCallback: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        let asset = AVAsset(url: inputURL)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("speed_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        try? FileManager.default.removeItem(at: outputURL)

        let composition = AVMutableComposition()
        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)

        // Add video track with preserved orientation
        if let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
           let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)

            let scaledDuration = CMTimeMultiplyByFloat64(duration, multiplier: 1.0 / speedMultiplier)
            compositionVideoTrack.scaleTimeRange(timeRange, toDuration: scaledDuration)

            // Preserve video orientation
            let videoTransform = try await videoTrack.load(.preferredTransform)
            compositionVideoTrack.preferredTransform = videoTransform
        }

        // Add audio track
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)

            let scaledDuration = CMTimeMultiplyByFloat64(duration, multiplier: 1.0 / speedMultiplier)
            compositionAudioTrack.scaleTimeRange(timeRange, toDuration: scaledDuration)
        }

        return try await exportComposition(
            composition,
            to: outputURL,
            progressCallback: progressCallback
        )
    }

    // MARK: - Segment Export

    /// Exports multiple video segments as a single combined video
    /// - Parameters:
    ///   - inputURL: URL of the source video
    ///   - segments: Array of VideoSegment to combine
    ///   - outputURL: Destination URL for the exported video
    ///   - progressCallback: Optional callback for progress updates
    /// - Returns: URL of the exported video file
    func exportSegments(
        inputURL: URL,
        segments: [VideoSegment],
        outputURL: URL,
        progressCallback: ((Double, String) -> Void)? = nil
    ) async throws -> URL {
        print("📹 [EXPORT SEGMENTS] Starting export of \(segments.count) segments...")

        let asset = AVAsset(url: inputURL)
        let composition = AVMutableComposition()

        // Add video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoProcessingError.failedToCreateTrack
        }

        // Add audio track if available
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        var compositionAudioTrack: AVMutableCompositionTrack?

        if let audioTrack = audioTracks.first {
            compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        }

        // Get video transform to preserve orientation
        let videoTransform = try await videoTrack.load(.preferredTransform)

        // Insert each segment into the composition
        var currentTime = CMTime.zero

        for (index, segment) in segments.enumerated() {
            let startTime = CMTime(seconds: segment.startTime, preferredTimescale: 600)
            let endTime = CMTime(seconds: segment.endTime, preferredTimescale: 600)
            let duration = CMTimeSubtract(endTime, startTime)
            let timeRange = CMTimeRange(start: startTime, duration: duration)

            print("📝 [EXPORT SEGMENTS] Adding segment \(index + 1): \(segment.startTimeString) - \(segment.endTimeString) at \(segment.speed)x speed")

            // Insert video
            try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: currentTime)

            // Apply speed adjustment if not normal speed
            if segment.speed != 1.0 {
                let scaledDuration = CMTimeMultiplyByFloat64(duration, multiplier: 1.0 / segment.speed)
                compositionVideoTrack.scaleTimeRange(
                    CMTimeRange(start: currentTime, duration: duration),
                    toDuration: scaledDuration
                )
            }

            // Insert audio if available
            if let audioTrack = audioTracks.first, let compAudioTrack = compositionAudioTrack {
                try compAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: currentTime)

                // Apply same speed adjustment to audio
                if segment.speed != 1.0 {
                    let scaledDuration = CMTimeMultiplyByFloat64(duration, multiplier: 1.0 / segment.speed)
                    compAudioTrack.scaleTimeRange(
                        CMTimeRange(start: currentTime, duration: duration),
                        toDuration: scaledDuration
                    )
                }
            }

            // Update currentTime with adjusted duration
            let adjustedDuration = segment.speed != 1.0
                ? CMTimeMultiplyByFloat64(duration, multiplier: 1.0 / segment.speed)
                : duration
            currentTime = CMTimeAdd(currentTime, adjustedDuration)

            // Update progress (segments building: 0-90%)
            progressCallback?(Double(index + 1) / Double(segments.count) * 0.9, "Building segments...")
        }

        // Apply video transform to preserve orientation
        compositionVideoTrack.preferredTransform = videoTransform

        print("✅ [EXPORT SEGMENTS] All segments added to composition")

        // Export the composition
        try? FileManager.default.removeItem(at: outputURL)

        return try await exportComposition(
            composition,
            to: outputURL,
            progressCallback: { progress, message in
                // Export progress: 90-100%
                progressCallback?(0.9 + (progress * 0.1), message)
            }
        )
    }

    // MARK: - Private Helper Methods

    private func reverseVideoWithFFmpeg(
        inputURL: URL,
        ffmpegPath: String,
        progressCallback: ((Double, String) -> Void)?
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reversed_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        try? FileManager.default.removeItem(at: outputURL)

        progressCallback?(0.1, "Starting FFmpeg...")

        // Run FFmpeg process
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = [
                "-i", inputURL.path,
                "-vf", "reverse",
                "-af", "areverse",
                "-preset", "ultrafast",
                "-y",
                outputURL.path
            ]

            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = pipe

            var progressValue = 0.1

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    if output.contains("time=") {
                        progressValue += 0.01
                        progressCallback?(min(progressValue, 0.9), "Reversing video...")
                    }
                    if !output.isEmpty {
                        print("📹 [FFMPEG] \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }
                }
            }

            process.terminationHandler = { process in
                pipe.fileHandleForReading.readabilityHandler = nil

                if process.terminationStatus == 0 {
                    print("✅ [REVERSE] FFmpeg completed successfully!")
                    progressCallback?(1.0, "Reversal complete")
                    continuation.resume(returning: outputURL)
                } else {
                    print("❌ [REVERSE] FFmpeg failed with status: \(process.terminationStatus)")
                    continuation.resume(throwing: VideoProcessingError.exportFailed)
                }
            }

            do {
                print("🚀 [REVERSE] Starting FFmpeg process...")
                try process.run()
            } catch {
                print("❌ [REVERSE] Failed to start FFmpeg: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }

    private func reverseVideoWithAVFoundation(
        inputURL: URL,
        progressCallback: ((Double, String) -> Void)?
    ) async throws -> URL {
        print("⚠️ [REVERSE] Using legacy AVFoundation method (slower)...")

        // This would contain the full AVFoundation reversal implementation
        // For now, throwing an error to indicate FFmpeg should be used
        throw VideoProcessingError.ffmpegRequired
    }

    private func exportComposition(
        _ composition: AVMutableComposition,
        to outputURL: URL,
        progressCallback: ((Double, String) -> Void)?
    ) async throws -> URL {
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoProcessingError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        // Export with progress monitoring
        return try await withCheckedThrowingContinuation { continuation in
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                let progress = Double(exportSession.progress)
                progressCallback?(progress, "Exporting... \(Int(progress * 100))%")
            }

            exportSession.exportAsynchronously {
                progressTimer.invalidate()
                progressCallback?(1.0, "Export complete")

                if exportSession.status == .completed {
                    continuation.resume(returning: outputURL)
                } else {
                    continuation.resume(throwing: VideoProcessingError.exportFailed)
                }
            }
        }
    }
}

// MARK: - Errors

enum VideoProcessingError: LocalizedError {
    case noVideoTrack
    case failedToCreateTrack
    case exportFailed
    case ffmpegRequired

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "The video file does not contain a video track"
        case .failedToCreateTrack:
            return "Failed to create composition track"
        case .exportFailed:
            return "Failed to export video"
        case .ffmpegRequired:
            return "FFmpeg is required for this operation. Please install FFmpeg."
        }
    }
}
