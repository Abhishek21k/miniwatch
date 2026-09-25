import Foundation
import Testing
@testable import MiniwatchCore

private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

@Suite struct StopwatchStateTests {
    @Test func runsPausesAndResumes() {
        var s = StopwatchState()
        #expect(s.isIdle)
        s.start(at: t0)
        #expect(s.elapsed(at: t0 + 5) == 5)
        s.pause(at: t0 + 8)
        #expect(!s.isRunning)
        #expect(s.elapsed(at: t0 + 500) == 8)
        s.start(at: t0 + 100)
        #expect(s.elapsed(at: t0 + 102) == 10)
    }

    @Test func togglingTwiceIsAPause() {
        var s = StopwatchState()
        s.toggle(at: t0)
        s.toggle(at: t0 + 3)
        #expect(s.elapsed(at: t0 + 60) == 3)
        #expect(!s.isIdle)
    }

    @Test func lapsRecordSplitsAndDurations() {
        var s = StopwatchState()
        s.lap(at: t0) // ignored while stopped
        s.start(at: t0)
        s.lap(at: t0 + 5)
        s.lap(at: t0 + 12)
        #expect(s.splits == [5, 12])
        #expect(s.lapDurations == [5, 7])
    }

    @Test func resetReturnsToIdle() {
        var s = StopwatchState()
        s.start(at: t0)
        s.lap(at: t0 + 1)
        s.reset()
        #expect(s.isIdle)
        #expect(s == StopwatchState())
    }

    @Test func survivesCodableRoundTrip() throws {
        var s = StopwatchState()
        s.start(at: t0)
        s.lap(at: t0 + 2)
        let decoded = try JSONDecoder().decode(StopwatchState.self, from: JSONEncoder().encode(s))
        #expect(decoded == s)
    }
}

@Suite struct TimeFormatTests {
    @Test func formats() {
        #expect(TimeFormat.short(0) == "0:00")
        #expect(TimeFormat.short(7.99) == "0:07")
        #expect(TimeFormat.short(754) == "12:34")
        #expect(TimeFormat.short(3723) == "1:02:03")
        #expect(TimeFormat.precise(59.999) == "0:59.99")
        #expect(TimeFormat.precise(754.56) == "12:34.56")
        #expect(TimeFormat.short(-3) == "0:00")
    }
}

@Suite struct ClockStopwatchTests {
    private func root(_ entries: [[String: Any]]) -> [String: Any] {
        ["MTStopwatches": entries.map { ["$MTStopwatch": $0] }]
    }

    private func entry(state: Int, start: Date? = nil, offset: Double = 0, previous: Double = 0, laps: [Double] = []) -> [String: Any] {
        var e: [String: Any] = [
            "MTStopwatchState": state,
            "MTStopwatchOffset": offset,
            "MTStopwatchCurrentInterval": 0,
            "MTStopwatchPreviousLapsTotalInterval": previous,
            "MTStopwatchLaps": laps,
            "MTStopwatchIdentifier": UUID().uuidString,
        ]
        e["MTStopwatchStartDate"] = start
        return e
    }

    @Test func absentWhenClockNeverUsed() {
        #expect(ClockStopwatch.decode(nil) == .absent)
    }

    // Mirrors the transitions recorded from MobileTimer's view model:
    // start@0, lap@5, pause@8, resume@108, lap@112, pause@113.
    @Test func runningAfterALap() {
        let value = root([entry(state: 2, start: t0 + 5, previous: 5, laps: [5])])
        guard case .stopwatch(let c) = ClockStopwatch.decode(value) else { Issue.record("decode failed"); return }
        #expect(c.isRunning)
        #expect(c.elapsed(at: t0 + 8) == 8)
        #expect(c.splits == [5])
    }

    @Test func pausedAfterResumeAndSecondLap() {
        let value = root([entry(state: 1, offset: 1, previous: 12, laps: [5, 7])])
        guard case .stopwatch(let c) = ClockStopwatch.decode(value) else { Issue.record("decode failed"); return }
        #expect(!c.isRunning)
        #expect(c.isActive)
        #expect(c.elapsed(at: t0 + 9_999) == 13)
        #expect(c.splits == [5, 12])
    }

    @Test func prefersTheRunningEntry() {
        let value = root([entry(state: 0), entry(state: 2, start: t0)])
        guard case .stopwatch(let c) = ClockStopwatch.decode(value) else { Issue.record("decode failed"); return }
        #expect(c.state == .running)
    }

    @Test func rejectsUnknownFormats() {
        #expect(ClockStopwatch.decode("nope") == .unrecognized)
        #expect(ClockStopwatch.decode(root([entry(state: 7)])) == .unrecognized)
        #expect(ClockStopwatch.decode(root([entry(state: 2)])) == .unrecognized) // running without a start date
        #expect(ClockStopwatch.decode(root([["MTStopwatchState": 0]])) == .unrecognized)
    }
}
