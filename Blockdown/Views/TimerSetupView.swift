import SwiftUI

/// Idle state: pick a duration (default 48h), name the timer, start it.
struct TimerSetupView: View {
    @Environment(TimerEngine.self) private var engine

    private enum SetupMode: String, CaseIterable {
        case duration = "Duration"
        case eta = "ETA"
    }

    @State private var mode = SetupMode.duration
    @State private var hours = 48
    @State private var minutes = 0
    @State private var seconds = 0
    @State private var targetDate = Date.now.addingTimeInterval(48 * 3600)
    @State private var name = "Blockdown"

    private static let maxHours = 168

    #if DEBUG
    // Test hook: launch with `-eta` to open the ETA tab directly.
    init() {
        if ProcessInfo.processInfo.arguments.contains("-eta") {
            _mode = State(initialValue: .eta)
        }
    }
    #endif

    private var totalDuration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    /// Seconds until the picked ETA. The wheel shows whole minutes, so the
    /// target is floored to :00 seconds and the countdown ends exactly then.
    private var etaDuration: TimeInterval {
        let floored = (targetDate.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60
        return Date(timeIntervalSinceReferenceDate: floored).timeIntervalSinceNow
    }

    private var startDuration: TimeInterval {
        mode == .duration ? totalDuration : min(TimeInterval(Self.maxHours * 3600), etaDuration)
    }

    var body: some View {
        VStack(spacing: 20) {
            Picker("Mode", selection: $mode) {
                ForEach(SetupMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 60)

            Group {
                if mode == .duration {
                    DurationWheels(hours: $hours, minutes: $minutes, seconds: $seconds)
                } else {
                    DatePicker(
                        "End time",
                        selection: $targetDate,
                        in: Date.now.addingTimeInterval(60)...Date.now.addingTimeInterval(TimeInterval(Self.maxHours * 3600)),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }
            }
            .frame(height: 210)
            .padding(.horizontal, 24)

            if mode == .duration {
                presetChips
            } else {
                etaSummary
            }

            nameField
                .padding(.horizontal, 24)

            liveActivityToggle
                .padding(.horizontal, 24)

            Spacer(minLength: 0)

            HStack {
                CircleControlButton(title: "Reset", tint: .gray) {
                    if mode == .duration {
                        setDuration(hours: 48, minutes: 0, seconds: 0)
                    } else {
                        targetDate = .now.addingTimeInterval(48 * 3600)
                    }
                }
                Spacer()
                CircleControlButton(title: "Start", tint: .blockdownTheme) {
                    commitName()
                    engine.setPlannedDuration(startDuration)
                    engine.start(asETA: mode == .eta)
                }
                .opacity(startDuration < 1 ? 0.35 : 1)
                .disabled(startDuration < 1)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .onAppear {
            name = engine.name
            let total = Int(engine.plannedDuration)
            hours = min(Self.maxHours, total / 3600)
            minutes = (total % 3600) / 60
            seconds = total % 60
        }
        .onChange(of: hours) { clampToMaximum() }
        .onChange(of: minutes) { clampToMaximum() }
        .onChange(of: seconds) { clampToMaximum() }
    }

    /// "That's 21h 34m from now · ends Thu 2:26 PM"
    private var etaSummary: some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let remaining = targetDate.timeIntervalSince(context.date)
            if remaining >= 1 {
                Text("That's \(TimeFormatting.compact(remaining)) from now")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.blockdownTheme)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .glassEffect(.regular.tint(Color.blockdownTheme.opacity(0.12)), in: .capsule)
            } else {
                Text("Pick a time in the future")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 9)
            }
        }
    }

    private var presetChips: some View {
        HStack(spacing: 10) {
            PresetChip(label: "24h", isSelected: matches(24)) { setDuration(hours: 24, minutes: 0, seconds: 0) }
            PresetChip(label: "48h", isSelected: matches(48)) { setDuration(hours: 48, minutes: 0, seconds: 0) }
            PresetChip(label: "72h", isSelected: matches(72)) { setDuration(hours: 72, minutes: 0, seconds: 0) }
            PresetChip(label: "1 wk", isSelected: matches(168)) { setDuration(hours: 168, minutes: 0, seconds: 0) }
        }
    }

    private var nameField: some View {
        HStack {
            Text("Name")
                .foregroundStyle(.secondary)
            TextField("Blockdown", text: $name)
                .multilineTextAlignment(.trailing)
                .submitLabel(.done)
                .onSubmit(commitName)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var liveActivityToggle: some View {
        PhysicalToggleRow(title: "Live Activity", isOn: engine.liveActivityEnabled) {
            engine.setLiveActivityEnabled(!engine.liveActivityEnabled)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func matches(_ h: Int) -> Bool {
        hours == h && minutes == 0 && seconds == 0
    }

    private func setDuration(hours h: Int, minutes m: Int, seconds s: Int) {
        hours = h
        minutes = m
        seconds = s
    }

    private func clampToMaximum() {
        if totalDuration > TimeInterval(Self.maxHours * 3600) {
            setDuration(hours: Self.maxHours, minutes: 0, seconds: 0)
        }
        engine.setPlannedDuration(totalDuration)
    }

    private func commitName() {
        engine.rename(to: name)
        name = engine.name
    }
}

// MARK: - Wheels

struct DurationWheels: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 0) {
            wheel(selection: $hours, range: 0...168, unit: "hours")
            wheel(selection: $minutes, range: 0...59, unit: "min")
            wheel(selection: $seconds, range: 0...59, unit: "sec")
        }
    }

    private func wheel(selection: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        Picker(unit, selection: selection) {
            ForEach(range, id: \.self) { value in
                // Unit lives inside the row so the selection pill
                // always encloses both the number and the label.
                HStack(spacing: 5) {
                    Text("\(value)")
                        .monospacedDigit()
                    Text(unit)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
    }
}

// MARK: - Preset chip

private struct PresetChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.blockdownTheme : Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(isSelected ? Color.blockdownTheme.opacity(0.25) : .clear).interactive(),
            in: .capsule
        )
    }
}
