import Foundation
import AppKit
import SwiftUI
import Combine

@MainActor
public protocol MediaProviderDriver: AnyObject {
    var bundleIdentifier: String { get }
    var displayName: String { get }
    var isRunning: Bool { get }
    func fetchState() async -> NowPlayingTrack?
    func playPause()
    func nextTrack()
    func previousTrack()
    func seek(to seconds: TimeInterval)
    func setVolume(_ volume: Double)
    func toggleShuffle()
    func cycleRepeatMode()
    func toggleLike()
    func setPlaybackSpeed(_ rate: Double)
}

// MARK: - AppleScript Executor Helper

public enum AppleScriptRunner {
    public static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    public static func run(_ source: String) -> NSAppleEventDescriptor? {
        guard !isRunningUnitTests else { return nil }
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if error != nil {
            return nil
        }
        return result
    }

    public static func isAppRunning(bundleID: String) -> Bool {
        guard !isRunningUnitTests else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }
}

// MARK: - Apple Music Driver

@MainActor
public final class AppleMusicDriver: MediaProviderDriver {
    public let bundleIdentifier = "com.apple.Music"
    public let displayName = "Apple Music"
    private var cachedArtworkTitle: String = ""
    private var cachedArtwork: NSImage?
    private var cachedColor: Color = Color(red: 0.22, green: 0.80, blue: 0.98)

    public var isRunning: Bool {
        AppleScriptRunner.isAppRunning(bundleID: bundleIdentifier)
    }

