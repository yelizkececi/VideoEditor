//
//  VideoEditorViewModel.swift
//  VideoEditor
//
//  ViewModel for video editing - Coordinates UI state and delegates business logic to services
//

import SwiftUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers

@MainActor
class VideoEditorViewModel: ObservableObject {

    // MARK: - Published Properties (UI State)

    @Published var player: AVPlayer?
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var hasVideo = false
    @Published var errorMessage: String?
    @Published var statusMessage = ""
    @Published var videoFileName = ""
    @Published var videoDuration = ""

    // Timeline properties
    @Published var playheadPosition: Double = 0.5
    @Published var trimStartPosition: Double = 0.0
    @Published var trimEndPosition: Double = 1.0
    @Published var segments: [VideoSegment] = []
    @Published var thumbnailGenerator = ThumbnailGenerator()

    // Text overlay properties
    @Published var textOverlays: [TextOverlay] = []
    @Published var selectedTextOverlay: TextOverlay?

    // MARK: - Private Properties

    private var currentVideoURL: URL?
    private var currentAsset: AVAsset?
    var videoDurationSeconds: Double = 0.0 // Internal for text overlay timing

    // Services (Business Logic Layer)
    private let videoProcessingService = VideoProcessingService()

    // MARK: - Computed Properties

    var trimStartTimeString: String {
        formatTime(trimStartPosition * videoDurationSeconds)
    }

    var trimEndTimeString: String {
        formatTime(trimEndPosition * videoDurationSeconds)
    }

    var playheadTimeString: String {
        formatTime(playheadPosition * videoDurationSeconds)
    }

    // MARK: - Video Import

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
        isProcessing = true
        statusMessage = "Loading video..."

        currentVideoURL = url
        videoFileName = url.lastPathComponent

        let asset = AVAsset(url: url)
        currentAsset = asset

        // Load video duration in background
        let durationSeconds = await Task.detached {
            do {
                let duration = try await asset.load(.duration)
                return CMTimeGetSeconds(duration)
            } catch {
                return 0.0
            }
        }.value

        videoDurationSeconds = durationSeconds
        videoDuration = durationSeconds > 0 ? formatDuration(durationSeconds) : "Unknown"

