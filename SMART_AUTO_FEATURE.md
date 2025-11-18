# Smart Auto Feature - Intelligent Text Styling

## Overview
The Smart Auto feature analyzes the video background where text will appear and automatically chooses optimal colors for maximum readability and visual appeal.

## Features

### 1. **Auto-Style** (Color Analysis)
Analyzes the video frame at the text position and automatically sets:
- **Text Color**: White or Black (depending on background)
- **Background Color**: Contrasting semi-transparent overlay
- **Shadow**: Automatic shadow for enhanced readability

### 2. **Auto-Position** (Collision Avoidance)
Finds the best position avoiding other overlays (as described in AUTO_POSITION_FEATURE.md)

### 3. **Smart Auto** (Combined)
One-click solution that:
1. First finds optimal position (avoiding other text)
2. Then analyzes background colors at that position
3. Sets optimal text/background colors

## How It Works

### Color Analysis Algorithm

1. **Frame Extraction**
   - Extracts the video frame at the text's start time
   - Uses AVAssetImageGenerator for accurate frame capture

2. **Sample Region**
   - Samples a 20% area around the text position
   - Ensures representative color analysis

3. **Average Color Calculation**
   - Processes all pixels in the sample region
   - Calculates RGB averages
   - Uses weighted brightness formula: `(0.299 * R + 0.587 * G + 0.114 * B)`
   - This formula matches human perception of brightness

4. **Intelligent Color Selection**

   **For Bright Backgrounds (brightness > 0.5):**
   - Text: Black
   - Background: Semi-transparent black (40% opacity)
   - Shadow: Black

   **For Dark Backgrounds (brightness ≤ 0.5):**
   - Text: White
   - Background: Semi-transparent white (30% opacity)
   - Shadow: White

5. **Automatic Shadow**
   - Always enabled for maximum readability
   - Shadow color matches contrast choice
   - 4pt shadow radius

## Buttons in the Text Overlay Editor

### 1. Smart Auto Button (Header - Top Right)
- **Icon**: ✨ Sparkles
- **Location**: Next to Cancel/Save buttons
- **Action**: Optimizes both position AND colors
- **When to use**: Starting fresh or want full automation

### 2. Auto-Position Button (Position Section)
- **Icon**: 🪄 Wand and stars
- **Location**: Position section, below X/Y sliders
- **Action**: Only adjusts position
- **When to use**: Happy with colors, just need better position

### 3. Auto-Style Button (Styling Section)
- **Icon**: 🎨 Paint palette
- **Location**: Styling section header
- **Action**: Only adjusts colors
- **When to use**: Position is good, colors need optimization

## Use Cases

### News/Documentary Overlays
- Bright outdoor scenes → Black text automatically
- Dark indoor scenes → White text automatically
- Always readable regardless of background

### Social Media Content
- Quick styling for multiple text elements
- Ensures text stands out on any background
- Professional look without manual tweaking

### Educational Videos
- Clear, readable annotations
- Consistent style across changing scenes
- Automatic adaptation to scene lighting

### Interview Lower Thirds
- Speaker names always readable
- Adapts to scene brightness
- Professional appearance

## Technical Details

### Performance
- Frame extraction: ~50-100ms per frame
- Color analysis: ~10-20ms per sample
- Total time: < 200ms per text overlay
- Runs asynchronously (non-blocking UI)

### Accuracy
- Samples 20% of frame area (not just single pixel)
- Weighted brightness formula matches human vision
- Handles edge cases (very bright/dark scenes)

### Video Compatibility
- Works with any video format supported by AVFoundation
- Respects video orientation/transform
- Resolution-independent (normalized coordinates)

## Example Workflow

### Quick Setup:
1. Add text overlay
2. Type your text
3. Click **"Smart Auto"** in header
4. Done! ✨

### Manual Fine-Tuning:
1. Click **"Smart Auto"** for baseline
2. Manually adjust position if needed
3. Click **"Auto-Style"** to reanalyze colors at new position
4. Tweak colors manually if desired

### Position Only:
1. Set colors manually
2. Click **"Auto-Position"** to avoid collisions
3. Colors remain unchanged

## Code Locations

- **Model Logic**: `VideoEditor/Models/TextOverlay.swift`
  - `autoStyle(videoFrame:)` method
  - `averageColor(of:)` helper method

- **Frame Extraction**: `VideoEditor/ViewModels/VideoEditorViewModel.swift`
  - `extractFrame(at:)` method

- **UI Implementation**: `VideoEditor/Views/TextOverlayView.swift`
  - Smart Auto button in header
  - Auto-Style button in Styling section
  - Auto-Position button in Position section

## Future Enhancements (Ideas)

- [ ] Detect faces and avoid placing text over them
- [ ] Motion analysis - place text in stable areas
- [ ] Color palette extraction for brand consistency
- [ ] Multi-frame sampling for moving backgrounds
- [ ] Machine learning for optimal positioning
- [ ] A/B testing different color schemes
