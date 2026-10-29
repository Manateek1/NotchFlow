import Foundation
import SwiftUI
import AppKit

// MARK: - Island State & Activity Definitions

public enum IslandDisplayState: String, CaseIterable, Codable, Equatable, Sendable {
    case hidden
    case minimalIdle
    case compactPill
    case duoMode
    case quickPeek
    case systemHUD
    case expanded
    case locked
}

public enum IslandActivityKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case music
    case calendar
    case weather
    case battery
    case connectivity
    case focus
    case systemHUD
    case lockScreen
    case minimal

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .music: return "Now Playing"
        case .calendar: return "Calendar"
        case .weather: return "Weather"
        case .battery: return "Battery"
        case .connectivity: return "Audio & Connectivity"
        case .focus: return "Focus Mode"
        case .systemHUD: return "System HUD"
        case .lockScreen: return "Lock State"
        case .minimal: return "Minimal Idle"
        }
    }

    public var symbolName: String {
        switch self {
        case .music: return "waveform"
        case .calendar: return "calendar"
        case .weather: return "cloud.sun.fill"
        case .battery: return "battery.100.bolt"
        case .connectivity: return "airpodspro"
        case .focus: return "moon.fill"
        case .systemHUD: return "slider.horizontal.3"
        case .lockScreen: return "lock.fill"
        case .minimal: return "capsule.portrait"
        }
    }

    public var defaultPriority: Int {
        switch self {
        case .lockScreen: return 100
        case .systemHUD: return 90
        case .connectivity: return 80
        case .battery: return 75
        case .focus: return 70
        case .music: return 60
        case .calendar: return 50
        case .weather: return 40
        case .minimal: return 10
        }
    }
}

// MARK: - Appearance & Behavior Enums

public enum IslandStyleMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic = "automatic"
    case realNotch = "realNotch"
    case simulatedPill = "simulatedPill"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic (Detect Hardware Notch)"
        case .realNotch: return "Notch Hugger Mode"
        case .simulatedPill: return "Floating Pill Mode (Notchless Style)"
        }
    }
}

public enum AnimationSpeedPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case smooth = "smooth"
    case fast = "fast"
    case instant = "instant"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .smooth: return "Smooth (Fluid Spring)"
        case .fast: return "Fast (Snappy)"
        case .instant: return "Instant (Minimal Motion)"
        }
    }

    public var response: Double {
        switch self {
        case .smooth: return 0.36
        case .fast: return 0.22
        case .instant: return 0.08
        }
    }

    public var dampingFraction: Double {
        switch self {
        case .smooth: return 0.78
        case .fast: return 0.84
        case .instant: return 0.98
        }
    }
}

public enum AppearanceThemeMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case darkOnly = "darkOnly"
    case system = "system"
    case adaptiveGlass = "adaptiveGlass"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .darkOnly: return "OLED Pitch Black (Notch Native)"
        case .system: return "Follow System Appearance"
        case .adaptiveGlass: return "Translucent Obsidian Glass"
        }
    }
}

public enum AccentColorPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case cyanFlow = "cyanFlow"
    case electricIndigo = "electricIndigo"
    case emeraldPulse = "emeraldPulse"
    case amberGlow = "amberGlow"
    case roseQuartz = "roseQuartz"
    case dynamicArtwork = "dynamicArtwork"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cyanFlow: return "Cyan Flow"
        case .electricIndigo: return "Electric Indigo"
        case .emeraldPulse: return "Emerald Pulse"
        case .amberGlow: return "Amber Glow"
        case .roseQuartz: return "Rose Quartz"
        case .dynamicArtwork: return "Dynamic Album Artwork"
        }
    }

    public var primaryColor: Color {
        switch self {
        case .cyanFlow: return Color(red: 0.20, green: 0.82, blue: 0.98)
        case .electricIndigo: return Color(red: 0.48, green: 0.42, blue: 0.98)
        case .emeraldPulse: return Color(red: 0.18, green: 0.88, blue: 0.62)
        case .amberGlow: return Color(red: 0.98, green: 0.68, blue: 0.20)
        case .roseQuartz: return Color(red: 0.96, green: 0.38, blue: 0.58)
        case .dynamicArtwork: return Color(red: 0.28, green: 0.78, blue: 0.98)
        }
    }

    public var secondaryColor: Color {
        switch self {
        case .cyanFlow: return Color(red: 0.38, green: 0.46, blue: 0.98)
        case .electricIndigo: return Color(red: 0.76, green: 0.36, blue: 0.96)
        case .emeraldPulse: return Color(red: 0.12, green: 0.72, blue: 0.82)
        case .amberGlow: return Color(red: 0.96, green: 0.42, blue: 0.24)
        case .roseQuartz: return Color(red: 0.68, green: 0.34, blue: 0.94)
        case .dynamicArtwork: return Color(red: 0.56, green: 0.42, blue: 0.96)
        }
    }
}

