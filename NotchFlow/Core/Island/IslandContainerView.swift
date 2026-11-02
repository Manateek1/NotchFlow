import SwiftUI
import AppKit

public struct IslandContainerView: View {
    public let targetScreen: NSScreen?
    public let onOpenSettings: () -> Void

    @ObservedObject var coordinator = IslandCoordinator.shared
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var media = MediaManager.shared
    @ObservedObject var calendar = CalendarManager.shared
    @ObservedObject var weather = WeatherManager.shared
    @ObservedObject var battery = BatteryManager.shared
    @ObservedObject var connectivity = ConnectivityManager.shared
    @ObservedObject var focus = FocusManager.shared
    @ObservedObject var lockScreen = LockScreenManager.shared

    @State private var isHoveringRightWing: Bool = false

    public init(targetScreen: NSScreen?, onOpenSettings: @escaping () -> Void) {
        self.targetScreen = targetScreen
        self.onOpenSettings = onOpenSettings
    }

    private var useFloatingPillMode: Bool {
        switch settings.islandStyleMode {
        case .simulatedPill:
            return true
        case .realNotch:
            return false
        case .automatic:
            return false
        }
    }

    private var activeAccent: Color {
        if settings.accentColorPreset == .dynamicArtwork && media.currentTrack.hasActiveTrack {
            return media.currentTrack.dominantColor
        }
        return settings.accentColorPreset.primaryColor
    }

    private var centerNotchGapWidth: CGFloat {
        if useFloatingPillMode {
            return 28
        }
        let hw = targetScreen?.notchSize.width ?? 180
        return max(148, min(184, hw - 12))
    }

