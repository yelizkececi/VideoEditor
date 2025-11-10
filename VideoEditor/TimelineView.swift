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

    var body: some View {
        VStack(spacing: 8) {
            // Timeline header
            HStack {
                Text("Timeline")
                    .font(.headline)

                Spacer()

                if viewModel.hasVideo {
                    Text("Duration: \(viewModel.videoDuration)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            if viewModel.hasVideo {
                // Timeline scrubber
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let startX = viewModel.trimStartPosition * totalWidth
                    let endX = viewModel.trimEndPosition * totalWidth

                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )

                        // Video thumbnail strip (gradient placeholder)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.4),
                                    Color.purple.opacity(0.4),
                                    Color.pink.opacity(0.4)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(height: 60)

                        // Selected region overlay
                        Rectangle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: max(0, endX - startX), height: 60)
                            .offset(x: startX)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.blue, lineWidth: 2)
                                    .frame(width: max(0, endX - startX), height: 60)
                            )

                        // Start trim handle
                        TrimHandle(isStart: true)
                            .position(x: startX, y: 30)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let dragX = startX + value.translation.width
                                        let newPosition = max(0, min(dragX / totalWidth, viewModel.trimEndPosition - 0.05))
                                        viewModel.updateTrimStart(newPosition)
                                    }
                            )

                        // End trim handle
                        TrimHandle(isStart: false)
                            .position(x: endX, y: 30)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let dragX = endX + value.translation.width
                                        let newPosition = max(viewModel.trimStartPosition + 0.05, min(dragX / totalWidth, 1.0))
                                        viewModel.updateTrimEnd(newPosition)
                                    }
                            )

                        // Time markers
                        VStack {
                            Spacer()
                            HStack(spacing: 0) {
                                Text(viewModel.trimStartTimeString)
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.75))
                                    .cornerRadius(4)
                                    .position(x: max(30, min(startX, totalWidth - 60)), y: 8)

                                Spacer()

                                Text(viewModel.trimEndTimeString)
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.75))
                                    .cornerRadius(4)
                                    .position(x: max(60, min(endX, totalWidth - 30)), y: 8)
                            }
                        }
                    }
                }
                .frame(height: 80)
                .padding(.horizontal)

                // Trim info and controls
                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(viewModel.trimStartTimeString) - \(viewModel.trimEndTimeString)")
                            .font(.system(.body, design: .monospaced))
                    }

                    Spacer()

                    Button("Reset") {
                        viewModel.resetTrim()
                    }
                    .buttonStyle(.bordered)

                    Button("Add to Segments") {
                        viewModel.addSegment()
                    }
                    .buttonStyle(.borderedProminent)
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

                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(Array(viewModel.segments.enumerated()), id: \.offset) { index, segment in
                                    SegmentRow(
                                        index: index,
                                        segment: segment,
                                        onDelete: { viewModel.deleteSegment(at: index) },
                                        onMoveUp: { viewModel.moveSegmentUp(at: index) },
                                        onMoveDown: { viewModel.moveSegmentDown(at: index) }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                    .padding(.horizontal)
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
            }
        }
        .padding(.vertical)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct TrimHandle: View {
    let isStart: Bool

    var body: some View {
        ZStack {
            // Handle bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .frame(width: 12, height: 60)
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

struct SegmentRow: View {
    let index: Int
    let segment: VideoSegment
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

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

#Preview {
    TimelineView(viewModel: VideoEditorViewModel())
        .frame(height: 300)
}
