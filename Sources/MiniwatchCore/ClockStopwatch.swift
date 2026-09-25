import Foundation

/// A read-only snapshot of the macOS Clock app's stopwatch.
///
/// Clock keeps its stopwatch in `mobiletimerd`, persisted under the `MTStopwatches` key of the
/// `com.apple.mobiletimerd` preferences domain. The format is private, so decoding is strict:
/// anything unexpected yields `.unrecognized` and the mirror switches itself off.
///
/// Field semantics (verified against MobileTimer's own view model):
/// - `MTStopwatchState`: 0 stopped, 1 paused, 2 running
/// - `MTStopwatchStartDate`: start of the current run of the current lap (absent unless running)
/// - `MTStopwatchOffset`: current-lap time banked before the latest resume
/// - `MTStopwatchPreviousLapsTotalInterval`: sum of completed laps
/// - `MTStopwatchLaps`: completed lap durations, oldest first
public struct ClockStopwatch: Equatable, Sendable {
    public enum State: Int, Sendable { case stopped = 0, paused = 1, running = 2 }

    public var state: State
    public var startDate: Date?
    public var offset: TimeInterval
    public var previousLapsTotal: TimeInterval
    /// Completed lap durations, oldest first.
    public var laps: [TimeInterval]

    public init(state: State, startDate: Date?, offset: TimeInterval, previousLapsTotal: TimeInterval, laps: [TimeInterval]) {
        self.state = state
        self.startDate = startDate
        self.offset = offset
        self.previousLapsTotal = previousLapsTotal
        self.laps = laps
    }

    public var isRunning: Bool { state == .running && startDate != nil }
    public var isActive: Bool { state != .stopped }

    public func elapsed(at now: Date) -> TimeInterval {
        let run = isRunning ? max(0, now.timeIntervalSince(startDate!)) : 0
        return previousLapsTotal + offset + run
    }

    /// See `StopwatchState.anchor`.
    public var anchor: Date? {
        isRunning ? startDate!.addingTimeInterval(-(previousLapsTotal + offset)) : nil
    }

    /// Cumulative split times, oldest first.
    public var splits: [TimeInterval] {
        laps.reduce(into: []) { $0.append(($0.last ?? 0) + $1) }
    }

    public enum Decoded: Equatable, Sendable {
        /// Clock has never stored a stopwatch.
        case absent
        case stopwatch(ClockStopwatch)
        /// The private format changed; don't guess.
        case unrecognized
    }

    /// Decodes the value stored under `MTStopwatches`. When several stopwatches are stored,
    /// the one that's running (else paused, else any) wins.
    public static func decode(_ value: Any?) -> Decoded {
        guard let value else { return .absent }
        guard let root = value as? [String: Any],
              let entries = root["MTStopwatches"] as? [Any] else { return .unrecognized }

        var decoded: [ClockStopwatch] = []
        for entry in entries {
            guard let wrapper = entry as? [String: Any],
                  let fields = wrapper["$MTStopwatch"] as? [String: Any],
                  let stopwatch = ClockStopwatch(fields: fields) else { return .unrecognized }
            decoded.append(stopwatch)
        }
        let best = decoded.first { $0.state == .running }
            ?? decoded.first { $0.state == .paused }
            ?? decoded.first
        return best.map(Decoded.stopwatch) ?? .absent
    }

    init?(fields: [String: Any]) {
        guard let rawState = (fields["MTStopwatchState"] as? NSNumber)?.intValue,
              let state = State(rawValue: rawState),
              let offset = (fields["MTStopwatchOffset"] as? NSNumber)?.doubleValue,
              let previous = (fields["MTStopwatchPreviousLapsTotalInterval"] as? NSNumber)?.doubleValue
        else { return nil }

        let startDate = fields["MTStopwatchStartDate"] as? Date
        if state == .running && startDate == nil { return nil }

        var laps: [TimeInterval] = []
        if let rawLaps = fields["MTStopwatchLaps"] {
            guard let numbers = rawLaps as? [NSNumber] else { return nil }
            laps = numbers.map(\.doubleValue)
        }
        self.init(state: state, startDate: startDate, offset: offset, previousLapsTotal: previous, laps: laps)
    }
}
