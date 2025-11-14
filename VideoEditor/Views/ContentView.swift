//
//  ContentView.swift
//  VideoEditor
//
//  Created on 8.11.25.
//

import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var viewModel = VideoEditorViewModel()

    var body: some View {
        HSplitView {
            // Left side - video player and timeline
            VStack(spacing: 0) {
                // Video player
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    ZStack {
                        Color.black.opacity(0.9)

                        VStack(spacing: 24) {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 70))
                                .foregroundStyle(.gray.gradient)

                            VStack(spacing: 8) {
                                Text("No video loaded")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.gray)

                                Text("Click Import Video to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Video info bar
                if viewModel.hasVideo {
                    HStack(spacing: 12) {
                        Image(systemName: "film")
                            .foregroundColor(.secondary)

                        Text(viewModel.videoFileName)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(viewModel.videoDuration)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: .controlBackgroundColor))
                }

                // Timeline
                Divider()

                TimelineView(viewModel: viewModel)
                    .frame(minHeight: 300, maxHeight: .infinity)
            }

            // Right sidebar - Modern controls
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "film.fill")
                            .font(.title2)
                            .foregroundStyle(.blue.gradient)

                        Text("Video Editor")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Spacer()
                    }

                    if viewModel.hasVideo {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(viewModel.videoFileName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
                .padding(20)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                ScrollView {
                    VStack(spacing: 20) {
                        // Import Section
                        VStack(alignment: .leading, spacing: 10) {
                            ModernButton(
                                title: "Import Video",
                                icon: "square.and.arrow.down.fill",
                                color: .blue,
                                isProminent: true,
                                isDisabled: viewModel.isProcessing
                            ) {
                                viewModel.importVideo()
                            }
                        }

                        Divider()

                        // Export Section
                        VStack(alignment: .leading, spacing: 10) {
                            ModernButton(
                                title: "Export Video",
                                icon: "arrow.up.circle.fill",
                                color: .green,
                                isProminent: true,
                                isDisabled: !viewModel.hasVideo || viewModel.isProcessing
                            ) {
                                viewModel.exportVideo()
                            }

                            if !viewModel.segments.isEmpty {
                                ModernButton(
                                    title: "Export Segments (\(viewModel.segments.count))",
                                    icon: "film.stack.fill",
                                    color: .orange,
                                    isProminent: true,
                                    isDisabled: viewModel.isProcessing
                                ) {
                                    viewModel.exportSegments()
                                }
                            }
                        }

                        // Stats Section
                        if viewModel.hasVideo {
                            Divider()

                            ModernStatsCard(
                                duration: viewModel.videoDuration,
                                segments: viewModel.segments.count
                            )
                        }
                    }
                    .padding(16)
                }

                // Bottom status area
                VStack(spacing: 12) {
                    if viewModel.isProcessing {
                        VStack(spacing: 8) {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .controlSize(.small)
                                Text(viewModel.statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }

                            ProgressView(value: viewModel.progress)
                                .tint(.blue)

                            Text("\(Int(viewModel.progress * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if let error = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(16)
            }
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 240)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 900)
    }
}

// MARK: - Modern Components

struct ModernButtonGroup<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                content
            }
        }
        .padding(.vertical, 4)
    }
}

struct ModernButton: View {
    let title: String
    let icon: String
    var color: Color = .blue
    var isProminent: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 20)

                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()

                if !isDisabled {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(isHovered ? 1 : 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isProminent
                          ? color.opacity(isDisabled ? 0.3 : 1)
                          : (isHovered && !isDisabled ? color.opacity(0.1) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isProminent ? Color.clear : color.opacity(isDisabled ? 0.3 : 0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isProminent
                         ? .white
                         : (isDisabled ? color.opacity(0.5) : color))
        .disabled(isDisabled)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

struct ModernStatsCard: View {
    let duration: String
    let segments: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Statistics")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                StatItem(icon: "clock.fill", label: "Duration", value: duration, color: .blue)

                Divider()
                    .frame(height: 30)

                StatItem(icon: "film.fill", label: "Segments", value: "\(segments)", color: .orange)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color.gradient)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
}
