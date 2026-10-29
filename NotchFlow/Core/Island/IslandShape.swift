import SwiftUI

/// A top-anchored hardware notch shape with smooth concave top ears and continuous squircle bottom corners,
/// morphing cleanly into a floating pill when `topInset` > 0.
public struct NotchIslandShape: Shape {
    public var topShoulderRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topShoulderRadius, bottomCornerRadius) }
        set {
            topShoulderRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    public init(topShoulderRadius: CGFloat = 10, bottomCornerRadius: CGFloat = 18) {
        self.topShoulderRadius = topShoulderRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let shoulder = min(topShoulderRadius, rect.height * 0.35, rect.width * 0.15)
        let bottomR = min(bottomCornerRadius, rect.height * 0.5, (rect.width - shoulder * 2) * 0.5)

        var path = Path()

        // Start top-left outer shoulder edge
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left concave shoulder curve down into left vertical wall
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder),
            control: CGPoint(x: rect.minX + shoulder, y: rect.minY)
        )

        // Left wall down to bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY - bottomR))

        // Bottom-left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + shoulder + bottomR, y: rect.maxY),
            control: CGPoint(x: rect.minX + shoulder, y: rect.maxY)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.maxX - shoulder - bottomR, y: rect.maxY))

        // Bottom-right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - bottomR),
            control: CGPoint(x: rect.maxX - shoulder, y: rect.maxY)
        )

        // Right wall up to top-right shoulder
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder))

        // Top-right concave shoulder curve out to top-right edge
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - shoulder, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}
