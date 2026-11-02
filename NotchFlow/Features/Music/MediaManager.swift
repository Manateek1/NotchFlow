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
    private var isUsingDemoTracks: Bool = false
    private var demoTrackIndex: Int = 0
    @Published public private(set) var artworkFlipTrigger: Bool = false

    private init() {
        loadInteractiveDemoTrack(index: 0)
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

        self.isUsingDemoTracks = false
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
        } else if isUsingDemoTracks {
            currentTrack.isPlaying.toggle()
            if currentTrack.isPlaying {
                startInterpolationTimer()
            } else {
                stopInterpolationTimer()
            }
        } else {
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
        if let driver = activeDriver {
            driver.nextTrack()
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                await refreshNowPlaying()
            }
        } else if isUsingDemoTracks {
            demoTrackIndex = (demoTrackIndex + 1) % 3
            loadInteractiveDemoTrack(index: demoTrackIndex)
            onTrackChangedQuickPeek?(currentTrack)
        }
    }

    public func previousTrack() {
        if let driver = activeDriver {
            driver.previousTrack()
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                await refreshNowPlaying()
            }
        } else if isUsingDemoTracks {
            demoTrackIndex = (demoTrackIndex + 2) % 3
            loadInteractiveDemoTrack(index: demoTrackIndex)
            onTrackChangedQuickPeek?(currentTrack)
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

    /// Loads rich demo preview metadata when triggered from Onboarding, Settings Preview, or initial showcase.
    public func loadInteractiveDemoTrack(index: Int? = nil) {
        isUsingDemoTracks = true
        let idx = index ?? demoTrackIndex
        demoTrackIndex = idx
        artworkFlipTrigger.toggle()

        struct DemoSpec {
            let title: String
            let artist: String
            let album: String
            let duration: TimeInterval
            let elapsed: TimeInterval
            let topHex: (CGFloat, CGFloat, CGFloat)
            let midHex: (CGFloat, CGFloat, CGFloat)
            let botHex: (CGFloat, CGFloat, CGFloat)
            let accent: Color
        }

        let specs: [DemoSpec] = [
            DemoSpec(
                title: "Ocean Drive",
                artist: "Miami Nights",
                album: "Coastal Horizons",
                duration: 197,
                elapsed: 49,
                topHex: (0.14, 0.28, 0.44),
                midHex: (0.34, 0.58, 0.74),
                botHex: (0.86, 0.56, 0.46),
                accent: Color(red: 0.44, green: 0.68, blue: 0.82)
            ),
            DemoSpec(
                title: "Sunset Boulevard",
                artist: "The Midnight",
                album: "Endless Summer",
                duration: 242,
                elapsed: 84,
                topHex: (0.22, 0.14, 0.38),
                midHex: (0.68, 0.28, 0.52),
                botHex: (0.94, 0.58, 0.34),
                accent: Color(red: 0.88, green: 0.48, blue: 0.62)
            ),
            DemoSpec(
                title: "Awake",
                artist: "Tycho",
                album: "Dive",
                duration: 284,
                elapsed: 112,
                topHex: (0.12, 0.32, 0.36),
                midHex: (0.24, 0.62, 0.58),
                botHex: (0.76, 0.72, 0.54),
                accent: Color(red: 0.36, green: 0.76, blue: 0.68)
            )
        ]

        let spec = specs[idx % specs.count]
        let cover = Self.renderStudioAlbumArtwork(
            top: spec.topHex,
            mid: spec.midHex,
            bot: spec.botHex,
            seed: idx
        )

        currentTrack = NowPlayingTrack(
            title: spec.title,
            artist: spec.artist,
            album: spec.album,
            duration: spec.duration,
            elapsedTime: spec.elapsed,
            isPlaying: true,
            playbackRate: 1.0,
            volume: 82,
            isShuffling: false,
            repeatMode: .all,
            isExplicit: false,
            isLossless: true,
            isDolbyAtmos: true,
            isPodcast: false,
            isLiked: false,
            artworkImage: cover,
            artworkURL: nil,
            dominantColor: spec.accent,
            sourceBundleID: "com.apple.Music",
            sourceAppName: "Music"
        )
        startInterpolationTimer()
    }

    private static func renderStudioAlbumArtwork(
        top: (CGFloat, CGFloat, CGFloat),
        mid: (CGFloat, CGFloat, CGFloat),
        bot: (CGFloat, CGFloat, CGFloat),
        seed: Int
    ) -> NSImage {
        let size = NSSize(width: 240, height: 240)
        let img = NSImage(size: size)
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                CGColor(red: top.0, green: top.1, blue: top.2, alpha: 1.0),
                CGColor(red: mid.0, green: mid.1, blue: mid.2, alpha: 1.0),
                CGColor(red: bot.0, green: bot.1, blue: bot.2, alpha: 1.0)
            ] as CFArray
            let locations: [CGFloat] = [0.0, 0.52, 1.0]
            if let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
                ctx.drawLinearGradient(
                    grad,
                    start: CGPoint(x: 0, y: 240),
                    end: CGPoint(x: 240, y: 0),
                    options: []
                )
            }

            // Soft sun / moon halo + orb
            ctx.saveGState()
            let orbX: CGFloat = seed == 1 ? 148 : 108
            let orbY: CGFloat = 114
            ctx.setFillColor(CGColor(red: 1.0, green: 0.88, blue: 0.72, alpha: 0.24))
            ctx.fillEllipse(in: CGRect(x: orbX - 58, y: orbY - 58, width: 116, height: 116))
            ctx.setFillColor(CGColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 0.94))
            ctx.fillEllipse(in: CGRect(x: orbX - 36, y: orbY - 36, width: 72, height: 72))
            ctx.restoreGState()

            // Distant horizon mountain layer
            ctx.saveGState()
            let backPath = CGMutablePath()
            backPath.move(to: CGPoint(x: 0, y: 0))
            backPath.addLine(to: CGPoint(x: 0, y: 98))
            backPath.addQuadCurve(to: CGPoint(x: 132, y: 84), control: CGPoint(x: 68, y: 124))
            backPath.addQuadCurve(to: CGPoint(x: 240, y: 106), control: CGPoint(x: 188, y: 74))
            backPath.addLine(to: CGPoint(x: 240, y: 0))
            backPath.closeSubpath()
            ctx.setFillColor(CGColor(red: top.0 * 0.62, green: top.1 * 0.62, blue: top.2 * 0.68, alpha: 0.78))
            ctx.addPath(backPath)
            ctx.fillPath()
            ctx.restoreGState()

            // Foreground coastal ridge layer
            ctx.saveGState()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 76))
            path.addQuadCurve(to: CGPoint(x: 120, y: 64), control: CGPoint(x: 62, y: 94))
            path.addQuadCurve(to: CGPoint(x: 240, y: 82), control: CGPoint(x: 178, y: 48))
            path.addLine(to: CGPoint(x: 240, y: 0))
            path.closeSubpath()
            ctx.setFillColor(CGColor(red: top.0 * 0.36, green: top.1 * 0.38, blue: top.2 * 0.46, alpha: 0.96))
            ctx.addPath(path)
            ctx.fillPath()
            ctx.restoreGState()
        }
        img.unlockFocus()
        return img
    }
}