public enum IdleVisibilityMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case alwaysVisible = "alwaysVisible"
    case minimalPill = "minimalPill"
    case autoHideWhenInactive = "autoHideWhenInactive"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .alwaysVisible: return "Always Show Compact Island"
        case .minimalPill: return "Minimal Notch Hugger When Idle"
        case .autoHideWhenInactive: return "Auto-Hide When No Activity"
        }
    }
}

public enum IslandCornerStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case continuousSquircle = "continuousSquircle"
    case classicNotch = "classicNotch"
    case capsulePill = "capsulePill"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .continuousSquircle: return "Continuous Squircle"
        case .classicNotch: return "Top-Anchored Notch Flare"
        case .capsulePill: return "Full Capsule Pill"
        }
    }
}

public enum MiddleClickAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case cycleActivities = "cycleActivities"
    case playPauseMedia = "playPauseMedia"
    case toggleExpand = "toggleExpand"
    case none = "none"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cycleActivities: return "Cycle Active Island Widget"
        case .playPauseMedia: return "Play / Pause Media"
        case .toggleExpand: return "Expand / Collapse Island"
        case .none: return "Do Nothing"
        }
    }
}

public enum MediaProviderPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic = "automatic"
    case appleMusic = "appleMusic"
    case spotify = "spotify"
    case browser = "browser"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic (Active Player)"
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .browser: return "Web Browsers (Safari / Chrome)"
        }
    }
}

public enum WaveformVisualStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case bars = "bars"
    case liquidWave = "liquidWave"
    case spectrumDots = "spectrumDots"
    case minimalPulse = "minimalPulse"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bars: return "Harmonic Equalizer Bars"
        case .liquidWave: return "Fluid Sine Wave"
        case .spectrumDots: return "Spectrum Matrix"
        case .minimalPulse: return "Minimal Beat Pulse"
        }
    }
}

public enum ExpandedPlayerLayout: String, CaseIterable, Codable, Identifiable, Sendable {
    case standard = "standard"
    case cinemaArtwork = "cinemaArtwork"
    case compactControls = "compactControls"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard: return "Standard Studio Player"
        case .cinemaArtwork: return "Large Artwork Showcase"
        case .compactControls: return "Compact Deck"
        }
    }
}

public enum TemperatureUnit: String, CaseIterable, Codable, Identifiable, Sendable {
    case fahrenheit = "fahrenheit"
    case celsius = "celsius"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }

    public var title: String {
        switch self {
        case .fahrenheit: return "Fahrenheit (°F)"
        case .celsius: return "Celsius (°C)"
        }
    }
}

// MARK: - System HUD & QuickPeek Payloads

public enum SystemHUDKind: String, Codable, Equatable, Sendable {
    case volume
    case mute
    case brightness
    case batteryCharging
    case batteryLow
    case batteryFull
    case powerMode
    case connectivity
    case audioOutput
    case focusMode
}

public struct SystemHUDPayload: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: SystemHUDKind
    public let title: String
    public let subtitle: String?
    public let symbolName: String
    public let progress: Double? // 0.0 ... 1.0
    public let valueText: String?
    public let tintColorName: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        kind: SystemHUDKind,
        title: String,
        subtitle: String? = nil,
        symbolName: String,
        progress: Double? = nil,
        valueText: String? = nil,
        tintColorName: String = "cyan",
        timestamp: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.progress = progress
        self.valueText = valueText
        self.tintColorName = tintColorName
        self.timestamp = timestamp
    }

    public var tintColor: Color {
        switch tintColorName {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "yellow": return .yellow
        case "purple": return .purple
        case "indigo": return .indigo
        case "blue": return .blue
        case "white": return .white
        default: return Color(red: 0.22, green: 0.82, blue: 0.98)
        }
    }
}

public struct QuickPeekNotification: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let category: IslandActivityKind
    public let priority: Int
    public let title: String
    public let subtitle: String
    public let badgeText: String?
    public let symbolName: String
    public let accentColor: String
    public let duration: TimeInterval
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        category: IslandActivityKind,
        priority: Int? = nil,
        title: String,
        subtitle: String,
        badgeText: String? = nil,
        symbolName: String,
        accentColor: String = "cyan",
        duration: TimeInterval = 3.2,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.priority = priority ?? category.defaultPriority
        self.title = title
        self.subtitle = subtitle
        self.badgeText = badgeText
        self.symbolName = symbolName
        self.accentColor = accentColor
        self.duration = duration
        self.createdAt = createdAt
    }
}
