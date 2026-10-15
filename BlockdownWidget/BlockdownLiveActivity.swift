import ActivityKit
import SwiftUI
import WidgetKit

struct BlockdownLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BlockdownActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.72))
                .activitySystemActionForegroundColor(Color.blockdownTheme)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.name)
                            .font(.headline)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "timer")
                            .foregroundStyle(Color.blockdownTheme)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusText(state: context.state)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        CountdownText(state: context.state)
                            .font(.system(size: 40, weight: .light))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                        TimerProgressBar(state: context.state)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Color.blockdownTheme)
            } compactTrailing: {
                CountdownText(state: context.state)
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(Color.blockdownTheme)
                    .frame(maxWidth: 62)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Color.blockdownTheme)
            }
            .keylineTint(Color.blockdownTheme)
        }
    }
}

// MARK: - Lock screen

private struct LockScreenView: View {
    let state: BlockdownActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label {
                    Text(state.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "timer")
                        .foregroundStyle(Color.blockdownTheme)
                }
                Spacer()
                StatusText(state: state)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            CountdownText(state: state)
                .font(.system(size: 46, weight: .light))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(state.finished ? Color.blockdownTheme : Color.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            TimerProgressBar(state: state)
        }
        .padding(16)
    }
}

// MARK: - Shared pieces

private struct CountdownText: View {
    let state: BlockdownActivityAttributes.ContentState

    var body: some View {
        if state.finished {
            Text("0:00:00")
        } else if let pausedRemaining = state.pausedRemaining {
            Text(TimeFormatting.hms(pausedRemaining))
        } else {
            Text(timerInterval: Date.now...max(Date.now, state.endDate), countsDown: true)
        }
    }
}

private struct StatusText: View {
    let state: BlockdownActivityAttributes.ContentState

    var body: some View {
        if state.finished {
            Text("Finished")
        } else if state.isPaused {
            Text("Paused")
        } else {
            Text("Ends \(TimeFormatting.endTime(state.endDate))")
        }
    }
}

private struct TimerProgressBar: View {
    let state: BlockdownActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.finished {
                ProgressView(value: 1)
            } else if let pausedRemaining = state.pausedRemaining {
                ProgressView(value: progressFraction(remaining: pausedRemaining))
            } else {
                ProgressView(
                    timerInterval: state.endDate.addingTimeInterval(-state.totalDuration)...state.endDate,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
            }
        }
        .progressViewStyle(.linear)
        .tint(Color.blockdownTheme)
    }

    private func progressFraction(remaining: TimeInterval) -> Double {
        guard state.totalDuration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / state.totalDuration))
    }
}
