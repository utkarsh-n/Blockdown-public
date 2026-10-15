import ActivityKit
import Foundation

struct BlockdownActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Display name of the timer.
        var name: String
        /// Moment the timer will fire (only meaningful while running).
        var endDate: Date
        /// Total planned duration in seconds, used for progress.
        var totalDuration: TimeInterval
        /// Non-nil when paused: seconds left on the clock.
        var pausedRemaining: TimeInterval?
        /// True once the timer has completed.
        var finished: Bool

        var isPaused: Bool { pausedRemaining != nil }
    }
}
