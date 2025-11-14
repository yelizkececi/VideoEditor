//
//  TimelineView.swift
//  VideoEditor
//
//  Created on 8.11.25.
//

import SwiftUI
import AVFoundation

struct TimelineView: View {
    @ObservedObject var viewModel: VideoEditorViewModel
    @ObservedObject var thumbnailGenerator: ThumbnailGenerator
    @State private var isDraggingPlayhead = false
    @State private var showTimeInputs = false
    @State private var startTimeInput = ""
    @State private var endTimeInput = ""
    @State private var segmentSpeed: Double = 1.0 // Speed for new segments

    init(viewModel: VideoEditorViewModel) {
        self.viewModel = viewModel
        self.thumbnailGenerator = viewModel.thumbnailGenerator
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 8) {
                // Timeline header
                HStack {
                    Text("Timeline")
                        .font(.headline)

                    Spacer()
                    Spacer()
                }
                .padding(.horizontal)

                if viewModel.hasVideo {
                    // Timeline with thumbnails - absolute positioning
                    GeometryReader { geometry in
                        let totalWidth = geometry.size.width
                        // Absolute positioning
                        let playheadX = viewModel.playheadPosition * totalWidth
                        let startX = viewModel.trimStartPosition * totalWidth
                        let endX = viewModel.trimEndPosition * totalWidth

                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 80)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                                )
                                .zIndex(0)

                            // Thumbnail strip (always show, will be empty initially)
                            ThumbnailStripView(
                                thumbnails: thumbnailGenerator.thumbnails,
                                width: totalWidth,
                                isGenerating: thumbnailGenerator.isGenerating
                            )
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .zIndex(1)

                            // Start trim handle (left edge)
                            TrimHandle(isStart: true)
                                .position(x: startX, y: 49)
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
                                        .onChanged { value in
                                            let mouseX = value.location.x
                                            let clampedX = max(0, min(mouseX, totalWidth))
                                            let newPosition = clampedX / totalWidth
                                            viewModel.updateTrimStart(newPosition)
                                        }
                                )
                                .zIndex(5)

