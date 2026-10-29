import SwiftUI
import AppKit
import ApplicationServices

public enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case behavior = "Behavior"
    case music = "Music & Media"
    case calendarWeather = "Calendar & Weather"
    case systemHUDs = "System HUDs"
    case permissions = "Permissions"
    case about = "About"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .behavior: return "hand.tap.fill"
        case .music: return "waveform.circle.fill"
        case .calendarWeather: return "calendar.badge.clock"
        case .systemHUDs: return "slider.horizontal.below.rectangle"
        case .permissions: return "lock.shield.fill"
        case .about: return "info.circle.fill"
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

    @State private var selectedSection: SettingsSection = .general
    @State private var isAccessibilityTrusted: Bool = AXIsProcessTrusted()

    public var onOpenOnboarding: (() -> Void)?

    public init(onOpenOnboarding: (() -> Void)? = nil) {
        self.onOpenOnboarding = onOpenOnboarding
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            VStack(alignment: .leading, spacing: 10) {
                // Brand Header
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("NotchFlow")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Dynamic Island for Mac")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 4)

                // Section Navigation Buttons
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SettingsSection.allCases) { section in
                        let isSelected = (selectedSection == section)
                        let accent = settings.accentColorPreset.primaryColor

                        Button {
                            selectedSection = section
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: section.symbolName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(isSelected ? .black : accent)
                                    .frame(width: 20)

                                Text(section.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? .black : .white.opacity(0.88))

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected
                                    ? accent
                                    : Color.white.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)

                Spacer()

                // Quick Island State Bar at Bottom of Sidebar
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable NotchFlow", isOn: $settings.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Button("Expand") {
                            coordinator.toggleExpandCollapse()
                        }
                        .controlSize(.small)

                        Button("Cycle Widget") {
                            coordinator.cycleActivity()
                        }
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .frame(width: 220)
            .background(Color(red: 0.06, green: 0.07, blue: 0.10))

            Divider()
                .background(Color.white.opacity(0.12))

            // Right Detail Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionHeader(selectedSection)
                    sectionDetailContent(selectedSection)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 540, minHeight: 500)
            .background(Color(red: 0.09, green: 0.10, blue: 0.14))
        }
        .preferredColorScheme(.dark)
    }

    private func sectionHeader(_ section: SettingsSection) -> some View {
        HStack(spacing: 10) {
            Image(systemName: section.symbolName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(settings.accentColorPreset.primaryColor)
                .frame(width: 34, height: 34)
                .background(settings.accentColorPreset.primaryColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(section.rawValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(sectionSubtitle(for: section))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func sectionSubtitle(for section: SettingsSection) -> String {
        switch section {
        case .general: return "Configure startup behavior, display placement, and menu bar preferences."
        case .appearance: return "Customize notch geometry, animations, accent colors, and visual themes."
        case .behavior: return "Fine-tune hover, click, swipe gestures, Duo Mode, and auto-dismiss timing."
        case .music: return "Configure Now Playing providers, album art effects, and live waveforms."
        case .calendarWeather: return "Manage EventKit calendars, meeting countdowns, and local weather."
        case .systemHUDs: return "Customize and test Dynamic Island HUDs for volume, brightness, battery, and audio."
        case .permissions: return "Inspect macOS system permissions and open System Settings panes."
        case .about: return "Version information, open-source license, privacy policy, and credits."
        }
    }

    @ViewBuilder
    private func sectionDetailContent(_ section: SettingsSection) -> some View {
        switch section {
        case .general:
            generalSection
        case .appearance:
            appearanceSection
        case .behavior:
            behaviorSection
        case .music:
            musicSection
        case .calendarWeather:
            calendarWeatherSection
        case .systemHUDs:
            systemHUDsSection
        case .permissions:
            permissionsSection
        case .about:
            aboutSection
        }
    }

    // MARK: - 1. General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Application & Startup") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable NotchFlow Dynamic Island", isOn: $settings.isEnabled)
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle("Launch NotchFlow at Login", isOn: $settings.launchAtLogin)
                            Text("System Status: \(settings.launchAtLoginSystemStatus)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Divider()
                    Toggle("Show NotchFlow Icon in Menu Bar", isOn: $settings.showMenuBarIcon)
                    Divider()
                    Toggle("Start Minimized in Background on Launch", isOn: $settings.startMinimized)
                }
                .padding(8)
            }

            GroupBox("Display & Multi-Monitor Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Preferred Display", selection: $settings.preferredDisplayID) {
                        Text("Automatic (Notched or Main Display)").tag("main")
                        Text("Built-in MacBook Display").tag("builtIn")
                        ForEach(NSScreen.screens, id: \.displayID) { screen in
                            Text(screen.displayLabel).tag(screen.persistentDisplayID)
                        }
                    }
                    .disabled(settings.showOnAllDisplays)

                    Divider()
                    Toggle("Show Dynamic Island on All Connected Displays", isOn: $settings.showOnAllDisplays)
                }
                .padding(8)
            }

            GroupBox("Quick Actions") {
                HStack(spacing: 12) {
                    Button("Re-run Welcome Onboarding...") {
                        onOpenOnboarding?()
                    }
                    Button("Reposition Island Panels") {
                        IslandWindowController.shared.rebuildPanels()
                    }
                    Spacer()
                    Button("Reset All Settings to Defaults", role: .destructive) {
                        settings.resetToDefaults()
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - 2. Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Island Mode & Geometry") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Island Shape Mode", selection: $settings.islandStyleMode) {
                        ForEach(IslandStyleMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Picker("Corner Styling", selection: $settings.cornerStyle) {
                        ForEach(IslandCornerStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }

                    Picker("Idle Visibility", selection: $settings.idleVisibility) {
                        ForEach(IdleVisibilityMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Divider()

                    HStack {
                        Text("Compact Width Fine-Tune")
                        Spacer()
                        Slider(value: $settings.compactWidthAdjustment, in: -30...60, step: 2)
                            .frame(width: 200)
                        Text("\(Int(settings.compactWidthAdjustment)) pt")
                            .font(.caption.monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }

                    HStack {
                        Text("Compact Height Fine-Tune")
                        Spacer()
                        Slider(value: $settings.compactHeightAdjustment, in: -4...14, step: 1)
                            .frame(width: 200)
                        Text("\(Int(settings.compactHeightAdjustment)) pt")
                            .font(.caption.monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }

                    HStack {
                        Text("Expanded Panel Scale")
                        Spacer()
                        Slider(value: $settings.expandedScale, in: 0.90...1.15, step: 0.05)
                            .frame(width: 200)
                        Text("\(Int(settings.expandedScale * 100))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                .padding(8)
            }

            GroupBox("Colors, Theme & Outlines") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Island Surface Theme", selection: $settings.appearanceTheme) {
                        ForEach(AppearanceThemeMode.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }

                    Picker("Accent Color Preset", selection: $settings.accentColorPreset) {
                        ForEach(AccentColorPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    Divider()
                    Toggle("Show Subtle Contrast Rim Outline", isOn: $settings.showContrastOutline)
                    Toggle("Tint Rim Outline with Active Accent Color", isOn: $settings.coloredOutline)
                }
                .padding(8)
            }

            GroupBox("Motion & Animation") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Animation Speed", selection: $settings.animationSpeed) {
                        ForEach(AnimationSpeedPreset.allCases) { speed in
                            Text(speed.title).tag(speed)
                        }
                    }
                    Toggle("Respect macOS Reduce Motion Accessibility Setting", isOn: $settings.respectReduceMotion)
                }
                .padding(8)
            }
        }
    }

    // MARK: - 3. Behavior Section

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Mouse & Hover Interactions") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Expand Dynamic Island on Cursor Hover", isOn: $settings.expandOnHover)

                    if settings.expandOnHover {
                        HStack {
                            Text("Hover Expansion Delay")
                            Spacer()
                            Slider(value: $settings.hoverDelay, in: 0.05...0.75, step: 0.05)
                                .frame(width: 200)
                            Text(String(format: "%.2fs", settings.hoverDelay))
                                .font(.caption.monospacedDigit())
                                .frame(width: 48, alignment: .trailing)
                        }
                    }

                    Divider()
                    Toggle("Expand or Collapse on Click", isOn: $settings.expandOnClick)
                    Toggle("Dismiss Expanded Panel When Clicking Outside", isOn: $settings.clickOutsideToDismiss)

                    HStack {
                        Text("Auto-Collapse Delay After Cursor Leaves")
                        Spacer()
                        Slider(value: $settings.autoDismissDelay, in: 1.5...10.0, step: 0.5)
                            .frame(width: 200)
                        Text(String(format: "%.1fs", settings.autoDismissDelay))
                            .font(.caption.monospacedDigit())
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                .padding(8)
            }

            GroupBox("Trackpad Gestures & Multitasking") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Two-Finger Trackpad Swipe Gestures", isOn: $settings.enableSwipeGestures)
                    Toggle("Natural Swipe Direction for Track Skipping", isOn: $settings.naturalSwipeDirection)
                    Divider()

                    Picker("Middle-Click Action", selection: $settings.middleClickAction) {
                        ForEach(MiddleClickAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }

                    Divider()
                    Toggle("Enable Duo Mode (Show Music + Calendar/Weather Simultaneously)", isOn: $settings.enableDuoMode)

                    Picker("Preferred Default Compact Activity", selection: $settings.preferredIdleActivity) {
                        Text("Now Playing (Music)").tag(IslandActivityKind.music)
                        Text("Calendar Countdown").tag(IslandActivityKind.calendar)
                        Text("Local Weather").tag(IslandActivityKind.weather)
                        Text("Battery Status").tag(IslandActivityKind.battery)
                        Text("Minimal Indicator").tag(IslandActivityKind.minimal)
                    }
                    .onChange(of: settings.preferredIdleActivity) { _, newValue in
                        coordinator.primaryActivity = newValue
                        coordinator.recalculateRestingState()
                    }

                    Divider()
                    Toggle("Automatically Hide Island in Fullscreen Apps / Games", isOn: $settings.hideInFullscreen)
                }
                .padding(8)
            }
        }
    }

    // MARK: - 4. Music Section

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Now Playing & Media Sources") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Music & Now Playing Activity", isOn: $settings.enableMusic)

                    Picker("Preferred Media Provider", selection: $settings.preferredMediaProvider) {
                        ForEach(MediaProviderPreference.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }

                    Picker("Expanded Player Layout", selection: $settings.expandedPlayerLayout) {
                        ForEach(ExpandedPlayerLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Visuals, Artwork & Waveform") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show Album Artwork", isOn: $settings.showAlbumArtwork)
                    Toggle("Ambient Artwork Glow Effect", isOn: $settings.artworkGlowEffect)
                    Toggle("Dim & Shrink Artwork When Paused", isOn: $settings.dimArtworkOnPause)
                    Divider()
                    Toggle("Show Reactive Audio Waveform", isOn: $settings.showWaveform)

                    Picker("Waveform Style", selection: $settings.waveformStyle) {
                        ForEach(WaveformVisualStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }

                    Divider()
                    Toggle("Show Playback Transport Controls", isOn: $settings.showPlaybackControls)
                    Toggle("Show Audio Quality & Format Badges (Lossless, Dolby Atmos, Explicit)", isOn: $settings.showAudioFormatBadges)
                }
                .padding(8)
            }

            GroupBox("Interactive Player Preview") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Test Now Playing in the Dynamic Island")
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("Loads sample metadata or refreshes Apple Music / Spotify immediately.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Load Demo Track") {
                        mediaMgr.loadInteractiveDemoTrack()
                        coordinator.expandIsland(to: .music)
                    }
                    Button("Refresh Player") {
                        Task { await mediaMgr.refreshNowPlaying() }
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - 5. Calendar & Weather Section

    private var calendarWeatherSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Calendar & Schedule (EventKit)") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Calendar Integration", isOn: $settings.enableCalendar)
                    Toggle("Show Live Countdown to Next Meeting", isOn: $settings.showEventCountdown)
                    Toggle("Show One-Click Join Button for Video Calls (Zoom, Meet, Teams)", isOn: $settings.showMeetingJoinButton)
                    Toggle("Exclude Subscribed Calendars", isOn: $settings.excludeSubscribedCalendars)
                        .onChange(of: settings.excludeSubscribedCalendars) { _, _ in
                            calendarMgr.refreshAll()
                        }
                    Toggle("Include Declined Events", isOn: $settings.showDeclinedEvents)
                        .onChange(of: settings.showDeclinedEvents) { _, _ in
                            calendarMgr.refreshAll()
                        }

                    Divider()

                    HStack {
                        Text("Calendar Permission: \(calendarMgr.permissionStatusLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !calendarMgr.hasCalendarAccess {
                            Button("Grant Calendar Access") {
                                Task { _ = await calendarMgr.requestAccess() }
                            }
                            .controlSize(.small)
                        } else {
                            Button("Refresh Events") {
                                calendarMgr.refreshAll()
                            }
                            .controlSize(.small)
                        }
                    }

                    if !calendarMgr.availableCalendars.isEmpty {
                        Divider()
                        Text("Visible Calendars (Leave all checked to show all):")
                            .font(.caption.weight(.semibold))
                        ForEach(calendarMgr.availableCalendars) { cal in
                            let isSelected = settings.selectedCalendarIDs.isEmpty || settings.selectedCalendarIDs.contains(cal.id)
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(cal.color)
                                    .frame(width: 8, height: 8)
                                Toggle("\(cal.title) (\(cal.sourceTitle))", isOn: Binding(
                                    get: { isSelected },
                                    set: { enabled in
                                        var current = settings.selectedCalendarIDs.isEmpty
                                            ? calendarMgr.availableCalendars.map { $0.id }
                                            : settings.selectedCalendarIDs
                                        if enabled {
                                            if !current.contains(cal.id) { current.append(cal.id) }
                                        } else {
                                            current.removeAll { $0 == cal.id }
                                        }
                                        settings.selectedCalendarIDs = current
                                        calendarMgr.refreshAll()
                                    }
                                ))
                            }
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Weather Integration") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Weather Widget", isOn: $settings.enableWeather)
                    Toggle("Show Weather Summary on Empty Calendar Days", isOn: $settings.showWeatherOnEmptyCalendarDay)

                    Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                        ForEach(TemperatureUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }

                    HStack {
                        Text("Custom City (Optional):")
                        TextField("Automatic (Current Location / Timezone)", text: $settings.customWeatherCity)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                Task { await weatherMgr.refreshWeather(force: true) }
                            }
                        Button("Update") {
                            Task { await weatherMgr.refreshWeather(force: true) }
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - 6. System HUDs Section

    private var systemHUDsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("System Event HUD Toggles") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Volume & Mute HUD", isOn: $settings.enableVolumeHUD)
                    Toggle("Display Brightness HUD", isOn: $settings.enableBrightnessHUD)
                    Toggle("Battery Level & Low Power Mode HUD", isOn: $settings.enableBatteryHUD)
                    Toggle("Charger Connected / Disconnected HUD", isOn: $settings.enableChargingNotifications)
                    Toggle("Bluetooth & AirPods Connectivity HUD", isOn: $settings.enableConnectivityHUD)
                    Toggle("Audio Output Device Changes HUD", isOn: $settings.enableAudioDeviceHUD)
                    Toggle("Focus Mode Status HUD", isOn: $settings.enableFocusHUD)
                    Toggle("Lock / Unlock Transition Animation", isOn: $settings.enableLockScreenAnimation)
                    Toggle("Hide Sensitive Schedule Details When Locked", isOn: $settings.hideSensitiveContentWhenLocked)
                }
                .padding(8)
            }

            GroupBox("HUD Style & Timing") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Elastic Spring Overshoot on HUD Pop", isOn: $settings.enableHUDOvershoot)
                    Toggle("Show Percentage Value on Volume & Brightness HUDs", isOn: $settings.showHUDPercentageText)

                    HStack {
                        Text("QuickPeek Notification Duration")
                        Spacer()
                        Slider(value: $settings.quickPeekDuration, in: 1.5...6.0, step: 0.5)
                            .frame(width: 200)
                        Text(String(format: "%.1fs", settings.quickPeekDuration))
                            .font(.caption.monospacedDigit())
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                .padding(8)
            }

            GroupBox("Interactive HUD Test Bench") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Click any button below to preview the live Dynamic Island HUD animation immediately:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Test Volume HUD") {
                            volumeMgr.emitVolumeHUD()
                        }
                        Button("Test Brightness HUD") {
                            brightnessMgr.emitBrightnessHUD()
                        }
                        Button("Test Charger HUD") {
                            coordinator.presentSystemHUD(
                                SystemHUDPayload(
                                    kind: .batteryCharging,
                                    title: "Charging Connected",
                                    subtitle: "\(batteryMgr.state.percentage)% Battery",
                                    symbolName: "battery.100percent.bolt",
                                    progress: Double(batteryMgr.state.percentage) / 100.0,
                                    valueText: "\(batteryMgr.state.percentage)%",
                                    tintColorName: "green"
                                )
                            )
                        }
                    }

                    HStack(spacing: 8) {
                        Button("Test AirPods Pro HUD") {
                            coordinator.presentSystemHUD(
                                SystemHUDPayload(
                                    kind: .connectivity,
                                    title: "AirPods Pro",
                                    subtitle: "Connected • 94% Battery",
                                    symbolName: "airpodspro",
                                    progress: 0.94,
                                    valueText: "94%",
                                    tintColorName: "cyan"
                                )
                            )
                        }
                        Button("Test Focus HUD") {
                            focusMgr.cycleFocusProfile()
                        }
                        Button("Test QuickPeek Banner") {
                            coordinator.enqueueQuickPeek(
                                QuickPeekNotification(
                                    category: .calendar,
                                    title: "Design Review Sync",
                                    subtitle: "Starts in 4m • Google Meet",
                                    badgeText: "JOIN",
                                    symbolName: "video.fill",
                                    accentColor: "cyan",
                                    duration: settings.quickPeekDuration
                                )
                            )
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - 7. Permissions Section

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            permissionRow(
                title: "Calendars (EventKit)",
                description: "Used to display upcoming events, meeting countdowns, and the monthly calendar grid.",
                status: calendarMgr.permissionStatusLabel,
                isGranted: calendarMgr.hasCalendarAccess,
                actionTitle: calendarMgr.hasCalendarAccess ? "Open Settings" : "Request Access"
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

            permissionRow(
                title: "Location Services (Weather)",
                description: "Optional. Used to fetch accurate local weather conditions. Falls back to city or timezone if declined.",
                status: weatherMgr.permissionStatusLabel,
                isGranted: weatherMgr.authorizationStatus == .authorized || weatherMgr.authorizationStatus == .authorizedAlways,
                actionTitle: "Request Location"
            ) {
                weatherMgr.requestLocationPermission()
            }

            permissionRow(
                title: "Media Automation (Apple Events)",
                description: "Used to read song artwork and control playback in Apple Music and Spotify.",
                status: "Contextual (Prompted when Music/Spotify is running)",
                isGranted: true,
                actionTitle: "Automation Settings"
            ) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }

            permissionRow(
                title: "Accessibility (Optional)",
                description: "Optional. Only needed if you want enhanced global media key interception on external keyboards.",
                status: isAccessibilityTrusted ? "Trusted" : "Optional (Not Required for Core Features)",
                isGranted: isAccessibilityTrusted,
                actionTitle: "Open Accessibility"
            ) {
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
            }
        }
    }

    private func permissionRow(
        title: String,
        description: String,
        status: String,
        isGranted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        GroupBox {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: isGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isGranted ? .green : .orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .bold))
                    Text(description)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Text("Status: \(status)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isGranted ? .green : .secondary)
                }

                Spacer()

                Button(actionTitle, action: action)
            }
            .padding(8)
        }
    }

    // MARK: - 8. About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("NotchFlow")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Version 1.0.0 (Build 1) • Native macOS Swift & AppKit")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("Created by Dillon Nagar")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    Spacer()

                    if let repoURL = URL(string: "https://github.com/Manateek1/NotchFlow") {
                        Link("GitHub Repository", destination: repoURL)
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(10)
            }

            GroupBox("Privacy & Architecture") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Zero Telemetry & 100% Local Execution")
                        .font(.system(size: 13, weight: .bold))
                    Text("NotchFlow runs locally on your Mac with zero analytics, zero tracking, and no required accounts. Calendar events, media playback state, and system metrics never leave your device. Weather forecasts are fetched anonymously via Open-Meteo.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            GroupBox("Open Source License & Disclaimer") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Released under the MIT License • Copyright © 2026 Dillon Nagar")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text("NotchFlow is an independent open-source project and is not affiliated with, endorsed by, or sponsored by Apple Inc. or Alcove.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
        }
    }
}
