//
//  TextOverlay.swift
//  VideoEditor
//
//  Model representing a text overlay on video
//

import SwiftUI

struct TextOverlay: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var startTime: Double // in seconds
    var endTime: Double // in seconds

    // Position (normalized 0.0 to 1.0 for portability across video sizes)
    var x: Double // 0.0 = left, 1.0 = right
    var y: Double // 0.0 = top, 1.0 = bottom

    // Styling
    var fontSize: CGFloat
    var fontName: String
    var textColor: Color
    var backgroundColor: Color
    var backgroundOpacity: Double
    var textAlignment: TextAlignment
    var opacity: Double

    // Shadow for better readability
    var hasShadow: Bool
    var shadowColor: Color
    var shadowRadius: CGFloat

    enum TextAlignment: String, CaseIterable {
        case left = "Left"
        case center = "Center"
        case right = "Right"

        var systemAlignment: NSTextAlignment {
            switch self {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            }
        }
    }

    init(
        text: String = "New Text",
        startTime: Double = 0.0,
        endTime: Double = 5.0,
        x: Double = 0.5,
        y: Double = 0.5,
        fontSize: CGFloat = 48,
        fontName: String = "Helvetica-Bold",
        textColor: Color = .white,
        backgroundColor: Color = .black,
        backgroundOpacity: Double = 0.5,
        textAlignment: TextAlignment = .center,
        opacity: Double = 1.0,
        hasShadow: Bool = true,
        shadowColor: Color = .black,
        shadowRadius: CGFloat = 4
    ) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.x = x
        self.y = y
        self.fontSize = fontSize
        self.fontName = fontName
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.textAlignment = textAlignment
        self.opacity = opacity
        self.hasShadow = hasShadow
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
    }

    var duration: Double {
        endTime - startTime
    }

    var startTimeString: String {
        formatTime(startTime)
    }

    var endTimeString: String {
        formatTime(endTime)
    }

    var durationString: String {
        formatTime(duration)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, secs, milliseconds)
    }

    // Common presets
    static func titlePreset() -> TextOverlay {
        TextOverlay(
            text: "Title",
            y: 0.2,
            fontSize: 72,
            fontName: "Helvetica-Bold"
        )
    }

    static func subtitlePreset() -> TextOverlay {
        TextOverlay(
            text: "Subtitle",
            y: 0.85,
            fontSize: 36,
            fontName: "Helvetica"
        )
    }

    static func watermarkPreset() -> TextOverlay {
        TextOverlay(
            text: "Watermark",
            x: 0.9,
            y: 0.9,
            fontSize: 24,
            fontName: "Helvetica",
            backgroundColor: .clear,
            backgroundOpacity: 0.0,
            opacity: 0.6
        )
    }
}

// MARK: - Color Extensions for Codable and NSColor conversion

extension TextOverlay {
    // Convert SwiftUI Color to NSColor for video rendering
    func nsTextColor() -> NSColor {
        return NSColor(textColor)
    }

    func nsBackgroundColor() -> NSColor {
        return NSColor(backgroundColor)
    }

    func nsShadowColor() -> NSColor {
        return NSColor(shadowColor)
    }
}
