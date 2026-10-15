import Foundation
import Observation

enum TimerPhase: String, Codable {
    case idle
    case running
    case paused
    case finished
}

@MainActor
@Observable
final class TimerEngine {
    static let defaultDuration: TimeInterval = 48 * 3600
    static let maximumDuration: TimeInterval = 168 * 3600
    static let minimumDuration: TimeInterval = 1

    var name = "Blockdown"
    var plannedDuration = TimerEngine.defaultDuration
    private(set) var liveActivityEnabled = true
    /// True when the running timer was started from an ETA (target date);
    /// the ring then fills counter-clockwise toward the target instead of
    /// draining clockwise.
    private(set) var etaMode = false
    private(set) var phase = TimerPhase.idle
    private(set) var endDate: Date?
    private(set) var startDate: Date?
    private(set) var pausedRemaining: TimeInterval?

    let history = HistoryStore()

    @ObservationIgnored private let liveActivity = LiveActivityController()
    @ObservationIgnored private var completionTask: Task<Void, Never>?

    init() {
        restore()
    }

    // MARK: - Derived state

    func remaining(at date: Date = .now) -> TimeInterval {
        switch phase {
        case .idle: plannedDuration
        case .running: max(0, endDate?.timeIntervalSince(date) ?? 0)
        case .paused: pausedRemaining ?? 0
        case .finished: 0
        }
    }

    func fractionRemaining(at date: Date = .now) -> Double {
        guard plannedDuration > 0 else { return 0 }
        return min(1, max(0, remaining(at: date) / plannedDuration))
    }

    var isActive: Bool { phase == .running || phase == .paused }

    // MARK: - Actions

    func start(asETA: Bool = false) {
        guard phase == .idle, plannedDuration >= Self.minimumDuration else { return }
        NotificationManager.shared.requestAuthorization()
        etaMode = asETA
        let now = Date.now
        startDate = now
        endDate = now.addingTimeInterval(plannedDuration)
        pausedRemaining = nil
        phase = .running
        NotificationManager.shared.scheduleEnd(named: name, at: endDate!)
        if liveActivityEnabled {
            liveActivity.start(state: contentState())
        }
        scheduleCompletion()
        persist()
    }

    /// Turns the Live Activity on or off, taking effect immediately mid-run.
    func setLiveActivityEnabled(_ enabled: Bool) {
        guard enabled != liveActivityEnabled else { return }
        liveActivityEnabled = enabled
        if isActive {
            if enabled {
                liveActivity.start(state: contentState())
            } else {
                liveActivity.end(state: contentState(), immediately: true)
            }
        }
        persist()
    }

    func pause() {
        guard phase == .running, let endDate else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        phase = .paused
        completionTask?.cancel()
        NotificationManager.shared.cancel()
        syncLiveActivity()
        persist()
    }

    func resume() {
        guard phase == .paused, let pausedRemaining else { return }
        endDate = Date.now.addingTimeInterval(pausedRemaining)
        self.pausedRemaining = nil
        phase = .running
        NotificationManager.shared.scheduleEnd(named: name, at: endDate!)
        syncLiveActivity()
        scheduleCompletion()
        persist()
    }

    /// Cancels the timer, recording it in history if it was ever started.
    func stop() {
        guard isActive else { return }
        recordSession(outcome: .stopped, end: .now)
        completionTask?.cancel()
        NotificationManager.shared.cancel()
        liveActivity.end(state: contentState(finished: true), immediately: true)
        reset()
    }

    /// Stops the current run (if any) and starts fresh at the full duration.
    func restart() {
        if isActive {
            recordSession(outcome: .stopped, end: .now)
            completionTask?.cancel()
            NotificationManager.shared.cancel()
            liveActivity.end(state: contentState(finished: true), immediately: true)
        }
        let wasETA = etaMode
        reset()
        start(asETA: wasETA)
    }

    /// Dismisses the "finished" state back to idle.
    func acknowledgeFinished() {
        guard phase == .finished else { return }
        reset()
    }

    /// Adds or subtracts time from a running or paused timer.
    func adjust(by delta: TimeInterval) {
        switch phase {
        case .running:
            guard let endDate else { return }
            let newRemaining = clampRemaining(endDate.timeIntervalSinceNow + delta)
            self.endDate = Date.now.addingTimeInterval(newRemaining)
            NotificationManager.shared.scheduleEnd(named: name, at: self.endDate!)
            syncLiveActivity()
            scheduleCompletion()
        case .paused:
            guard let pausedRemaining else { return }
            self.pausedRemaining = clampRemaining(pausedRemaining + delta)
            syncLiveActivity()
        default:
            return
        }
        persist()
    }

