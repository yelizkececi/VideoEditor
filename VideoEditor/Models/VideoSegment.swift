//
//  VideoSegment.swift
//  VideoEditor
//
//  Created on 8.11.25.
//

import Foundation

struct VideoSegment: Identifiable {
    let id = UUID()
    let startTime: Double
    let endTime: Double
    var speed: Double // Speed multiplier (1.0 = normal, 2.0 = 2x, 0.5 = half speed)

    var duration: Double {
        endTime - startTime
    }

    var adjustedDuration: Double {
        duration / speed
    }

    var startTimeString: String {
        formatTime(startTime)
    }

    var endTimeString: String {
        formatTime(endTime)
    }

    var durationString: String {
        formatTime(duration)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, secs, milliseconds)
    }
}
