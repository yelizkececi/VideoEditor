# Auto-Position Feature

## Overview
Added an intelligent auto-positioning feature that automatically finds the best placement for text overlays on your video, avoiding collisions with other text elements.

## How It Works

### Algorithm
The auto-position feature uses a smart scoring system:

1. **Defines 9 Safe Zones**: Pre-selected positions that work well for text:
   - Top Center (Title position)
   - Bottom Center (Subtitle position)
   - Center
   - Top Left, Top Right
   - Bottom Left, Bottom Right
   - Upper Center, Lower Center

2. **Time-Based Collision Detection**:
   - Only considers overlays that appear at the same time
   - Ignores text that appears at different times

3. **Distance-Based Scoring**:
   - Each position starts with a score of 1.0
   - Score is reduced based on proximity to other overlays:
     - Very close (< 0.2 distance): -0.8 penalty
     - Moderately close (< 0.4 distance): -0.3 penalty
   - Center positions get a +0.1 bonus (generally better)

4. **Best Position Selection**:
   - Chooses the position with the highest score
   - Automatically updates the text overlay coordinates

## How to Use

### In the Text Overlay Editor:

1. Open any text overlay for editing
2. Scroll to the **Position** section
3. Click the **"Auto-Position"** button (with magic wand icon ✨)
4. The text will instantly move to the optimal position

### Features:

- **Smart Avoidance**: Automatically avoids other text overlays that appear at the same time
- **Time-Aware**: Overlays at different times can occupy the same space
- **Visual Feedback**: Position updates immediately with live preview
- **Safe Zones**: Uses cinematically appropriate positions
- **One-Click**: Single button to find perfect placement

## Example Use Cases

### Multiple Subtitles
If you have multiple subtitle overlays:
- First subtitle → Bottom Center
- Second (overlapping time) → Auto-positions to Upper Center or side
- Third → Finds next best available position

### Title + Subtitle + Watermark
- Title at top
- Subtitle at bottom
- Watermark auto-positions to corner that doesn't conflict

### Dynamic Text Elements
Perfect for:
- Social media videos with multiple callouts
- Educational videos with annotations
- Interviews with speaker names
- Tutorial videos with step indicators

## Technical Details

### Position Coordinates
- Uses normalized coordinates (0.0 to 1.0)
- Works across any video resolution
- x: 0.0 = left edge, 1.0 = right edge
- y: 0.0 = top edge, 1.0 = bottom edge

### Performance
- O(n×m) complexity where n = 9 positions, m = existing overlays
- Instant calculation even with many overlays
- No video analysis required

## Button Location

**Text Overlay Editor → Position Section → "Auto-Position" Button**

The button appears below the X/Y sliders with:
- Magic wand icon (wand.and.stars)
- Tooltip: "Automatically find the best position avoiding other overlays"
- Bordered style for visibility

## Code Location

- **Model**: `VideoEditor/Models/TextOverlay.swift` - `autoPosition()` method
- **UI**: `VideoEditor/Views/TextOverlayView.swift` - Auto-Position button in editor
