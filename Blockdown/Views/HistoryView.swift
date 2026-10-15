import SwiftUI

struct HistoryView: View {
    @Environment(TimerEngine.self) private var engine
    @State private var confirmingClear = false

    var body: some View {
        NavigationStack {
            Group {
                if engine.history.sessions.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished and stopped timers will show up here.")
                    )
                } else {
                    List {
                        ForEach(engine.history.sessions) { session in
                            HistoryRow(session: session)
                        }
                        .onDelete { engine.history.delete(at: $0) }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !engine.history.sessions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) {
                            confirmingClear = true
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear all history?",
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    engine.history.clear()
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let session: TimerSession

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(session.name)
                    .font(.headline)
                Spacer()
                outcomeBadge
            }
            Text("\(dateString(session.start))  →  \(dateString(session.end))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Ran \(TimeFormatting.compact(session.actualDuration)) of \(TimeFormatting.compact(session.plannedDuration))")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }

    private var outcomeBadge: some View {
        Text(session.outcome == .completed ? "Completed" : "Stopped")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                (session.outcome == .completed ? Color.blockdownTheme : Color.gray).opacity(0.18),
                in: .capsule
            )
            .foregroundStyle(session.outcome == .completed ? Color.blockdownTheme : Color.secondary)
    }

    private func dateString(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
