//
//  VideoEditorViewModel.swift
//  VideoEditor
//
//  Created on 8.11.25.
//

import SwiftUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers

@MainActor
class VideoEditorViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var hasVideo = false
    @Published var errorMessage: String?
    @Published var statusMessage = ""
    @Published var videoFileName = ""
    @Published var videoDuration = ""

    // Timeline properties - Absolute positioning
    @Published var playheadPosition: Double = 0.5       // 0.0 to 1.0 - current playhead position
    @Published var trimStartPosition: Double = 0.0      // 0.0 to 1.0 - absolute start position
    @Published var trimEndPosition: Double = 1.0        // 0.0 to 1.0 - absolute end position
    @Published var segments: [VideoSegment] = []
    @Published var thumbnailGenerator = ThumbnailGenerator()

    private var currentVideoURL: URL?
    private var currentAsset: AVAsset?
    private var videoDurationSeconds: Double = 0.0

    var trimStartTimeString: String {
        formatTime(trimStartPosition * videoDurationSeconds)
    }

    var trimEndTimeString: String {
        formatTime(trimEndPosition * videoDurationSeconds)
    }

    var playheadTimeString: String {
        formatTime(playheadPosition * videoDurationSeconds)
    }

    // MARK: - Import Video

    func importVideo() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.message = "Select a video file to edit"

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    await self.loadVideo(from: url)
                }
            }
        }
    }

    private func loadVideo(from url: URL) async {
        currentVideoURL = url
        videoFileName = url.lastPathComponent

        let asset = AVAsset(url: url)
        currentAsset = asset

        // Get video duration
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            videoDurationSeconds = seconds
            videoDuration = formatDuration(seconds)
        } catch {
            videoDuration = "Unknown"
            videoDurationSeconds = 0.0
        }

        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)

        player = newPlayer
        hasVideo = true
        errorMessage = nil

        // Reset timeline
        playheadPosition = 0.5
        trimStartPosition = 0.0
        trimEndPosition = 1.0
        segments.removeAll()

        // Generate thumbnails
        Task {
            do {
                try await thumbnailGenerator.generateThumbnails(for: asset, count: 15)
            } catch {
                print("❌ Failed to generate thumbnails: \(error)")
            }
        }

        // Auto-play
        newPlayer.play()
    }

    // MARK: - Reverse Video

    func reverseVideo() async {
        guard let inputURL = currentVideoURL else {
            errorMessage = "No video loaded"
            return
        }

        isProcessing = true
        progress = 0.0
        statusMessage = "Reversing video..."
        errorMessage = nil

        do {
            let reversedURL = try await performReverseVideo(inputURL: inputURL)
            await loadVideo(from: reversedURL)
            statusMessage = "Video reversed successfully"
        } catch {
            errorMessage = "Error reversing video: \(error.localizedDescription)"
        }

        isProcessing = false
        progress = 0.0
    }

    private func performReverseVideo(inputURL: URL) async throws -> URL {
        print("🎬 [REVERSE] Starting FFmpeg reverse video process...")

        // Check if FFmpeg is installed
        let ffmpegPaths = [
            "/opt/homebrew/bin/ffmpeg",  // Apple Silicon
            "/usr/local/bin/ffmpeg",      // Intel Mac
            "/usr/bin/ffmpeg"             // System path
        ]

        guard let ffmpegPath = ffmpegPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            print("❌ [REVERSE] FFmpeg not found! Please install: brew install ffmpeg")
            // Fallback to old method if FFmpeg not available
            return try await performReverseVideoLegacy(inputURL: inputURL)
        }

        print("✅ [REVERSE] Using FFmpeg at: \(ffmpegPath)")

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reversed_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        try? FileManager.default.removeItem(at: outputURL)

        await MainActor.run {
            self.progress = 0.1
        }

        // Run FFmpeg process
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = [
                "-i", inputURL.path,           // Input file
                "-vf", "reverse",              // Reverse video filter
                "-af", "areverse",             // Reverse audio filter
                "-preset", "ultrafast",        // Fast encoding
                "-y",                          // Overwrite output
                outputURL.path                 // Output file
            ]

            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = pipe

            // Monitor progress
            let progressQueue = DispatchQueue(label: "ffmpeg.progress")
            var progressValue = 0.1

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8) {
                    // FFmpeg outputs progress to stderr
                    if output.contains("time=") {
                        progressValue += 0.01
                        Task { @MainActor in
                            self.progress = min(progressValue, 0.9)
                        }
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
                    Task { @MainActor in
                        self.progress = 1.0
                    }
                    continuation.resume(returning: outputURL)
                } else {
                    print("❌ [REVERSE] FFmpeg failed with status: \(process.terminationStatus)")
                    continuation.resume(throwing: VideoEditorError.exportFailed)
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

    // Legacy method (fallback if FFmpeg not available)
    private func performReverseVideoLegacy(inputURL: URL) async throws -> URL {
        print("⚠️ [REVERSE] Using legacy AVFoundation method (slower)...")
        let asset = AVAsset(url: inputURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            print("❌ [REVERSE] No video track found!")
            throw VideoEditorError.noVideoTrack
        }
        print("✅ [REVERSE] Video track loaded")

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        print("✅ [REVERSE] Audio tracks loaded: \(audioTracks.count)")

        let duration = try await asset.load(.duration)
        print("✅ [REVERSE] Duration: \(CMTimeGetSeconds(duration)) seconds")

        // Create output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reversed_legacy_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        try? FileManager.default.removeItem(at: outputURL)

        // Create reader and writer
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Video setup
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )
        reader.add(videoOutput)

        let naturalSize = try await videoTrack.load(.naturalSize)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: naturalSize.width,
            AVVideoHeightKey: naturalSize.height
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        writer.add(videoInput)

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: nil
        )

        // Audio setup
        var audioInput: AVAssetWriterInput?
        var audioOutput: AVAssetReaderTrackOutput?

        if let audioTrack = audioTracks.first {
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM]
            )
            reader.add(output)
            audioOutput = output

            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44100,
                    AVEncoderBitRateKey: 128000
                ]
            )
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            audioInput = input
        }

        // Start processing
        print("🚀 [REVERSE] Starting reader and writer...")
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        print("✅ [REVERSE] Reader status: \(reader.status.rawValue), Writer status: \(writer.status.rawValue)")

        // Collect video samples
        print("📹 [REVERSE] Collecting video samples...")
        var videoSamples: [CMSampleBuffer] = []
        while let sample = videoOutput.copyNextSampleBuffer() {
            videoSamples.append(sample)

            let currentProgress = min(Double(videoSamples.count) / 1000.0, 0.3)
            await MainActor.run {
                self.progress = currentProgress
            }
        }
        print("✅ [REVERSE] Collected \(videoSamples.count) video samples")

        // Collect audio samples
        print("🔊 [REVERSE] Collecting audio samples...")
        var audioSamples: [CMSampleBuffer] = []
        if let audioOut = audioOutput {
            while let sample = audioOut.copyNextSampleBuffer() {
                audioSamples.append(sample)
            }
        }
        print("✅ [REVERSE] Collected \(audioSamples.count) audio samples")

        await MainActor.run {
            self.progress = 0.3
        }

        let totalSamples = videoSamples.count
        print("📊 [REVERSE] Total samples to process: \(totalSamples)")

        // Write reversed video samples using semaphore synchronization
        print("✍️ [REVERSE] Starting to write reversed video samples...")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let semaphore = DispatchSemaphore(value: 0)
            let processingQueue = DispatchQueue(label: "com.videoeditor.video.processing")

            print("🔄 [REVERSE VIDEO] Starting with \(videoSamples.count) samples")

            // Set up the callback to signal the semaphore
            videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.videoeditor.video.callback")) {
                semaphore.signal()
                print("📥 [REVERSE VIDEO] Callback signaled - writer is ready")
            }

            // Process samples on a separate queue
            processingQueue.async {
                var currentIndex = videoSamples.count - 1

                while currentIndex >= 0 {
                    autoreleasepool {
                        // Wait for writer to be ready
                        if !videoInput.isReadyForMoreMediaData {
                            print("⏳ [REVERSE VIDEO] Waiting at index \(currentIndex)...")
                            semaphore.wait()
                            print("✅ [REVERSE VIDEO] Writer ready again at index \(currentIndex)")
                        }

                        // Process samples while writer is ready
                        while videoInput.isReadyForMoreMediaData && currentIndex >= 0 {
                            let sample = videoSamples[currentIndex]
                            let originalTime = CMSampleBufferGetPresentationTimeStamp(sample)
                            let reversedTime = CMTimeSubtract(duration, originalTime)

                            if let imageBuffer = CMSampleBufferGetImageBuffer(sample) {
                                pixelBufferAdaptor.append(imageBuffer, withPresentationTime: reversedTime)
                            }

                            if currentIndex % 10 == 0 {
                                print("📝 [REVERSE VIDEO] Processed sample \(videoSamples.count - currentIndex)/\(videoSamples.count)")
                            }

                            let progress = 0.3 + (Double(totalSamples - currentIndex) / Double(totalSamples) * 0.5)
                            Task { @MainActor in
                                self.progress = progress
                            }

                            currentIndex -= 1
                        }
                    }
                }

                print("✅ [REVERSE VIDEO] All samples processed, finishing...")
                videoInput.markAsFinished()
                continuation.resume()
            }
        }
        print("✅ [REVERSE] Video writing phase complete")

        // Write reversed audio samples
        if let audioIn = audioInput, !audioSamples.isEmpty {
            print("✍️ [REVERSE] Starting to write reversed audio samples...")
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let semaphore = DispatchSemaphore(value: 0)
                let processingQueue = DispatchQueue(label: "com.videoeditor.audio.processing")

                print("🔄 [REVERSE AUDIO] Starting with \(audioSamples.count) samples")

                // Set up the callback to signal the semaphore
                audioIn.requestMediaDataWhenReady(on: DispatchQueue(label: "com.videoeditor.audio.callback")) {
                    semaphore.signal()
                    print("📥 [REVERSE AUDIO] Callback signaled - writer is ready")
                }

                // Process samples on a separate queue
                processingQueue.async {
                    var currentAudioIndex = audioSamples.count - 1

                    while currentAudioIndex >= 0 {
                        autoreleasepool {
                            // Wait for writer to be ready
                            if !audioIn.isReadyForMoreMediaData {
                                print("⏳ [REVERSE AUDIO] Waiting at index \(currentAudioIndex)...")
                                semaphore.wait()
                                print("✅ [REVERSE AUDIO] Writer ready again at index \(currentAudioIndex)")
                            }

                            // Process samples while writer is ready
                            while audioIn.isReadyForMoreMediaData && currentAudioIndex >= 0 {
                                let sample = audioSamples[currentAudioIndex]
                                let originalTime = CMSampleBufferGetPresentationTimeStamp(sample)
                                let reversedTime = CMTimeSubtract(duration, originalTime)

                                let timingInfo = CMSampleTimingInfo(
                                    duration: CMSampleBufferGetDuration(sample),
                                    presentationTimeStamp: reversedTime,
                                    decodeTimeStamp: .invalid
                                )

                                if let newSample = try? CMSampleBuffer(copying: sample, withNewTiming: [timingInfo]) {
                                    audioIn.append(newSample)
                                }

                                if currentAudioIndex % 5 == 0 {
                                    print("📝 [REVERSE AUDIO] Processed sample \(audioSamples.count - currentAudioIndex)/\(audioSamples.count)")
                                }

                                currentAudioIndex -= 1
                            }
                        }
                    }

                    print("✅ [REVERSE AUDIO] All samples processed, finishing...")
                    audioIn.markAsFinished()
                    Task { @MainActor in
                        self.progress = 0.85
                    }
                    continuation.resume()
                }
            }
            print("✅ [REVERSE] Audio writing phase complete")
        } else {
            print("ℹ️ [REVERSE] Skipping audio (no audio input or samples)")
        }

        await MainActor.run {
            self.progress = 0.9
        }
        print("💾 [REVERSE] Finishing writer...")

        await writer.finishWriting()
        print("✅ [REVERSE] Writer finished with status: \(writer.status.rawValue)")

        if let error = writer.error {
            print("❌ [REVERSE] Writer error: \(error.localizedDescription)")
        }

        await MainActor.run {
            self.progress = 1.0
        }

        guard writer.status == .completed else {
            print("❌ [REVERSE] Writer status is not completed: \(writer.status.rawValue)")
            throw VideoEditorError.exportFailed
        }

        print("🎉 [REVERSE] Video reversal completed successfully!")
        print("📁 [REVERSE] Output file: \(outputURL.path)")
        return outputURL
    }

    // MARK: - Trim Video

    func trimVideo() async {
        guard let inputURL = currentVideoURL else {
            errorMessage = "No video loaded"
            return
        }

        isProcessing = true
        progress = 0.0
        statusMessage = "Trimming video..."
        errorMessage = nil

        do {
            // For demo purposes, trim first 5 seconds
            let trimmedURL = try await performTrimVideo(inputURL: inputURL, startTime: 0, endTime: 5)
            await loadVideo(from: trimmedURL)
            statusMessage = "Video trimmed successfully"
        } catch {
            errorMessage = "Error trimming video: \(error.localizedDescription)"
        }

        isProcessing = false
        progress = 0.0
    }

    private func performTrimVideo(inputURL: URL, startTime: Double, endTime: Double) async throws -> URL {
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

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoEditorError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        // Export with progress monitoring to prevent UI freeze
        return try await withCheckedThrowingContinuation { continuation in
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                Task { @MainActor in
                    self.progress = Double(exportSession.progress)
                    self.statusMessage = "Trimming video... \(Int(exportSession.progress * 100))%"
                }
            }

            exportSession.exportAsynchronously {
                progressTimer.invalidate()

                Task { @MainActor in
                    self.progress = 1.0
                }

                if exportSession.status == .completed {
                    continuation.resume(returning: outputURL)
                } else {
                    continuation.resume(throwing: VideoEditorError.exportFailed)
                }
            }
        }
    }

    // MARK: - Adjust Speed

    func adjustSpeed() async {
        guard let inputURL = currentVideoURL else {
            errorMessage = "No video loaded"
            return
        }

        isProcessing = true
        progress = 0.0
        statusMessage = "Adjusting speed..."
        errorMessage = nil

        do {
            // For demo, make it 2x speed
            let adjustedURL = try await performSpeedAdjustment(inputURL: inputURL, speedMultiplier: 2.0)
            await loadVideo(from: adjustedURL)
            statusMessage = "Speed adjusted successfully"
        } catch {
            errorMessage = "Error adjusting speed: \(error.localizedDescription)"
        }

        isProcessing = false
        progress = 0.0
    }

    private func performSpeedAdjustment(inputURL: URL, speedMultiplier: Double) async throws -> URL {
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

        // Export
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoEditorError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        // Export with progress monitoring to prevent UI freeze
        return try await withCheckedThrowingContinuation { continuation in
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                Task { @MainActor in
                    self.progress = Double(exportSession.progress)
                    self.statusMessage = "Adjusting speed... \(Int(exportSession.progress * 100))%"
                }
            }

            exportSession.exportAsynchronously {
                progressTimer.invalidate()

                Task { @MainActor in
                    self.progress = 1.0
                }

                if exportSession.status == .completed {
                    continuation.resume(returning: outputURL)
                } else {
                    continuation.resume(throwing: VideoEditorError.exportFailed)
                }
            }
        }
    }

    // MARK: - Export Video

    func exportVideo() {
        guard let inputURL = currentVideoURL else {
            errorMessage = "No video loaded"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "edited_video.mp4"
        panel.message = "Export video"

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    await self.performExport(from: inputURL, to: url)
                }
            }
        }
    }

    private func performExport(from inputURL: URL, to outputURL: URL) async {
        isProcessing = true
        progress = 0.0
        statusMessage = "Exporting video..."
        errorMessage = nil

        do {
            try? FileManager.default.removeItem(at: outputURL)
            try FileManager.default.copyItem(at: inputURL, to: outputURL)

            statusMessage = "Video exported successfully"
            progress = 1.0

            // Show success message briefly
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            statusMessage = ""
        } catch {
            errorMessage = "Error exporting video: \(error.localizedDescription)"
        }

        isProcessing = false
        progress = 0.0
    }

    // MARK: - Timeline Management

    func updateTrimStart(_ position: Double) {
        trimStartPosition = max(0, min(position, 1.0))
    }

    func updateTrimEnd(_ position: Double) {
        trimEndPosition = max(0, min(position, 1.0))
    }

    func updatePlayhead(_ position: Double, snapToThumbnails: Bool = false) {
        var finalPosition = position

        // Snap to nearest thumbnail if enabled
        if snapToThumbnails && !thumbnailGenerator.thumbnails.isEmpty {
            let thumbnailCount = thumbnailGenerator.thumbnails.count
            let thumbnailWidth = 1.0 / Double(thumbnailCount)
            let nearestIndex = round(position * Double(thumbnailCount))
            finalPosition = (nearestIndex / Double(thumbnailCount)).clamped(to: 0...1)
        }

        playheadPosition = finalPosition

        // Sync video player with playhead
        if let player = player, let duration = player.currentItem?.duration {
            let timeInSeconds = finalPosition * CMTimeGetSeconds(duration)
            let targetTime = CMTime(seconds: timeInSeconds, preferredTimescale: 600)
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func resetTrim() {
        trimStartPosition = 0.0
        trimEndPosition = 1.0
    }

    /// Split video at current playhead position
    func splitAtPlayhead() {
        guard playheadPosition > 0.0 && playheadPosition < 1.0 else {
            errorMessage = "Playhead must be between start and end"
            return
        }

        // Create two segments: before and after playhead
        let startTime = trimStartPosition * videoDurationSeconds
        let playheadTime = playheadPosition * videoDurationSeconds
        let endTime = trimEndPosition * videoDurationSeconds

        // Only split if playhead is within the current selection
        if playheadPosition > trimStartPosition && playheadPosition < trimEndPosition {
            // Segment before playhead
            let segment1 = VideoSegment(startTime: startTime, endTime: playheadTime)
            segments.append(segment1)

            // Segment after playhead
            let segment2 = VideoSegment(startTime: playheadTime, endTime: endTime)
            segments.append(segment2)

            // Reset selection
            resetTrim()
        } else {
            errorMessage = "Playhead must be within selected region"
        }
    }

    func addSegment() {
        let startTime = trimStartPosition * videoDurationSeconds
        let endTime = trimEndPosition * videoDurationSeconds

        let segment = VideoSegment(startTime: startTime, endTime: endTime)
        segments.append(segment)

        // Reset trim handles for next segment
        resetTrim()
    }

    func deleteSegment(at index: Int) {
        guard index >= 0 && index < segments.count else { return }
        segments.remove(at: index)
    }

    func moveSegmentUp(at index: Int) {
        guard index > 0 && index < segments.count else { return }
        segments.swapAt(index, index - 1)
    }

    func moveSegmentDown(at index: Int) {
        guard index >= 0 && index < segments.count - 1 else { return }
        segments.swapAt(index, index + 1)
    }

    func clearSegments() {
        segments.removeAll()
    }

    // MARK: - Export Segments

    func exportSegments() {
        guard !segments.isEmpty else {
            errorMessage = "No segments to export"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "segments_export.mp4"
        panel.message = "Export segments as single video"

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    await self.performSegmentsExport(to: url)
                }
            }
        }
    }

    private func performSegmentsExport(to outputURL: URL) async {
        guard let inputURL = currentVideoURL else {
            errorMessage = "No video loaded"
            return
        }

        isProcessing = true
        progress = 0.0
        statusMessage = "Exporting segments..."
        errorMessage = nil

        do {
            let exportedURL = try await exportSegmentsToVideo(inputURL: inputURL, segments: segments, outputURL: outputURL)
            statusMessage = "Segments exported successfully"
            progress = 1.0

            // Show success message briefly
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            statusMessage = ""
        } catch {
            errorMessage = "Error exporting segments: \(error.localizedDescription)"
        }

        isProcessing = false
        progress = 0.0
    }

    private func exportSegmentsToVideo(inputURL: URL, segments: [VideoSegment], outputURL: URL) async throws -> URL {
        print("📹 [EXPORT SEGMENTS] Starting export of \(segments.count) segments...")

        let asset = AVAsset(url: inputURL)
        let composition = AVMutableComposition()

        // Add video track
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoEditorError.noVideoTrack
        }

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoEditorError.failedToCreateTrack
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

            print("📝 [EXPORT SEGMENTS] Adding segment \(index + 1): \(segment.startTimeString) - \(segment.endTimeString)")

            // Insert video
            try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: currentTime)

            // Insert audio if available
            if let audioTrack = audioTracks.first, let compAudioTrack = compositionAudioTrack {
                try compAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: currentTime)
            }

            currentTime = CMTimeAdd(currentTime, duration)

            await MainActor.run {
                self.progress = Double(index + 1) / Double(segments.count) * 0.9
            }
        }

        // Apply video transform to preserve orientation
        compositionVideoTrack.preferredTransform = videoTransform

        print("✅ [EXPORT SEGMENTS] All segments added to composition")

        // Export the composition
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoEditorError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        // Export with progress monitoring to prevent UI freeze
        return try await withCheckedThrowingContinuation { continuation in
            // Monitor progress on background thread
            let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                Task { @MainActor in
                    let exportProgress = Double(exportSession.progress)
                    self.progress = 0.9 + (exportProgress * 0.1) // 90-100%
                    self.statusMessage = "Exporting segments... \(Int(exportProgress * 100))%"
                }
            }

            exportSession.exportAsynchronously {
                progressTimer.invalidate()

                Task { @MainActor in
                    self.progress = 1.0
                    self.statusMessage = "Export complete"
                }

                if exportSession.status == .completed {
                    print("🎉 [EXPORT SEGMENTS] Export completed successfully!")
                    continuation.resume(returning: outputURL)
                } else {
                    print("❌ [EXPORT SEGMENTS] Export failed with status: \(exportSession.status.rawValue)")
                    if let error = exportSession.error {
                        print("❌ [EXPORT SEGMENTS] Error: \(error.localizedDescription)")
                    }
                    continuation.resume(throwing: VideoEditorError.exportFailed)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, secs, milliseconds)
    }
}

// MARK: - Errors

enum VideoEditorError: LocalizedError {
    case noVideoTrack
    case failedToCreateTrack
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "The video file does not contain a video track"
        case .failedToCreateTrack:
            return "Failed to create composition track"
        case .exportFailed:
            return "Failed to export video"
        }
    }
}

// MARK: - Extensions

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
