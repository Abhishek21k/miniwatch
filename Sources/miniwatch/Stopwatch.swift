import AppKit
import MiniwatchCore
import Observation

/// The app's single source of truth: miniwatch's own stopwatch, plus (when mirroring) a
/// read-only view of the Clock app's. The UI shows Clock's only while miniwatch's is idle.
@MainActor @Observable
final class Stopwatch {
    private(set) var local: StopwatchState
    /// Clock app's stopwatch, set by `ClockMirror`; nil when mirroring is off.
    var clock: ClockStopwatch?
    /// Clock's stopwatch as it stood at the last reset. Reset clears the island, so this snapshot
    /// stays hidden until Clock's stopwatch changes (started, paused, lapped or reset in Clock).
    private var dismissedClock: ClockStopwatch?

    @ObservationIgnored private let defaults: UserDefaults
    private static let storageKey = "stopwatch"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        local = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(StopwatchState.self, from: $0) }
            ?? StopwatchState()
    }

    // MARK: What the UI shows

    var isMirroring: Bool { local.isIdle && clock?.isActive == true && clock != dismissedClock }
    var isIdle: Bool { local.isIdle && !isMirroring }
    var isRunning: Bool { isMirroring ? clock!.isRunning : local.isRunning }
    var anchor: Date? { isMirroring ? clock!.anchor : local.anchor }
    var splits: [TimeInterval] { isMirroring ? clock!.splits : local.splits }

    func elapsed(at now: Date = .now) -> TimeInterval {
        isMirroring ? clock!.elapsed(at: now) : local.elapsed(at: now)
    }

    /// The most recent laps, newest first, numbered from 1.
    func recentLaps(_ count: Int = 3) -> [(number: Int, duration: TimeInterval)] {
        let durations = zip(splits, [0] + splits).map { $0 - $1 }
        return durations.enumerated().suffix(count).reversed().map { ($0.offset + 1, $0.element) }
    }

    // MARK: Controls (always miniwatch's own stopwatch; Clock's is view-only)

    func toggle() { mutate { $0.toggle(at: .now) } }
    func lap() { mutate { $0.lap(at: .now) } }
    func reset() {
        if dismissedClock != clock { dismissedClock = clock }
        mutate { $0.reset() }
    }

    private func mutate(_ change: (inout StopwatchState) -> Void) {
        var next = local
        change(&next)
        guard next != local else { return }
        local = next
        if let data = try? JSONEncoder().encode(local) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}

@MainActor @Observable
final class Settings {
    var showIsland: Bool { didSet { defaults.set(showIsland, forKey: "showIsland") } }
    var mirrorClock: Bool { didSet { defaults.set(mirrorClock, forKey: "mirrorClock") } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["showIsland": true, "mirrorClock": false])
        showIsland = defaults.bool(forKey: "showIsland")
        mirrorClock = defaults.bool(forKey: "mirrorClock")
    }
}

/// Runs `body` now and again whenever an observable property it read changes.
@MainActor
func track(_ body: @escaping @MainActor @Sendable () -> Void) {
    withObservationTracking(body) {
        Task { @MainActor in track(body) }
    }
}
