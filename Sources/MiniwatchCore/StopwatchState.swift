import Foundation

/// A drift-free stopwatch: elapsed time is derived from a start date plus banked time,
/// so nothing ticks in the background and the reading survives sleep and relaunch.
public struct StopwatchState: Codable, Equatable, Sendable {
    /// Time banked from previous runs.
    public var accumulated: TimeInterval = 0
    /// Non-nil while running.
    public var startedAt: Date?
    /// Cumulative split times, oldest first.
    public var splits: [TimeInterval] = []

    public init() {}

    public var isRunning: Bool { startedAt != nil }
    public var isIdle: Bool { !isRunning && accumulated == 0 && splits.isEmpty }

    public func elapsed(at now: Date) -> TimeInterval {
        accumulated + (startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// While running, the instant elapsed time would read zero had it never paused.
    /// Whole-second ticks fall on this anchor plus an integer.
    public var anchor: Date? {
        startedAt?.addingTimeInterval(-accumulated)
    }

    /// Individual lap durations, oldest first.
    public var lapDurations: [TimeInterval] {
        zip(splits, [0] + splits).map { $0 - $1 }
    }

    public mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        startedAt = now
    }

    public mutating func pause(at now: Date) {
        guard startedAt != nil else { return }
        accumulated = elapsed(at: now)
        startedAt = nil
    }

    public mutating func toggle(at now: Date) {
        isRunning ? pause(at: now) : start(at: now)
    }

    public mutating func lap(at now: Date) {
        guard isRunning else { return }
        splits.append(elapsed(at: now))
    }

    public mutating func reset() {
        self = StopwatchState()
    }
}
