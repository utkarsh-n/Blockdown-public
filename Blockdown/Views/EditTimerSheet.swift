import SwiftUI

/// Rename the timer and add/subtract time granularly while it runs.
struct EditTimerSheet: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var adjustHours = 1
    @State private var adjustMinutes = 0

    private var adjustAmount: TimeInterval {
        TimeInterval(adjustHours * 3600 + adjustMinutes * 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Blockdown", text: $name)
                        .submitLabel(.done)
                }

                Section {
                    PhysicalToggleRow(title: "Live Activity", isOn: engine.liveActivityEnabled) {
                        engine.setLiveActivityEnabled(!engine.liveActivityEnabled)
                    }
                } footer: {
                    Text("Show the countdown on the Lock Screen and in the Dynamic Island. Turning this off removes it immediately.")
                }

                if engine.isActive {
                    Section {
                        TimelineView(.periodic(from: .now, by: 1.0)) { context in
                            LabeledContent("Time remaining") {
                                Text(TimeFormatting.hms(engine.remaining(at: context.date)))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.blockdownTheme)
                            }
                        }

                        HStack(spacing: 0) {
                            Picker("Hours", selection: $adjustHours) {
                                ForEach(0...48, id: \.self) { Text("\($0) hr").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                            Picker("Minutes", selection: $adjustMinutes) {
                                ForEach(0...59, id: \.self) { Text("\($0) min").tag($0) }
                            }
                            .pickerStyle(.wheel)
                            .labelsHidden()
                        }
                        .frame(height: 130)

                        HStack {
                            Button {
                                engine.adjust(by: -adjustAmount)
                            } label: {
                                Label("Subtract", systemImage: "minus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                engine.adjust(by: adjustAmount)
                            } label: {
                                Label("Add", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .disabled(adjustAmount < 60)
                    } header: {
                        Text("Adjust Time")
                    } footer: {
                        Text("Adds to or subtracts from the running timer, up to the 168-hour maximum.")
                    }
                }
            }
            .navigationTitle("Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        engine.rename(to: name)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { name = engine.name }
    }
}
