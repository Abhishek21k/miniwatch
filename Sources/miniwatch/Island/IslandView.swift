import MiniwatchCore
import SwiftUI

struct IslandView: View {
    let stopwatch: Stopwatch
    let island: IslandState

    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: IslandLayout { island.layout }
    private var mode: IslandMode { island.mode(idle: stopwatch.isIdle) }
    private var hasLaps: Bool { !stopwatch.splits.isEmpty }

    private var spring: Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.38, dampingFraction: 0.8)
    }

    var body: some View {
        let mode = self.mode
        let size = layout.size(mode, hasLaps: hasLaps)
        let ear = layout.ear(mode)
        let shape = IslandShape(ear: ear, top: layout.topRadius(mode), bottom: layout.bottomRadius(mode))

        content(mode)
            .frame(width: size.width, height: size.height)
            .padding(.horizontal, ear)
            .background(shape.fill(.black))
            .clipShape(shape)
            .shadow(color: .black.opacity(mode == .expanded ? 0.35 : 0), radius: 14, y: 6)
            .scaleEffect(layout.notch == nil && mode == .hidden ? 0.85 : 1, anchor: .top)
            .opacity(mode == .hidden ? 0 : 1)
            .padding(.top, layout.topInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
            .animation(spring, value: mode)
            .animation(spring, value: hasLaps)
            .animation(spring, value: stopwatch.isRunning)
    }

    @ViewBuilder
    private func content(_ mode: IslandMode) -> some View {
        switch mode {
        case .hidden:
            Color.clear
        case .peek:
            peek
        case .compact:
            compact.transition(.opacity.combined(with: .scale(scale: 0.9)))
        case .expanded:
            expanded.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        }
    }

    // MARK: Peek — idle, pointer on the notch

    private var peek: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: layout.notch?.height ?? 0)
            Image(systemName: "play.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { act(stopwatch.toggle) }
        .transition(.opacity)
    }

    // MARK: Compact — time on the wings

    @ViewBuilder
    private var compact: some View {
        if let notch = layout.notch {
            HStack(spacing: 0) {
                indicator.frame(width: IslandLayout.wing)
                Color.clear.frame(width: notch.width)
                ticking.frame(width: IslandLayout.wing)
            }
        } else {
            HStack(spacing: 8) {
                indicator
                ticking
            }
        }
    }

    @ViewBuilder
    private var indicator: some View {
        if stopwatch.isMirroring {
            Image(systemName: stopwatch.isRunning ? "clock.fill" : "clock")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.orange)
                .contentTransition(.symbolEffect(.replace))
        } else {
            Circle()
                .fill(stopwatch.isRunning ? Color.orange : .clear)
                .strokeBorder(.orange, lineWidth: 1.5)
                .frame(width: 7, height: 7)
        }
    }

    /// Redraws once per displayed second, aligned to the stopwatch rather than the wall clock.
    /// No digit roll here: it's always on screen, and each roll is ~20 CPU-rendered frames.
    private var ticking: some View {
        TimelineView(SecondsSchedule(anchor: stopwatch.anchor)) { context in
            Text(TimeFormat.short(stopwatch.elapsed(at: context.date)))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(stopwatch.isRunning ? 1 : 0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .matchedGeometryEffect(id: "time", in: ns)
    }

    // MARK: Expanded — big time and two controls

    private var expanded: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: layout.notch?.height ?? 0)
            HStack(spacing: 0) {
                leftControl
                Spacer(minLength: 8)
                bigTime
                Spacer(minLength: 8)
                rightControl
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity)

            if hasLaps {
                laps.padding(.bottom, 10)
            }
        }
    }

    private var bigTime: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !stopwatch.isRunning)) { context in
            let t = stopwatch.elapsed(at: context.date)
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(TimeFormat.short(t))
                        .font(.system(size: 32, weight: .light).monospacedDigit())
                        .contentTransition(.numericText(value: t.rounded(.down)))
                        .animation(.snappy(duration: 0.3), value: Int(t))
                    Text(TimeFormat.fraction(t))
                        .font(.system(size: 18, weight: .light).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                }
                .foregroundStyle(.white.opacity(stopwatch.isRunning ? 1 : 0.6))
                if stopwatch.isMirroring {
                    Text("Clock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .lineLimit(1)
            .fixedSize()
        }
        .matchedGeometryEffect(id: "time", in: ns)
        .contentShape(Rectangle())
        .onTapGesture { act(stopwatch.toggle) }
    }

    @ViewBuilder
    private var leftControl: some View {
        if stopwatch.isMirroring {
            // Clock's stopwatch is view-only; keep the layout balanced.
            Color.clear.frame(width: RoundButton.size, height: RoundButton.size)
        } else if stopwatch.isRunning {
            RoundButton(symbol: "flag.fill", tint: .white, help: "Lap  ⌃⌥L") { act(stopwatch.lap) }
        } else {
            RoundButton(symbol: "arrow.counterclockwise", tint: .white, help: "Reset  ⌃⌥R") { act(stopwatch.reset) }
        }
    }

    @ViewBuilder
    private var rightControl: some View {
        // Always miniwatch's own stopwatch, even while Clock's time is on show.
        let running = stopwatch.local.isRunning
        RoundButton(
            symbol: running ? "pause.fill" : "play.fill",
            tint: running ? .orange : .green,
            help: "\(running ? "Pause" : "Start")  ⌃⌥S"
        ) { act(stopwatch.toggle) }
    }

    private var laps: some View {
        HStack(spacing: 14) {
            ForEach(stopwatch.recentLaps(), id: \.number) { lap in
                HStack(spacing: 5) {
                    Text("#\(lap.number)").foregroundStyle(.white.opacity(0.35))
                    Text(TimeFormat.precise(lap.duration)).foregroundStyle(.white.opacity(0.75))
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .frame(height: IslandLayout.lapsHeight)
        .animation(spring, value: stopwatch.splits.count)
    }

    private func act(_ action: () -> Void) {
        action()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

struct RoundButton: View {
    static let size: CGFloat = 36

    let symbol: String
    let tint: Color
    let help: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Self.size, height: Self.size)
                .background(Circle().fill(tint.opacity(hovered ? 0.3 : 0.18)))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.15), value: hovered)
        .help(help)
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Timeline entries at each whole second of stopwatch time; a single entry while paused.
struct SecondsSchedule: TimelineSchedule {
    let anchor: Date?

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        guard let anchor else { return AnyIterator([startDate].makeIterator()) }
        var first: Date? = startDate
        var second = startDate.timeIntervalSince(anchor).rounded(.down) + 1
        return AnyIterator {
            if let date = first {
                first = nil
                return date
            }
            defer { second += 1 }
            // A hair past the boundary so flooring never lands on the previous second.
            return anchor.addingTimeInterval(second + 0.005)
        }
    }
}
