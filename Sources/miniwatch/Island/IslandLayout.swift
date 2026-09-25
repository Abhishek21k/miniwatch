import AppKit

enum IslandMode: Equatable {
    /// Nothing to show; on a notch this looks exactly like the stock notch.
    case hidden
    /// Idle, but the pointer is resting on the notch: offer a play button.
    case peek
    /// Running or paused: time on the notch's wings.
    case compact
    /// Hovered: big time and controls.
    case expanded
}

/// Island geometry for one screen. With a notch, the island grows out of it; without one,
/// it floats as a pill just below the menu bar.
struct IslandLayout: Equatable {
    /// The hardware notch, or nil on screens without one.
    var notch: CGSize?
    /// Gap between the screen's top edge and the island's top edge.
    var topInset: CGFloat

    static let wing: CGFloat = 58
    static let expandedWidth: CGFloat = 320
    static let lapsHeight: CGFloat = 22

    init(screen: NSScreen) {
        notch = screen.notchSize
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        topInset = notch == nil ? (menuBar > 0 ? menuBar : 24) + 6 : 0
    }

    init(notch: CGSize?, topInset: CGFloat) {
        self.notch = notch
        self.topInset = topInset
    }

    /// Size of the island's body (excluding the notch "ears").
    func size(_ mode: IslandMode, hasLaps: Bool) -> CGSize {
        let laps = hasLaps ? Self.lapsHeight : 0
        guard let notch else {
            switch mode {
            case .hidden, .peek, .compact: return CGSize(width: 108, height: 30)
            case .expanded: return CGSize(width: Self.expandedWidth, height: 76 + laps)
            }
        }
        switch mode {
        case .hidden: return notch
        case .peek: return CGSize(width: notch.width + 16, height: notch.height + 24)
        case .compact: return CGSize(width: notch.width + 2 * Self.wing, height: notch.height)
        case .expanded:
            return CGSize(width: max(Self.expandedWidth, notch.width + 2 * Self.wing), height: notch.height + 72 + laps)
        }
    }

    /// Concave flare where the island meets the top edge (notch only).
    func ear(_ mode: IslandMode) -> CGFloat {
        guard notch != nil else { return 0 }
        switch mode {
        case .hidden: return 0
        case .peek, .compact: return 6
        case .expanded: return 10
        }
    }

    /// Convex top corners (floating pill only).
    func topRadius(_ mode: IslandMode) -> CGFloat {
        guard notch == nil else { return 0 }
        return mode == .expanded ? 24 : 15
    }

    func bottomRadius(_ mode: IslandMode) -> CGFloat {
        guard notch != nil else { return topRadius(mode) }
        switch mode {
        case .hidden: return 8
        case .peek: return 14
        case .compact: return 10
        case .expanded: return 26
        }
    }

    /// Full outline including ears, in a screen's coordinate space.
    func frame(_ mode: IslandMode, hasLaps: Bool, on screen: NSScreen) -> CGRect {
        let body = size(mode, hasLaps: hasLaps)
        let width = body.width + 2 * ear(mode)
        return CGRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - topInset - body.height,
            width: width, height: body.height
        )
    }

    /// The panel stays this size; SwiftUI animates the island inside it.
    var panelSize: CGSize {
        CGSize(width: Self.expandedWidth + 2 * 10 + 2 * 48, height: topInset + (notch?.height ?? 0) + 76 + Self.lapsHeight + 48)
    }
}

extension NSScreen {
    /// Size of the camera housing, or nil when the screen has none.
    var notchSize: CGSize? {
        guard safeAreaInsets.top > 0,
              let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return nil }
        return CGSize(width: frame.width - left.width - right.width, height: safeAreaInsets.top)
    }
}
