import Foundation
import SwiftUI
import Combine
import ServiceManagement

@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()

    private let defaults: UserDefaults

    // MARK: - General
    @Published public var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }
    @Published public var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            syncLaunchAtLogin(launchAtLogin)
        }
    }
    @Published public var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }
    @Published public var startMinimized: Bool {
        didSet { defaults.set(startMinimized, forKey: Keys.startMinimized) }
    }
    @Published public var preferredDisplayID: String {
        didSet { defaults.set(preferredDisplayID, forKey: Keys.preferredDisplayID) }
    }
    @Published public var showOnAllDisplays: Bool {
        didSet { defaults.set(showOnAllDisplays, forKey: Keys.showOnAllDisplays) }
    }
    @Published public var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    // MARK: - Appearance
    @Published public var islandStyleMode: IslandStyleMode {
        didSet { defaults.set(islandStyleMode.rawValue, forKey: Keys.islandStyleMode) }
    }
    @Published public var compactWidthAdjustment: Double {
        didSet { defaults.set(compactWidthAdjustment, forKey: Keys.compactWidthAdjustment) }
    }
    @Published public var compactHeightAdjustment: Double {
        didSet { defaults.set(compactHeightAdjustment, forKey: Keys.compactHeightAdjustment) }
    }
    @Published public var expandedScale: Double {
        didSet { defaults.set(expandedScale, forKey: Keys.expandedScale) }
    }
    @Published public var animationSpeed: AnimationSpeedPreset {
        didSet { defaults.set(animationSpeed.rawValue, forKey: Keys.animationSpeed) }
    }
    @Published public var respectReduceMotion: Bool {
        didSet { defaults.set(respectReduceMotion, forKey: Keys.respectReduceMotion) }
    }
    @Published public var appearanceTheme: AppearanceThemeMode {
        didSet { defaults.set(appearanceTheme.rawValue, forKey: Keys.appearanceTheme) }
    }
    @Published public var accentColorPreset: AccentColorPreset {
        didSet { defaults.set(accentColorPreset.rawValue, forKey: Keys.accentColorPreset) }
    }
    @Published public var showContrastOutline: Bool {
        didSet { defaults.set(showContrastOutline, forKey: Keys.showContrastOutline) }
    }
    @Published public var coloredOutline: Bool {
        didSet { defaults.set(coloredOutline, forKey: Keys.coloredOutline) }
    }
    @Published public var idleVisibility: IdleVisibilityMode {
        didSet { defaults.set(idleVisibility.rawValue, forKey: Keys.idleVisibility) }
    }
    @Published public var cornerStyle: IslandCornerStyle {
        didSet { defaults.set(cornerStyle.rawValue, forKey: Keys.cornerStyle) }
    }

    // MARK: - Behavior
    @Published public var expandOnHover: Bool {
        didSet { defaults.set(expandOnHover, forKey: Keys.expandOnHover) }
    }
    @Published public var hoverDelay: Double {
        didSet { defaults.set(hoverDelay, forKey: Keys.hoverDelay) }
    }
    @Published public var expandOnClick: Bool {
        didSet { defaults.set(expandOnClick, forKey: Keys.expandOnClick) }
    }
    @Published public var clickOutsideToDismiss: Bool {
        didSet { defaults.set(clickOutsideToDismiss, forKey: Keys.clickOutsideToDismiss) }
    }
    @Published public var autoDismissDelay: Double {
        didSet { defaults.set(autoDismissDelay, forKey: Keys.autoDismissDelay) }
    }
    @Published public var enableSwipeGestures: Bool {
        didSet { defaults.set(enableSwipeGestures, forKey: Keys.enableSwipeGestures) }
    }
    @Published public var naturalSwipeDirection: Bool {
        didSet { defaults.set(naturalSwipeDirection, forKey: Keys.naturalSwipeDirection) }
    }
    @Published public var middleClickAction: MiddleClickAction {
        didSet { defaults.set(middleClickAction.rawValue, forKey: Keys.middleClickAction) }
    }
    @Published public var hideInFullscreen: Bool {
        didSet { defaults.set(hideInFullscreen, forKey: Keys.hideInFullscreen) }
    }
    @Published public var enableDuoMode: Bool {
        didSet { defaults.set(enableDuoMode, forKey: Keys.enableDuoMode) }
    }
    @Published public var preferredIdleActivity: IslandActivityKind {
        didSet { defaults.set(preferredIdleActivity.rawValue, forKey: Keys.preferredIdleActivity) }
    }

    // MARK: - Music
    @Published public var enableMusic: Bool {
        didSet { defaults.set(enableMusic, forKey: Keys.enableMusic) }
    }
    @Published public var preferredMediaProvider: MediaProviderPreference {
        didSet { defaults.set(preferredMediaProvider.rawValue, forKey: Keys.preferredMediaProvider) }
    }
    @Published public var showAlbumArtwork: Bool {
        didSet { defaults.set(showAlbumArtwork, forKey: Keys.showAlbumArtwork) }
    }
    @Published public var artworkGlowEffect: Bool {
        didSet { defaults.set(artworkGlowEffect, forKey: Keys.artworkGlowEffect) }
    }
    @Published public var dimArtworkOnPause: Bool {
        didSet { defaults.set(dimArtworkOnPause, forKey: Keys.dimArtworkOnPause) }
    }
    @Published public var showWaveform: Bool {
        didSet { defaults.set(showWaveform, forKey: Keys.showWaveform) }
    }
    @Published public var waveformStyle: WaveformVisualStyle {
        didSet { defaults.set(waveformStyle.rawValue, forKey: Keys.waveformStyle) }
    }
    @Published public var showPlaybackControls: Bool {
        didSet { defaults.set(showPlaybackControls, forKey: Keys.showPlaybackControls) }
    }
    @Published public var expandedPlayerLayout: ExpandedPlayerLayout {
        didSet { defaults.set(expandedPlayerLayout.rawValue, forKey: Keys.expandedPlayerLayout) }
    }
    @Published public var showAudioFormatBadges: Bool {
        didSet { defaults.set(showAudioFormatBadges, forKey: Keys.showAudioFormatBadges) }
    }

    // MARK: - Calendar & Weather
    @Published public var enableCalendar: Bool {
        didSet { defaults.set(enableCalendar, forKey: Keys.enableCalendar) }
    }
    @Published public var selectedCalendarIDs: [String] {
        didSet { defaults.set(selectedCalendarIDs, forKey: Keys.selectedCalendarIDs) }
    }
    @Published public var excludeSubscribedCalendars: Bool {
        didSet { defaults.set(excludeSubscribedCalendars, forKey: Keys.excludeSubscribedCalendars) }
    }
    @Published public var showDeclinedEvents: Bool {
        didSet { defaults.set(showDeclinedEvents, forKey: Keys.showDeclinedEvents) }
    }
    @Published public var showEventCountdown: Bool {
        didSet { defaults.set(showEventCountdown, forKey: Keys.showEventCountdown) }
    }
    @Published public var showMeetingJoinButton: Bool {
        didSet { defaults.set(showMeetingJoinButton, forKey: Keys.showMeetingJoinButton) }
    }
    @Published public var enableWeather: Bool {
        didSet { defaults.set(enableWeather, forKey: Keys.enableWeather) }
    }
    @Published public var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Keys.temperatureUnit) }
    }
    @Published public var showWeatherOnEmptyCalendarDay: Bool {
        didSet { defaults.set(showWeatherOnEmptyCalendarDay, forKey: Keys.showWeatherOnEmptyCalendarDay) }
    }
    @Published public var customWeatherCity: String {
        didSet { defaults.set(customWeatherCity, forKey: Keys.customWeatherCity) }
    }

    // MARK: - System HUDs & Lock Screen
    @Published public var enableVolumeHUD: Bool {
        didSet { defaults.set(enableVolumeHUD, forKey: Keys.enableVolumeHUD) }
    }
    @Published public var enableBrightnessHUD: Bool {
        didSet { defaults.set(enableBrightnessHUD, forKey: Keys.enableBrightnessHUD) }
    }
    @Published public var enableBatteryHUD: Bool {
        didSet { defaults.set(enableBatteryHUD, forKey: Keys.enableBatteryHUD) }
    }
    @Published public var enableChargingNotifications: Bool {
        didSet { defaults.set(enableChargingNotifications, forKey: Keys.enableChargingNotifications) }
    }
    @Published public var enableConnectivityHUD: Bool {
        didSet { defaults.set(enableConnectivityHUD, forKey: Keys.enableConnectivityHUD) }
    }
    @Published public var enableAudioDeviceHUD: Bool {
        didSet { defaults.set(enableAudioDeviceHUD, forKey: Keys.enableAudioDeviceHUD) }
    }
    @Published public var enableFocusHUD: Bool {
        didSet { defaults.set(enableFocusHUD, forKey: Keys.enableFocusHUD) }
    }
    @Published public var enableHUDOvershoot: Bool {
        didSet { defaults.set(enableHUDOvershoot, forKey: Keys.enableHUDOvershoot) }
    }
    @Published public var showHUDPercentageText: Bool {
        didSet { defaults.set(showHUDPercentageText, forKey: Keys.showHUDPercentageText) }
    }
    @Published public var quickPeekDuration: Double {
        didSet { defaults.set(quickPeekDuration, forKey: Keys.quickPeekDuration) }
    }
    @Published public var enableLockScreenAnimation: Bool {
        didSet { defaults.set(enableLockScreenAnimation, forKey: Keys.enableLockScreenAnimation) }
    }
    @Published public var hideSensitiveContentWhenLocked: Bool {
        didSet { defaults.set(hideSensitiveContentWhenLocked, forKey: Keys.hideSensitiveContentWhenLocked) }
    }

    private enum Keys {
        static let isEnabled = "nf.isEnabled"
        static let launchAtLogin = "nf.launchAtLogin"
        static let showMenuBarIcon = "nf.showMenuBarIcon"
        static let startMinimized = "nf.startMinimized"
        static let preferredDisplayID = "nf.preferredDisplayID"
        static let showOnAllDisplays = "nf.showOnAllDisplays"
        static let hasCompletedOnboarding = "nf.hasCompletedOnboarding"

        static let islandStyleMode = "nf.islandStyleMode"
        static let compactWidthAdjustment = "nf.compactWidthAdjustment"
        static let compactHeightAdjustment = "nf.compactHeightAdjustment"
        static let expandedScale = "nf.expandedScale"
        static let animationSpeed = "nf.animationSpeed"
        static let respectReduceMotion = "nf.respectReduceMotion"
        static let appearanceTheme = "nf.appearanceTheme"
        static let accentColorPreset = "nf.accentColorPreset"
        static let showContrastOutline = "nf.showContrastOutline"
        static let coloredOutline = "nf.coloredOutline"
        static let idleVisibility = "nf.idleVisibility"
        static let cornerStyle = "nf.cornerStyle"

        static let expandOnHover = "nf.expandOnHover"
        static let hoverDelay = "nf.hoverDelay"
        static let expandOnClick = "nf.expandOnClick"
        static let clickOutsideToDismiss = "nf.clickOutsideToDismiss"
        static let autoDismissDelay = "nf.autoDismissDelay"
        static let enableSwipeGestures = "nf.enableSwipeGestures"
        static let naturalSwipeDirection = "nf.naturalSwipeDirection"
        static let middleClickAction = "nf.middleClickAction"
        static let hideInFullscreen = "nf.hideInFullscreen"
        static let enableDuoMode = "nf.enableDuoMode"
        static let preferredIdleActivity = "nf.preferredIdleActivity"

        static let enableMusic = "nf.enableMusic"
        static let preferredMediaProvider = "nf.preferredMediaProvider"
        static let showAlbumArtwork = "nf.showAlbumArtwork"
        static let artworkGlowEffect = "nf.artworkGlowEffect"
        static let dimArtworkOnPause = "nf.dimArtworkOnPause"
        static let showWaveform = "nf.showWaveform"
        static let waveformStyle = "nf.waveformStyle"
        static let showPlaybackControls = "nf.showPlaybackControls"
        static let expandedPlayerLayout = "nf.expandedPlayerLayout"
        static let showAudioFormatBadges = "nf.showAudioFormatBadges"

        static let enableCalendar = "nf.enableCalendar"
        static let selectedCalendarIDs = "nf.selectedCalendarIDs"
        static let excludeSubscribedCalendars = "nf.excludeSubscribedCalendars"
        static let showDeclinedEvents = "nf.showDeclinedEvents"
        static let showEventCountdown = "nf.showEventCountdown"
        static let showMeetingJoinButton = "nf.showMeetingJoinButton"
        static let enableWeather = "nf.enableWeather"
        static let temperatureUnit = "nf.temperatureUnit"
        static let showWeatherOnEmptyCalendarDay = "nf.showWeatherOnEmptyCalendarDay"
        static let customWeatherCity = "nf.customWeatherCity"

        static let enableVolumeHUD = "nf.enableVolumeHUD"
        static let enableBrightnessHUD = "nf.enableBrightnessHUD"
        static let enableBatteryHUD = "nf.enableBatteryHUD"
        static let enableChargingNotifications = "nf.enableChargingNotifications"
        static let enableConnectivityHUD = "nf.enableConnectivityHUD"
        static let enableAudioDeviceHUD = "nf.enableAudioDeviceHUD"
        static let enableFocusHUD = "nf.enableFocusHUD"
        static let enableHUDOvershoot = "nf.enableHUDOvershoot"
        static let showHUDPercentageText = "nf.showHUDPercentageText"
        static let quickPeekDuration = "nf.quickPeekDuration"
        static let enableLockScreenAnimation = "nf.enableLockScreenAnimation"
        static let hideSensitiveContentWhenLocked = "nf.hideSensitiveContentWhenLocked"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        self.launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        self.showMenuBarIcon = defaults.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
        self.startMinimized = defaults.object(forKey: Keys.startMinimized) as? Bool ?? false
        self.preferredDisplayID = defaults.string(forKey: Keys.preferredDisplayID) ?? "main"
        self.showOnAllDisplays = defaults.object(forKey: Keys.showOnAllDisplays) as? Bool ?? false
        self.hasCompletedOnboarding = defaults.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? false

        self.islandStyleMode = IslandStyleMode(rawValue: defaults.string(forKey: Keys.islandStyleMode) ?? "") ?? .automatic
        self.compactWidthAdjustment = defaults.object(forKey: Keys.compactWidthAdjustment) as? Double ?? 0.0
        self.compactHeightAdjustment = defaults.object(forKey: Keys.compactHeightAdjustment) as? Double ?? 0.0
        self.expandedScale = defaults.object(forKey: Keys.expandedScale) as? Double ?? 1.0
        self.animationSpeed = AnimationSpeedPreset(rawValue: defaults.string(forKey: Keys.animationSpeed) ?? "") ?? .smooth
        self.respectReduceMotion = defaults.object(forKey: Keys.respectReduceMotion) as? Bool ?? true
        self.appearanceTheme = AppearanceThemeMode(rawValue: defaults.string(forKey: Keys.appearanceTheme) ?? "") ?? .darkOnly
        self.accentColorPreset = AccentColorPreset(rawValue: defaults.string(forKey: Keys.accentColorPreset) ?? "") ?? .cyanFlow
        self.showContrastOutline = defaults.object(forKey: Keys.showContrastOutline) as? Bool ?? true
        self.coloredOutline = defaults.object(forKey: Keys.coloredOutline) as? Bool ?? false
        self.idleVisibility = IdleVisibilityMode(rawValue: defaults.string(forKey: Keys.idleVisibility) ?? "") ?? .alwaysVisible
        self.cornerStyle = IslandCornerStyle(rawValue: defaults.string(forKey: Keys.cornerStyle) ?? "") ?? .continuousSquircle

        self.expandOnHover = defaults.object(forKey: Keys.expandOnHover) as? Bool ?? true
        self.hoverDelay = defaults.object(forKey: Keys.hoverDelay) as? Double ?? 0.18
        self.expandOnClick = defaults.object(forKey: Keys.expandOnClick) as? Bool ?? true
        self.clickOutsideToDismiss = defaults.object(forKey: Keys.clickOutsideToDismiss) as? Bool ?? true
        self.autoDismissDelay = defaults.object(forKey: Keys.autoDismissDelay) as? Double ?? 4.5
        self.enableSwipeGestures = defaults.object(forKey: Keys.enableSwipeGestures) as? Bool ?? true
        self.naturalSwipeDirection = defaults.object(forKey: Keys.naturalSwipeDirection) as? Bool ?? true
        self.middleClickAction = MiddleClickAction(rawValue: defaults.string(forKey: Keys.middleClickAction) ?? "") ?? .cycleActivities
        self.hideInFullscreen = defaults.object(forKey: Keys.hideInFullscreen) as? Bool ?? true
        self.enableDuoMode = defaults.object(forKey: Keys.enableDuoMode) as? Bool ?? true
        self.preferredIdleActivity = IslandActivityKind(rawValue: defaults.string(forKey: Keys.preferredIdleActivity) ?? "") ?? .music

        self.enableMusic = defaults.object(forKey: Keys.enableMusic) as? Bool ?? true
        self.preferredMediaProvider = MediaProviderPreference(rawValue: defaults.string(forKey: Keys.preferredMediaProvider) ?? "") ?? .automatic
        self.showAlbumArtwork = defaults.object(forKey: Keys.showAlbumArtwork) as? Bool ?? true
        self.artworkGlowEffect = defaults.object(forKey: Keys.artworkGlowEffect) as? Bool ?? true
        self.dimArtworkOnPause = defaults.object(forKey: Keys.dimArtworkOnPause) as? Bool ?? true
        self.showWaveform = defaults.object(forKey: Keys.showWaveform) as? Bool ?? true
        self.waveformStyle = WaveformVisualStyle(rawValue: defaults.string(forKey: Keys.waveformStyle) ?? "") ?? .bars
        self.showPlaybackControls = defaults.object(forKey: Keys.showPlaybackControls) as? Bool ?? true
        self.expandedPlayerLayout = ExpandedPlayerLayout(rawValue: defaults.string(forKey: Keys.expandedPlayerLayout) ?? "") ?? .standard
        self.showAudioFormatBadges = defaults.object(forKey: Keys.showAudioFormatBadges) as? Bool ?? true

        self.enableCalendar = defaults.object(forKey: Keys.enableCalendar) as? Bool ?? true
        self.selectedCalendarIDs = defaults.stringArray(forKey: Keys.selectedCalendarIDs) ?? []
        self.excludeSubscribedCalendars = defaults.object(forKey: Keys.excludeSubscribedCalendars) as? Bool ?? false
        self.showDeclinedEvents = defaults.object(forKey: Keys.showDeclinedEvents) as? Bool ?? false
        self.showEventCountdown = defaults.object(forKey: Keys.showEventCountdown) as? Bool ?? true
        self.showMeetingJoinButton = defaults.object(forKey: Keys.showMeetingJoinButton) as? Bool ?? true
        self.enableWeather = defaults.object(forKey: Keys.enableWeather) as? Bool ?? true
        self.temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: Keys.temperatureUnit) ?? "") ?? .fahrenheit
        self.showWeatherOnEmptyCalendarDay = defaults.object(forKey: Keys.showWeatherOnEmptyCalendarDay) as? Bool ?? true
        self.customWeatherCity = defaults.string(forKey: Keys.customWeatherCity) ?? ""

        self.enableVolumeHUD = defaults.object(forKey: Keys.enableVolumeHUD) as? Bool ?? true
        self.enableBrightnessHUD = defaults.object(forKey: Keys.enableBrightnessHUD) as? Bool ?? true
        self.enableBatteryHUD = defaults.object(forKey: Keys.enableBatteryHUD) as? Bool ?? true
        self.enableChargingNotifications = defaults.object(forKey: Keys.enableChargingNotifications) as? Bool ?? true
        self.enableConnectivityHUD = defaults.object(forKey: Keys.enableConnectivityHUD) as? Bool ?? true
        self.enableAudioDeviceHUD = defaults.object(forKey: Keys.enableAudioDeviceHUD) as? Bool ?? true
        self.enableFocusHUD = defaults.object(forKey: Keys.enableFocusHUD) as? Bool ?? true
        self.enableHUDOvershoot = defaults.object(forKey: Keys.enableHUDOvershoot) as? Bool ?? true
        self.showHUDPercentageText = defaults.object(forKey: Keys.showHUDPercentageText) as? Bool ?? true
        self.quickPeekDuration = defaults.object(forKey: Keys.quickPeekDuration) as? Double ?? 3.2
        self.enableLockScreenAnimation = defaults.object(forKey: Keys.enableLockScreenAnimation) as? Bool ?? true
        self.hideSensitiveContentWhenLocked = defaults.object(forKey: Keys.hideSensitiveContentWhenLocked) as? Bool ?? true
    }

    public func resetToDefaults() {
        isEnabled = true
        islandStyleMode = .automatic
        compactWidthAdjustment = 0.0
        compactHeightAdjustment = 0.0
        expandedScale = 1.0
        animationSpeed = .smooth
        respectReduceMotion = true
        appearanceTheme = .darkOnly
        accentColorPreset = .cyanFlow
        showContrastOutline = true
        coloredOutline = false
        idleVisibility = .alwaysVisible
        cornerStyle = .continuousSquircle
        expandOnHover = true
        hoverDelay = 0.18
        expandOnClick = true
        clickOutsideToDismiss = true
        autoDismissDelay = 4.5
        enableSwipeGestures = true
        naturalSwipeDirection = true
        middleClickAction = .cycleActivities
        hideInFullscreen = true
        enableDuoMode = true
        preferredIdleActivity = .music
        enableMusic = true
        preferredMediaProvider = .automatic
        showAlbumArtwork = true
        artworkGlowEffect = true
        dimArtworkOnPause = true
        showWaveform = true
        waveformStyle = .bars
        showPlaybackControls = true
        expandedPlayerLayout = .standard
        showAudioFormatBadges = true
        enableCalendar = true
        excludeSubscribedCalendars = false
        showDeclinedEvents = false
        showEventCountdown = true
        showMeetingJoinButton = true
        enableWeather = true
        temperatureUnit = .fahrenheit
        showWeatherOnEmptyCalendarDay = true
        enableVolumeHUD = true
        enableBrightnessHUD = true
        enableBatteryHUD = true
        enableChargingNotifications = true
        enableConnectivityHUD = true
        enableAudioDeviceHUD = true
        enableFocusHUD = true
        enableHUDOvershoot = true
        showHUDPercentageText = true
        quickPeekDuration = 3.2
        enableLockScreenAnimation = true
        hideSensitiveContentWhenLocked = true
    }

    private func syncLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            // In unsigned local development builds or sandboxed test runs, SMAppService may decline registration gracefully.
        }
    }

    public var launchAtLoginSystemStatus: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "Enabled"
        case .notRegistered: return "Not Registered"
        case .notFound: return "App Service Not Found (Run from /Applications)"
        case .requiresApproval: return "Requires Approval in System Settings > Login Items"
        @unknown default: return "Unknown"
        }
    }
}
