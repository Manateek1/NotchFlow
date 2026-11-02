import SwiftUI
import AppKit

public struct ExpandedMusicPlayerView: View {
    @ObservedObject var media = MediaManager.shared
    @ObservedObject var volumeMgr = VolumeManager.shared
    @ObservedObject var connectivityMgr = ConnectivityManager.shared
    @ObservedObject var settings = SettingsStore.shared

    @State private var isDraggingScrubber: Bool = false
    @State private var isHoveringScrubber: Bool = false
    @State private var isHoveringArtwork: Bool = false
    @State private var dragProgress: Double = 0.0
    @State private var showVolumeBar: Bool = false
    @State private var prevNudge: CGFloat = 0
    @State private var nextNudge: CGFloat = 0

    public init() {}

    private var track: NowPlayingTrack {
        media.currentTrack
    }

    private var activeAccent: Color {
        if settings.accentColorPreset == .dynamicArtwork {
            return track.dominantColor
        }
        return settings.accentColorPreset.primaryColor
    }

    public var body: some View {
        VStack(spacing: 16) {
            // 1. Track Header Row: Album Art + Title/Artist + iOS Waveform
            HStack(alignment: .center, spacing: 16) {
                if settings.showAlbumArtwork {
                    artworkView
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(track.title.isEmpty ? "Not Playing" : track.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if track.isExplicit {
                            Text("E")
                                .font(.system(size: 8.5, weight: .heavy))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 0.5)
                                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 2.5))
                        }
                    }

                    Text(track.artist.isEmpty ? track.sourceAppName : track.artist)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if settings.showWaveform {
                    WaveformVisualizerView(
                        isPlaying: track.isPlaying,
                        style: settings.waveformStyle,
                        accentColor: activeAccent,
                        secondaryColor: activeAccent.opacity(0.55),
                        barCount: 5,
                        height: 20
                    )
                    .padding(.trailing, 2)
                }
            }

            // 2. Inline Scrubber Row: Elapsed + Thumb-less Pill Progress + Remaining
            HStack(alignment: .center, spacing: 12) {
                Text(isDraggingScrubber ? NowPlayingTrack.formatTime(track.duration * dragProgress) : track.formattedElapsed)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.44))
                    .frame(width: 36, alignment: .leading)

                GeometryReader { geo in
                    let currentProg = isDraggingScrubber ? dragProgress : track.progress
                    let barHeight: CGFloat = (isDraggingScrubber || isHoveringScrubber) ? 8.0 : 6.0
                    let fillWidth = max(barHeight, geo.size.width * CGFloat(min(1, max(0, currentProg))))

                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(height: barHeight)

                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(isDraggingScrubber ? 1.0 : 0.85))
                            .frame(width: fillWidth, height: barHeight)
                    }
                    .frame(maxHeight: .infinity)
                    .animation(.spring(response: 0.24, dampingFraction: 0.78), value: isHoveringScrubber)
                    .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isDraggingScrubber)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        isHoveringScrubber = hovering
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDraggingScrubber = true
                                let fraction = max(0, min(1, Double(value.location.x / max(1, geo.size.width))))
                                dragProgress = fraction
                            }
                            .onEnded { value in
                                let fraction = max(0, min(1, Double(value.location.x / max(1, geo.size.width))))
                                media.seek(to: fraction)
                                isDraggingScrubber = false
                            }
                    )
                }
                .frame(height: 14)

                Text(track.formattedRemaining)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.44))
                    .frame(width: 40, alignment: .trailing)
            }

            // 3. Symmetrical 5-Button iOS Dynamic Island Transport Bar
            if settings.showPlaybackControls {
                HStack(alignment: .center, spacing: 0) {
                    Spacer(minLength: 10)

                    // 1. Star / Favorite
                    TransportIconButton(
                        symbol: track.isLiked ? "star.fill" : "star",
                        size: 19,
                        color: track.isLiked ? activeAccent : .white.opacity(0.44),
                        helpText: "Favorite Track"
                    ) {
                        media.toggleLike()
                    }

                    Spacer()

                    // 2. Previous Track
                    TransportIconButton(
                        symbol: "backward.fill",
                        size: 21,
                        color: .white,
                        horizontalOffset: prevNudge,
                        helpText: "Previous Track"
                    ) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                            prevNudge = -4
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                prevNudge = 0
                            }
                        }
                        media.previousTrack()
                    }

                    Spacer()

                    // 3. Play / Pause (Pure iOS Symbol — No Background Circle)
                    TransportIconButton(
                        symbol: track.isPlaying ? "pause.fill" : "play.fill",
                        size: 28,
                        color: .white,
                        helpText: track.isPlaying ? "Pause" : "Play"
                    ) {
                        media.togglePlayPause()
                    }

                    Spacer()

                    // 4. Next Track
                    TransportIconButton(
                        symbol: "forward.fill",
                        size: 21,
                        color: .white,
                        horizontalOffset: nextNudge,
                        helpText: "Next Track"
                    ) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                            nextNudge = 4
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                nextNudge = 0
                            }
                        }
                        media.nextTrack()
                    }

                    Spacer()

                    // 5. Audio Output / Device Route
                    let outputSymbol: String = {
                        guard let dev = connectivityMgr.primaryAudioDevice else { return "laptopcomputer" }
                        if dev.name.localizedCaseInsensitiveContains("MacBook") || dev.name.localizedCaseInsensitiveContains("Speaker") {
                            return "laptopcomputer"
                        }
                        return dev.symbolName
                    }()
                    TransportIconButton(
                        symbol: outputSymbol,
                        size: 19,
                        color: showVolumeBar ? .white : .white.opacity(0.44),
                        helpText: "Audio Output & Volume"
                    ) {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                            showVolumeBar.toggle()
                        }
                    }

                    Spacer(minLength: 10)
                }
            }

            // Optional Sleek Inline Output Volume Pill Bar
            if showVolumeBar {
                HStack(spacing: 10) {
                    Button {
                        volumeMgr.toggleMute(triggerHUD: false)
                    } label: {
                        Image(systemName: volumeMgr.volumeSymbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 18)
                    }
                    .buttonStyle(.plain)

                    TouchPillSlider(
                        value: Binding(
                            get: { volumeMgr.isMuted ? 0 : volumeMgr.volume },
                            set: { volumeMgr.setSystemVolume($0, triggerHUD: false) }
                        ),
                        fillColor: .white,
                        height: 6
                    )

                    Text(connectivityMgr.primaryAudioDevice?.name ?? volumeMgr.outputDeviceName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(1)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
    }

    private var artworkView: some View {
        let size: CGFloat = (settings.expandedPlayerLayout == .cinemaArtwork) ? 68 : 62
        let dimmed = settings.dimArtworkOnPause && !track.isPlaying

        return ZStack {
            if settings.artworkGlowEffect {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(activeAccent.opacity(track.isPlaying ? 0.36 : 0.12))
                    .frame(width: size, height: size)
                    .blur(radius: 12)
            }

            if let nsImg = track.artworkImage {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 8, y: 4)
                    .opacity(dimmed ? 0.65 : 1.0)
                    .scaleEffect(dimmed ? 0.88 : (isHoveringArtwork ? 1.04 : 1.0))
            } else {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [activeAccent.opacity(0.55), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.40, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    )
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.74), value: track.isPlaying)
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isHoveringArtwork)
        .onHover { hovering in
            isHoveringArtwork = hovering
        }
        .onTapGesture {
            media.openSourceApplication()
        }
    }
}

