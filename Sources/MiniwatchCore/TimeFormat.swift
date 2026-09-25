import Foundation

public enum TimeFormat {
    /// Whole seconds, e.g. `0:07`, `12:34`, `1:02:03`.
    public static func short(_ t: TimeInterval) -> String {
        let total = Int(max(0, t).rounded(.down))
        let (h, m, s) = (total / 3600, total / 60 % 60, total % 60)
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Hundredths of a second, e.g. `.42`.
    public static func fraction(_ t: TimeInterval) -> String {
        String(format: ".%02d", Int((max(0, t) * 100).rounded(.down)) % 100)
    }

    /// `short` + `fraction`, e.g. `12:34.56`.
    public static func precise(_ t: TimeInterval) -> String {
        short(t) + fraction(t)
    }
}
