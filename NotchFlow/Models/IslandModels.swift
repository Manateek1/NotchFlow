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
        case .connectivity: return "Connectivity"
        case .focus: return "Focus"
        case .systemHUD: return "Controls"
        case .lockScreen: return "Lock Screen"
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

// MARK: - HUD Visual Theme (White / Accent / Glow)

public enum HUDBarTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case white = "white"
    case accent = "accent"
    case glow = "glow"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .white: return "White"
        case .accent: return "Accent"
        case .glow: return "Glow"
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
        case .automatic: return "Automatic (Hardware Notch)"
        case .realNotch: return "Notch Mode (Top-Anchored)"
        case .simulatedPill: return "Floating Pill Mode"
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
        case .smooth: return "Smooth"
        case .fast: return "Fast"
        case .instant: return "Instant"
        }
    }

    public var symbolName: String {
        switch self {
        case .smooth: return "tortoise.fill"
        case .fast: return "hare.fill"
        case .instant: return "bolt.fill"
        }
    }

    public var response: Double {
        switch self {
        case .smooth: return 0.38
        case .fast: return 0.24
        case .instant: return 0.10
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
        case .adaptiveGlass: return "Obsidian Translucent"
        }
    }
}

public enum AccentColorPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case dynamicArtwork = "dynamicArtwork"
    case cyanFlow = "cyanFlow"
    case emeraldPulse = "emeraldPulse"
    case amberGlow = "amberGlow"
    case electricIndigo = "electricIndigo"
    case roseQuartz = "roseQuartz"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dynamicArtwork: return "Dynamic Album Artwork"
        case .cyanFlow: return "Glacier Blue"
        case .emeraldPulse: return "Teal Mint"
        case .amberGlow: return "Warm Amber"
        case .electricIndigo: return "Soft Indigo"
        case .roseQuartz: return "Coral Rose"
        }
    }

    public var primaryColor: Color {
        switch self {
        case .dynamicArtwork: return Color(red: 0.44, green: 0.68, blue: 0.82)
        case .cyanFlow: return Color(red: 0.38, green: 0.72, blue: 0.90)
        case .emeraldPulse: return Color(red: 0.24, green: 0.80, blue: 0.70)
        case .amberGlow: return Color(red: 0.96, green: 0.62, blue: 0.32)
        case .electricIndigo: return Color(red: 0.56, green: 0.52, blue: 0.96)
        case .roseQuartz: return Color(red: 0.94, green: 0.44, blue: 0.56)
        }
    }

    public var secondaryColor: Color {
        switch self {
        case .dynamicArtwork: return Color(red: 0.28, green: 0.46, blue: 0.64)
        case .cyanFlow: return Color(red: 0.24, green: 0.48, blue: 0.78)
        case .emeraldPulse: return Color(red: 0.14, green: 0.56, blue: 0.52)
        case .amberGlow: return Color(red: 0.88, green: 0.38, blue: 0.22)
        case .electricIndigo: return Color(red: 0.38, green: 0.32, blue: 0.78)
        case .roseQuartz: return Color(red: 0.68, green: 0.28, blue: 0.48)
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
        case .alwaysVisible: return "Always Show Active Island"
        case .minimalPill: return "Hug Notch When Idle"
        case .autoHideWhenInactive: return "Auto-Hide When Inactive"
        }
    }
}

public enum IslandCornerStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case classicNotch = "classicNotch"
    case continuousSquircle = "continuousSquircle"
    case capsulePill = "capsulePill"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classicNotch: return "Hardware Notch Curve (Default)"
        case .continuousSquircle: return "Continuous Squircle"
        case .capsulePill: return "Floating Capsule Pill"
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
        case .cycleActivities: return "Switch Active Widget"
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
        case .bars: return "Dynamic Island Bars"
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
        case .standard: return "Apple Dynamic Island Studio"
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
        tintColorName: String = "white",
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
        case "green": return Color(red: 0.29, green: 0.87, blue: 0.50)
        case "orange": return Color(red: 0.98, green: 0.58, blue: 0.24)
        case "red": return Color(red: 0.96, green: 0.34, blue: 0.34)
        case "yellow": return Color(red: 0.98, green: 0.80, blue: 0.24)
        case "purple": return Color(red: 0.68, green: 0.52, blue: 0.98)
        case "indigo": return Color(red: 0.48, green: 0.52, blue: 0.98)
        case "blue": return Color(red: 0.38, green: 0.72, blue: 0.98)
        case "white": return .white
        default: return .white
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
        accentColor: String = "white",
        duration: TimeInterval = 2.8,
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
