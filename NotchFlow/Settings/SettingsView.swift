import SwiftUI
import AppKit
import ApplicationServices

public enum SettingsSection: String, CaseIterable, Identifiable {
    // Top
    case general = "General"
    // Notifications
    case battery = "Battery"
    case connectivity = "Connectivity"
    case focus = "Focus"
    case display = "Display"
    case sound = "Sound"
    // Live Activities
    case nowPlaying = "Now Playing"
    case calendar = "Calendar"
    case weather = "Weather"
    case lockScreen = "Lock Screen"
    // NotchFlow
    case gestures = "Gestures"
    case permissions = "Permissions"
    case about = "About"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .battery: return "bolt.fill"
        case .connectivity: return "airpodspro"
        case .focus: return "moon.fill"
        case .display: return "sun.max.fill"
        case .sound: return "speaker.wave.2.fill"
        case .nowPlaying: return "play.fill"
        case .calendar: return "calendar"
        case .weather: return "cloud.sun.fill"
        case .lockScreen: return "lock.fill"
        case .gestures: return "hand.draw.fill"
        case .permissions: return "checkmark.shield.fill"
        case .about: return "info.circle.fill"
        }
    }

    public var badgeColor: Color {
        switch self {
        case .general: return Color(red: 0.56, green: 0.56, blue: 0.58)
        case .battery: return Color(red: 0.96, green: 0.56, blue: 0.22)
        case .connectivity: return Color(red: 0.18, green: 0.80, blue: 0.44)
        case .focus: return Color(red: 0.38, green: 0.42, blue: 0.94)
        case .display: return Color(red: 0.64, green: 0.36, blue: 0.96)
        case .sound: return Color(red: 0.94, green: 0.30, blue: 0.68)
        case .nowPlaying: return Color(red: 0.96, green: 0.28, blue: 0.36)
        case .calendar: return Color(red: 0.98, green: 0.38, blue: 0.24)
        case .weather: return Color(red: 0.24, green: 0.68, blue: 0.94)
        case .lockScreen: return Color(red: 0.16, green: 0.16, blue: 0.18)
        case .gestures: return Color(red: 0.24, green: 0.78, blue: 0.70)
        case .permissions: return Color(red: 0.20, green: 0.58, blue: 0.98)
        case .about: return Color(red: 0.56, green: 0.56, blue: 0.58)
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var coordinator = IslandCoordinator.shared
    @ObservedObject var calendarMgr = CalendarManager.shared
    @ObservedObject var weatherMgr = WeatherManager.shared
    @ObservedObject var mediaMgr = MediaManager.shared
    @ObservedObject var volumeMgr = VolumeManager.shared
    @ObservedObject var brightnessMgr = BrightnessManager.shared
    @ObservedObject var batteryMgr = BatteryManager.shared
    @ObservedObject var focusMgr = FocusManager.shared

    @State private var selectedSection: SettingsSection
    @State private var isAccessibilityTrusted: Bool = AXIsProcessTrusted()

    public var onOpenOnboarding: (() -> Void)?

    private let switchMint = Color(red: 0.24, green: 0.78, blue: 0.70)
    private let sidebarBg = Color(red: 0.21, green: 0.21, blue: 0.22)
    private let detailBg = Color(red: 0.23, green: 0.23, blue: 0.24)

    public init(initialSection: SettingsSection = .display, onOpenOnboarding: (() -> Void)? = nil) {
        self._selectedSection = State(initialValue: initialSection)
        self.onOpenOnboarding = onOpenOnboarding
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar (macOS Sequoia / Alcove Style)
            VStack(alignment: .leading, spacing: 2) {
                // Space for macOS Window Traffic Lights
                Spacer()
                    .frame(height: 36)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        sidebarRow(.general)

                        sidebarCategoryHeader("Notifications")
                        sidebarRow(.battery)
                        sidebarRow(.connectivity)
                        sidebarRow(.focus)
                        sidebarRow(.display)
                        sidebarRow(.sound)

                        sidebarCategoryHeader("Live Activities")
                        sidebarRow(.nowPlaying)
                        sidebarRow(.calendar)
                        sidebarRow(.weather)
                        sidebarRow(.lockScreen)

                        sidebarCategoryHeader("NotchFlow")
                        sidebarRow(.gestures)
                        sidebarRow(.permissions)
                        sidebarRow(.about)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                }
            }
            .frame(width: 196)
            .background(sidebarBg)

            // Hairline Vertical Divider
            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(width: 1)

            // Right Detail Pane
            VStack(spacing: 0) {
                // Top Detail Header Bar
                HStack(spacing: 10) {
                    squircleBadge(for: selectedSection, size: 22, iconSize: 11.5)

                    Text(selectedSection.rawValue)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    previewHeaderButton(for: selectedSection)
                }
                .padding(.horizontal, 20)
                .frame(height: 48)
                .background(detailBg)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionContent(for: selectedSection)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minWidth: 444, maxWidth: .infinity, maxHeight: .infinity)
            .background(detailBg)
        }
        .background(detailBg)
        .tint(switchMint)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar Helpers

    private func sidebarCategoryHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.42))
            .padding(.horizontal, 8)
            .padding(.top, 9)
            .padding(.bottom, 2)
    }

    private func sidebarRow(_ section: SettingsSection) -> some View {
        let isSelected = (selectedSection == section)

        return Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 9) {
                squircleBadge(for: section, size: 22, iconSize: 11)

                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 0.98 : 0.84))

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.11) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func squircleBadge(for section: SettingsSection, size: CGFloat, iconSize: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            section.badgeColor.opacity(0.95),
                            section.badgeColor.opacity(0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )

            Image(systemName: section.symbolName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func previewHeaderButton(for section: SettingsSection) -> some View {
        switch section {
        case .display:
            Button("Preview HUD") {
                brightnessMgr.emitBrightnessHUD()
            }
            .buttonStyle(HeaderPillButtonStyle())
        case .sound:
            Button("Preview HUD") {
                volumeMgr.emitVolumeHUD()
            }
            .buttonStyle(HeaderPillButtonStyle())
        case .battery:
            Button("Preview HUD") {
                coordinator.presentSystemHUD(
                    SystemHUDPayload(
                        kind: .batteryCharging,
                        title: "Charging",
                        subtitle: "\(batteryMgr.state.percentage)%",
                        symbolName: "battery.100percent.bolt",
                        progress: Double(batteryMgr.state.percentage) / 100.0,
                        valueText: "\(batteryMgr.state.percentage)%",
                        tintColorName: "green"
                    )
                )
            }
            .buttonStyle(HeaderPillButtonStyle())
        case .connectivity:
            Button("Preview AirPods") {
                coordinator.presentSystemHUD(
                    SystemHUDPayload(
                        kind: .connectivity,
                        title: "AirPods Pro",
                        subtitle: "Connected",
                        symbolName: "airpodspro",
                        progress: 0.92,
                        valueText: "92%",
                        tintColorName: "green"
                    )
                )
            }
            .buttonStyle(HeaderPillButtonStyle())
        case .focus:
            Button("Toggle Focus") {
                focusMgr.cycleFocusProfile()
            }
            .buttonStyle(HeaderPillButtonStyle())
        case .nowPlaying:
            Button("Open Player") {
                mediaMgr.loadInteractiveDemoTrack()
                coordinator.expandIsland(to: .music)
            }
            .buttonStyle(HeaderPillButtonStyle())
        case .calendar:
            Button("Open Calendar") {
                coordinator.expandIsland(to: .calendar)
            }
            .buttonStyle(HeaderPillButtonStyle())
        default:
            EmptyView()
        }
    }

    // MARK: - Section Router

    @ViewBuilder
    private func sectionContent(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            generalSection
        case .display:
            hudConfigurationSection(
                title: "Display",
                symbol: "sun.max.fill",
                symbolColor: Color(red: 0.64, green: 0.36, blue: 0.96),
                isEnabled: $settings.enableBrightnessHUD
            )
        case .sound:
            hudConfigurationSection(
                title: "Sound",
                symbol: "speaker.wave.2.fill",
                symbolColor: Color(red: 0.94, green: 0.30, blue: 0.68),
                isEnabled: $settings.enableVolumeHUD
            )
        case .battery:
            batterySection
        case .connectivity:
            connectivitySection
        case .focus:
            focusSection
        case .nowPlaying:
            nowPlayingSection
        case .calendar:
            calendarSection
        case .weather:
            weatherSection
        case .lockScreen:
            lockScreenSection
        case .gestures:
            gesturesSection
        case .permissions:
            permissionsSection
        case .about:
            aboutSection
        }
    }

    // MARK: - Shared HUD Customizer (Matches `lh-2.png` Display & Sound Panes 1:1!)

    private func hudConfigurationSection(
        title: String,
        symbol: String,
        symbolColor: Color,
        isEnabled: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Master Card
            SettingsCard {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(switchMint)
                        .frame(width: 20)
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Toggle("", isOn: isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            // HUDs Subheader Row
            HStack {
                Text("HUDs")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                Spacer()
                HStack(spacing: 8) {
                    Toggle("", isOn: isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.38))
                }
            }
            .padding(.horizontal, 4)

            // Main Visual HUD Customizer Card
            SettingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    // 1. Duration Slider Row
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Duration")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.white.opacity(0.90))
                            Spacer()
                            Text(String(format: "%.1f s", settings.hudDuration))
                                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.82))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }

                        Slider(value: $settings.hudDuration, in: 0.8...3.5, step: 0.1)
                            .tint(.white.opacity(0.45))
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    CardDivider()

                    // 2. Three Visual HUD Bar Theme Cards (White / Accent / Glow)
                    HStack(spacing: 12) {
                        ForEach(HUDBarTheme.allCases) { theme in
                            hudThemePreviewCard(theme)
                        }
                    }
                    .padding(.horizontal, 14)

                    CardDivider()

                    // 3. Three Visual Animation Speed Cards (Smooth / Fast / Instant)
                    HStack(spacing: 10) {
                        ForEach(AnimationSpeedPreset.allCases) { speed in
                            animationSpeedCard(speed)
                        }
                    }
                    .padding(.horizontal, 14)

                    CardDivider()

                    // 4. Show Percentage Switch Row
                    HStack {
                        Text("Show percentage")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.90))
                        Spacer()
                        Toggle("", isOn: $settings.showHUDPercentageText)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 14)

                    CardDivider()

                    // 5. Hide Label Switch Row
                    HStack {
                        Text("Hide label")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.90))
                        Spacer()
                        Toggle("", isOn: $settings.hudHideLabel)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 14)

                    CardDivider()

                    // 6. Symbol Scaling Visual Cards (Retain symbol size vs Scale symbol size)
                    HStack(spacing: 12) {
                        symbolScalingCard(
                            title: "Retain symbol size",
                            isSelected: !settings.hudScaleSymbolSize,
                            symbol: symbol,
                            scales: false
                        ) {
                            settings.hudScaleSymbolSize = false
                        }

                        symbolScalingCard(
                            title: "Scale symbol size",
                            isSelected: settings.hudScaleSymbolSize,
                            symbol: symbol,
                            scales: true
                        ) {
                            settings.hudScaleSymbolSize = true
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func hudThemePreviewCard(_ theme: HUDBarTheme) -> some View {
        let isSelected = (settings.hudBarTheme == theme)
        let barColor: Color = {
            switch theme {
            case .white: return .white
            case .accent: return switchMint
            case .glow: return .white
            }
        }()

        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                settings.hudBarTheme = theme
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.black)
                        .frame(height: 36)

                    // Simulated HUD Bar
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 72, height: 4.5)

                        Capsule(style: .continuous)
                            .fill(barColor)
                            .frame(width: 48, height: 4.5)
                            .shadow(
                                color: theme == .glow ? Color.white.opacity(0.95) : .clear,
                                radius: theme == .glow ? 6 : 0
                            )
                    }
                }
                .padding(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(isSelected ? switchMint : Color.white.opacity(0.10), lineWidth: isSelected ? 2.0 : 1.0)
                )

                Text(theme.title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.55))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func animationSpeedCard(_ speed: AnimationSpeedPreset) -> some View {
        let isSelected = (settings.animationSpeed == speed)

        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                settings.animationSpeed = speed
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 36)

                    Image(systemName: speed.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? switchMint : .white.opacity(0.55))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isSelected ? switchMint : Color.white.opacity(0.10), lineWidth: isSelected ? 2.0 : 1.0)
                )

                Text(speed.title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.55))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func symbolScalingCard(
        title: String,
        isSelected: Bool,
        symbol: String,
        scales: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 40)

                    if scales {
                        HStack(spacing: 8) {
                            Image(systemName: symbol)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isSelected ? switchMint : .white.opacity(0.55))
                            HStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle()
                                        .fill((isSelected ? switchMint : Color.white).opacity(0.35))
                                        .frame(width: 2.5, height: 2.5)
                                }
                            }
                            Image(systemName: symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isSelected ? switchMint : .white.opacity(0.55))
                        }
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(isSelected ? switchMint : .white.opacity(0.55))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isSelected ? switchMint : Color.white.opacity(0.10), lineWidth: isSelected ? 2.0 : 1.0)
                )

                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.55))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 1. General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("Enable NotchFlow Dynamic Island", isOn: $settings.isEnabled)
                    CardDivider()
                    settingsSwitchRow("Launch at Login", subtitle: settings.launchAtLoginSystemStatus, isOn: $settings.launchAtLogin)
                    CardDivider()
                    settingsSwitchRow("Show Icon in Menu Bar", isOn: $settings.showMenuBarIcon)
                    CardDivider()
                    settingsSwitchRow("Start Minimized in Background", isOn: $settings.startMinimized)
                    CardDivider()
                    settingsSwitchRow("Hide in Fullscreen Apps & Games", isOn: $settings.hideInFullscreen)
                }
                .padding(.vertical, 12)
            }

            // Island Hardware Mode Visual Selector
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Island Geometry & Display")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)

                    HStack(spacing: 12) {
                        islandModePreviewCard(
                            title: "MacBook Notch",
                            isNotched: true,
                            isSelected: settings.islandStyleMode != .simulatedPill
                        ) {
                            settings.islandStyleMode = .realNotch
                        }

                        islandModePreviewCard(
                            title: "Floating Pill",
                            isNotched: false,
                            isSelected: settings.islandStyleMode == .simulatedPill
                        ) {
                            settings.islandStyleMode = .simulatedPill
                        }
                    }
                    .padding(.horizontal, 14)

                    CardDivider()

                    HStack {
                        Text("Preferred Display")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.90))
                        Spacer()
                        Picker("", selection: $settings.preferredDisplayID) {
                            Text("Automatic (Primary Display)").tag("main")
                            Text("Built-in MacBook Display").tag("builtIn")
                            ForEach(NSScreen.screens, id: \.displayID) { screen in
                                Text(screen.displayLabel).tag(screen.persistentDisplayID)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 210)
                        .disabled(settings.showOnAllDisplays)
                    }
                    .padding(.horizontal, 14)

                    CardDivider()
                    settingsSwitchRow("Show on All Connected Displays", isOn: $settings.showOnAllDisplays)
                }
                .padding(.vertical, 12)
            }

            SettingsCard {
                HStack(spacing: 10) {
                    Button("Welcome Guide") {
                        onOpenOnboarding?()
                    }
                    .buttonStyle(SecondaryCardButtonStyle())

                    Button("Reposition Island") {
                        IslandWindowController.shared.rebuildPanels()
                    }
                    .buttonStyle(SecondaryCardButtonStyle())

                    Spacer()

                    Button("Reset Defaults") {
                        settings.resetToDefaults()
                    }
                    .buttonStyle(SecondaryCardButtonStyle(isDestructive: true))
                }
                .padding(12)
            }
        }
    }

    private func islandModePreviewCard(title: String, isNotched: Bool, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.34, green: 0.24, blue: 0.48),
                                    Color(red: 0.18, green: 0.16, blue: 0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 44)

                    if isNotched {
                        NotchIslandShape(topShoulderRadius: 6, bottomCornerRadius: 9)
                            .fill(Color.black)
                            .frame(width: 86, height: 18)
                    } else {
                        Capsule(style: .continuous)
                            .fill(Color.black)
                            .frame(width: 78, height: 15)
                            .padding(.top, 6)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isSelected ? switchMint : Color.white.opacity(0.10), lineWidth: isSelected ? 2.0 : 1.0)
                )

                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.55))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Battery Section

    private var batterySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("Battery Status & Low Battery HUD", isOn: $settings.enableBatteryHUD)
                    CardDivider()
                    settingsSwitchRow("Charger Connected / Disconnected Alert", isOn: $settings.enableChargingNotifications)
                    CardDivider()
                    settingsSwitchRow("Elastic Spring Overshoot", isOn: $settings.enableHUDOvershoot)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 3. Connectivity Section

    private var connectivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("AirPods & Bluetooth Connection HUD", isOn: $settings.enableConnectivityHUD)
                    CardDivider()
                    settingsSwitchRow("Audio Output Route Changes", isOn: $settings.enableAudioDeviceHUD)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 4. Focus Section

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("Focus & Do Not Disturb HUD", isOn: $settings.enableFocusHUD)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 5. Now Playing Section

    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("Enable Now Playing Live Activity", isOn: $settings.enableMusic)
                    CardDivider()
                    HStack {
                        Text("Media Source")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.90))
                        Spacer()
                        Picker("", selection: $settings.preferredMediaProvider) {
                            ForEach(MediaProviderPreference.allCases) { p in
                                Text(p.title).tag(p)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    .padding(.horizontal, 14)
                    CardDivider()
                    HStack {
                        Text("Color Accent")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.90))
                        Spacer()
                        Picker("", selection: $settings.accentColorPreset) {
                            ForEach(AccentColorPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.vertical, 12)
            }

            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("Show Album Artwork", isOn: $settings.showAlbumArtwork)
                    CardDivider()
                    settingsSwitchRow("Dim & Shrink Artwork When Paused", isOn: $settings.dimArtworkOnPause)
                    CardDivider()
                    settingsSwitchRow("Show Reactive Audio Waveform", isOn: $settings.showWaveform)
                    CardDivider()
                    settingsSwitchRow("Show Lossless, Dolby Atmos & Explicit Badges", isOn: $settings.showAudioFormatBadges)
                    CardDivider()
                    settingsSwitchRow("Duo Mode (Split Music + Calendar/Weather)", isOn: $settings.enableDuoMode)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 6. Calendar Section

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("Enable Calendar Live Activity", isOn: $settings.enableCalendar)
                    CardDivider()
                    settingsSwitchRow("Show Live Countdown to Next Meeting", isOn: $settings.showEventCountdown)
                    CardDivider()
                    settingsSwitchRow("One-Click Join Button (Zoom, Meet, Teams, FaceTime)", isOn: $settings.showMeetingJoinButton)
                    CardDivider()
                    settingsSwitchRow("Exclude Subscribed Calendars", isOn: $settings.excludeSubscribedCalendars)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 7. Weather Section

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("Enable Weather Integration", isOn: $settings.enableWeather)
                    CardDivider()
                    HStack {
                        Text("Temperature Unit")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.90))
                        Spacer()
                        Picker("", selection: $settings.temperatureUnit) {
                            ForEach(TemperatureUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }
                    .padding(.horizontal, 14)
                    CardDivider()
                    HStack(spacing: 8) {
                        Text("Custom City")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.90))
                        Spacer()
                        TextField("Automatic", text: $settings.customWeatherCity)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .onSubmit {
                                Task { await weatherMgr.refreshWeather(force: true) }
                            }
                        Button("Update") {
                            Task { await weatherMgr.refreshWeather(force: true) }
                        }
                        .buttonStyle(SecondaryCardButtonStyle())
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 8. Lock Screen Section

    private var lockScreenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("Lock & Unlock Notch Animation", isOn: $settings.enableLockScreenAnimation)
                    CardDivider()
                    settingsSwitchRow("Hide Sensitive Calendar Titles While Locked", isOn: $settings.hideSensitiveContentWhenLocked)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 9. Gestures Section

    private var gesturesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                VStack(spacing: 12) {
                    settingsSwitchRow("Expand Island on Cursor Hover", isOn: $settings.expandOnHover)
                    CardDivider()
                    settingsSwitchRow("Expand or Collapse on Click", isOn: $settings.expandOnClick)
                    CardDivider()
                    settingsSwitchRow("Dismiss When Clicking Outside", isOn: $settings.clickOutsideToDismiss)
                    CardDivider()
                    settingsSwitchRow("Two-Finger Trackpad Swipes", isOn: $settings.enableSwipeGestures)
                    CardDivider()
                    settingsSwitchRow("Natural Horizontal Swipe Direction", isOn: $settings.naturalSwipeDirection)
                }
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 10. Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            permissionCard(
                title: "Calendars (EventKit)",
                subtitle: calendarMgr.permissionStatusLabel,
                isGranted: calendarMgr.hasCalendarAccess,
                actionTitle: calendarMgr.hasCalendarAccess ? "Open Settings" : "Grant Access"
            ) {
                Task {
                    if !calendarMgr.hasCalendarAccess {
                        let ok = await calendarMgr.requestAccess()
                        if !ok, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            permissionCard(
                title: "Location Services (Weather)",
                subtitle: weatherMgr.permissionStatusLabel,
                isGranted: weatherMgr.authorizationStatus == .authorized || weatherMgr.authorizationStatus == .authorizedAlways,
                actionTitle: "Request Location"
            ) {
                weatherMgr.requestLocationPermission()
            }

            permissionCard(
                title: "Media Automation (Apple Music & Spotify)",
                subtitle: "Prompted automatically when controlling playback",
                isGranted: true,
                actionTitle: "Automation Settings"
            ) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func permissionCard(
        title: String,
        subtitle: String,
        isGranted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        SettingsCard {
            HStack(spacing: 12) {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isGranted ? switchMint : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryCardButtonStyle())
            }
            .padding(14)
        }
    }

    // MARK: - 11. About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("NotchFlow")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Version 1.1.0 • Native macOS Dynamic Island")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.58))
                        Text("100% Free & Open Source (MIT License) • Zero Telemetry")
                            .font(.system(size: 11))
                            .foregroundStyle(switchMint)
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
    }

    // MARK: - Reusable Row Helpers

    private func settingsSwitchRow(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.90))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Reusable Native macOS Settings Card Components

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.75)
            )
    }
}

private struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
            .padding(.horizontal, 14)
    }
}

private struct HeaderPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10))
            )
    }
}

private struct SecondaryCardButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isDestructive ? Color(red: 0.98, green: 0.42, blue: 0.42) : .white.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.15 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
    }
}
