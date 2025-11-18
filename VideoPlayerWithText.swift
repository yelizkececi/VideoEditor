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

    var body: some View {
        ZStack {
            VideoPlayer(player: player)

            // Overlay text layers
            GeometryReader { geometry in
                ForEach(textOverlays.filter { isOverlayVisible($0, at: currentTime) }) { overlay in
                    TextOverlayPreview(
                        overlay: overlay,
                        videoSize: geometry.size
                    )
                }
            }
        }
    }

    private func isOverlayVisible(_ overlay: TextOverlay, at time: Double) -> Bool {
        return time >= overlay.startTime && time <= overlay.endTime
    }
}

struct TextOverlayPreview: View {
    let overlay: TextOverlay
    let videoSize: CGSize

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
                x: overlay.x * videoSize.width,
                y: overlay.y * videoSize.height
            )
    }

    private var scaledFontSize: CGFloat {
        // Scale font size based on video dimensions (assuming 1920x1080 as base)
        let scaleFactor = min(videoSize.width / 1920, videoSize.height / 1080)
        return overlay.fontSize * scaleFactor * 0.5 // Additional scaling for preview
    }

    private var textAlignment: TextAlignment {
        switch overlay.textAlignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}
