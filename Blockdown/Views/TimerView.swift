import SwiftUI

struct TimerView: View {
    @Environment(TimerEngine.self) private var engine
    @State private var showingEditSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if engine.phase == .idle {
                    TimerSetupView()
                } else {
                    CountdownView(showingEditSheet: $showingEditSheet)
                }
            }
            .navigationTitle("Blockdown")
            .toolbar {
                if engine.isActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showingEditSheet = true
                            } label: {
                                Label("Edit Timer", systemImage: "pencil")
                            }
                            Button {
                                engine.restart()
                            } label: {
                                Label("Restart Timer", systemImage: "arrow.circlepath")
                            }
                            Divider()
                            Toggle(isOn: Binding(
                                get: { engine.liveActivityEnabled },
                                set: { engine.setLiveActivityEnabled($0) }
                            )) {
                                Label("Live Activity", systemImage: "bolt.badge.clock")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditTimerSheet()
            }
        }
    }
}

// MARK: - Countdown (running / paused / finished)

private struct CountdownView: View {
    @Environment(TimerEngine.self) private var engine
    @Binding var showingEditSheet: Bool
    @State private var fluid = FluidMotion()

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 12)

            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                CountdownRing(
                    remaining: engine.remaining(at: context.date),
                    fraction: engine.fractionRemaining(at: context.date),
                    phase: engine.phase,
                    endDate: engine.endDate,
                    name: engine.name,
                    etaMode: engine.etaMode,
                    fluid: fluid
                )
            }
            .onAppear { fluid.start() }
            .onDisappear { fluid.stop() }

            if engine.isActive {
                adjustChips
            }

            Spacer(minLength: 0)

            controlButtons
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
        }
        .padding(.top, 8)
    }

    private var adjustChips: some View {
        HStack(spacing: 10) {
            AdjustChip(label: "−1h", delta: -3600)
            AdjustChip(label: "−15m", delta: -900)
            AdjustChip(label: "+15m", delta: 900)
            AdjustChip(label: "+1h", delta: 3600)
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack {
            switch engine.phase {
            case .running:
                CircleControlButton(title: "Cancel", tint: .gray) { engine.stop() }
                Spacer()
                CircleControlButton(title: "Pause", tint: .blockdownTheme) { engine.pause() }
            case .paused:
                CircleControlButton(title: "Cancel", tint: .gray) { engine.stop() }
                Spacer()
                CircleControlButton(title: "Resume", tint: .blockdownTheme) { engine.resume() }
            case .finished:
                CircleControlButton(title: "Done", tint: .gray) { engine.acknowledgeFinished() }
                Spacer()
                CircleControlButton(title: "Restart", tint: .blockdownTheme) { engine.restart() }
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Ring

private struct CountdownRing: View {
    let remaining: TimeInterval
    let fraction: Double
    let phase: TimerPhase
    let endDate: Date?
    let name: String
    let etaMode: Bool
    let fluid: FluidMotion

    private static let ringWidth: CGFloat = 26

    /// Duration timers drain clockwise (fraction remaining, like the Clock
    /// app); ETA timers fill counter-clockwise with progress toward the
    /// target, reaching a full ring at the ETA.
    private var arcFraction: Double {
        etaMode ? 1 - fraction : fraction
    }

    private var arcColor: Color {
        phase == .paused ? Color.blockdownTheme.opacity(0.35) : .blockdownTheme
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Clear glass tube — iOS 27 style: transparency defined by
                // rim highlights, not a frosted band.
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.07), .white.opacity(0.015)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: Self.ringWidth
                    )
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.45), .white.opacity(0.08), .white.opacity(0.25)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
                Circle()
                    .inset(by: Self.ringWidth - 1)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)

                FluidLayer(
                    poolAngle: fluid.poolAngle,
                    tilt: fluid.tilt,
                    velocity: fluid.velocity,
                    ringWidth: Self.ringWidth
                )

                progressArc

                VStack(spacing: 8) {
                    Text(TimeFormatting.hms(remaining))
                        .font(.system(size: 56, weight: .thin))
                        .monospacedDigit()
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: true))

                    subtitle
                }
                .padding(.horizontal, Self.ringWidth + 16)
            }
            .frame(width: 330, height: 330)

            Text(name)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var progressArc: some View {
        ZStack {
            // Main arc with a soft glow.
            Circle()
                .inset(by: Self.ringWidth / 2)
                .trim(from: 0, to: arcFraction)
                .stroke(arcColor, style: StrokeStyle(lineWidth: Self.ringWidth - 8, lineCap: .round))
                .shadow(color: arcColor.opacity(phase == .paused ? 0 : 0.55), radius: 7)

            // Specular highlight along the outer edge for the glassy look.
            Circle()
                .inset(by: Self.ringWidth / 2 - 5)
                .trim(from: 0, to: arcFraction)
                .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .rotationEffect(.degrees(-90))
        .scaleEffect(x: etaMode ? -1 : 1)
        .animation(.linear(duration: 1), value: arcFraction)
    }

    @ViewBuilder
    private var subtitle: some View {
        switch phase {
        case .running:
            if let endDate {
                HStack(spacing: 5) {
                    Image(systemName: "bell.fill")
                    Text(TimeFormatting.endTime(endDate))
                }
                .font(.title3)
                .foregroundStyle(.secondary)
            }
        case .paused:
            Text("Paused")
                .font(.title3)
                .foregroundStyle(.secondary)
        case .finished:
            Text("Timer finished")
                .font(.title3)
                .foregroundStyle(Color.blockdownTheme)
        default:
            EmptyView()
        }
    }
}