    public var body: some View {
        let islandSize = coordinator.currentIslandSize(for: targetScreen)
        let topPad: CGFloat = useFloatingPillMode ? 6 : 0
        let hoverScaleX: CGFloat = (coordinator.isHoveringIsland && coordinator.displayState != .expanded) ? 1.035 : 1.0
        let hoverScaleY: CGFloat = (coordinator.isHoveringIsland && coordinator.displayState != .expanded) ? 1.025 : 1.0

        ZStack(alignment: .top) {
            Color.clear

            if coordinator.displayState != .hidden {
                islandBody(size: islandSize)
                    .frame(width: islandSize.width, height: islandSize.height)
                    .background(islandBackground)
                    .clipShape(islandClipShape(for: islandSize))
                    .overlay(islandBorderOverlay(for: islandSize))
                    .scaleEffect(x: hoverScaleX, y: hoverScaleY, anchor: .top)
                    .shadow(
                        color: Color.black.opacity(coordinator.displayState == .expanded ? 0.52 : 0.38),
                        radius: coordinator.displayState == .expanded ? 24 : 12,
                        x: 0,
                        y: coordinator.displayState == .expanded ? 12 : 5
                    )
                    .padding(.top, topPad)
                    .animation(.spring(response: 0.28, dampingFraction: 0.68), value: coordinator.isHoveringIsland)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if coordinator.displayState == .quickPeek {
                            coordinator.expandIsland(to: coordinator.currentQuickPeek?.category)
                        } else if settings.expandOnClick && coordinator.displayState != .expanded {
                            coordinator.expandIsland()
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - State Switcher Content

    @ViewBuilder
    private func islandBody(size: CGSize) -> some View {
        switch coordinator.displayState {
        case .hidden:
            EmptyView()

        case .minimalIdle:
            minimalIdleView

        case .compactPill:
            compactPillView

        case .duoMode:
            duoModeView

        case .systemHUD:
            if let hud = coordinator.activeHUD {
                systemHUDView(hud)
            } else {
                compactPillView
            }

        case .quickPeek:
            if let peek = coordinator.currentQuickPeek {
                quickPeekView(peek)
            } else {
                compactPillView
            }

        case .locked:
            lockActivityView

        case .expanded:
            expandedPanelView
        }
    }

    // MARK: - 1. Minimal Idle View

    private var minimalIdleView: some View {
        HStack(spacing: 0) {
            if focus.isFocusActive {
                Image(systemName: focus.activeProfile.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(focus.activeProfile.tintColor)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 2. Compact Pill View

    private var compactPillView: some View {
        HStack(spacing: 0) {
            // Left Wing (to the left of the physical camera cutout)
            compactLeftWing(for: coordinator.primaryActivity)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Hardware Notch Center Cutout Space
            Spacer()
                .frame(width: centerNotchGapWidth)

            // Right Wing (to the right of the physical camera cutout)
            compactRightWing(for: coordinator.primaryActivity)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, useFloatingPillMode ? 14 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func compactLeftWing(for activity: IslandActivityKind) -> some View {
        switch activity {
        case .music:
            compactArtworkThumbnail(scale: 1.0)

        case .calendar:
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.23))
            }

        case .weather:
            let w = weather.currentWeather
            Image(systemName: w?.symbolName ?? "cloud.sun.fill")
                .font(.system(size: 12.5))
                .foregroundStyle(w?.symbolColor ?? Color(red: 0.98, green: 0.80, blue: 0.28))

        case .battery:
            Image(systemName: battery.state.symbolName)
                .font(.system(size: 12.5))
                .foregroundStyle(battery.state.statusColor)

        case .connectivity:
            Image(systemName: connectivity.primaryAudioDevice?.symbolName ?? "airpodspro")
                .font(.system(size: 12.5))
                .foregroundStyle(.white)

        default:
            Image(systemName: focus.isFocusActive ? focus.activeProfile.symbolName : "waveform")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(focus.isFocusActive ? focus.activeProfile.tintColor : activeAccent)
        }
    }

    @ViewBuilder
    private func compactRightWing(for activity: IslandActivityKind) -> some View {
        switch activity {
        case .music:
            ZStack {
                if isHoveringRightWing {
                    Button {
                        media.togglePlayPause()
                    } label: {
                        Image(systemName: media.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                } else if settings.showWaveform {
                    WaveformVisualizerView(
                        isPlaying: media.currentTrack.isPlaying,
                        style: settings.waveformStyle,
                        accentColor: activeAccent,
                        secondaryColor: activeAccent.opacity(0.55),
                        barCount: 4,
                        height: 15
                    )
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: media.currentTrack.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(activeAccent)
                }
            }
            .frame(width: 24, height: 22)
            .onHover { hovering in
                withAnimation(.spring(response: 0.24, dampingFraction: 0.76)) {
                    isHoveringRightWing = hovering
                }
            }

        case .calendar:
            if let ev = calendar.currentOrNextEvent {
                Text(ev.countdownText())
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color(red: 0.98, green: 0.62, blue: 0.28))
                    .lineLimit(1)
            } else if settings.enableWeather, let w = weather.currentWeather {
                Text(w.formattedTemperature(unit: settings.temperatureUnit))
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            } else {
                Text("Clear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

        case .weather:
            if let w = weather.currentWeather {
                Text(w.formattedTemperature(unit: settings.temperatureUnit))
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            } else {
                Text("72°")
                    .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
            }

        case .battery:
            Text("\(battery.state.percentage)%")
                .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(battery.state.statusColor)

        case .connectivity:
            let pct = Double(connectivity.primaryAudioDevice?.batteryPercentage ?? 92) / 100.0
            ZStack {
                Circle()
                    .stroke(Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.28), lineWidth: 2.2)
                    .frame(width: 16, height: 16)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(Color(red: 0.29, green: 0.87, blue: 0.50), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 16, height: 16)
            }

        default:
            Text(focus.isFocusActive ? focus.activeProfile.title : "")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
        }
    }

    private func compactArtworkThumbnail(scale: CGFloat) -> some View {
        let dimmed = settings.dimArtworkOnPause && !media.currentTrack.isPlaying
        return Group {
            if let img = media.currentTrack.artworkImage, settings.showAlbumArtwork {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 21, height: 21)
                    .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
                    .scaleEffect(dimmed ? 0.86 : scale)
                    .opacity(dimmed ? 0.62 : 1.0)
            } else {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .fill(activeAccent.opacity(0.28))
                    .frame(width: 21, height: 21)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(activeAccent)
                    )
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: media.currentTrack.isPlaying)
    }

    // MARK: - 3. Duo Mode View (Music on Left Wing + Calendar/Weather on Right Wing)

    private var duoModeView: some View {
        HStack(spacing: 0) {
            // Left Wing: Compact Music + Mini Waveform
            Button {
                coordinator.expandIsland(to: .music)
            } label: {
                HStack(spacing: 6) {
                    compactArtworkThumbnail(scale: 1.0)
                    WaveformVisualizerView(
                        isPlaying: media.currentTrack.isPlaying,
                        style: settings.waveformStyle,
                        accentColor: activeAccent,
                        secondaryColor: activeAccent.opacity(0.55),
                        barCount: 4,
                        height: 13
                    )
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center Camera Notch Gap
            Spacer()
                .frame(width: centerNotchGapWidth)

            // Right Wing: Secondary Activity (Calendar Countdown or Weather)
            Button {
                coordinator.expandIsland(to: coordinator.secondaryDuoActivity)
            } label: {
                if coordinator.secondaryDuoActivity == .calendar, let ev = calendar.currentOrNextEvent {
                    HStack(spacing: 4.5) {
                        Circle()
                            .fill(ev.color)
                            .frame(width: 5.5, height: 5.5)
                        Text(ev.countdownText())
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                    }
                } else if let w = weather.currentWeather {
                    HStack(spacing: 4.5) {
                        Image(systemName: w.symbolName)
                            .font(.system(size: 11.5))
                            .foregroundStyle(w.symbolColor)
                        Text(w.formattedTemperature(unit: settings.temperatureUnit))
                            .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color(red: 0.98, green: 0.80, blue: 0.28))
                        Text("72°")
                            .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, useFloatingPillMode ? 14 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 4. System HUD View (Horizontal Notch Wing Expansion — Matches `lh-1.png` 1:1!)

    private func systemHUDView(_ hud: SystemHUDPayload) -> some View {
        let prog = hud.progress ?? 0.75
        let iconSize: CGFloat = settings.hudScaleSymbolSize
            ? (13.0 + CGFloat(prog) * 3.5)
            : 14.5
        let barColor = hudBarFillColor(for: hud, progress: prog)
        let isGlow = settings.hudBarTheme == .glow

        return HStack(spacing: 0) {
            // Left Wing: Crisp Animated SF Symbol (+ Optional Label)
            HStack(spacing: 7) {
                Image(systemName: hud.symbolName)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(hud.kind == .mute ? Color(red: 0.96, green: 0.36, blue: 0.36) : .white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 22, height: 22)

                if !settings.hudHideLabel {
                    Text(hud.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Center Camera Notch Cutout Space
            Spacer()
                .frame(width: centerNotchGapWidth)

            // Right Wing: Sleek Thumb-less Pill Progress Bar or AirPods Ring
            HStack(spacing: 7) {
                if hud.kind == .connectivity || hud.kind == .audioOutput {
                    ZStack {
                        Circle()
                            .stroke(Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.28), lineWidth: 2.4)
                            .frame(width: 18, height: 18)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(1, max(0.08, prog))))
                            .stroke(
                                Color(red: 0.29, green: 0.87, blue: 0.50),
                                style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 18, height: 18)
                    }
                } else if hud.progress != nil {
                    GeometryReader { geo in
                        let clamped = CGFloat(min(1, max(0, prog)))
                        let fillW = max(6, geo.size.width * clamped)
                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(barColor.opacity(0.24))
                                .frame(height: 6.5)

                            Capsule(style: .continuous)
                                .fill(barColor)
                                .frame(width: fillW, height: 6.5)
                                .shadow(
                                    color: isGlow ? barColor.opacity(0.85) : .clear,
                                    radius: isGlow ? 7 : 0
                                )
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(width: settings.showHUDPercentageText ? 68 : 88, height: 12)
                }

                if settings.showHUDPercentageText, let valText = hud.valueText {
                    Text(valText)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                } else if hud.progress == nil, let sub = hud.valueText ?? hud.subtitle {
                    Text(sub)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(hud.tintColor)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, useFloatingPillMode ? 16 : 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hudBarFillColor(for hud: SystemHUDPayload, progress: Double) -> Color {
        if hud.kind == .batteryCharging || hud.kind == .batteryFull {
            return Color(red: 0.29, green: 0.87, blue: 0.50)
        }
        if hud.kind == .batteryLow {
            return Color(red: 0.96, green: 0.36, blue: 0.36)
        }
        switch settings.hudBarTheme {
        case .white:
            return .white
        case .accent:
            return activeAccent
        case .glow:
            if hud.kind == .volume && progress > 0.80 {
                return Color(red: 0.96, green: 0.42, blue: 0.32)
            }
            return Color(red: 0.95, green: 0.56, blue: 0.36)
        }
    }

    // MARK: - 5. QuickPeek Notification View (iOS / Alcove Marquee Drop-Down)

    private func quickPeekView(_ peek: QuickPeekNotification) -> some View {
        VStack(spacing: 0) {
            // Top Row Flanking the Hardware Notch
            HStack(spacing: 0) {
                if peek.category == .music {
                    compactArtworkThumbnail(scale: 1.14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Image(systemName: peek.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.98, green: 0.62, blue: 0.28))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
                    .frame(width: centerNotchGapWidth)

                if peek.category == .music {
                    WaveformVisualizerView(
                        isPlaying: media.currentTrack.isPlaying,
                        style: settings.waveformStyle,
                        accentColor: activeAccent,
                        secondaryColor: activeAccent.opacity(0.55),
                        barCount: 4,
                        height: 15
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else if let badge = peek.badgeText {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.16), in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(height: 36)
            .padding(.horizontal, 20)

            Spacer(minLength: 2)

            // Bottom Strip: Track / Event Marquee Line
            HStack(spacing: 5) {
                Image(systemName: peek.category == .music ? "music.note" : peek.symbolName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))

                Text(peek.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.90))
                    .lineLimit(1)

                if !peek.subtitle.isEmpty {
                    Text("∙")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.38))

                    Text(peek.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.08),
                        .init(color: .black, location: 0.92),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 6. Lock Screen / Unlock Transition View

    private var lockActivityView: some View {
        HStack(spacing: 0) {
            Image(systemName: lockScreen.isScreenLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
                .frame(width: centerNotchGapWidth)

            if !settings.hideSensitiveContentWhenLocked, let w = weather.currentWeather {
                HStack(spacing: 4) {
                    Image(systemName: w.symbolName)
                        .font(.system(size: 11))
                        .foregroundStyle(w.symbolColor)
                    Text(w.formattedTemperature(unit: settings.temperatureUnit))
                        .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.88))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Text(lockScreen.isScreenLocked ? "Locked" : "Unlocked")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 7. Expanded Panel View (Pure Apple Dynamic Island Studio — Zero Top Tab Clutter!)

    private var expandedPanelView: some View {
        ZStack(alignment: .bottom) {
            // Main Studio Content
            VStack(spacing: 0) {
                // Top clearance so content breathes naturally below the camera cutout
                Spacer()
                    .frame(height: useFloatingPillMode ? 18 : 24)

                Group {
                    switch coordinator.expandedTab {
                    case .music:
                        ExpandedMusicPlayerView()
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                                )
                            )
                    case .calendar:
                        ExpandedCalendarView()
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                                )
                            )
                    default:
                        ExpandedSystemDashboardView(selectedTab: coordinator.expandedTab)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()
                    .frame(height: 18)
            }
            .padding(.horizontal, 28)

            // Subtle Hover-Responsive Bottom Page Dots + Settings Gear
            HStack(spacing: 6) {
                Spacer()

                HStack(spacing: 5) {
                    pageDot(for: .music, help: "Now Playing")
                    pageDot(for: .calendar, help: "Calendar & Weather")
                    pageDot(for: .systemHUD, help: "System Controls")
                }
                .opacity(coordinator.isHoveringIsland ? 0.85 : 0.0)

                Spacer()
            }
            .overlay(alignment: .trailing) {
                if coordinator.isHoveringIsland {
                    HStack(spacing: 6) {
                        Button {
                            onOpenSettings()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        .buttonStyle(.plain)
                        .help("Open NotchFlow Settings")
                    }
                    .padding(.trailing, 24)
                    .transition(.opacity)
                }
            }
            .padding(.bottom, 7)
            .animation(.easeInOut(duration: 0.18), value: coordinator.isHoveringIsland)
        }
    }

    private func pageDot(for tab: IslandActivityKind, help: String) -> some View {
        let isSelected = (coordinator.expandedTab == tab) ||
            (tab == .systemHUD && [.weather, .battery, .connectivity, .focus, .systemHUD].contains(coordinator.expandedTab))

        return Button {
            coordinator.withIslandAnimation {
                coordinator.expandedTab = tab
                if tab == .music || tab == .calendar {
                    coordinator.primaryActivity = tab
                }
            }
        } label: {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.72 : 0.22))
                .frame(width: isSelected ? 14 : 5, height: 4.5)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Background, Clip Shape, and Optional Perimeter Rim

    @ViewBuilder
    private var islandBackground: some View {
        // Pure pitch-black hardware notch surface so the physical camera cutout disappears completely
        Color.black
    }

    private func islandClipShape(for size: CGSize) -> AnyShape {
        if useFloatingPillMode || settings.cornerStyle == .capsulePill {
            let r: CGFloat = (coordinator.displayState == .expanded) ? 32.0 : (size.height * 0.5)
            return AnyShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        } else {
            let topEar: CGFloat = (coordinator.displayState == .expanded) ? 16.0 : 10.0
            let bottomR: CGFloat
            switch coordinator.displayState {
            case .expanded:
                bottomR = 34.0
            case .quickPeek:
                bottomR = 20.0
            default:
                bottomR = 14.0
            }
            return AnyShape(NotchIslandShape(topShoulderRadius: topEar, bottomCornerRadius: bottomR))
        }
    }

    @ViewBuilder
    private func islandBorderOverlay(for size: CGSize) -> some View {
        if settings.showContrastOutline || settings.coloredOutline {
            let strokeColor: Color = settings.coloredOutline
                ? activeAccent.opacity(0.45)
                : Color.white.opacity(0.10)
            if useFloatingPillMode || settings.cornerStyle == .capsulePill {
                let r: CGFloat = (coordinator.displayState == .expanded) ? 32.0 : (size.height * 0.5)
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 0.75)
            } else {
                let topEar: CGFloat = (coordinator.displayState == .expanded) ? 16.0 : 10.0
                let bottomR: CGFloat = (coordinator.displayState == .expanded) ? 34.0 : 14.0
                NotchPerimeterStrokeShape(topShoulderRadius: topEar, bottomCornerRadius: bottomR)
                    .stroke(strokeColor, lineWidth: 0.75)
            }
        }
    }
}
