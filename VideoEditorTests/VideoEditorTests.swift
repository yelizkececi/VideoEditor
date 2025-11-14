//
//  VideoEditorTests.swift
//  VideoEditorTests
//
//  Unit Tests for Video Editor application
//

import XCTest
@testable import VideoEditor

@MainActor
final class VideoEditorTests: XCTestCase {

    // MARK: - VideoSegment Tests

    func testVideoSegmentCreation() throws {
        let segment = VideoSegment(startTime: 0.0, endTime: 10.0, speed: 1.0)

        XCTAssertEqual(segment.startTime, 0.0, "Start time should be 0.0")
        XCTAssertEqual(segment.endTime, 10.0, "End time should be 10.0")
        XCTAssertEqual(segment.speed, 1.0, "Speed should be 1.0")
        XCTAssertNotNil(segment.id, "Segment should have a unique ID")
    }

    func testVideoSegmentDuration() throws {
        let segment = VideoSegment(startTime: 5.0, endTime: 15.0, speed: 1.0)

        XCTAssertEqual(segment.duration, 10.0, "Duration should be 10 seconds")
    }

    func testVideoSegmentAdjustedDuration() throws {
        let normalSpeed = VideoSegment(startTime: 0.0, endTime: 10.0, speed: 1.0)
        XCTAssertEqual(normalSpeed.adjustedDuration, 10.0, "Normal speed adjusted duration should be 10s")

        let doubleSpeed = VideoSegment(startTime: 0.0, endTime: 10.0, speed: 2.0)
        XCTAssertEqual(doubleSpeed.adjustedDuration, 5.0, "Double speed adjusted duration should be 5s")

        let halfSpeed = VideoSegment(startTime: 0.0, endTime: 10.0, speed: 0.5)
        XCTAssertEqual(halfSpeed.adjustedDuration, 20.0, "Half speed adjusted duration should be 20s")
    }

    func testVideoSegmentTimeFormatting() throws {
        let segment = VideoSegment(startTime: 65.5, endTime: 125.75, speed: 1.0)

        // Start time: 65.5 seconds = 1:05.50
        XCTAssertEqual(segment.startTimeString, "1:05.50", "Start time formatting should be correct")

        // End time: 125.75 seconds = 2:05.75
        XCTAssertEqual(segment.endTimeString, "2:05.75", "End time formatting should be correct")

        // Duration: 60.25 seconds = 1:00.25
        XCTAssertEqual(segment.durationString, "1:00.25", "Duration formatting should be correct")
    }

    func testVideoSegmentUniqueIDs() throws {
        let segment1 = VideoSegment(startTime: 0.0, endTime: 10.0, speed: 1.0)
        let segment2 = VideoSegment(startTime: 0.0, endTime: 10.0, speed: 1.0)

        XCTAssertNotEqual(segment1.id, segment2.id, "Each segment should have a unique ID")
    }

    // MARK: - VideoEditorViewModel Tests

    func testViewModelInitialState() throws {
        let viewModel = VideoEditorViewModel()

        XCTAssertNil(viewModel.player, "Player should be nil initially")
        XCTAssertFalse(viewModel.isProcessing, "Should not be processing initially")
        XCTAssertEqual(viewModel.progress, 0.0, "Progress should be 0 initially")
        XCTAssertFalse(viewModel.hasVideo, "Should not have video initially")
        XCTAssertNil(viewModel.errorMessage, "Should not have error message initially")
        XCTAssertEqual(viewModel.statusMessage, "", "Status message should be empty initially")
        XCTAssertEqual(viewModel.videoFileName, "", "Video file name should be empty initially")
        XCTAssertEqual(viewModel.videoDuration, "", "Video duration should be empty initially")
    }

    func testViewModelTimelineInitialState() throws {
        let viewModel = VideoEditorViewModel()

        XCTAssertEqual(viewModel.playheadPosition, 0.5, "Playhead should start at 0.5")
        XCTAssertEqual(viewModel.trimStartPosition, 0.0, "Trim start should be 0.0")
        XCTAssertEqual(viewModel.trimEndPosition, 1.0, "Trim end should be 1.0")
        XCTAssertTrue(viewModel.segments.isEmpty, "Segments array should be empty initially")
    }

