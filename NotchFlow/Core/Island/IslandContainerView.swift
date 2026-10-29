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
            return !(targetScreen?.hasPhysicalNotch ?? false)
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
            return 12
        }
        let hw = targetScreen?.notchSize.width ?? 184
        return max(150, hw - 8)
    }

    public var body: some View {
        let islandSize = coordinator.currentIslandSize(for: targetScreen)
        let topPad: CGFloat = useFloatingPillMode ? 6 : 0

        ZStack(alignment: .top) {
            Color.clear

            if coordinator.displayState != .hidden {
                islandBody(size: islandSize)
                    .frame(width: islandSize.width, height: islandSize.height)
                    .background(islandBackground)
                    .clipShape(islandClipShape(for: islandSize))
                    .overlay(islandBorderOverlay(for: islandSize))
                    .shadow(
                        color: Color.black.opacity(coordinator.displayState == .expanded ? 0.55 : 0.35),
                        radius: coordinator.displayState == .expanded ? 22 : 10,
                        x: 0,
                        y: coordinator.displayState == .expanded ? 10 : 4
                    )
                    .padding(.top, topPad)
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
        HStack(spacing: 8) {
            Circle()
                .fill(activeAccent.opacity(0.85))
                .frame(width: 6, height: 6)

            Spacer(minLength: useFloatingPillMode ? 24 : centerNotchGapWidth)

            if focus.isFocusActive {
                Image(systemName: focus.activeProfile.symbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(focus.activeProfile.tintColor)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, useFloatingPillMode ? 14 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 2. Compact Pill View

    private var compactPillView: some View {
        HStack(spacing: 0) {
            // Left Wing
            compactLeftWing(for: coordinator.primaryActivity)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Hardware Notch Center Spacer
            Spacer()
                .frame(width: centerNotchGapWidth)

            // Right Wing
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
            HStack(spacing: 6) {
                compactArtworkThumbnail
                if useFloatingPillMode {
                    Text(media.currentTrack.hasActiveTrack ? media.currentTrack.title : "Music")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }

        case .calendar:
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.orange)
                if useFloatingPillMode, let ev = calendar.currentOrNextEvent {
                    Text(ev.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }

        case .weather:
            HStack(spacing: 5) {
                let w = weather.currentWeather
                Image(systemName: w?.symbolName ?? "cloud.sun.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(w?.symbolColor ?? .yellow)
                if useFloatingPillMode, let w {
                    Text(w.conditionDescription)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }

        case .battery:
            HStack(spacing: 5) {
                Image(systemName: battery.state.symbolName)
                    .font(.system(size: 12))
                    .foregroundStyle(battery.state.statusColor)
            }

        case .connectivity:
            HStack(spacing: 5) {
                Image(systemName: connectivity.primaryAudioDevice?.symbolName ?? "airpodspro")
                    .font(.system(size: 12))
                    .foregroundStyle(activeAccent)
            }

        default:
            HStack(spacing: 5) {
                Image(systemName: focus.isFocusActive ? focus.activeProfile.symbolName : "waveform")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(focus.isFocusActive ? focus.activeProfile.tintColor : activeAccent)
            }
        }
    }

    @ViewBuilder
    private func compactRightWing(for activity: IslandActivityKind) -> some View {
        switch activity {
        case .music:
            if focus.isFocusActive && !media.currentTrack.isPlaying {
                Image(systemName: focus.activeProfile.symbolName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(focus.activeProfile.tintColor)
            } else if settings.showWaveform {
                WaveformVisualizerView(
                    isPlaying: media.currentTrack.isPlaying,
                    style: settings.waveformStyle,
                    accentColor: activeAccent,
                    barCount: 4,
                    height: 14
                )
            } else {
                Image(systemName: media.currentTrack.isPlaying ? "Pause" : "play.fill")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(activeAccent)
            }

        case .calendar:
            if let ev = calendar.currentOrNextEvent {
                Text(ev.countdownText())
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } else if settings.enableWeather, let w = weather.currentWeather {
                Text(w.formattedTemperature(unit: settings.temperatureUnit))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Text("Free")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

        case .weather:
            if let w = weather.currentWeather {
                Text(w.formattedTemperature(unit: settings.temperatureUnit))
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Text("--°")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }

        case .battery:
            Text("\(battery.state.percentage)%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(battery.state.statusColor)

        case .connectivity:
            Text(connectivity.primaryAudioDevice?.batteryPercentage.map { "\($0)%" } ?? "Audio")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

        default:
            Text(focus.isFocusActive ? focus.activeProfile.title : "Ready")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
        }
    }

    private var compactArtworkThumbnail: some View {
        Group {
            if let img = media.currentTrack.artworkImage, settings.showAlbumArtwork {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(activeAccent.opacity(0.28))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(activeAccent)
                    )
            }
        }
    }

    // MARK: - 3. Duo Mode View (Music + Calendar/Weather Split View)

    private var duoModeView: some View {
        HStack(spacing: 0) {
            // Left Wing: Compact Music + Waveform
            Button {
                coordinator.expandIsland(to: .music)
            } label: {
                HStack(spacing: 6) {
                    compactArtworkThumbnail
                    WaveformVisualizerView(
                        isPlaying: media.currentTrack.isPlaying,
                        style: settings.waveformStyle,
                        accentColor: activeAccent,
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
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ev.color)
                            .frame(width: 5, height: 5)
                        Text(ev.countdownText())
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                } else if let w = weather.currentWeather {
                    HStack(spacing: 4) {
                        Image(systemName: w.symbolName)
                            .font(.system(size: 11))
                            .foregroundStyle(w.symbolColor)
                        Text(w.formattedTemperature(unit: settings.temperatureUnit))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: battery.state.symbolName)
                            .font(.system(size: 11))
                            .foregroundStyle(battery.state.statusColor)
                        Text("\(battery.state.percentage)%")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, useFloatingPillMode ? 14 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 4. System HUD View

    private func systemHUDView(_ hud: SystemHUDPayload) -> some View {
        VStack(spacing: 4) {
            if !useFloatingPillMode {
                Spacer(minLength: max(18, (targetScreen?.notchSize.height ?? 30) - 8))
            }

            HStack(spacing: 10) {
                Image(systemName: hud.symbolName)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(hud.tintColor)
                    .frame(width: 20)

                Text(hud.title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 6)

                if let prog = hud.progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                                .frame(height: 5.5)
                            Capsule()
                                .fill(hud.tintColor)
                                .frame(width: max(4, geo.size.width * CGFloat(min(1, max(0, prog)))), height: 5.5)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    .frame(width: 78, height: 10)
                }

                if settings.showHUDPercentageText, let valText = hud.valueText {
                    Text(valText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(hud.tintColor)
                        .frame(minWidth: 34, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, useFloatingPillMode ? 0 : 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 5. QuickPeek Notification View

    private func quickPeekView(_ peek: QuickPeekNotification) -> some View {
        VStack(spacing: 4) {
            if !useFloatingPillMode {
                Spacer(minLength: max(20, (targetScreen?.notchSize.height ?? 30) - 6))
            }

            HStack(spacing: 10) {
                if peek.category == .music, let art = media.currentTrack.artworkImage {
                    Image(nsImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else {
                    ZStack {
                        Circle()
                            .fill(activeAccent.opacity(0.2))
                            .frame(width: 28, height: 28)
                        Image(systemName: peek.symbolName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(activeAccent)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(peek.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(peek.subtitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if let badge = peek.badgeText {
                    Text(badge)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(activeAccent, in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, useFloatingPillMode ? 0 : 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 6. Lock Screen / Unlock Transition View

    private var lockActivityView: some View {
        HStack(spacing: 10) {
            Image(systemName: lockScreen.isScreenLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(lockScreen.isScreenLocked ? .orange : .green)

            Text(lockScreen.isScreenLocked ? "Mac Locked" : "Unlocked")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            if !settings.hideSensitiveContentWhenLocked, let w = weather.currentWeather {
                HStack(spacing: 4) {
                    Image(systemName: w.symbolName)
                        .font(.system(size: 11))
                        .foregroundStyle(w.symbolColor)
                    Text(w.formattedTemperature(unit: settings.temperatureUnit))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 7. Expanded Panel View

    private var expandedPanelView: some View {
        VStack(spacing: 10) {
            // Top Header Bar (clears physical camera notch in the center!)
            HStack(spacing: 8) {
                // Left Activity Switcher Pills
                HStack(spacing: 4) {
                    expandedTabButton(.music, icon: "waveform", label: "Music")
                    expandedTabButton(.calendar, icon: "calendar", label: "Schedule")
                }

                Spacer(minLength: useFloatingPillMode ? 12 : centerNotchGapWidth * 0.72)

                // Right Activity Switcher + Settings + Collapse
                HStack(spacing: 5) {
                    expandedTabButton(.systemHUD, icon: "slider.horizontal.3", label: "Control")

                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Open NotchFlow Settings")

                    Button {
                        coordinator.collapseIsland()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Collapse Island")
                }
            }
            .padding(.top, useFloatingPillMode ? 10 : 8)

            // Main Expanded Content Area
            Group {
                switch coordinator.expandedTab {
                case .music:
                    ExpandedMusicPlayerView()
                case .calendar:
                    ExpandedCalendarView()
                default:
                    ExpandedSystemDashboardView(selectedTab: coordinator.expandedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private func expandedTabButton(_ tab: IslandActivityKind, icon: String, label: String) -> some View {
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
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.72))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isSelected ? activeAccent : Color.white.opacity(0.08),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background, Clip Shape, and Contrast Outline

    @ViewBuilder
    private var islandBackground: some View {
        switch settings.appearanceTheme {
        case .darkOnly:
            Color(red: 0.02, green: 0.02, blue: 0.03)
        case .adaptiveGlass:
            ZStack {
                Color.black.opacity(0.84)
                LinearGradient(
                    colors: [activeAccent.opacity(0.10), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        case .system:
            Color(red: 0.04, green: 0.04, blue: 0.06)
        }
    }

    private func islandClipShape(for size: CGSize) -> AnyShape {
        if useFloatingPillMode || settings.cornerStyle == .capsulePill {
            let r = (coordinator.displayState == .expanded) ? 26.0 : (size.height * 0.5)
            return AnyShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        } else if settings.cornerStyle == .classicNotch {
            let bottomR: CGFloat = (coordinator.displayState == .expanded) ? 24.0 : 15.0
            return AnyShape(NotchIslandShape(topShoulderRadius: 9, bottomCornerRadius: bottomR))
        } else {
            let r: CGFloat = (coordinator.displayState == .expanded) ? 24.0 : 16.0
            return AnyShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: r,
                    bottomTrailingRadius: r,
                    topTrailingRadius: 4,
                    style: .continuous
                )
            )
        }
    }

    @ViewBuilder
    private func islandBorderOverlay(for size: CGSize) -> some View {
        if settings.showContrastOutline || settings.coloredOutline {
            let strokeColor: Color = settings.coloredOutline
                ? activeAccent.opacity(0.55)
                : Color.white.opacity(0.14)
            islandClipShape(for: size)
                .stroke(
                    LinearGradient(
                        colors: [
                            strokeColor.opacity(useFloatingPillMode ? 0.8 : 0.2),
                            strokeColor,
                            strokeColor.opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: settings.coloredOutline ? 1.5 : 1.0
                )
        }
    }
}
