# Video Editor

A modern macOS video editor built with SwiftUI and powered by FFmpeg for fast, professional video processing.

## Features

- **Import Videos**: Support for MP4, MOV, and other video formats
- **Video Playback**: Integrated video player with playback controls
- **Reverse Video**: Lightning-fast video reversal using FFmpeg (10-100x faster than frame-by-frame)
- **Trim Video**: Cut and trim video segments
- **Speed Adjustment**: Change video playback speed
- **Export**: Save edited videos to your desired location

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- **FFmpeg** (for fast video processing)

## Installation

### 1. Install FFmpeg

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

1. Open `VideoEditor.xcodeproj` in Xcode
2. Build and run the project (⌘R)
3. Import a video file to start editing

## Usage

1. Click "Import Video" to select a video file
2. Use the editing tools in the left sidebar:
   - **Reverse Video**: Plays the video in reverse (uses FFmpeg for speed)
   - **Trim Video**: Cuts the video to a specific duration
   - **Adjust Speed**: Changes the playback speed (2x by default)
3. Click "Export Video" to save your edited video

## Architecture

The app follows the MVVM pattern:
- `VideoEditorApp.swift`: Main app entry point
- `ContentView.swift`: UI layout and user interface
- `VideoEditorViewModel.swift`: Business logic and video processing

### Video Processing

- **Primary**: FFmpeg for professional-grade, fast video processing
- **Fallback**: AVFoundation frame-by-frame processing (slower, used when FFmpeg unavailable)

## Performance

With FFmpeg installed:
- 2-second video: ~0.5 seconds to reverse
- 10-second video: ~2 seconds to reverse
- Much faster than frame-by-frame processing!

## Troubleshooting

### "FFmpeg not found" message
Install FFmpeg using the command above. The app will work without it, but will be significantly slower.

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

## License

This project is available for personal and educational use.
