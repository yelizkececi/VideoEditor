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
            // Left sidebar - controls
            VStack(alignment: .leading, spacing: 20) {
                Text("Video Editor")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)

                Divider()

                // Import section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Import")
                        .font(.headline)

                    Button(action: {
                        viewModel.importVideo()
                    }) {
                        Label("Import Video", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isProcessing)
                }

                Divider()

                // Editing tools
                VStack(alignment: .leading, spacing: 10) {
                    Text("Edit")
                        .font(.headline)

                    Button(action: {
                        Task {
                            await viewModel.reverseVideo()
                        }
                    }) {
                        Label("Reverse Video", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!viewModel.hasVideo || viewModel.isProcessing)

                    Button(action: {
                        Task {
                            await viewModel.trimVideo()
                        }
                    }) {
                        Label("Trim Video", systemImage: "scissors")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!viewModel.hasVideo || viewModel.isProcessing)

                    Button(action: {
                        Task {
                            await viewModel.adjustSpeed()
                        }
                    }) {
                        Label("Adjust Speed", systemImage: "speedometer")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!viewModel.hasVideo || viewModel.isProcessing)
                }

                Divider()

                // Export section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Export")
                        .font(.headline)

                    Button(action: {
                        viewModel.exportVideo()
                    }) {
                        Label("Export Full Video", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!viewModel.hasVideo || viewModel.isProcessing)

                    Button(action: {
                        viewModel.exportSegments()
                    }) {
                        Label("Export Segments (\(viewModel.segments.count))", systemImage: "film.stack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(viewModel.segments.isEmpty || viewModel.isProcessing)
                }

                Spacer()

                // Progress indicator
                if viewModel.isProcessing {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.progress) {
                            Text(viewModel.statusMessage)
                                .font(.caption)
                        }
                        Text("\(Int(viewModel.progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(3)
                }
            }
            .padding(20)
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 350)
            .background(Color(nsColor: .controlBackgroundColor))

            // Right side - video player and timeline
            VStack(spacing: 0) {
                // Video player
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    ZStack {
                        Color.black

                        VStack(spacing: 20) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)

                            Text("No video loaded")
                                .font(.title2)
                                .foregroundColor(.gray)

                            Text("Import a video to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Video info bar
                if viewModel.hasVideo {
                    HStack {
                        Text(viewModel.videoFileName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(viewModel.videoDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                }

                // Timeline
                Divider()

                TimelineView(viewModel: viewModel)
                    .frame(height: 300)
            }
        }
        .frame(minWidth: 900, minHeight: 900)
    }
}

#Preview {
    ContentView()
}
