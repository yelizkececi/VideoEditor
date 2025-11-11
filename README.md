# Video Editor

A modern macOS video editor built with SwiftUI and powered by FFmpeg for fast, professional video processing.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)

## ✨ Features

### Video Processing
- **Import Videos**: Support for MP4, MOV, and other video formats
- **Video Playback**: Integrated AVKit player with playback controls
- **Reverse Video**: Lightning-fast video reversal using FFmpeg (10-100x faster than frame-by-frame)
- **Trim Video**: Precise trimming with interactive timeline
- **Speed Adjustment**: Change video playback speed
- **Segment Management**: Create, organize, and export multiple video segments
- **Export**: Save full videos or combined segments

### Timeline Features
- **Interactive Playhead**: Drag to scrub through video with 1:1 mouse tracking
- **Trim Handles**: Click and drag start/end handles to define selection range
- **Thumbnail Preview**: Visual timeline with video frame thumbnails
- **Precise Time Input**: Enter exact timestamps (M:SS format) for frame-accurate trimming
- **Segment List**: Scrollable list showing all created segments with reordering controls
- **Visual Feedback**: Real-time updates as you interact with timeline controls

## 📋 Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- **FFmpeg** (optional, for faster video processing)

## 🚀 Installation

### 1. Install FFmpeg (Recommended)

The app uses FFmpeg for fast video processing. Install it using Homebrew:

```bash
brew install ffmpeg
```

**Don't have Homebrew?** Install it first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Note:** The app will automatically fall back to slower AVFoundation processing if FFmpeg is not installed.

### 2. Build the App

1. Clone the repository
2. Open `VideoEditor.xcodeproj` in Xcode
3. Build and run the project (⌘R)
4. Import a video file to start editing

## 🎯 Usage

### Basic Workflow
1. **Import**: Click "Import Video" to select a video file
2. **Edit**: Use the timeline to position playhead and set trim handles
3. **Segment**: Click "Add Selection" to create segments from your selection
4. **Export**: Export individual segments or the full video

### Timeline Controls
- **Playhead (Orange)**: Drag to scrub through video
- **Start Handle (Left)**: Drag to set selection start point
- **End Handle (Right)**: Drag to set selection end point
- **Click Timeline**: Jump playhead to specific position
- **Precise Input**: Use "Show Precise Input" for exact timestamp entry

### Editing Tools
- **Reverse Video**: Reverses the entire video (uses FFmpeg for speed)
- **Trim Video**: Cuts video to selected range
- **Adjust Speed**: Changes playback speed (configurable)
- **Split at Playhead**: Divide selection into two segments at playhead position

## 🏗️ Architecture

The project follows clean architecture principles with MVVM pattern:

```
VideoEditor/
├── 📁 App/
│   └── VideoEditorApp.swift        # App entry point
├── 📁 Views/
│   ├── ContentView.swift           # Main view with controls
│   └── TimelineView.swift          # Timeline UI (playhead, handles, thumbnails)
├── 📁 ViewModels/
│   └── VideoEditorViewModel.swift  # Business logic & state management
├── 📁 Models/
│   └── VideoSegment.swift          # Video segment data model
└── 📁 Services/
    └── ThumbnailGenerator.swift    # Thumbnail generation service
```

### Key Components

#### Views
- **ContentView**: Main application layout with sidebar controls and video player
- **TimelineView**: Interactive timeline with playhead, trim handles, and thumbnail strip
- **PlayheadView**: Orange draggable playhead indicator
- **TrimHandle**: White handles for start/end selection points
- **SegmentRow**: Individual segment display in the list

#### ViewModel
- **VideoEditorViewModel**: Manages video state, playback, editing operations, and export
  - Handles FFmpeg/AVFoundation video processing
  - Manages timeline positions and segments
  - Coordinates thumbnail generation

#### Services
- **ThumbnailGenerator**: Async thumbnail generation from video frames
  - Generates preview thumbnails at specified intervals
  - Supports single frame extraction at specific times

### Video Processing

- **Primary**: FFmpeg for professional-grade, fast video processing
  - Used for: Video reversal, exports
  - 10-100x faster than frame-by-frame
- **Fallback**: AVFoundation for frame-accurate operations
  - Used for: Trimming, speed adjustment, segments
  - Preserves video orientation (portrait/landscape)

## ⚡ Performance

### With FFmpeg installed:
- 2-second video: ~0.5 seconds to reverse
- 10-second video: ~2 seconds to reverse
- Real-time progress monitoring during export
- Non-blocking UI with async/await operations

### Timeline:
- Smooth 1:1 mouse tracking for all controls
- Dynamic thumbnail loading
- Efficient LazyVStack for segment rendering
- Position-based drag gestures for precise control

## 🔧 Troubleshooting

### "FFmpeg not found" message
Install FFmpeg using the command above. The app will work without it, but will be significantly slower for video reversal.

### Video processing is slow
Make sure FFmpeg is installed. Check the console logs - you should see:
```
✅ [REVERSE] Using FFmpeg at: /opt/homebrew/bin/ffmpeg
```

If you see:
```
⚠️ [REVERSE] Using legacy AVFoundation method (slower)...
```
Then FFmpeg is not installed or not in the expected path.

### Trim handles not moving
Ensure you're clicking and dragging the white handle bars directly. They use named coordinate space for accurate positioning.

### Video rotated after export
The app preserves `preferredTransform` to maintain orientation. If videos still rotate, check that your input video has correct metadata.

## 🎨 UI/UX Features

- **Sensitivity Control**: Adjustable slider (currently disabled for direct 1:1 tracking)
- **Hover Effects**: Thumbnail highlighting on mouse hover
- **Visual Feedback**: Playhead grows slightly during drag
- **Snap to Thumbnail**: Optional snapping when clicking timeline
- **Progress Indicators**: Real-time export progress with percentage
- **Error Handling**: Clear error messages in UI

## 📝 Recent Updates

- ✅ Implemented interactive trim handles with mouse-based positioning
- ✅ Fixed playhead to follow mouse proportionally (1:1 tracking)
- ✅ Reorganized project with clean architecture
- ✅ Added scrollable segment list
- ✅ Improved timeline interaction with direct mouse positioning
- ✅ Added precise time input for frame-accurate trimming
- ✅ Maintained video orientation during all exports

## 📄 License

This project is available for personal and educational use.

---

**Built with ❤️ using SwiftUI, AVFoundation, and FFmpeg**