    func testUpdateTrimStart() throws {
        let viewModel = VideoEditorViewModel()

        viewModel.updateTrimStart(0.3)
        XCTAssertEqual(viewModel.trimStartPosition, 0.3, "Trim start should update to 0.3")

        // Test clamping to valid range
        viewModel.updateTrimStart(-0.5)
        XCTAssertEqual(viewModel.trimStartPosition, 0.0, "Trim start should clamp to 0.0")

        viewModel.updateTrimStart(1.5)
        XCTAssertEqual(viewModel.trimStartPosition, 1.0, "Trim start should clamp to 1.0")
    }

    func testUpdateTrimEnd() throws {
        let viewModel = VideoEditorViewModel()

        viewModel.updateTrimEnd(0.7)
        XCTAssertEqual(viewModel.trimEndPosition, 0.7, "Trim end should update to 0.7")

        // Test clamping to valid range
        viewModel.updateTrimEnd(-0.5)
        XCTAssertEqual(viewModel.trimEndPosition, 0.0, "Trim end should clamp to 0.0")

        viewModel.updateTrimEnd(1.5)
        XCTAssertEqual(viewModel.trimEndPosition, 1.0, "Trim end should clamp to 1.0")
    }

    func testUpdatePlayhead() throws {
        let viewModel = VideoEditorViewModel()

        viewModel.updatePlayhead(0.75)
        XCTAssertEqual(viewModel.playheadPosition, 0.75, "Playhead should update to 0.75")
    }

    func testResetTrim() throws {
        let viewModel = VideoEditorViewModel()

        // Set custom trim positions
        viewModel.updateTrimStart(0.2)
        viewModel.updateTrimEnd(0.8)

        // Reset
        viewModel.resetTrim()

        XCTAssertEqual(viewModel.trimStartPosition, 0.0, "Trim start should reset to 0.0")
        XCTAssertEqual(viewModel.trimEndPosition, 1.0, "Trim end should reset to 1.0")
    }

    func testAddSegment() throws {
        let viewModel = VideoEditorViewModel()

        // Set trim positions
        viewModel.updateTrimStart(0.2)
        viewModel.updateTrimEnd(0.8)

        // Add segment
        viewModel.addSegment(speed: 1.5)

        XCTAssertEqual(viewModel.segments.count, 1, "Should have one segment")

        let segment = viewModel.segments[0]
        XCTAssertEqual(segment.speed, 1.5, "Segment speed should be 1.5")

        // After adding, trim should reset
        XCTAssertEqual(viewModel.trimStartPosition, 0.0, "Trim should reset after adding segment")
        XCTAssertEqual(viewModel.trimEndPosition, 1.0, "Trim should reset after adding segment")
    }

    func testDeleteSegment() throws {
        let viewModel = VideoEditorViewModel()

        // Add multiple segments
        viewModel.addSegment(speed: 1.0)
        viewModel.addSegment(speed: 2.0)
        viewModel.addSegment(speed: 0.5)

        XCTAssertEqual(viewModel.segments.count, 3, "Should have 3 segments")

        // Delete middle segment
        viewModel.deleteSegment(at: 1)

        XCTAssertEqual(viewModel.segments.count, 2, "Should have 2 segments after deletion")
    }

    func testMoveSegmentUp() throws {
        let viewModel = VideoEditorViewModel()

        // Add segments
        viewModel.updateTrimStart(0.0)
        viewModel.updateTrimEnd(0.3)
        viewModel.addSegment(speed: 1.0)

        viewModel.updateTrimStart(0.3)
        viewModel.updateTrimEnd(0.6)
        viewModel.addSegment(speed: 2.0)

        let firstSegmentId = viewModel.segments[0].id
        let secondSegmentId = viewModel.segments[1].id

        // Move second segment up
        viewModel.moveSegmentUp(at: 1)

        XCTAssertEqual(viewModel.segments[0].id, secondSegmentId, "Second segment should now be first")
        XCTAssertEqual(viewModel.segments[1].id, firstSegmentId, "First segment should now be second")
    }

