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
    var fontWeight: FontWeight
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

    enum FontWeight: String, CaseIterable {
        case ultraLight = "Ultra Light"
        case thin = "Thin"
        case light = "Light"
        case regular = "Regular"
        case medium = "Medium"
        case semibold = "Semibold"
        case bold = "Bold"
        case heavy = "Heavy"
        case black = "Black"

        var swiftUIWeight: Font.Weight {
            switch self {
            case .ultraLight: return .ultraLight
            case .thin: return .thin
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            case .black: return .black
            }
        }

        var nsWeight: NSFont.Weight {
            switch self {
            case .ultraLight: return .ultraLight
            case .thin: return .thin
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            case .black: return .black
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
        fontWeight: FontWeight = .bold,
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
        self.fontWeight = fontWeight
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

    // Auto-style: Analyze video frame and set optimal colors (no background)
    mutating func autoStyle(videoFrame: NSImage?) {
        guard let frame = videoFrame else {
            // Default: white text if no frame provided
            textColor = .white
            backgroundColor = .clear
            backgroundOpacity = 0.0
            hasShadow = false
            shadowColor = .clear
            shadowRadius = 0
            opacity = 1.0
            return
        }

        // Calculate position in image coordinates
        guard let cgImage = frame.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            textColor = .white
            return
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // Sample area around text position (20% of frame size)
        let sampleWidth = width * 0.2
        let sampleHeight = height * 0.2
        let sampleX = x * width - sampleWidth / 2
        let sampleY = y * height - sampleHeight / 2

        let sampleRect = CGRect(
            x: max(0, sampleX),
            y: max(0, sampleY),
            width: min(sampleWidth, width - sampleX),
            height: min(sampleHeight, height - sampleY)
        )

        // Get average color of the sample area
        guard let croppedImage = cgImage.cropping(to: sampleRect) else {
            textColor = .white
            return
        }

        let avgColor = averageColor(of: croppedImage)

        // Calculate brightness (0.0 = dark, 1.0 = bright)
        let brightness = avgColor.brightness

        // Simple logic: Start with white, switch to black only if background is very bright
        if brightness > 0.7 {
            // Very bright background → use black text
            textColor = .black
        } else {
            // Default to white for dark/medium backgrounds
            textColor = .white
        }

        // Use handwritten font for natural, casual look
        // Try common handwritten fonts available on macOS
        let handwrittenFonts = [
            "Snell Roundhand",
            "Bradley Hand Bold",
            "Noteworthy-Bold",
            "Marker Felt Wide",
            "Comic Sans MS"
        ]

        // Find first available font, fallback to default
        var selectedFont = "Helvetica-Bold"
        for font in handwrittenFonts {
            if NSFont(name: font, size: 12) != nil {
                selectedFont = font
                break
            }
        }

        fontName = selectedFont
        fontSize = 48 // Good readable size

        // No background by default
        backgroundColor = .clear
        backgroundOpacity = 0.0

        // No shadow - clean look
        hasShadow = false
        shadowColor = .clear
        shadowRadius = 0
        opacity = 1.0 // Full opacity for text
    }

    // Calculate average color of a CGImage
    private func averageColor(of cgImage: CGImage) -> (red: Double, green: Double, blue: Double, brightness: Double) {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalRed: Double = 0
        var totalGreen: Double = 0
        var totalBlue: Double = 0
        let pixelCount = width * height

        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let red = Double(pixelData[i])
            let green = Double(pixelData[i + 1])
            let blue = Double(pixelData[i + 2])

            totalRed += red
            totalGreen += green
            totalBlue += blue
        }

        let avgRed = totalRed / Double(pixelCount) / 255.0
        let avgGreen = totalGreen / Double(pixelCount) / 255.0
        let avgBlue = totalBlue / Double(pixelCount) / 255.0

        // Calculate perceived brightness using standard formula
        let brightness = (0.299 * avgRed + 0.587 * avgGreen + 0.114 * avgBlue)

        return (avgRed, avgGreen, avgBlue, brightness)
    }

    // Auto-position: Find optimal placement avoiding other overlays
    mutating func autoPosition(existingOverlays: [TextOverlay]) {
        // Define safe zones (areas that work well for text)
        let safePositions: [(x: Double, y: Double, name: String)] = [
            (0.5, 0.15, "Top Center"),       // Title position
            (0.5, 0.85, "Bottom Center"),    // Subtitle position
            (0.5, 0.5, "Center"),            // Dead center
            (0.15, 0.15, "Top Left"),        // Upper left
            (0.85, 0.15, "Top Right"),       // Upper right
            (0.15, 0.85, "Bottom Left"),     // Lower left
            (0.85, 0.85, "Bottom Right"),    // Lower right
            (0.5, 0.3, "Upper Center"),      // Upper-mid
            (0.5, 0.7, "Lower Center"),      // Lower-mid
        ]

        // Filter overlays that overlap in time
        let overlappingOverlays = existingOverlays.filter { overlay in
            // Check if time ranges overlap
            let thisStart = self.startTime
            let thisEnd = self.endTime
            let otherStart = overlay.startTime
            let otherEnd = overlay.endTime

            return !(thisEnd <= otherStart || thisStart >= otherEnd)
        }

        // Score each position based on distance from existing overlays
        var bestPosition = (x: 0.5, y: 0.5, score: 0.0, name: "Center")

        for position in safePositions {
            var score = 1.0 // Start with full score

            // Reduce score based on proximity to existing overlays
            for overlay in overlappingOverlays {
                let distance = sqrt(pow(position.x - overlay.x, 2) + pow(position.y - overlay.y, 2))

                // If too close, heavily penalize
                if distance < 0.2 {
                    score -= 0.8
                } else if distance < 0.4 {
                    score -= 0.3
                }
            }

            // Prefer certain positions (center positions are generally better)
            if position.name.contains("Center") {
                score += 0.1
            }

            if score > bestPosition.score {
                bestPosition = (position.x, position.y, score, position.name)
            }
        }

        // Apply the best position
        self.x = bestPosition.x
        self.y = bestPosition.y
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