    public func fetchState() async -> NowPlayingTrack? {
        guard isRunning else { return nil }

        let script = """
        tell application "Music"
            if player state is stopped then
                return "STOPPED"
            end if
            set pState to (player state as string)
            set tName to name of current track
            set tArtist to artist of current track
            set tAlbum to album of current track
            set tDur to duration of current track
            set tPos to player position
            set tVol to sound volume
            set tShuf to shuffle enabled
            set tRep to (song repeat as string)
            set tLoved to loved of current track
            return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (tDur as string) & "|||" & (tPos as string) & "|||" & (tVol as string) & "|||" & (tShuf as string) & "|||" & tRep & "|||" & (tLoved as string)
        end tell
        """

        guard let desc = AppleScriptRunner.run(script),
              let raw = desc.stringValue,
              raw != "STOPPED" else {
            return nil
        }

        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 10 else { return nil }

        let isPlaying = parts[0].lowercased().contains("playing")
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
        let elapsed = Double(parts[5].replacingOccurrences(of: ",", with: ".")) ?? 0
        let volume = Double(parts[6]) ?? 75
        let isShuffling = parts[7].lowercased() == "true"
        let repeatRaw = parts[8].lowercased()
        let repeatMode: RepeatMode = repeatRaw.contains("one") ? .one : (repeatRaw.contains("all") ? .all : .off)
        let isLiked = parts[9].lowercased() == "true"

        if title != cachedArtworkTitle {
            cachedArtworkTitle = title
            if let art = fetchArtworkData() {
                cachedArtwork = art
                if let dom = art.extractDominantColor() {
                    cachedColor = Color(nsColor: dom)
                }
            } else {
                cachedArtwork = nil
                cachedColor = Color(red: 0.96, green: 0.32, blue: 0.48)
            }
        }

        let lowerTitle = title.lowercased()
        let isExplicit = lowerTitle.contains("explicit")

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: isPlaying,
            playbackRate: 1.0,
            volume: volume,
            isShuffling: isShuffling,
            repeatMode: repeatMode,
            isExplicit: isExplicit,
            isLossless: true,
            isDolbyAtmos: false,
            isPodcast: false,
            isLiked: isLiked,
            artworkImage: cachedArtwork,
            artworkURL: nil,
            dominantColor: cachedColor,
            sourceBundleID: bundleIdentifier,
            sourceAppName: displayName
        )
    }

    private func fetchArtworkData() -> NSImage? {
        let script = """
        tell application "Music"
            try
                return raw data of artwork 1 of current track
            end try
        end tell
        """
        guard let desc = AppleScriptRunner.run(script) else { return nil }
        let data = desc.data
        if !data.isEmpty, let img = NSImage(data: data) {
            return img
        }
        return nil
    }

    public func playPause() {
        _ = AppleScriptRunner.run(#"tell application "Music" to playpause"#)
    }

    public func nextTrack() {
        _ = AppleScriptRunner.run(#"tell application "Music" to next track"#)
    }

    public func previousTrack() {
        _ = AppleScriptRunner.run(#"tell application "Music" to back track"#)
    }

    public func seek(to seconds: TimeInterval) {
        let clamped = max(0, seconds)
        _ = AppleScriptRunner.run("tell application \"Music\" to set player position to \(clamped)")
    }

    public func setVolume(_ volume: Double) {
        let v = Int(max(0, min(100, volume)))
        _ = AppleScriptRunner.run("tell application \"Music\" to set sound volume to \(v)")
    }

    public func toggleShuffle() {
        _ = AppleScriptRunner.run(#"tell application "Music" to set shuffle enabled to not shuffle enabled"#)
    }

    public func cycleRepeatMode() {
        let script = """
        tell application "Music"
            if song repeat is off then
                set song repeat to all
            else if song repeat is all then
                set song repeat to one
            else
                set song repeat to off
            end if
        end tell
        """
        _ = AppleScriptRunner.run(script)
    }

    public func toggleLike() {
        _ = AppleScriptRunner.run(#"tell application "Music" to set loved of current track to not (loved of current track)"#)
    }

    public func setPlaybackSpeed(_ rate: Double) {
        // Apple Music standard tracks play at 1.0x
    }
}

// MARK: - Spotify Driver

@MainActor
public final class SpotifyDriver: MediaProviderDriver {
    public let bundleIdentifier = "com.spotify.client"
    public let displayName = "Spotify"
    private var artworkCache: [String: (NSImage, Color)] = [:]

    public var isRunning: Bool {
        AppleScriptRunner.isAppRunning(bundleID: bundleIdentifier)
    }

    public func fetchState() async -> NowPlayingTrack? {
        guard isRunning else { return nil }

        let script = """
        tell application "Spotify"
            if player state is stopped then
                return "STOPPED"
            end if
            set pState to (player state as string)
            set tName to name of current track
            set tArtist to artist of current track
            set tAlbum to album of current track
            set tDur to (duration of current track) / 1000.0
            set tPos to player position
            set tVol to sound volume
            set tShuf to shuffling
            set tRep to repeating
            set tArtUrl to artwork url of current track
            set tId to id of current track
            return pState & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (tDur as string) & "|||" & (tPos as string) & "|||" & (tVol as string) & "|||" & (tShuf as string) & "|||" & (tRep as string) & "|||" & tArtUrl & "|||" & tId
        end tell
        """

        guard let desc = AppleScriptRunner.run(script),
              let raw = desc.stringValue,
              raw != "STOPPED" else {
            return nil
        }

        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 11 else { return nil }

        let isPlaying = parts[0].lowercased().contains("playing")
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let duration = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
        let elapsed = Double(parts[5].replacingOccurrences(of: ",", with: ".")) ?? 0
        let volume = Double(parts[6]) ?? 75
        let isShuffling = parts[7].lowercased() == "true"
        let isRepeating = parts[8].lowercased() == "true"
        let artURL = parts[9]
        let trackID = parts[10]
        let isPodcast = trackID.contains(":episode:")

        var artworkImage: NSImage?
        var dominantColor = Color(red: 0.12, green: 0.84, blue: 0.42)

        if let cached = artworkCache[artURL] {
            artworkImage = cached.0
            dominantColor = cached.1
        } else if let url = URL(string: artURL), !artURL.isEmpty {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let img = NSImage(data: data) {
                let col = img.extractDominantColor().map { Color(nsColor: $0) } ?? dominantColor
                artworkCache[artURL] = (img, col)
                artworkImage = img
                dominantColor = col
            }
        }

        return NowPlayingTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsedTime: elapsed,
            isPlaying: isPlaying,
            playbackRate: 1.0,
            volume: volume,
            isShuffling: isShuffling,
            repeatMode: isRepeating ? .all : .off,
            isExplicit: false,
            isLossless: false,
            isDolbyAtmos: false,
            isPodcast: isPodcast,
            isLiked: false,
            artworkImage: artworkImage,
            artworkURL: artURL,
            dominantColor: dominantColor,
            sourceBundleID: bundleIdentifier,
            sourceAppName: displayName
        )
    }

    public func playPause() {
        _ = AppleScriptRunner.run(#"tell application "Spotify" to playpause"#)
    }

    public func nextTrack() {
        _ = AppleScriptRunner.run(#"tell application "Spotify" to next track"#)
    }

    public func previousTrack() {
        _ = AppleScriptRunner.run(#"tell application "Spotify" to previous track"#)
    }

    public func seek(to seconds: TimeInterval) {
        let clamped = max(0, seconds)
        _ = AppleScriptRunner.run("tell application \"Spotify\" to set player position to \(clamped)")
    }

    public func setVolume(_ volume: Double) {
        let v = Int(max(0, min(100, volume)))
        _ = AppleScriptRunner.run("tell application \"Spotify\" to set sound volume to \(v)")
    }

    public func toggleShuffle() {
        _ = AppleScriptRunner.run(#"tell application "Spotify" to set shuffling to not shuffling"#)
    }

    public func cycleRepeatMode() {
        _ = AppleScriptRunner.run(#"tell application "Spotify" to set repeating to not repeating"#)
    }

    public func toggleLike() {
        // Spotify AppleScript dictionary does not expose library save directly; open track in Spotify
        _ = AppleScriptRunner.run(#"tell application "Spotify" to activate"#)
    }

    public func setPlaybackSpeed(_ rate: Double) {
        // Handled when supported by client
    }
}

// MARK: - Browser Media Driver (Safari & Chrome)

@MainActor
public final class BrowserMediaDriver: MediaProviderDriver {
    public let bundleIdentifier = "com.apple.Safari"
    public let displayName = "Web Browser"

    public var isRunning: Bool {
        AppleScriptRunner.isAppRunning(bundleID: "com.apple.Safari") ||
        AppleScriptRunner.isAppRunning(bundleID: "com.google.Chrome")
    }

    public func fetchState() async -> NowPlayingTrack? {
        // Only query browser tabs if the user explicitly chose Browser as their preferred media provider
        guard SettingsStore.shared.preferredMediaProvider == .browser else { return nil }

        if AppleScriptRunner.isAppRunning(bundleID: "com.google.Chrome") {
            let script = """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    set tTitle to title of active tab of front window
                    set tURL to URL of active tab of front window
                    return tTitle & "|||" & tURL
                end if
            end tell
            """
            if let desc = AppleScriptRunner.run(script), let raw = desc.stringValue {
                let parts = raw.components(separatedBy: "|||")
                if parts.count == 2, !parts[0].isEmpty {
                    let host = URL(string: parts[1])?.host ?? "Chrome"
                    return NowPlayingTrack(
                        title: parts[0],
                        artist: host,
                        album: "Google Chrome",
                        duration: 0,
                        elapsedTime: 0,
                        isPlaying: true,
                        sourceBundleID: "com.google.Chrome",
                        sourceAppName: "Chrome"
                    )
                }
            }
        }
        return nil
    }

    public func playPause() {}
    public func nextTrack() {}
    public func previousTrack() {}
    public func seek(to seconds: TimeInterval) {}
    public func setVolume(_ volume: Double) {}
    public func toggleShuffle() {}
    public func cycleRepeatMode() {}
    public func toggleLike() {}
    public func setPlaybackSpeed(_ rate: Double) {}
}

// MARK: - Central Media Manager

@MainActor
public final class MediaManager: ObservableObject {
    public static let shared = MediaManager()

    @Published public private(set) var currentTrack: NowPlayingTrack = NowPlayingTrack()
    @Published public private(set) var activeDriver: MediaProviderDriver?
    @Published public var playbackSpeed: Double = 1.0

    public var onTrackChangedQuickPeek: ((NowPlayingTrack) -> Void)?

    private let appleMusicDriver = AppleMusicDriver()
    private let spotifyDriver = SpotifyDriver()
    private let browserDriver = BrowserMediaDriver()

    private var interpolationTimer: Timer?
    private var lastNotifiedTrackKey: String = ""
    private var distributedObservers: [NSObjectProtocol] = []

    private init() {
        setupDistributedNotificationObservers()
        Task {
            await refreshNowPlaying()
        }
    }

    private func setupDistributedNotificationObservers() {
        let dnc = DistributedNotificationCenter.default()

        // Apple Music instant notification
        let musicObs = dnc.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo
            let name = userInfo?["Name"] as? String
            let artist = userInfo?["Artist"] as? String
            let album = userInfo?["Album"] as? String
            let state = userInfo?["Player State"] as? String
            let totalTimeMs = userInfo?["Total Time"] as? Double
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let name, let state {
                    let playing = state.lowercased() == "playing"
                    if self.currentTrack.title != name || self.currentTrack.artist != (artist ?? "") {
                        self.currentTrack.title = name
                        self.currentTrack.artist = artist ?? ""
                        self.currentTrack.album = album ?? ""
                        if let totalTimeMs {
                            self.currentTrack.duration = totalTimeMs / 1000.0
                        }
                    }
                    self.currentTrack.isPlaying = playing
                }
                await self.refreshNowPlaying()
            }
        }

        // Spotify instant notification
        let spotifyObs = dnc.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshNowPlaying()
            }
        }

        distributedObservers = [musicObs, spotifyObs]
    }

    public func refreshNowPlaying() async {
        guard SettingsStore.shared.enableMusic else {
            stopInterpolationTimer()
            return
        }

        let pref = SettingsStore.shared.preferredMediaProvider
        var orderedDrivers: [MediaProviderDriver] = []

        switch pref {
        case .appleMusic:
            orderedDrivers = [appleMusicDriver, spotifyDriver]
        case .spotify:
            orderedDrivers = [spotifyDriver, appleMusicDriver]
        case .browser:
            orderedDrivers = [browserDriver, appleMusicDriver, spotifyDriver]
        case .automatic:
            orderedDrivers = [appleMusicDriver, spotifyDriver, browserDriver]
        }

        var fallbackStoppedTrack: (NowPlayingTrack, MediaProviderDriver)?

        for driver in orderedDrivers {
            if let track = await driver.fetchState() {
                if track.isPlaying {
                    applyTrack(track, driver: driver)
                    return
                } else if fallbackStoppedTrack == nil && track.hasActiveTrack {
                    fallbackStoppedTrack = (track, driver)
                }
            }
        }

        if let (pausedTrack, driver) = fallbackStoppedTrack {
            applyTrack(pausedTrack, driver: driver)
        } else {
            stopInterpolationTimer()
        }
    }

    private func applyTrack(_ track: NowPlayingTrack, driver: MediaProviderDriver) {
        let trackKey = "\(track.sourceBundleID):\(track.title):\(track.artist)"
        let isNewSong = !lastNotifiedTrackKey.isEmpty && lastNotifiedTrackKey != trackKey && track.isPlaying
        lastNotifiedTrackKey = trackKey

        self.activeDriver = driver
        self.currentTrack = track

        if track.isPlaying {
            startInterpolationTimer()
        } else {
            stopInterpolationTimer()
        }

        if isNewSong {
            onTrackChangedQuickPeek?(track)
        }
    }

    private func startInterpolationTimer() {
        guard interpolationTimer == nil else { return }
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.currentTrack.isPlaying else { return }
                let next = self.currentTrack.elapsedTime + (0.5 * self.playbackSpeed)
                if self.currentTrack.duration > 0 && next <= self.currentTrack.duration {
                    self.currentTrack.elapsedTime = next
                } else if self.currentTrack.duration > 0 && next > self.currentTrack.duration {
                    await self.refreshNowPlaying()
                }
            }
        }
    }

    private func stopInterpolationTimer() {
        interpolationTimer?.invalidate()
        interpolationTimer = nil
    }

    // MARK: - Playback Controls

    public func togglePlayPause() {
        if let driver = activeDriver {
            driver.playPause()
            currentTrack.isPlaying.toggle()
            if currentTrack.isPlaying {
                startInterpolationTimer()
            } else {
                stopInterpolationTimer()
            }
            Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                await refreshNowPlaying()
            }
        } else {
            // If no active driver yet, try Apple Music or Spotify if running, or launch Music
            if appleMusicDriver.isRunning {
                appleMusicDriver.playPause()
            } else if spotifyDriver.isRunning {
                spotifyDriver.playPause()
            }
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await refreshNowPlaying()
            }
        }
    }

    public func nextTrack() {
        activeDriver?.nextTrack()
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await refreshNowPlaying()
        }
    }

    public func previousTrack() {
        activeDriver?.previousTrack()
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await refreshNowPlaying()
        }
    }

    public func seek(to progressFraction: Double) {
        guard currentTrack.duration > 0 else { return }
        let targetSeconds = max(0, min(currentTrack.duration, currentTrack.duration * progressFraction))
        currentTrack.elapsedTime = targetSeconds
        activeDriver?.seek(to: targetSeconds)
    }

    public func setVolume(_ newVolume: Double) {
        let clamped = max(0, min(100, newVolume))
        currentTrack.volume = clamped
        activeDriver?.setVolume(clamped)
    }

    public func toggleShuffle() {
        currentTrack.isShuffling.toggle()
        activeDriver?.toggleShuffle()
    }

    public func cycleRepeatMode() {
        switch currentTrack.repeatMode {
        case .off: currentTrack.repeatMode = .all
        case .all: currentTrack.repeatMode = .one
        case .one: currentTrack.repeatMode = .off
        }
        activeDriver?.cycleRepeatMode()
    }

    public func toggleLike() {
        currentTrack.isLiked.toggle()
        activeDriver?.toggleLike()
    }

    public func cyclePodcastSpeed() {
        let speeds: [Double] = [1.0, 1.25, 1.5, 2.0, 0.75]
        if let idx = speeds.firstIndex(of: playbackSpeed) {
            playbackSpeed = speeds[(idx + 1) % speeds.count]
        } else {
            playbackSpeed = 1.0
        }
        activeDriver?.setPlaybackSpeed(playbackSpeed)
    }

    public func openSourceApplication() {
        let bundleID = currentTrack.sourceBundleID
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Loads rich demo preview metadata only when explicitly triggered by the user from Onboarding or Settings Preview.
    public func loadInteractiveDemoTrack() {
        currentTrack = NowPlayingTrack(
            title: "Midnight Horizon",
            artist: "NotchFlow Synth Collective",
            album: "Dynamic Horizons (Lossless Edition)",
            duration: 218,
            elapsedTime: 64,
            isPlaying: true,
            playbackRate: 1.0,
            volume: 82,
            isShuffling: false,
            repeatMode: .all,
            isExplicit: false,
            isLossless: true,
            isDolbyAtmos: true,
            isPodcast: false,
            isLiked: true,
            artworkImage: NSApp.applicationIconImage,
            artworkURL: nil,
            dominantColor: Color(red: 0.22, green: 0.82, blue: 0.98),
            sourceBundleID: "com.apple.Music",
            sourceAppName: "Music"
        )
        startInterpolationTimer()
    }
}
