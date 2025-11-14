//
//  VideoEditorUITests.swift
//  VideoEditorUITests
//
//  UI Tests for Video Editor application
//

import XCTest

final class VideoEditorUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Initial State Tests

    func testInitialAppState() throws {
        // Verify main window exists
        XCTAssertTrue(app.windows.firstMatch.exists, "Main window should exist")

        // Verify "Video Editor" title exists
        let title = app.staticTexts["Video Editor"]
        XCTAssertTrue(title.exists, "App title should be visible")

        // Verify Import Video button exists and is enabled
        let importButton = app.buttons["Import Video"]
        XCTAssertTrue(importButton.exists, "Import Video button should exist")
        XCTAssertTrue(importButton.isEnabled, "Import Video button should be enabled initially")
    }

    func testNoVideoLoadedState() throws {
        // Verify "No video loaded" message is displayed initially
        let noVideoMessage = app.staticTexts["No video loaded"]
        XCTAssertTrue(noVideoMessage.exists, "No video loaded message should be visible initially")

        // Verify timeline shows empty state
        let timelineEmptyText = app.staticTexts["Import a video to use the timeline"]
        XCTAssertTrue(timelineEmptyText.exists, "Timeline should show empty state message")

        // Verify Export Video button is disabled when no video is loaded
        let exportButton = app.buttons["Export Video"]
        XCTAssertTrue(exportButton.exists, "Export Video button should exist")
        XCTAssertFalse(exportButton.isEnabled, "Export Video button should be disabled without video")
    }

    // MARK: - UI Element Existence Tests

    func testSidebarElementsExist() throws {
        // Verify sidebar header
        let sidebarTitle = app.staticTexts["Video Editor"]
        XCTAssertTrue(sidebarTitle.exists, "Sidebar title should exist")

        // Verify Import button
        let importButton = app.buttons["Import Video"]
        XCTAssertTrue(importButton.exists, "Import Video button should exist")

        // Verify Export button
        let exportButton = app.buttons["Export Video"]
        XCTAssertTrue(exportButton.exists, "Export Video button should exist")
    }

    func testTimelineElementsExist() throws {
        // Verify Timeline header
        let timelineHeader = app.staticTexts["Timeline"]
        XCTAssertTrue(timelineHeader.exists, "Timeline header should exist")

        // Verify timeline controls exist (when no video is loaded, they might not be visible)
        // This test ensures the timeline area is present
        let timelineArea = app.scrollViews.firstMatch
        XCTAssertTrue(timelineArea.exists, "Timeline scroll view should exist")
    }

    // MARK: - Button State Tests

    func testImportButtonAlwaysEnabled() throws {
        let importButton = app.buttons["Import Video"]
        XCTAssertTrue(importButton.isEnabled, "Import button should always be enabled")
    }

    func testExportButtonDisabledWithoutVideo() throws {
        let exportButton = app.buttons["Export Video"]
        XCTAssertFalse(exportButton.isEnabled, "Export button should be disabled without video")
    }

    // MARK: - Import Video Dialog Tests

    func testImportVideoOpensFileDialog() throws {
        let importButton = app.buttons["Import Video"]

        // Click the import button
        importButton.click()

        // Wait for file dialog to appear
        let fileDialog = app.sheets.firstMatch
        let dialogAppeared = fileDialog.waitForExistence(timeout: 2.0)

        XCTAssertTrue(dialogAppeared, "File selection dialog should appear after clicking Import")

        // Cancel the dialog if it appeared
        if dialogAppeared {
            let cancelButton = fileDialog.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.click()
            }
        }
    }

    // MARK: - Export Video Dialog Tests

    func testExportVideoDialogWhenDisabled() throws {
        let exportButton = app.buttons["Export Video"]

        // Should not open dialog when disabled
        XCTAssertFalse(exportButton.isEnabled, "Export should be disabled without video")

        // Verify clicking disabled button does nothing
        let initialSheetCount = app.sheets.count
        exportButton.click()

        // Wait a moment to ensure no sheet appears
        sleep(1)

        let finalSheetCount = app.sheets.count
        XCTAssertEqual(initialSheetCount, finalSheetCount, "No dialog should appear when export is disabled")
    }

    // MARK: - Statistics Display Tests

    func testStatisticsHiddenWithoutVideo() throws {
        // Statistics section should not be visible without a video
        let statsHeader = app.staticTexts["Statistics"]
        XCTAssertFalse(statsHeader.exists, "Statistics should be hidden without video loaded")
    }

    // MARK: - Layout Tests

    func testSplitViewLayout() throws {
        // Verify window has expected minimum size
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")

        // The app should have both video player area and sidebar visible
        let scrollViews = app.scrollViews
        XCTAssertGreaterThan(scrollViews.count, 0, "Should have at least one scroll view (timeline)")
    }

    // MARK: - Timeline Controls Tests

    func testTimelineControlsHiddenWithoutVideo() throws {
        // Timeline controls should not be visible without video
        let resetButton = app.buttons["Reset Selection"]
        XCTAssertFalse(resetButton.exists, "Reset Selection button should not exist without video")

        let splitButton = app.buttons["Split at Playhead"]
        XCTAssertFalse(splitButton.exists, "Split at Playhead button should not exist without video")

        let addButton = app.buttons["Add Selection"]
        XCTAssertFalse(addButton.exists, "Add Selection button should not exist without video")

        let reverseButton = app.buttons["Reverse Video"]
        XCTAssertFalse(reverseButton.exists, "Reverse Video button should not exist without video")
    }

    // MARK: - Accessibility Tests

    func testImportButtonAccessibility() throws {
        let importButton = app.buttons["Import Video"]
        XCTAssertTrue(importButton.isHittable, "Import button should be accessible")
    }

    func testExportButtonAccessibility() throws {
        let exportButton = app.buttons["Export Video"]
        XCTAssertTrue(exportButton.exists, "Export button should exist for accessibility")
        // Note: It may not be hittable when disabled, which is correct behavior
    }

    // MARK: - Window Tests

    func testWindowTitle() throws {
        let mainWindow = app.windows.firstMatch
        XCTAssertTrue(mainWindow.exists, "Main window should exist")
    }

    func testMinimumWindowSize() throws {
        let mainWindow = app.windows.firstMatch

        // The app specifies minWidth: 900, minHeight: 900 in ContentView
        let frame = mainWindow.frame
        XCTAssertGreaterThanOrEqual(frame.width, 900, "Window width should be at least 900")
        XCTAssertGreaterThanOrEqual(frame.height, 900, "Window height should be at least 900")
    }

    // MARK: - Performance Tests

    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