    func testMoveSegmentDown() throws {
        let viewModel = VideoEditorViewModel()

        // Add segments
        viewModel.addSegment(speed: 1.0)
        viewModel.addSegment(speed: 2.0)

        let firstSegmentId = viewModel.segments[0].id
        let secondSegmentId = viewModel.segments[1].id

        // Move first segment down
        viewModel.moveSegmentDown(at: 0)

        XCTAssertEqual(viewModel.segments[0].id, secondSegmentId, "Second segment should now be first")
        XCTAssertEqual(viewModel.segments[1].id, firstSegmentId, "First segment should now be second")
    }

    func testUpdateSegmentSpeed() throws {
        let viewModel = VideoEditorViewModel()

        // Add segment
        viewModel.addSegment(speed: 1.0)

        // Update speed
        viewModel.updateSegmentSpeed(at: 0, speed: 3.0)

        XCTAssertEqual(viewModel.segments[0].speed, 3.0, "Segment speed should update to 3.0")
    }

    func testClearSegments() throws {
        let viewModel = VideoEditorViewModel()

        // Add multiple segments
        viewModel.addSegment(speed: 1.0)
        viewModel.addSegment(speed: 2.0)
        viewModel.addSegment(speed: 0.5)

        XCTAssertEqual(viewModel.segments.count, 3, "Should have 3 segments")

        // Clear all
        viewModel.clearSegments()

        XCTAssertTrue(viewModel.segments.isEmpty, "Segments array should be empty after clearing")
    }

    // MARK: - ThumbnailGenerator Tests

    func testThumbnailGeneratorInitialState() throws {
        let generator = ThumbnailGenerator()

        XCTAssertTrue(generator.thumbnails.isEmpty, "Thumbnails array should be empty initially")
        XCTAssertFalse(generator.isGenerating, "Should not be generating initially")
    }

    func testThumbnailGeneratorClear() throws {
        let generator = ThumbnailGenerator()

        // Clear should work even with empty state
        generator.clear()

        XCTAssertTrue(generator.thumbnails.isEmpty, "Thumbnails should be empty after clear")
    }

    // MARK: - Double Extension Tests

    func testDoubleClampedExtension() throws {
        let value1: Double = 0.5
        XCTAssertEqual(value1.clamped(to: 0...1), 0.5, "Value within range should not change")

        let value2: Double = -0.5
        XCTAssertEqual(value2.clamped(to: 0...1), 0.0, "Value below range should clamp to lower bound")

        let value3: Double = 1.5
        XCTAssertEqual(value3.clamped(to: 0...1), 1.0, "Value above range should clamp to upper bound")

        let value4: Double = 0.0
        XCTAssertEqual(value4.clamped(to: 0...1), 0.0, "Value at lower bound should stay at bound")

        let value5: Double = 1.0
        XCTAssertEqual(value5.clamped(to: 0...1), 1.0, "Value at upper bound should stay at bound")
    }

    // MARK: - Edge Case Tests

    func testSplitAtPlayheadOutOfRange() throws {
        let viewModel = VideoEditorViewModel()

        // Try to split at playhead when it's at the start
        viewModel.updatePlayhead(0.0)
        viewModel.splitAtPlayhead(speed: 1.0)

        XCTAssertTrue(viewModel.segments.isEmpty, "Should not create segments when playhead is at start")
        XCTAssertNotNil(viewModel.errorMessage, "Should show error message")

        // Clear error
        viewModel.errorMessage = nil

        // Try to split at playhead when it's at the end
        viewModel.updatePlayhead(1.0)
        viewModel.splitAtPlayhead(speed: 1.0)

        XCTAssertTrue(viewModel.segments.isEmpty, "Should not create segments when playhead is at end")
        XCTAssertNotNil(viewModel.errorMessage, "Should show error message")
    }

    func testDeleteSegmentOutOfRange() throws {
        let viewModel = VideoEditorViewModel()

        viewModel.addSegment(speed: 1.0)
        let initialCount = viewModel.segments.count

        // Try to delete invalid index
        viewModel.deleteSegment(at: -1)
        XCTAssertEqual(viewModel.segments.count, initialCount, "Should not delete with negative index")

        viewModel.deleteSegment(at: 100)
        XCTAssertEqual(viewModel.segments.count, initialCount, "Should not delete with out of bounds index")
    }
}
