import SwiftUI

public struct WaveformVisualizerView: View {
    public let isPlaying: Bool
    public let style: WaveformVisualStyle
    public let accentColor: Color
    public var barCount: Int = 5
    public var height: CGFloat = 16

    public init(
        isPlaying: Bool,
        style: WaveformVisualStyle,
        accentColor: Color,
        barCount: Int = 5,
        height: CGFloat = 16
    ) {
        self.isPlaying = isPlaying
        self.style = style
        self.accentColor = accentColor
        self.barCount = barCount
        self.height = height
    }

    public var body: some View {
        let reduceMotion = SettingsStore.shared.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if isPlaying && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isPlaying)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                waveformContent(phase: t)
            }
        } else {
            waveformContent(phase: 0)
        }
    }

    @ViewBuilder
    private func waveformContent(phase: Double) -> some View {
        switch style {
        case .bars:
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    let norm = barAmplitude(index: index, phase: phase)
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2.6, height: max(3.0, height * norm))
                }
            }
            .frame(height: height)

        case .liquidWave:
            Canvas { ctx, size in
                var path = Path()
                let midY = size.height * 0.5
                let amp = isPlaying ? size.height * 0.38 : size.height * 0.08
                path.move(to: CGPoint(x: 0, y: midY))
                let steps = 20
                for step in 0...steps {
                    let x = (CGFloat(step) / CGFloat(steps)) * size.width
                    let angle = (Double(step) / Double(steps)) * .pi * 2.4 + (phase * 6.5)
                    let y = midY + CGFloat(sin(angle)) * amp
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                ctx.stroke(
                    path,
                    with: .color(accentColor),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(width: CGFloat(barCount) * 5.2, height: height)

        case .spectrumDots:
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let norm = barAmplitude(index: index, phase: phase)
                    Circle()
                        .fill(accentColor.opacity(0.45 + 0.55 * norm))
                        .frame(width: 4.2, height: 4.2)
                        .offset(y: isPlaying ? (norm - 0.5) * (height * 0.45) : 0)
                }
            }
            .frame(height: height)

        case .minimalPulse:
            let scale = isPlaying ? (0.82 + 0.24 * CGFloat(abs(sin(phase * 3.8)))) : 0.75
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.28))
                    .frame(width: height * scale, height: height * scale)
                Circle()
                    .fill(accentColor)
                    .frame(width: height * 0.42, height: height * 0.42)
            }
            .frame(width: height, height: height)
        }
    }

    private func barAmplitude(index: Int, phase: Double) -> CGFloat {
        guard isPlaying, phase > 0 else {
            let resting: [CGFloat] = [0.24, 0.36, 0.28, 0.34, 0.22]
            return resting[index % resting.count]
        }
        let freq = 4.2 + Double(index) * 1.15
        let offset = Double(index) * 0.85
        let primary = sin(phase * freq + offset)
        let harmonic = cos(phase * (freq * 0.63) - offset * 1.3)
        let combined = abs(primary * 0.65 + harmonic * 0.35)
        return max(0.20, min(1.0, CGFloat(0.22 + combined * 0.78)))
    }
}