// MARK: - Fluid layer

/// A body of liquid contained inside the glass tube: crisp meniscus
/// surfaces at both ends, chromatic-aberration fringes where light exits
/// the liquid, and slosh asymmetry driven by angular velocity. Drawn
/// centered at the tube's bottom, then rotated to the pool angle.
private struct FluidLayer: View {
    let poolAngle: Double
    let tilt: Double
    let velocity: Double
    let ringWidth: CGFloat

    var body: some View {
        // Fixed volume of liquid; spreads wider when the device lies flat.
        let half = 0.115 + 0.10 * (1 - tilt)
        // Momentum piles liquid up on the side it is rushing toward.
        let lean = max(-0.05, min(0.05, velocity * 0.02))
        let trail = 0.25 - half + lean
        let lead = 0.25 + half + lean
        let liquid = Color.blockdownTheme

        ZStack {
            // The liquid body.
            arc(from: trail, to: lead, color: liquid.opacity(0.66), width: ringWidth - 6, blur: 0.4)
            // Depth: darker core so the tube reads filled, not painted.
            arc(from: trail + 0.012, to: lead - 0.012, color: .black.opacity(0.22), width: ringWidth - 16, blur: 1.4)

            // Chromatic aberration at the two liquid surfaces.
            arc(from: trail - 0.008, to: trail + 0.010, color: .red.opacity(0.42), width: ringWidth - 6, blur: 0.9)
                .blendMode(.plusLighter)
            arc(from: lead - 0.010, to: lead + 0.008, color: .blue.opacity(0.48), width: ringWidth - 6, blur: 0.9)
                .blendMode(.plusLighter)

            // Meniscus glints.
            arc(from: lead - 0.004, to: lead + 0.0015, color: .white.opacity(0.75), width: ringWidth - 9, blur: 0.3)
            arc(from: trail - 0.0015, to: trail + 0.004, color: .white.opacity(0.5), width: ringWidth - 9, blur: 0.3)
        }
        .rotationEffect(.radians(poolAngle - .pi / 2))
        .allowsHitTesting(false)
    }

    private func arc(from: Double, to: Double, color: Color, width: CGFloat, blur: CGFloat) -> some View {
        Circle()
            .inset(by: ringWidth / 2)
            .trim(from: max(0, from), to: min(1, to))
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .butt))
            .blur(radius: blur)
    }
}

// MARK: - Controls

struct CircleControlButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint == .gray ? Color.primary : tint)
                .frame(width: 88, height: 88)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tint.opacity(0.28)).interactive(), in: .circle)
    }
}

private struct AdjustChip: View {
    @Environment(TimerEngine.self) private var engine
    let label: String
    let delta: TimeInterval

    var body: some View {
        Button {
            engine.adjust(by: delta)
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Color.blockdownTheme)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Color.blockdownTheme.opacity(0.15)).interactive(), in: .capsule)
    }
}
