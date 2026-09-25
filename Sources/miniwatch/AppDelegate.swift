import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let stopwatch = Stopwatch()
    private let hotKeys = HotKeys()
    private var mirror: ClockMirror?
    private var statusItem: StatusItemController?
    private var island: IslandController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mirror = ClockMirror(stopwatch: stopwatch)
        self.mirror = mirror
        track { [settings] in mirror.isEnabled = settings.mirrorClock }

        statusItem = StatusItemController(stopwatch: stopwatch, settings: settings, mirror: mirror)
        island = IslandController(stopwatch: stopwatch, settings: settings)

        let hyper = controlKey | optionKey
        hotKeys.register(keyCode: kVK_ANSI_S, modifiers: hyper) { [stopwatch] in stopwatch.toggle() }
        hotKeys.register(keyCode: kVK_ANSI_L, modifiers: hyper) { [stopwatch] in stopwatch.lap() }
        hotKeys.register(keyCode: kVK_ANSI_R, modifiers: hyper) { [stopwatch] in stopwatch.reset() }

        // Script the controls without a mouse (opt-in: `defaults write io.github.miniwatch debugHooks -bool YES`):
        // post the distributed notifications `miniwatch.debug.toggle` / `.lap` / `.reset`.
        for name in ["toggle", "lap", "reset"] where UserDefaults.standard.bool(forKey: "debugHooks") {
            DistributedNotificationCenter.default().addObserver(
                forName: .init("miniwatch.debug.\(name)"), object: nil, queue: .main
            ) { [stopwatch] _ in
                MainActor.assumeIsolated {
                    switch name {
                    case "toggle": stopwatch.toggle()
                    case "lap": stopwatch.lap()
                    default: stopwatch.reset()
                    }
                }
            }
        }
    }
}
