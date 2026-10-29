import SwiftUI
import AppKit

public struct ExpandedMusicPlayerView: View {
    @ObservedObject var media = MediaManager.shared
    @ObservedObject var volumeMgr = VolumeManager.shared
    @ObservedObject var settings = SettingsStore.shared

    @State private var isDraggingScrubber: Bool = false
    @State private var dragProgress: Double = 0.0
    @State private var showVolumePopover: Bool = false

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
        VStack(spacing: 12) {
            // Top Row: Artwork + Metadata + Live Waveform
            HStack(alignment: .center, spacing: 14) {
                if settings.showAlbumArtwork {
                    artworkView
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if settings.showAudioFormatBadges && track.isExplicit {
                            Text("E")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    Text(track.artist.isEmpty ? track.sourceAppName : "\(track.artist)\(track.album.isEmpty ? "" : " — \(track.album)")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)

                    if settings.showAudioFormatBadges {
                        HStack(spacing: 6) {
                            Button {
                                media.openSourceApplication()
                            } label: {
                                HStack(spacing: 3.5) {
                                    Image(systemName: track.sourceSymbolName)
                                        .font(.system(size: 9.5, weight: .semibold))
                                    Text(track.sourceAppName)
                                        .font(.system(size: 9.5, weight: .semibold))
                                }
                                .foregroundStyle(activeAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(activeAccent.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(.plain)

                            if track.isLossless {
                                badgePill(icon: "waveform.path", text: "Lossless")
                            }
                            if track.isDolbyAtmos {
                                badgePill(icon: "hifispeaker.2.fill", text: "Dolby Atmos")
                            }
                            if track.isPodcast {
                                badgePill(icon: "mic.fill", text: "Podcast")
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer(minLength: 4)

                if settings.showWaveform {
                    WaveformVisualizerView(
                        isPlaying: track.isPlaying,
                        style: settings.waveformStyle,
                        accentColor: activeAccent,
                        barCount: 6,
                        height: 24
                    )
                    .padding(.trailing, 4)
                }
            }

            // Middle Row: Interactive Progress Bar & Timestamps
            VStack(spacing: 5) {
                GeometryReader { geo in
                    let currentProg = isDraggingScrubber ? dragProgress : track.progress
                    let fillWidth = max(4, geo.size.width * CGFloat(currentProg))

                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.14))
                            .frame(height: isDraggingScrubber ? 7 : 5)

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [activeAccent, activeAccent.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fillWidth, height: isDraggingScrubber ? 7 : 5)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
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
                .frame(height: 12)

                HStack {
                    Text(isDraggingScrubber ? NowPlayingTrack.formatTime(track.duration * dragProgress) : track.formattedElapsed)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(track.formattedRemaining)
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            // Bottom Row: Transport Controls + Output / Volume
            if settings.showPlaybackControls {
                HStack(spacing: 18) {
                    // Shuffle or Podcast Speed
                    if track.isPodcast {
                        Button {
                            media.cyclePodcastSpeed()
                        } label: {
                            Text(String(format: "%.2gx", media.playbackSpeed))
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundStyle(activeAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Cycle Podcast Playback Speed")
                    } else {
                        Button {
                            media.toggleShuffle()
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(track.isShuffling ? activeAccent : .white.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Shuffle")
                    }

                    Spacer()

                    // Previous
                    Button {
                        media.previousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help("Previous Track")

                    // Play / Pause
                    Button {
                        media.togglePlayPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 36, height: 36)
                            Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: track.isPlaying ? 0 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(track.isPlaying ? "Pause" : "Play")

                    // Next
                    Button {
                        media.nextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help("Next Track")

                    Spacer()

                    // Repeat
                    Button {
                        media.cycleRepeatMode()
                    } label: {
                        Image(systemName: track.repeatMode.symbolName)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(track.repeatMode != .off ? activeAccent : .white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .help("Cycle Repeat Mode")

                    // Like / Favorite
                    Button {
                        media.toggleLike()
                    } label: {
                        Image(systemName: track.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(track.isLiked ? .pink : .white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .help("Favorite Track")

                    // Inline Volume Toggle
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            showVolumePopover.toggle()
                        }
                    } label: {
                        Image(systemName: volumeMgr.outputDeviceSymbol)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(showVolumePopover ? activeAccent : .white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Output Volume Bar")
                }
            }

            if showVolumePopover {
                HStack(spacing: 8) {
                    Button {
                        volumeMgr.toggleMute(triggerHUD: false)
                    } label: {
                        Image(systemName: volumeMgr.volumeSymbolName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)

                    Slider(
                        value: Binding(
                            get: { volumeMgr.isMuted ? 0 : volumeMgr.volume },
                            set: { volumeMgr.setSystemVolume($0, triggerHUD: false) }
                        ),
                        in: 0...1
                    )
                    .tint(activeAccent)
                    .controlSize(.mini)

                    Text(volumeMgr.outputDeviceName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var artworkView: some View {
        let size: CGFloat = (settings.expandedPlayerLayout == .cinemaArtwork) ? 68 : 56
        let dimmed = settings.dimArtworkOnPause && !track.isPlaying

        return ZStack {
            if settings.artworkGlowEffect {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(activeAccent.opacity(track.isPlaying ? 0.45 : 0.15))
                    .frame(width: size, height: size)
                    .blur(radius: 10)
            }

            if let nsImg = track.artworkImage {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(dimmed ? 0.65 : 1.0)
                    .scaleEffect(dimmed ? 0.94 : 1.0)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [activeAccent.opacity(0.45), Color.indigo.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    )
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: track.isPlaying)
        .onTapGesture {
            media.openSourceApplication()
        }
    }

    private func badgePill(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .semibold))
            Text(text)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.72))
        .padding(.horizontal, 5.5)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.10), in: Capsule())
    }
}
