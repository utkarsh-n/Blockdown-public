import ActivityKit
import Foundation
import os

private let log = Logger(subsystem: "com.utkarsh.blockdown", category: "LiveActivity")

@MainActor
final class LiveActivityController {
    private var activity: Activity<BlockdownActivityAttributes>?

    /// True only when there is an activity the user can actually see.
    /// A lock-screen swipe leaves the activity "active" in ActivityKit but
    /// permanently invisible — treat anything non-.active as gone.
    var hasActivity: Bool {
        guard let activity else { return false }
        return activity.activityState == .active
    }

    /// Re-attach to a visible activity that survived an app relaunch,
    /// discarding dismissed/ended zombies.
    func reattach() {
        activity = Activity<BlockdownActivityAttributes>.activities
            .first { $0.activityState == .active }
    }

    func start(state: BlockdownActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.warning("Live Activities are disabled for this app; not starting one")
            return
        }
        // Never stack activities.
        endAllImmediately(finalState: state)
        do {
            activity = try Activity.request(
                attributes: BlockdownActivityAttributes(),
                content: ActivityContent(state: state, staleDate: nil)
            )
            log.info("Live Activity started: \(self.activity?.id ?? "nil", privacy: .public)")
        } catch {
            log.error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Pushes state into the live activity, resurrecting it if the user
    /// dismissed it from the lock screen or the system dropped it.
    func update(state: BlockdownActivityAttributes.ContentState) {
        guard let activity, activity.activityState == .active else {
            log.info("Activity missing or dismissed on update; recreating")
            start(state: state)
            return
        }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Ends the activity. Finished timers linger briefly on the lock screen;
    /// cancelled ones disappear immediately.
    func end(state: BlockdownActivityAttributes.ContentState, immediately: Bool) {
        guard let activity else { return }
        self.activity = nil
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: immediately ? .immediate : .default
            )
        }
    }

    private func endAllImmediately(finalState: BlockdownActivityAttributes.ContentState) {
        for stray in Activity<BlockdownActivityAttributes>.activities {
            Task {
                await stray.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
    }
}
