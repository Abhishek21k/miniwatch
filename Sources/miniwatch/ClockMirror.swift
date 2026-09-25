import Foundation
import MiniwatchCore

/// Mirrors the Clock app's stopwatch by polling the preferences `mobiletimerd` writes.
/// Read-only by design: miniwatch never writes to Clock's domain.
@MainActor
final class ClockMirror {
    private static let domain = "com.apple.mobiletimerd" as CFString
    private static let key = "MTStopwatches" as CFString

    private let stopwatch: Stopwatch
    private var timer: Timer?
    /// Set when Clock's private format no longer matches what miniwatch understands.
    private(set) var isUnrecognized = false

    init(stopwatch: Stopwatch) {
        self.stopwatch = stopwatch
    }

    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? start() : stop()
        }
    }

    private func start() {
        poll()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        stopwatch.clock = nil
    }

    private func poll() {
        CFPreferencesAppSynchronize(Self.domain)
        let value = CFPreferencesCopyAppValue(Self.key, Self.domain)
        let next: ClockStopwatch?
        switch ClockStopwatch.decode(value) {
        case .stopwatch(let clock):
            next = clock
            isUnrecognized = false
        case .absent:
            next = nil
            isUnrecognized = false
        case .unrecognized:
            next = nil
            isUnrecognized = true
        }
        if next != stopwatch.clock { stopwatch.clock = next }
    }
}
