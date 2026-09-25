import AppKit
import SwiftUI

/// Hover and layout state the island view renders from.
@MainActor @Observable
final class IslandState {
    var layout = IslandLayout(notch: nil, topInset: 30)
    var hovering = false

    func mode(idle: Bool) -> IslandMode {
        if idle { return hovering && layout.notch != nil ? .peek : .hidden }
        return hovering ? .expanded : .compact
    }
}

/// Owns the transparent panel pinned to the top of the screen and decides when the pointer
/// is "on" the island. Outside the island the panel ignores the mouse, so the menu bar
/// around it stays clickable.
@MainActor
final class IslandController {
    private let stopwatch: Stopwatch
    private let settings: Settings
    private let state = IslandState()
    private let panel = IslandPanel()
    private var screen: NSScreen?

    private var monitors: [Any] = []
    private var pointerInside = false
    private var hoverTask: Task<Void, Never>?
    /// Polls the pointer while it's on the island; mouse-moved events stop reaching
    /// global monitors once the panel accepts the mouse.
    private var exitWatch: Timer?

    init(stopwatch: Stopwatch, settings: Settings) {
        self.stopwatch = stopwatch
        self.settings = settings

        let host = IslandHostingView(rootView: IslandView(stopwatch: stopwatch, island: state))
        host.sizingOptions = []
        panel.contentView = host

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        }
        relayout()
        #if DEBUG
        // Pin a state for screenshots: `open build/miniwatch.app --args -debugHover YES`
        state.hovering = UserDefaults.standard.bool(forKey: "debugHover")
        #endif

        let handler: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.trackPointer() }
        }
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { handler($0); return $0 } as Any)

        track { [weak self] in
            guard let self else { return }
            if settings.showIsland {
                panel.orderFrontRegardless()
            } else {
                panel.orderOut(nil)
                state.hovering = false
            }
        }
    }

    private func relayout() {
        let screen = NSScreen.screens.first { $0.notchSize != nil } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        self.screen = screen
        state.layout = IslandLayout(screen: screen)
        #if DEBUG
        // Preview the no-notch pill on a notched Mac: `--args -debugNoNotch YES`
        if UserDefaults.standard.bool(forKey: "debugNoNotch") {
            state.layout = IslandLayout(notch: nil, topInset: screen.frame.maxY - screen.visibleFrame.maxY + 6)
        }
        #endif

        let size = state.layout.panelSize
        panel.setFrame(CGRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                              width: size.width, height: size.height), display: true)
    }

    /// The region that counts as "on the island" right now, with a little slop.
    private var hotRect: CGRect {
        guard settings.showIsland, let screen else { return .null }
        let mode = state.mode(idle: stopwatch.isIdle)
        // Idle without a notch, there's nothing on screen to hover.
        if mode == .hidden && state.layout.notch == nil { return .null }
        let hasLaps = !stopwatch.splits.isEmpty
        return state.layout.frame(mode, hasLaps: hasLaps, on: screen).insetBy(dx: -4, dy: -4)
    }

    private func trackPointer() {
        let inside = hotRect.contains(NSEvent.mouseLocation)
        guard inside != pointerInside else { return }
        pointerInside = inside
        panel.ignoresMouseEvents = !inside

        hoverTask?.cancel()
        let delay: Duration = inside ? (stopwatch.isIdle ? .milliseconds(220) : .milliseconds(90)) : .milliseconds(320)
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            state.hovering = inside
            updateExitWatch()
        }
        updateExitWatch()
    }

    private func updateExitWatch() {
        let needed = pointerInside || state.hovering
        if needed, exitWatch == nil {
            let timer = Timer(timeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.trackPointer() }
            }
            RunLoop.main.add(timer, forMode: .common)
            exitWatch = timer
        } else if !needed {
            exitWatch?.invalidate()
            exitWatch = nil
        }
    }
}

final class IslandPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Borderless windows get pushed below the menu bar unless we opt out.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Buttons should respond to the first click even though miniwatch never becomes active.
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
