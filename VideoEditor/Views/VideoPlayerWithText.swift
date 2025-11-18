//
//  VideoPlayerWithText.swift
//  VideoEditor
//
//  Video player with text overlay preview
//

import SwiftUI
import AVKit

struct VideoPlayerWithTextOverlay: View {
    let player: AVPlayer
    let textOverlays: [TextOverlay]
    let currentTime: Double

    @State private var videoSize: CGSize = .zero

    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .onAppear {
                    extractVideoSize()
                }

            // Overlay text layers - positioned relative to actual video, not player
            GeometryReader { geometry in
                let videoFrame = calculateVideoFrame(in: geometry.size)

                ForEach(textOverlays.filter { isOverlayVisible($0, at: currentTime) }) { overlay in
                    TextOverlayPreview(
                        overlay: overlay,
                        videoSize: videoSize,
                        containerSize: geometry.size,
                        videoFrame: videoFrame
                    )
                }
            }
        }
    }

    private func extractVideoSize() {
        guard let track = player.currentItem?.asset.tracks(withMediaType: .video).first else {
            return
        }

        Task {
            do {
                let size = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)

                await MainActor.run {
                    // Handle rotation - if video is rotated, swap width/height
                    if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
                        videoSize = CGSize(width: size.height, height: size.width)
                    } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
                        videoSize = CGSize(width: size.height, height: size.width)
                    } else {
                        videoSize = size
                    }
                }
            } catch {
                print("Error loading video size: \(error)")
            }
        }
    }

    private func calculateVideoFrame(in containerSize: CGSize) -> CGRect {
        guard videoSize.width > 0 && videoSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let videoAspect = videoSize.width / videoSize.height
        let containerAspect = containerSize.width / containerSize.height

        var videoFrame: CGRect

        if videoAspect > containerAspect {
            // Video is wider - fit to width
            let height = containerSize.width / videoAspect
            let y = (containerSize.height - height) / 2
            videoFrame = CGRect(x: 0, y: y, width: containerSize.width, height: height)
        } else {
            // Video is taller - fit to height
            let width = containerSize.height * videoAspect
            let x = (containerSize.width - width) / 2
            videoFrame = CGRect(x: x, y: 0, width: width, height: containerSize.height)
        }

        return videoFrame
    }

    private func isOverlayVisible(_ overlay: TextOverlay, at time: Double) -> Bool {
        return time >= overlay.startTime && time <= overlay.endTime
    }
}

struct TextOverlayPreview: View {
    let overlay: TextOverlay
    let videoSize: CGSize
    let containerSize: CGSize
    let videoFrame: CGRect

    var body: some View {
        Text(overlay.text)
            .font(.system(size: scaledFontSize, weight: .regular, design: .default))
            .foregroundColor(overlay.textColor)
            .multilineTextAlignment(textAlignment)
            .padding(8)
            .background(
                overlay.backgroundColor
                    .opacity(overlay.backgroundOpacity)
                    .cornerRadius(8)
            )
            .opacity(overlay.opacity)
            .shadow(
                color: overlay.hasShadow ? overlay.shadowColor : .clear,
                radius: overlay.hasShadow ? overlay.shadowRadius / 2 : 0,
                x: 1, y: 1
            )
            .position(
                x: videoFrame.minX + overlay.x * videoFrame.width,
                y: videoFrame.minY + overlay.y * videoFrame.height
            )
    }

    private var scaledFontSize: CGFloat {
        guard videoSize.width > 0 else { return overlay.fontSize * 0.5 }

        // Scale font size based on actual video dimensions
        let scaleFactor = min(videoFrame.width / videoSize.width, videoFrame.height / videoSize.height)
        return overlay.fontSize * scaleFactor
    }

    private var textAlignment: TextAlignment {
        switch overlay.textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}