// MARK: - Reusable Tactile iOS Transport Button

struct TransportIconButton: View {
    let symbol: String
    let size: CGFloat
    let color: Color
    var horizontalOffset: CGFloat = 0
    let helpText: String
    let action: () -> Void

    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.58)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.70)) {
                    isPressed = false
                }
            }
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(isHovered ? Color.white : color)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(isHovered ? 0.08 : 0.0))
                )
                .scaleEffect(isPressed ? 0.84 : (isHovered ? 1.06 : 1.0))
                .offset(x: horizontalOffset)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Reusable Thumb-less iOS Pill Slider

public struct TouchPillSlider: View {
    @Binding public var value: Double
    public var range: ClosedRange<Double> = 0...1
    public var fillColor: Color = .white
    public var height: CGFloat = 6.5
    public var glowEffect: Bool = false

    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...1,
        fillColor: Color = .white,
        height: CGFloat = 6.5,
        glowEffect: Bool = false
    ) {
        self._value = value
        self.range = range
        self.fillColor = fillColor
        self.height = height
        self.glowEffect = glowEffect
    }

    public var body: some View {
        GeometryReader { geo in
            let span = max(0.0001, range.upperBound - range.lowerBound)
            let normalized = min(1, max(0, (value - range.lowerBound) / span))
            let activeH = (isHovering || isDragging) ? height + 2.0 : height
            let fillW = max(activeH, geo.size.width * CGFloat(normalized))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(fillColor.opacity(0.20))
                    .frame(height: activeH)

                Capsule(style: .continuous)
                    .fill(fillColor)
                    .frame(width: fillW, height: activeH)
                    .shadow(color: glowEffect ? fillColor.opacity(0.75) : .clear, radius: glowEffect ? 6 : 0)
            }
            .frame(maxHeight: .infinity)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHovering)
            .animation(.spring(response: 0.20, dampingFraction: 0.78), value: isDragging)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let frac = min(1, max(0, Double(gesture.location.x / max(1, geo.size.width))))
                        value = range.lowerBound + frac * span
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: max(14, height + 6))
    }
}
