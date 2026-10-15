import Foundation

/// One completed run of a timer, recorded in history.
struct TimerSession: Identifiable, Codable, Hashable {
    enum Outcome: String, Codable {
        case completed
        case stopped
    }

    var id = UUID()
    var name: String
    var plannedDuration: TimeInterval
    var start: Date
    var end: Date
    var outcome: Outcome

    var actualDuration: TimeInterval { end.timeIntervalSince(start) }
}
