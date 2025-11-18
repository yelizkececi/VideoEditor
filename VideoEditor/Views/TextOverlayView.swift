//
//  TextOverlayView.swift
//  VideoEditor
//
//  UI for managing text overlays
//

import SwiftUI

struct TextOverlayPanel: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "textformat")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Text Overlays")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                if !viewModel.textOverlays.isEmpty {
                    Text("\(viewModel.textOverlays.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }

            if viewModel.hasVideo {
                // Add text buttons
                VStack(spacing: 8) {
                    Menu {
                        Button("Custom Text") {
                            viewModel.addTextOverlay(preset: .custom)
                            showingEditor = true
                        }
                        Button("Title") {
                            viewModel.addTextOverlay(preset: .title)
                            showingEditor = true
                        }
                        Button("Subtitle") {
                            viewModel.addTextOverlay(preset: .subtitle)
                            showingEditor = true
                        }
                        Button("Watermark") {
                            viewModel.addTextOverlay(preset: .watermark)
                            showingEditor = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.body)
                            Text("Add Text")
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // List of text overlays
                    if !viewModel.textOverlays.isEmpty {
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(Array(viewModel.textOverlays.enumerated()), id: \.element.id) { index, overlay in
                                    TextOverlayRow(
                                        overlay: overlay,
                                        isSelected: viewModel.selectedTextOverlay?.id == overlay.id,
                                        onSelect: {
                                            viewModel.selectedTextOverlay = overlay
                                            showingEditor = true
                                        },
                                        onDelete: {
                                            viewModel.deleteTextOverlay(at: index)
                                        },
                                        onDuplicate: {
                                            viewModel.duplicateTextOverlay(at: index)
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 200)

                        Button("Clear All") {
                            viewModel.clearTextOverlays()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
            } else {
                Text("Load a video to add text overlays")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditor) {
            if let selectedOverlay = viewModel.selectedTextOverlay {
                TextOverlayEditor(
                    overlay: selectedOverlay,
                    videoDuration: viewModel.videoDurationSeconds,
                    existingOverlays: viewModel.textOverlays.filter { $0.id != selectedOverlay.id },
                    viewModel: viewModel,
                    onSave: { updatedOverlay in
                        viewModel.updateTextOverlay(updatedOverlay)
                        showingEditor = false
                    },
                    onCancel: {
                        showingEditor = false
                    }
                )
            }
        }
    }
}

struct TextOverlayRow: View {
    let overlay: TextOverlay
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Text preview
            VStack(alignment: .leading, spacing: 4) {
                Text(overlay.text.isEmpty ? "Empty Text" : overlay.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("\(overlay.startTimeString) - \(overlay.endTimeString)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            HStack(spacing: 4) {
                Button(action: onDuplicate) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Duplicate")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(8)
        .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

struct TextOverlayEditor: View {
    @State private var overlay: TextOverlay
    let videoDuration: Double
    let existingOverlays: [TextOverlay]
    @ObservedObject var viewModel: VideoEditorViewModel
    let onSave: (TextOverlay) -> Void
    let onCancel: () -> Void

    @State private var availableFonts: [String] = []
    @State private var isAnalyzingColors = false

    init(overlay: TextOverlay, videoDuration: Double, existingOverlays: [TextOverlay], viewModel: VideoEditorViewModel, onSave: @escaping (TextOverlay) -> Void, onCancel: @escaping () -> Void) {
        _overlay = State(initialValue: overlay)
        self.videoDuration = videoDuration
        self.existingOverlays = existingOverlays
        self.viewModel = viewModel
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Text Overlay")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Smart Auto button - does position + styling
                Button(action: {
                    Task {
                        isAnalyzingColors = true
                        // First auto-position
                        overlay.autoPosition(existingOverlays: existingOverlays)
                        // Then auto-style based on that position
                        if let frame = await viewModel.extractFrame(at: overlay.startTime) {
                            overlay.autoStyle(videoFrame: frame)
                        }
                        isAnalyzingColors = false
                    }
                }) {
                    HStack(spacing: 4) {
                        if isAnalyzingColors {
                            ProgressView()
                                .scaleEffect(0.7)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("Smart Auto")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isAnalyzingColors)
                .help("Automatically optimize position and colors")

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    onSave(overlay)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Text content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Text Content")
                            .font(.headline)

                        TextEditor(text: $overlay.text)
                            .font(.system(size: 16))
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Timing
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timing")
                            .font(.headline)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Start Time (s)")
                                    .font(.caption)
                                TextField("0.0", value: $overlay.startTime, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }

                            VStack(alignment: .leading) {
                                Text("End Time (s)")
                                    .font(.caption)
                                TextField("5.0", value: $overlay.endTime, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }

                            VStack(alignment: .leading) {
                                Text("Duration")
                                    .font(.caption)
                                Text(overlay.durationString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Position
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Position")
                            .font(.headline)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("X (0.0 - 1.0)")
                                    .font(.caption)
                                Slider(value: $overlay.x, in: 0...1)
                                Text(String(format: "%.2f", overlay.x))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading) {
                                Text("Y (0.0 - 1.0)")
                                    .font(.caption)
                                Slider(value: $overlay.y, in: 0...1)
                                Text(String(format: "%.2f", overlay.y))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Preview position: \(positionDescription)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(action: {
                                overlay.autoPosition(existingOverlays: existingOverlays)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.caption)
                                    Text("Auto-Position")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.bordered)
                            .help("Automatically find the best position avoiding other overlays")
                        }
                    }

                    // Styling
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Styling")
                                .font(.headline)

                            Spacer()

                            Button(action: {
                                Task {
                                    isAnalyzingColors = true
                                    if let frame = await viewModel.extractFrame(at: overlay.startTime) {
                                        overlay.autoStyle(videoFrame: frame)
                                    }
                                    isAnalyzingColors = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if isAnalyzingColors {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "paintpalette")
                                            .font(.caption)
                                    }
                                    Text("Auto-Style")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isAnalyzingColors)
                            .help("Analyze video background and set optimal text/background colors")
                        }

                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Font")
                                    .font(.caption)
                                Picker("", selection: $overlay.fontName) {
                                    ForEach(availableFonts, id: \.self) { font in
                                        Text(font).tag(font)
                                    }
                                }
                                .frame(width: 200)
                            }

                            VStack(alignment: .leading) {
                                Text("Font Size")
                                    .font(.caption)
                                Slider(value: $overlay.fontSize, in: 12...120)
                                Text("\(Int(overlay.fontSize))pt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading) {
                                Text("Font Weight")
                                    .font(.caption)
                                Picker("", selection: $overlay.fontWeight) {
                                    ForEach(TextOverlay.FontWeight.allCases, id: \.self) { weight in
                                        Text(weight.rawValue).tag(weight)
                                    }
                                }
                                .frame(width: 120)
                            }
                        }

                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Opacity")
                                    .font(.caption)
                                Slider(value: $overlay.opacity, in: 0...1)
                                Text("\(Int(overlay.opacity * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Text Color")
                                    .font(.caption)
                                ColorPicker("", selection: $overlay.textColor)
                                    .labelsHidden()
                            }

                            VStack(alignment: .leading) {
                                Text("Background Color")
                                    .font(.caption)
                                ColorPicker("", selection: $overlay.backgroundColor)
                                    .labelsHidden()
                            }

                            VStack(alignment: .leading) {
                                Text("Background Opacity")
                                    .font(.caption)
                                Slider(value: $overlay.backgroundOpacity, in: 0...1)
                                    .frame(width: 100)
                            }
                        }

                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Alignment")
                                    .font(.caption)
                                Picker("", selection: $overlay.textAlignment) {
                                    ForEach(TextOverlay.TextAlignment.allCases, id: \.self) { alignment in
                                        Text(alignment.rawValue).tag(alignment)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 200)
                            }

                            Toggle("Shadow", isOn: $overlay.hasShadow)
                        }
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.headline)

                        ZStack {
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: 150)

                            Text(overlay.text)
                                .font(.custom(overlay.fontName, size: overlay.fontSize / 3))
                                .fontWeight(overlay.fontWeight.swiftUIWeight)
                                .foregroundColor(overlay.textColor)
                                .opacity(overlay.opacity)
                                .padding(8)
                                .background(
                                    overlay.backgroundColor.opacity(overlay.backgroundOpacity)
                                )
                                .cornerRadius(4)
                                .shadow(
                                    color: overlay.hasShadow ? overlay.shadowColor : .clear,
                                    radius: overlay.hasShadow ? overlay.shadowRadius : 0
                                )
                        }
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            loadAvailableFonts()
        }
    }

    private var positionDescription: String {
        let xDesc = overlay.x < 0.33 ? "left" : overlay.x > 0.67 ? "right" : "center"
        let yDesc = overlay.y < 0.33 ? "top" : overlay.y > 0.67 ? "bottom" : "middle"
        return "\(yDesc) \(xDesc)"
    }

    private func loadAvailableFonts() {
        let fontManager = NSFontManager.shared
        let allFonts = fontManager.availableFonts

        // Handwritten/Casual fonts (prioritized)
        let handwrittenFonts = [
            "Snell Roundhand",
            "Bradley Hand Bold",
            "Noteworthy-Bold",
            "Marker Felt Wide",
            "Comic Sans MS"
        ]

        // Common readable fonts
        let commonFonts = [
            "Helvetica",
            "Helvetica-Bold",
            "Arial",
            "Arial-BoldMT",
            "Times New Roman",
            "Times-Bold",
            "Courier",
            "Courier-Bold",
            "Georgia",
            "Georgia-Bold",
            "Verdana",
            "Verdana-Bold",
            "Impact",
            "Futura-Medium",
            "Futura-Bold",
            "Avenir-Medium",
            "Avenir-Heavy",
            "Baskerville",
            "Baskerville-Bold"
        ]

        var filteredFonts: [String] = []

        // Add handwritten fonts first (if available)
        for font in handwrittenFonts {
            if allFonts.contains(font) || NSFont(name: font, size: 12) != nil {
                filteredFonts.append(font)
            }
        }

        // Add common fonts
        for font in commonFonts {
            if allFonts.contains(font) || NSFont(name: font, size: 12) != nil {
                filteredFonts.append(font)
            }
        }

        // Add any other popular fonts that might be available
        let popularFonts = allFonts.filter { font in
            let lowercased = font.lowercased()
            return (lowercased.contains("bold") ||
                    lowercased.contains("medium") ||
                    lowercased.contains("regular")) &&
                   !lowercased.contains("oblique") &&
                   !lowercased.contains("italic") &&
                   !lowercased.contains("condensed") &&
                   !lowercased.contains("light") &&
                   !lowercased.contains("thin") &&
                   !filteredFonts.contains(font)
        }

        // Add up to 20 more popular fonts
        filteredFonts.append(contentsOf: popularFonts.prefix(20))

        // Remove duplicates and sort (keeping handwritten at top)
        let handwrittenCount = filteredFonts.filter { handwrittenFonts.contains($0) }.count
        let handwritten = Array(filteredFonts.prefix(handwrittenCount))
        let rest = Array(filteredFonts.dropFirst(handwrittenCount)).sorted()

        availableFonts = handwritten + rest

        // Fallback to all fonts if we have less than 10
        if availableFonts.count < 10 {
            availableFonts = allFonts.sorted()
        }
    }
}

#Preview {
    TextOverlayPanel(viewModel: VideoEditorViewModel())
        .frame(width: 240)
}