                            // End trim handle (right edge)
                            TrimHandle(isStart: false)
                                .position(x: endX, y: 49)
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
                                        .onChanged { value in
                                            let mouseX = value.location.x
                                            let clampedX = max(0, min(mouseX, totalWidth))
                                            let newPosition = clampedX / totalWidth
                                            viewModel.updateTrimEnd(newPosition)
                                        }
                                )
                                .zIndex(5)

                            // Playhead scrubber - follows mouse directly
                            PlayheadView(isDragging: isDraggingPlayhead)
                                .position(x: playheadX, y: 49)
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
                                        .onChanged { value in
                                            isDraggingPlayhead = true

                                            let mouseX = value.location.x
                                            let clampedX = max(0, min(mouseX, totalWidth))
                                            let newPosition = clampedX / totalWidth
                                            viewModel.updatePlayhead(newPosition)
                                        }
                                        .onEnded { _ in
                                            isDraggingPlayhead = false
                                        }
                                )
                                .onTapGesture { }
                                .zIndex(10) // Ensure playhead is always on top
                        }
                        .onTapGesture { location in
                            // Click to move playhead with snap to nearest thumbnail
                            let newPosition = location.x / totalWidth
                            viewModel.updatePlayhead(max(0, min(newPosition, 1.0)), snapToThumbnails: true)
                        }
                        .coordinateSpace(name: "timeline")
                    }
                    .frame(height: 100)
                    .padding(.horizontal)

                // Time indicators and precise input
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(viewModel.trimStartTimeString)
                                .font(.caption)
                                .monospacedDigit()
                        }

                        Spacer()

                        VStack(spacing: 2) {
                            Text("Playhead")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text(viewModel.playheadTimeString)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundColor(.orange)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("End")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(viewModel.trimEndTimeString)
                                .font(.caption)
                                .monospacedDigit()
                        }
                    }

                    // Precise time input toggle
                    Button(action: { showTimeInputs.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: showTimeInputs ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                            Text(showTimeInputs ? "Hide Precise Input" : "Show Precise Input")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)

                    if showTimeInputs {
                        PreciseTimeInputView(
                            startTime: $startTimeInput,
                            endTime: $endTimeInput,
                            onApply: { start, end in
                                applyPreciseTime(start: start, end: end)
                            }
                        )
                    }
                }
                .padding(.horizontal)

                // Controls
                VStack(spacing: 8) {
                    // Speed selector
                    HStack(spacing: 8) {
                        Text("Speed:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $segmentSpeed) {
                            Text("0.25x").tag(0.25)
                            Text("0.5x").tag(0.5)
                            Text("0.75x").tag(0.75)
                            Text("1.0x (Normal)").tag(1.0)
                            Text("1.25x").tag(1.25)
                            Text("1.5x").tag(1.5)
                            Text("2.0x").tag(2.0)
                            Text("3.0x").tag(3.0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }

                    HStack(spacing: 12) {
                        Button("Reset Selection") {
                            viewModel.resetTrim()
                        }
                        .buttonStyle(.bordered)

                        Button {
                            viewModel.splitAtPlayhead(speed: segmentSpeed)
                        } label: {
                            Label("Split at Playhead", systemImage: "scissors")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(viewModel.playheadPosition <= viewModel.trimStartPosition || viewModel.playheadPosition >= viewModel.trimEndPosition)

                        Button("Add Selection") {
                            viewModel.addSegment(speed: segmentSpeed)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.reverseVideo()
                            }
                        } label: {
                            Label("Reverse Video", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(viewModel.isProcessing)
                    }
                }
                .padding(.horizontal)

                    // Segments list
                    if !viewModel.segments.isEmpty {
                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Segments (\(viewModel.segments.count))")
                                    .font(.headline)

                                Spacer()

                                Button("Clear All") {
                                    viewModel.clearSegments()
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal)

                            // Scrollable segments list with fixed height
                            LazyVStack(spacing: 4) {
                                ForEach(Array(viewModel.segments.enumerated()), id: \.offset) { index, segment in
                                    SegmentRow(
                                        index: index,
                                        segment: segment,
                                        onDelete: { viewModel.deleteSegment(at: index) },
                                        onMoveUp: { viewModel.moveSegmentUp(at: index) },
                                        onMoveDown: { viewModel.moveSegmentDown(at: index) },
                                        onSpeedChange: { newSpeed in
                                            viewModel.updateSegmentSpeed(at: index, speed: newSpeed)
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                } else {
                    // No video loaded state
                    VStack(spacing: 12) {
                        Image(systemName: "timeline.selection")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)

                        Text("No video loaded")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Import a video to use the timeline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 120)
                    .padding(.vertical)
                }
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // Helper function to apply precise time
    private func applyPreciseTime(start: String, end: String) {
        guard let startSeconds = parseTimeString(start),
              let endSeconds = parseTimeString(end) else {
            return
        }

        let duration = viewModel.videoDuration
        let durationSeconds = parseDurationToSeconds(duration)

        if startSeconds >= 0 && endSeconds <= durationSeconds && startSeconds < endSeconds {
            viewModel.updateTrimStart(startSeconds / durationSeconds)
            viewModel.updateTrimEnd(endSeconds / durationSeconds)
        }
    }

    private func parseTimeString(_ timeString: String) -> Double? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let minutes = Double(components[0]),
              let seconds = Double(components[1]) else {
            return nil
        }
        return minutes * 60 + seconds
    }

    private func parseDurationToSeconds(_ duration: String) -> Double {
        let components = duration.split(separator: ":")
        guard components.count == 2,
              let minutes = Double(components[0]),
              let seconds = Double(components[1]) else {
            return 0
        }
        return minutes * 60 + seconds
    }
}

// MARK: - Thumbnail Strip View
struct ThumbnailStripView: View {
    let thumbnails: [ThumbnailGenerator.VideoThumbnail]
    let width: CGFloat
    let isGenerating: Bool

    var body: some View {
        Group {
            if !thumbnails.isEmpty {
                // Thumbnails available - ALWAYS show these first
                HStack(spacing: 0) {
                    ForEach(Array(thumbnails.enumerated()), id: \.element.id) { index, thumbnail in
                        thumbnail.image.asImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width / CGFloat(thumbnails.count), height: 80)
                            .clipped()
                            .overlay(
                                Rectangle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            } else if isGenerating {
                // Loading indicator - only when generating and empty
                ZStack {
                    Color.gray.opacity(0.1)

                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .controlSize(.small)

                        Text("Loading thumbnails...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Empty state
                Color.clear
            }
        }
    }
}

// MARK: - Playhead View
struct PlayheadView: View {
    var isDragging: Bool = false

    var body: some View {
        ZStack {
            // Vertical line - thicker when dragging
            Rectangle()
                .fill(Color.orange)
                .frame(width: isDragging ? 4 : 3, height: 80)
                .animation(.easeInOut(duration: 0.2), value: isDragging)

            // Top triangle - larger when dragging
            Triangle()
                .fill(Color.orange)
                .frame(width: isDragging ? 20 : 16, height: isDragging ? 14 : 12)
                .offset(y: -46)
                .animation(.easeInOut(duration: 0.2), value: isDragging)

            // Circular handle in the middle - larger when dragging
            Circle()
                .fill(Color.orange)
                .frame(width: isDragging ? 20 : 16, height: isDragging ? 20 : 16)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isDragging ? 3 : 2)
                )
                .shadow(color: .black.opacity(isDragging ? 0.5 : 0.3), radius: isDragging ? 5 : 3, x: 0, y: 2)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Trim Handle
struct TrimHandle: View {
    let isStart: Bool

    var body: some View {
        ZStack {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .frame(width: 12, height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.blue, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            // Chevron indicator
            VStack(spacing: 2) {
                Image(systemName: isStart ? "chevron.right" : "chevron.left")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.blue)
                Image(systemName: isStart ? "chevron.right" : "chevron.left")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Segment Row
struct SegmentRow: View {
    let index: Int
    let segment: VideoSegment
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSpeedChange: (Double) -> Void

    @State private var currentSpeed: Double

    init(index: Int, segment: VideoSegment, onDelete: @escaping () -> Void, onMoveUp: @escaping () -> Void, onMoveDown: @escaping () -> Void, onSpeedChange: @escaping (Double) -> Void) {
        self.index = index
        self.segment = segment
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onSpeedChange = onSpeedChange
        self._currentSpeed = State(initialValue: segment.speed)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Segment number
            Text("\(index + 1)")
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())

            // Segment info
            VStack(alignment: .leading, spacing: 2) {
                Text("Segment \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(segment.startTimeString) - \(segment.endTimeString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Speed picker
            Picker("", selection: $currentSpeed) {
                Text("0.25x").tag(0.25)
                Text("0.5x").tag(0.5)
                Text("0.75x").tag(0.75)
                Text("1.0x").tag(1.0)
                Text("1.25x").tag(1.25)
                Text("1.5x").tag(1.5)
                Text("2.0x").tag(2.0)
                Text("3.0x").tag(3.0)
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .onChange(of: currentSpeed) { oldValue, newValue in
                onSpeedChange(newValue)
            }

            // Duration
            Text(segment.durationString)
                .font(.caption)
                .foregroundColor(.secondary)
            
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)

            // Controls
            HStack(spacing: 4) {
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(index == 0)

                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Precise Time Input View
struct PreciseTimeInputView: View {
    @Binding var startTime: String
    @Binding var endTime: String
    let onApply: (String, String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Time (M:SS)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("0:00", text: $startTime)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .font(.system(.body, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("End Time (M:SS)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("0:00", text: $endTime)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .font(.system(.body, design: .monospaced))
                }

                Button("Apply") {
                    onApply(startTime, endTime)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text("Format: Minutes:Seconds (e.g., 1:30 for 1 minute 30 seconds)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    TimelineView(viewModel: VideoEditorViewModel())
        .frame(height: 400)
}
