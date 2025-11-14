# Video Editor Tests

This document explains the test suite for the Video Editor application.

## Test Structure

The project includes two types of tests:

### 1. Unit Tests (`VideoEditorTests/`)
- Tests business logic and view model functionality
- Tests model classes like `VideoSegment`
- Tests utility functions and extensions
- No UI interaction required

### 2. UI Tests (`VideoEditorUITests/`)
- Tests user interface and user interactions
- Tests app launch and initial state
- Tests button states and accessibility
- Tests file dialogs and navigation

## How to Add Test Targets to Xcode

Since the test files are created but not yet added to the Xcode project, follow these steps:

### Adding Unit Tests:

1. Open `VideoEditor.xcodeproj` in Xcode
2. Go to **File → New → Target...**
3. Choose **macOS → Test → Unit Testing Bundle**
4. Click **Next**
5. Set **Product Name** to `VideoEditorTests`
6. Set **Team** to your development team
7. Ensure **Target to be Tested** is set to `VideoEditor`
8. Click **Finish**
9. Delete the auto-generated test file
10. Right-click on the `VideoEditorTests` group in Project Navigator
11. Select **Add Files to "VideoEditor"...**
12. Navigate to `VideoEditorTests/VideoEditorTests.swift`
13. Make sure to check **Copy items if needed** and select the `VideoEditorTests` target
14. Click **Add**

### Adding UI Tests:

1. In Xcode, go to **File → New → Target...**
2. Choose **macOS → Test → UI Testing Bundle**
3. Click **Next**
4. Set **Product Name** to `VideoEditorUITests`
5. Set **Team** to your development team
6. Ensure **Target to be Tested** is set to `VideoEditor`
7. Click **Finish**
8. Delete the auto-generated test file
9. Right-click on the `VideoEditorUITests` group in Project Navigator
10. Select **Add Files to "VideoEditor"...**
11. Navigate to `VideoEditorUITests/VideoEditorUITests.swift`
12. Make sure to check **Copy items if needed** and select the `VideoEditorUITests` target
13. Click **Add**

## Running Tests

### Run All Tests:
```bash
# From command line
cd /path/to/VideoEditor
xcodebuild test -scheme VideoEditor -destination 'platform=macOS'
```

### Run Unit Tests Only:
```bash
xcodebuild test -scheme VideoEditor -only-testing:VideoEditorTests
```

### Run UI Tests Only:
```bash
xcodebuild test -scheme VideoEditor -only-testing:VideoEditorUITests
```

### Run Tests in Xcode:
1. Open the project in Xcode
2. Press `⌘U` to run all tests
3. Or use **Product → Test** from the menu
4. View results in the Test Navigator (⌘6)

## Test Coverage

### Unit Tests Cover:
- ✅ VideoSegment model creation and properties
- ✅ VideoSegment duration calculations
- ✅ VideoSegment time formatting
- ✅ VideoEditorViewModel initial state
- ✅ Timeline position updates (playhead, trim start/end)
- ✅ Segment management (add, delete, move, update speed)
- ✅ ThumbnailGenerator initial state
- ✅ Double extension clamping
- ✅ Edge cases and error handling

### UI Tests Cover:
- ✅ Initial app state and layout
- ✅ Button existence and states
- ✅ Empty state messages
- ✅ File dialog interactions
- ✅ Accessibility
- ✅ Window size constraints
- ✅ App launch performance

## Writing New Tests

### Unit Test Example:
```swift
func testNewFeature() throws {
    let viewModel = VideoEditorViewModel()

    // Your test code here
    XCTAssertEqual(expected, actual, "Description")
}
```

### UI Test Example:
```swift
func testNewUIFeature() throws {
    let button = app.buttons["Button Name"]
    XCTAssertTrue(button.exists, "Button should exist")
    button.click()
    // Assert result
}
```

## Best Practices

1. **Descriptive Names**: Use clear, descriptive test function names
2. **Arrange-Act-Assert**: Structure tests with setup, action, and assertion
3. **Test One Thing**: Each test should verify a single behavior
4. **Clean State**: Tests should not depend on each other
5. **Meaningful Assertions**: Include descriptive failure messages

## Troubleshooting

### Tests Not Running:
- Ensure test targets are properly added to the Xcode project
- Check that the test files are included in the test target membership
- Verify the main app target is set as "Target to be Tested"

### UI Tests Failing:
- UI tests require the app to launch successfully
- Check that accessibility identifiers match
- Ensure sufficient wait times for UI elements to appear

### Build Errors:
- Make sure `@testable import VideoEditor` is present in unit tests
- Verify all test target build settings are correct
- Clean build folder (⌘⇧K) and rebuild

## Continuous Integration

To run tests in CI/CD:

```bash
# Build and test
xcodebuild clean test \
  -project VideoEditor.xcodeproj \
  -scheme VideoEditor \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES
```

## Code Coverage

To view code coverage:
1. Run tests with coverage enabled (⌘U)
2. Open **Report Navigator** (⌘9)
3. Select the latest test report
4. Click on **Coverage** tab
5. Expand to see line-by-line coverage

Target: 80%+ coverage for business logic