    func rename(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = trimmed.isEmpty ? "Blockdown" : trimmed
        if isActive {
            if phase == .running, let endDate {
                NotificationManager.shared.scheduleEnd(named: name, at: endDate)
            }
            syncLiveActivity()
        }
        persist()
    }

    func setPlannedDuration(_ duration: TimeInterval) {
        guard phase == .idle else { return }
        plannedDuration = min(Self.maximumDuration, max(0, duration))
        persist()
    }

    // MARK: - Completion

    private func scheduleCompletion() {
        completionTask?.cancel()
        guard let endDate else { return }
        completionTask = Task { [weak self] in
            let interval = endDate.timeIntervalSinceNow
            if interval > 0 {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    /// Re-checks state after returning to the foreground.
    func refresh() {
        if phase == .running, let endDate, endDate.timeIntervalSinceNow <= 0 {
            finish()
        }
    }

    private func finish() {
        guard phase == .running else { return }
        recordSession(outcome: .completed, end: endDate ?? .now)
        phase = .finished
        completionTask?.cancel()
        liveActivity.end(state: contentState(finished: true), immediately: false)
        persist()
    }

    // MARK: - Helpers

    private func clampRemaining(_ value: TimeInterval) -> TimeInterval {
        min(Self.maximumDuration, max(Self.minimumDuration, value))
    }

    private func recordSession(outcome: TimerSession.Outcome, end: Date) {
        guard let startDate else { return }
        history.record(TimerSession(
            name: name,
            plannedDuration: plannedDuration,
            start: startDate,
            end: end,
            outcome: outcome
        ))
    }

    private func reset() {
        phase = .idle
        endDate = nil
        startDate = nil
        pausedRemaining = nil
        persist()
    }

    private func contentState(finished: Bool = false) -> BlockdownActivityAttributes.ContentState {
        BlockdownActivityAttributes.ContentState(
            name: name,
            endDate: endDate ?? .now,
            totalDuration: plannedDuration,
            pausedRemaining: phase == .paused ? pausedRemaining : nil,
            finished: finished
        )
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var name: String
        var plannedDuration: TimeInterval
        var phase: TimerPhase
        var endDate: Date?
        var startDate: Date?
        var pausedRemaining: TimeInterval?
        // Optional so snapshots written before these settings existed still decode.
        var liveActivityEnabled: Bool?
        var etaMode: Bool?
    }

    private static let snapshotKey = "blockdown.timer.snapshot"

    private func persist() {
        let snapshot = Snapshot(
            name: name,
            plannedDuration: plannedDuration,
            phase: phase,
            endDate: endDate,
            startDate: startDate,
            pausedRemaining: pausedRemaining,
            liveActivityEnabled: liveActivityEnabled,
            etaMode: etaMode
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        name = snapshot.name
        plannedDuration = snapshot.plannedDuration
        phase = snapshot.phase
        endDate = snapshot.endDate
        startDate = snapshot.startDate
        pausedRemaining = snapshot.pausedRemaining
        liveActivityEnabled = snapshot.liveActivityEnabled ?? true
        etaMode = snapshot.etaMode ?? false

        liveActivity.reattach()
        if !liveActivityEnabled {
            liveActivity.end(state: contentState(), immediately: true)
        }

        switch phase {
        case .running:
            if let endDate, endDate.timeIntervalSinceNow <= 0 {
                // Timer completed while the app was gone.
                recordSession(outcome: .completed, end: endDate)
                phase = .finished
                liveActivity.end(state: contentState(finished: true), immediately: false)
                persist()
            } else {
                scheduleCompletion()
                recreateActivityIfMissing()
            }
        case .paused:
            recreateActivityIfMissing()
        case .finished, .idle:
            break
        }
    }

    /// Pushes current state into the Live Activity (recreating a dismissed
    /// one), but only when the user has the Live Activity enabled.
    private func syncLiveActivity() {
        guard liveActivityEnabled else { return }
        liveActivity.update(state: contentState())
    }

    /// A reinstall or system eviction can drop the Live Activity while the
    /// timer keeps running — bring it back on the next launch. If one
    /// survived, push current state into it in case it went stale.
    private func recreateActivityIfMissing() {
        guard liveActivityEnabled else { return }
        if liveActivity.hasActivity {
            syncLiveActivity()
        } else {
            liveActivity.start(state: contentState())
        }
    }
}