        let playerItem = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: playerItem)

        player = newPlayer
        hasVideo = true
        errorMessage = nil
        isProcessing = false
        statusMessage = ""

        // Reset timeline
        playheadPosition = 0.5
        trimStartPosition = 0.0
        trimEndPosition = 1.0
        segments.removeAll()

        // Generate thumbnails
        do {
            try await thumbnailGenerator.generateThumbnails(for: asset, count: 15)
        } catch {
            errorMessage = "Failed to generate thumbnails: \(error.localizedDescription)"
        }

        // Auto-play
        newPlayer.play()
    }

    // MARK: - Video Editing Operations (Delegates to Service)

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
            let reversedURL = try await videoProcessingService.reverseVideo(
                inputURL: inputURL,
                progressCallback: { [weak self] progress, message in
                    Task { @MainActor in
                        self?.progress = progress
                        self?.statusMessage = message
                    }
                }
            )

            await loadVideo(from: reversedURL)
            statusMessage = "Video reversed successfully"
        } catch {
            errorMessage = "Error reversing video: \(error.localizedDescription)"
        }

        isProcessing = false
        progress = 0.0
    }

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
            let startTime = trimStartPosition * videoDurationSeconds
            let endTime = trimEndPosition * videoDurationSeconds

            let trimmedURL = try await videoProcessingService.trimVideo(
                inputURL: inputURL,
                startTime: startTime,
                endTime: endTime,
                progressCallback: { [weak self] progress, message in
                    Task { @MainActor in
                        self?.progress = progress
                        self?.statusMessage = message
                    }
                }
            )

            await loadVideo(from: trimmedURL)
            statusMessage = "Video trimmed successfully"
        } catch {
            errorMessage = "Error trimming video: \(error.localizedDescription)"
        }

        isProcessing = false
        progress = 0.0
    }

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
            let adjustedURL = try await videoProcessingService.adjustSpeed(
                inputURL: inputURL,
                speedMultiplier: 2.0,
                progressCallback: { [weak self] progress, message in
                    Task { @MainActor in
                        self?.progress = progress
                        self?.statusMessage = message
                    }
                }
            )

            await loadVideo(from: adjustedURL)
            statusMessage = "Speed adjusted successfully"
        } catch {
            errorMessage = "Error adjusting speed: \(error.localizedDescription)"
        }

        isProcessing = false
        progress = 0.0
    }

    // MARK: - Export Operations

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
            var finalURL = inputURL

            // Apply text overlays if any
            if !textOverlays.isEmpty {
                statusMessage = "Applying text overlays..."
                finalURL = try await videoProcessingService.applyTextOverlays(
                    inputURL: inputURL,
                    textOverlays: textOverlays,
                    progressCallback: { [weak self] progress, message in
                        Task { @MainActor in
                            self?.progress = progress * 0.8 // 80% for text overlay
                            self?.statusMessage = message
                        }
                    }
                )
            }

            try? FileManager.default.removeItem(at: outputURL)

            if finalURL == inputURL {
                // No text overlays, simple copy
                try FileManager.default.copyItem(at: inputURL, to: outputURL)
            } else {
                // Move processed file
                try FileManager.default.moveItem(at: finalURL, to: outputURL)
            }

            statusMessage = "Video exported successfully"
            progress = 1.0

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            statusMessage = ""
        } catch {
            errorMessage = "Error exporting video: \(error.localizedDescription)"
        }

        isProcessing = false
        progress = 0.0
    }

    func exportVideoWithText() {
        guard let inputURL = currentVideoURL else {
            errorMessage = "No video loaded"
            return
        }

        guard !textOverlays.isEmpty else {
            errorMessage = "No text overlays to apply"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "video_with_text.mp4"
        panel.message = "Export video with text overlays"

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    await self.performExport(from: inputURL, to: url)
                }
            }
        }
    }

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
            _ = try await videoProcessingService.exportSegments(
                inputURL: inputURL,
                segments: segments,
                outputURL: outputURL,
                progressCallback: { [weak self] progress, message in
                    Task { @MainActor in
                        self?.progress = progress
                        self?.statusMessage = message
                    }
                }
            )

            statusMessage = "Segments exported successfully"
            progress = 1.0

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            statusMessage = ""
        } catch {
            errorMessage = "Error exporting segments: \(error.localizedDescription)"
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

        if snapToThumbnails && !thumbnailGenerator.thumbnails.isEmpty {
            let thumbnailCount = thumbnailGenerator.thumbnails.count
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

    func splitAtPlayhead(speed: Double = 1.0) {
        guard playheadPosition > 0.0 && playheadPosition < 1.0 else {
            errorMessage = "Playhead must be between start and end"
            return
        }

        let startTime = trimStartPosition * videoDurationSeconds
        let playheadTime = playheadPosition * videoDurationSeconds
        let endTime = trimEndPosition * videoDurationSeconds

        if playheadPosition > trimStartPosition && playheadPosition < trimEndPosition {
            let segment1 = VideoSegment(startTime: startTime, endTime: playheadTime, speed: speed)
            segments.append(segment1)

            let segment2 = VideoSegment(startTime: playheadTime, endTime: endTime, speed: speed)
            segments.append(segment2)

            resetTrim()
        } else {
            errorMessage = "Playhead must be within selected region"
        }
    }

    func addSegment(speed: Double = 1.0) {
        let startTime = trimStartPosition * videoDurationSeconds
        let endTime = trimEndPosition * videoDurationSeconds

        let segment = VideoSegment(startTime: startTime, endTime: endTime, speed: speed)
        segments.append(segment)

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

    func updateSegmentSpeed(at index: Int, speed: Double) {
        guard index >= 0 && index < segments.count else { return }
        segments[index].speed = speed
    }

    // MARK: - Text Overlay Management

    func addTextOverlay(preset: TextOverlayPreset = .custom) {
        let overlay: TextOverlay
        let currentTime = playheadPosition * videoDurationSeconds

        switch preset {
        case .title:
            overlay = TextOverlay.titlePreset()
        case .subtitle:
            overlay = TextOverlay.subtitlePreset()
        case .watermark:
            overlay = TextOverlay.watermarkPreset()
        case .custom:
            overlay = TextOverlay(
                startTime: currentTime,
                endTime: min(currentTime + 5.0, videoDurationSeconds)
            )
        }

        textOverlays.append(overlay)
        selectedTextOverlay = overlay
    }

    func deleteTextOverlay(at index: Int) {
        guard index >= 0 && index < textOverlays.count else { return }
        let removedOverlay = textOverlays[index]
        textOverlays.remove(at: index)

        if selectedTextOverlay?.id == removedOverlay.id {
            selectedTextOverlay = nil
        }
    }

    func updateTextOverlay(_ overlay: TextOverlay) {
        if let index = textOverlays.firstIndex(where: { $0.id == overlay.id }) {
            textOverlays[index] = overlay
            if selectedTextOverlay?.id == overlay.id {
                selectedTextOverlay = overlay
            }
        }
    }

    func clearTextOverlays() {
        textOverlays.removeAll()
        selectedTextOverlay = nil
    }

    func duplicateTextOverlay(at index: Int) {
        guard index >= 0 && index < textOverlays.count else { return }
        var duplicate = textOverlays[index]
        duplicate.startTime += 1.0
        duplicate.endTime += 1.0
        textOverlays.append(duplicate)
    }

    enum TextOverlayPreset {
        case title
        case subtitle
        case watermark
        case custom
    }

    // MARK: - Video Frame Extraction

    func extractFrame(at time: Double) async -> NSImage? {
        guard let asset = currentAsset else { return nil }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)

        do {
            let cgImage = try await generator.image(at: cmTime).image
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            print("Error extracting frame: \(error)")
            return nil
        }
    }

    // MARK: - Helper Methods (UI Formatting)

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

// MARK: - Extensions

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
