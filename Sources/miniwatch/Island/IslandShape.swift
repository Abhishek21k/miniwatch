import SwiftUI

/// One animatable outline for every island state.
///
/// - `ear`: concave flare at the top edge, so a notch island melts into the bezel.
/// - `top`: convex top corners, for the floating pill.
/// - `bottom`: convex bottom corners.
///
/// The drawing rect includes the ears; the body is inset by `ear` on each side.
struct IslandShape: Shape {
    var ear: CGFloat
    var top: CGFloat
    var bottom: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(ear, AnimatablePair(top, bottom)) }
        set { (ear, top, bottom) = (newValue.first, newValue.second.first, newValue.second.second) }
    }

    func path(in rect: CGRect) -> Path {
        let left = rect.minX + ear, right = rect.maxX - ear
        let bodyWidth = right - left
        let e = min(ear, rect.height / 2)
        let t = min(top, bodyWidth / 2, rect.height / 2)
        let b = min(bottom, bodyWidth / 2, (rect.height - e - t))
        let minY = rect.minY, maxY = rect.maxY

        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: minY))
        // Top right: a concave ear or a convex corner share the same control point.
        p.addLine(to: CGPoint(x: right + e - t, y: minY))
        p.addQuadCurve(to: CGPoint(x: right, y: minY + e + t), control: CGPoint(x: right, y: minY))
        p.addLine(to: CGPoint(x: right, y: maxY - b))
        p.addQuadCurve(to: CGPoint(x: right - b, y: maxY), control: CGPoint(x: right, y: maxY))
        p.addLine(to: CGPoint(x: left + b, y: maxY))
        p.addQuadCurve(to: CGPoint(x: left, y: maxY - b), control: CGPoint(x: left, y: maxY))
        p.addLine(to: CGPoint(x: left, y: minY + e + t))
        p.addQuadCurve(to: CGPoint(x: left - e + t, y: minY), control: CGPoint(x: left, y: minY))
        p.closeSubpath()
        return p
    }
}
