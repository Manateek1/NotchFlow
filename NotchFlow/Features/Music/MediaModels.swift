import Foundation
import AppKit
import SwiftUI

public enum RepeatMode: String, Codable, CaseIterable, Sendable {
    case off
    case all
    case one

    public var symbolName: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

public struct NowPlayingTrack: Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var elapsedTime: TimeInterval
    public var isPlaying: Bool
    public var playbackRate: Double
    public var volume: Double // 0.0 ... 100.0
    public var isShuffling: Bool
    public var repeatMode: RepeatMode
    public var isExplicit: Bool
    public var isLossless: Bool
    public var isDolbyAtmos: Bool
    public var isPodcast: Bool
    public var isLiked: Bool
    public var artworkImage: NSImage?
    public var artworkURL: String?
    public var dominantColor: Color
    public var sourceBundleID: String
    public var sourceAppName: String

    public init(
        title: String = "Not Playing",
        artist: String = "Select a media player",
        album: String = "",
        duration: TimeInterval = 0,
        elapsedTime: TimeInterval = 0,
        isPlaying: Bool = false,
        playbackRate: Double = 1.0,
        volume: Double = 75,
        isShuffling: Bool = false,
        repeatMode: RepeatMode = .off,
        isExplicit: Bool = false,
        isLossless: Bool = false,
        isDolbyAtmos: Bool = false,
        isPodcast: Bool = false,
        isLiked: Bool = false,
        artworkImage: NSImage? = nil,
        artworkURL: String? = nil,
        dominantColor: Color = Color(red: 0.22, green: 0.80, blue: 0.98),
        sourceBundleID: String = "com.apple.Music",
        sourceAppName: String = "Music"
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.isPlaying = isPlaying
        self.playbackRate = playbackRate
        self.volume = volume
        self.isShuffling = isShuffling
        self.repeatMode = repeatMode
        self.isExplicit = isExplicit
        self.isLossless = isLossless
        self.isDolbyAtmos = isDolbyAtmos
        self.isPodcast = isPodcast
        self.isLiked = isLiked
        self.artworkImage = artworkImage
        self.artworkURL = artworkURL
        self.dominantColor = dominantColor
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
    }

    public var hasActiveTrack: Bool {
        !title.isEmpty && title != "Not Playing"
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1.0, max(0.0, elapsedTime / duration))
    }

    public var formattedElapsed: String {
        Self.formatTime(elapsedTime)
    }

    public var formattedRemaining: String {
        let remaining = max(0, duration - elapsedTime)
        return "-\(Self.formatTime(remaining))"
    }

    public var formattedDuration: String {
        Self.formatTime(duration)
    }

    public var sourceSymbolName: String {
        if isPodcast { return "mic.fill" }
        switch sourceBundleID {
        case "com.apple.Music": return "music.note"
        case "com.spotify.client": return "waveform.circle.fill"
        case "com.apple.Safari", "com.google.Chrome": return "globe"
        default: return "play.circle.fill"
        }
    }

    public static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    public static func == (lhs: NowPlayingTrack, rhs: NowPlayingTrack) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        abs(lhs.duration - rhs.duration) < 0.5 &&
        abs(lhs.elapsedTime - rhs.elapsedTime) < 0.5 &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.isShuffling == rhs.isShuffling &&
        lhs.repeatMode == rhs.repeatMode &&
        lhs.isExplicit == rhs.isExplicit &&
        lhs.isLossless == rhs.isLossless &&
        lhs.isDolbyAtmos == rhs.isDolbyAtmos &&
        lhs.isPodcast == rhs.isPodcast &&
        lhs.isLiked == rhs.isLiked &&
        lhs.artworkURL == rhs.artworkURL &&
        lhs.sourceBundleID == rhs.sourceBundleID
    }
}
