import SwiftUI

/// A hand-rolled switch that behaves like a physical control: the entire row
/// is one big button, the knob slides with a spring, and toggling gives a
/// haptic thunk. Replaces `Toggle`/`UISwitch`, whose small hit target proved
/// unreliable.
struct PhysicalToggleRow: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                switchBody
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
    }

    private var switchBody: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color.blockdownTheme : Color.primary.opacity(0.16))
                .frame(width: 58, height: 34)
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )

            Circle()
                .fill(.white)
                .frame(width: 28, height: 28)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .padding(3)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
    }
}
