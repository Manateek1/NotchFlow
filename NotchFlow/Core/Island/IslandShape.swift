import SwiftUI

/// A top-anchored hardware Dynamic Island shape with liquid-smooth concave top fillets ("ears")
/// and continuous superellipse bottom corners that blend invisibly into the macOS camera notch.
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

    public init(topShoulderRadius: CGFloat = 12, bottomCornerRadius: CGFloat = 16) {
        self.topShoulderRadius = topShoulderRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let shoulder = min(topShoulderRadius, rect.height * 0.38, rect.width * 0.14)
        let innerWidth = max(1, rect.width - shoulder * 2)
        let bottomR = min(bottomCornerRadius, rect.height * 0.52, innerWidth * 0.48)
        let k: CGFloat = 0.58 // Continuous squircle control point ratio

        var path = Path()

        // 1. Start at top-left outer flare on the top screen edge (y = 0)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // 2. Concave top-left ear curving smoothly down into the left vertical wall
        path.addCurve(
            to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder),
            control1: CGPoint(x: rect.minX + shoulder * 0.62, y: rect.minY),
            control2: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder * 0.38)
        )

        // 3. Left vertical wall down to bottom-left squircle start
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY - bottomR))

        // 4. Bottom-left continuous squircle corner
        path.addCurve(
            to: CGPoint(x: rect.minX + shoulder + bottomR, y: rect.maxY),
            control1: CGPoint(x: rect.minX + shoulder, y: rect.maxY - bottomR * (1 - k)),
            control2: CGPoint(x: rect.minX + shoulder + bottomR * (1 - k), y: rect.maxY)
        )

        // 5. Bottom horizontal edge
        path.addLine(to: CGPoint(x: rect.maxX - shoulder - bottomR, y: rect.maxY))

        // 6. Bottom-right continuous squircle corner
        path.addCurve(
            to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - bottomR),
            control1: CGPoint(x: rect.maxX - shoulder - bottomR * (1 - k), y: rect.maxY),
            control2: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - bottomR * (1 - k))
        )

        // 7. Right vertical wall up to top-right concave ear
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder))

        // 8. Concave top-right ear curving smoothly out to the top screen edge (y = 0)
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder * 0.38),
            control2: CGPoint(x: rect.maxX - shoulder * 0.62, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}

/// Open-top perimeter path for optional subtle specular rim lighting that never draws a line across y = 0.
public struct NotchPerimeterStrokeShape: Shape {
    public var topShoulderRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topShoulderRadius, bottomCornerRadius) }
        set {
            topShoulderRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    public init(topShoulderRadius: CGFloat = 12, bottomCornerRadius: CGFloat = 16) {
        self.topShoulderRadius = topShoulderRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let shoulder = min(topShoulderRadius, rect.height * 0.38, rect.width * 0.14)
        let innerWidth = max(1, rect.width - shoulder * 2)
        let bottomR = min(bottomCornerRadius, rect.height * 0.52, innerWidth * 0.48)
        let k: CGFloat = 0.58

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder),
            control1: CGPoint(x: rect.minX + shoulder * 0.62, y: rect.minY),
            control2: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder * 0.38)
        )
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY - bottomR))
        path.addCurve(
            to: CGPoint(x: rect.minX + shoulder + bottomR, y: rect.maxY),
            control1: CGPoint(x: rect.minX + shoulder, y: rect.maxY - bottomR * (1 - k)),
            control2: CGPoint(x: rect.minX + shoulder + bottomR * (1 - k), y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - shoulder - bottomR, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - bottomR),
            control1: CGPoint(x: rect.maxX - shoulder - bottomR * (1 - k), y: rect.maxY),
            control2: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - bottomR * (1 - k))
        )
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder * 0.38),
            control2: CGPoint(x: rect.maxX - shoulder * 0.62, y: rect.minY)
        )
        return path
    }
}
