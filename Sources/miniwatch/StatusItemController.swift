import AppKit
import MiniwatchCore
import ServiceManagement

/// The menu bar item. Left-click starts/pauses; right-click opens a small menu.
/// Shows a glyph while the island is on (the island carries the time), otherwise the time itself.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let stopwatch: Stopwatch
    private let settings: Settings
    private let mirror: ClockMirror
    private var ticker: Timer?

    init(stopwatch: Stopwatch, settings: Settings, mirror: ClockMirror) {
        self.stopwatch = stopwatch
        self.settings = settings
        self.mirror = mirror
        super.init()

        let button = item.button!
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly

        track { [weak self] in self?.refresh() }
    }

    // MARK: Rendering

    private var showsTime: Bool { !settings.showIsland && !stopwatch.isIdle }

    private func refresh() {
        // Touch every observable input so any change re-renders.
        _ = (stopwatch.isIdle, stopwatch.isRunning, stopwatch.anchor, settings.showIsland)
        render()
        scheduleTick()
    }

    private func render() {
        guard let button = item.button else { return }
        let running = stopwatch.isRunning

        if showsTime {
            button.image = nil
            button.imagePosition = .noImage
            button.attributedTitle = NSAttributedString(
                string: TimeFormat.short(stopwatch.elapsed()),
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                    .foregroundColor: running ? NSColor.labelColor : NSColor.secondaryLabelColor,
                ]
            )
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
            let image = NSImage(systemSymbolName: running ? "stopwatch.fill" : "stopwatch", accessibilityDescription: "miniwatch")
            image?.isTemplate = true
            button.image = image
        }
        button.toolTip = "Click to \(stopwatch.local.isRunning ? "pause" : "start") · right-click for more"
    }

    /// Re-renders exactly when the displayed second changes, and only while time is visible.
    private func scheduleTick() {
        ticker?.invalidate()
        ticker = nil
        guard showsTime, let anchor = stopwatch.anchor else { return }

        let next = anchor.addingTimeInterval(Date.now.timeIntervalSince(anchor).rounded(.down) + 1.005)
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.render()
                self?.scheduleTick()
            }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    // MARK: Interaction

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            stopwatch.toggle()
        }
    }

    private func showMenu() {
        item.menu = makeMenu()
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let running = stopwatch.local.isRunning, idle = stopwatch.local.isIdle

        if stopwatch.isMirroring {
            let note = NSMenuItem(title: "Showing Clock app’s stopwatch", action: nil, keyEquivalent: "")
            note.isEnabled = false
            menu.addItem(note)
        }

        menu.addItem(entry(running ? "Pause" : (idle ? "Start" : "Resume"), #selector(toggle), key: "s", hotKey: true))
        menu.addItem(entry("Lap", #selector(lap), key: "l", hotKey: true, enabled: running))
        menu.addItem(entry("Reset", #selector(reset), key: "r", hotKey: true, enabled: !idle))
        menu.addItem(.separator())

        menu.addItem(entry("Show Island", #selector(toggleIsland), on: settings.showIsland))
        let mirrorTitle = mirror.isUnrecognized ? "Show Clock App Stopwatch (unsupported on this macOS)" : "Show Clock App Stopwatch"
        menu.addItem(entry(mirrorTitle, #selector(toggleMirror), on: settings.mirrorClock))
        menu.addItem(entry("Launch at Login", #selector(toggleLaunchAtLogin), on: SMAppService.mainApp.status == .enabled))
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit miniwatch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    private func entry(_ title: String, _ action: Selector, key: String = "", hotKey: Bool = false,
                       enabled: Bool = true, on: Bool? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = enabled
        if hotKey { item.keyEquivalentModifierMask = [.control, .option] }
        if let on { item.state = on ? .on : .off }
        return item
    }

    @objc private func toggle() { stopwatch.toggle() }
    @objc private func lap() { stopwatch.lap() }
    @objc private func reset() { stopwatch.reset() }
    @objc private func toggleIsland() { settings.showIsland.toggle() }
    @objc private func toggleMirror() { settings.mirrorClock.toggle() }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            NSSound.beep()
        }
    }
}
