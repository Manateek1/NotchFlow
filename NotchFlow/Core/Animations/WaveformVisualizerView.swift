import SwiftUI

public struct WaveformVisualizerView: View {
    public let isPlaying: Bool
    public let style: WaveformVisualStyle
    public let accentColor: Color
    public var secondaryColor: Color? = nil
    public var barCount: Int = 5
    public var height: CGFloat = 18

    public init(
        isPlaying: Bool,
        style: WaveformVisualStyle,
        accentColor: Color,
        secondaryColor: Color? = nil,
        barCount: Int = 5,
        height: CGFloat = 18
    ) {
        self.isPlaying = isPlaying
        self.style = style
        self.accentColor = accentColor
        self.secondaryColor = secondaryColor
        self.barCount = barCount
        self.height = height
    }

    public var body: some View {
        let reduceMotion = SettingsStore.shared.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if isPlaying && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                waveformContent(phase: t)
            }
        } else {
            waveformContent(phase: 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: isPlaying)
        }
    }

    @ViewBuilder
    private func waveformContent(phase: Double) -> some View {
        let bottomColor = secondaryColor ?? accentColor.opacity(0.62)

        switch style {
        case .bars:
            HStack(alignment: .center, spacing: barCount <= 4 ? 2.2 : 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    let norm = barAmplitude(index: index, phase: phase)
                    let barH = isPlaying ? max(3.0, height * norm) : 3.0
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentColor, bottomColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barCount <= 4 ? 2.4 : 2.7, height: barH)
                }
            }
            .frame(height: height)

        case .liquidWave:
            Canvas { ctx, size in
                var path = Path()
                let midY = size.height * 0.5
                let amp = isPlaying ? size.height * 0.38 : size.height * 0.06
                path.move(to: CGPoint(x: 0, y: midY))
                let steps = 24
                for step in 0...steps {
                    let x = (CGFloat(step) / CGFloat(steps)) * size.width
                    let envelope = sin((Double(step) / Double(steps)) * .pi)
                    let angle = (Double(step) / Double(steps)) * .pi * 2.6 + (phase * 6.2)
                    let y = midY + CGFloat(sin(angle) * envelope) * amp
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                ctx.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [accentColor, bottomColor]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(width: CGFloat(barCount) * 5.0, height: height)

        case .spectrumDots:
            HStack(alignment: .center, spacing: 2.8) {
                ForEach(0..<barCount, id: \.self) { index in
                    let norm = barAmplitude(index: index, phase: phase)
                    Circle()
                        .fill(accentColor.opacity(isPlaying ? (0.45 + 0.55 * norm) : 0.45))
                        .frame(width: 3.8, height: 3.8)
                        .offset(y: isPlaying ? (norm - 0.5) * (height * 0.44) : 0)
                }
            }
            .frame(height: height)

        case .minimalPulse:
            let scale = isPlaying ? (0.82 + 0.22 * CGFloat(abs(sin(phase * 3.6)))) : 0.65
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.24))
                    .frame(width: height * scale, height: height * scale)
                Circle()
                    .fill(accentColor)
                    .frame(width: height * 0.38, height: height * 0.38)
            }
            .frame(width: height, height: height)
        }
    }

    private func barAmplitude(index: Int, phase: Double) -> CGFloat {
        guard isPlaying else {
            return 0.16
        }
        // Bell-shaped envelope so center bars reach higher like iOS Dynamic Island & Alcove (`lh-hero.png`)
        let envelopes5: [CGFloat] = [0.56, 0.86, 1.00, 0.82, 0.52]
        let envelopes4: [CGFloat] = [0.62, 0.98, 0.88, 0.58]
        let env = (barCount == 4)
            ? envelopes4[index % envelopes4.count]
            : envelopes5[index % envelopes5.count]

        if phase == 0 {
            // Static snapshot amplitude (used when exporting screenshots or when paused phase = 0)
            let snapshotHeights: [CGFloat] = [0.46, 0.78, 0.96, 0.68, 0.48]
            return snapshotHeights[index % snapshotHeights.count]
        }

        let periods: [Double] = [0.95, 1.46, 0.82, 1.24, 1.08]
        let period = periods[index % periods.count]
        let freq = (2.0 * .pi) / period
        let offset = Double(index) * 1.15
        let primary = (sin(phase * freq + offset) + 1.0) * 0.5
        let harmonic = (cos(phase * (freq * 0.67) - offset * 0.8) + 1.0) * 0.5
        let wave = CGFloat(primary * 0.68 + harmonic * 0.32)
        return max(0.20, min(1.0, (0.24 + wave * 0.76) * env))
    }
}
