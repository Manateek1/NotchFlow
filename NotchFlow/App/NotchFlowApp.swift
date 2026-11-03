import SwiftUI
import AppKit
import Combine

@main
public struct NotchFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    public init() {}

    public var body: some Scene {
        Settings {
            SettingsView {
                appDelegate.openOnboardingWindow()
            }
        }
    }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var powerMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return
        }

        let settings = SettingsStore.shared

        IslandWindowController.shared.onRequestOpenSettings = { [weak self] in
            self?.openSettingsWindow()
        }
        IslandWindowController.shared.start()

        setupMenuBarStatusItem()
        observeMenuBarPreference()

        let args = ProcessInfo.processInfo.arguments
        if let exportIdx = args.firstIndex(of: "--export-screenshots"), exportIdx + 1 < args.count {
            let outputDir = args[exportIdx + 1]
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.exportAppScreenshots(to: outputDir)
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if args.contains("--demo-music") {
            MediaManager.shared.loadInteractiveDemoTrack()
            IslandCoordinator.shared.expandIsland(to: .music)
        } else if args.contains("--demo-calendar") {
            IslandCoordinator.shared.expandIsland(to: .calendar)
        } else if args.contains("--demo-hud") {
            VolumeManager.shared.emitVolumeHUD()
        }

        if args.contains("--open-onboarding") || !settings.hasCompletedOnboarding {
            openOnboardingWindow()
        } else if args.contains("--open-settings") || !settings.startMinimized {
            openSettingsWindow()
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openSettingsWindow()
        } else {
            settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    private func observeMenuBarPreference() {
        SettingsStore.shared.$showMenuBarIcon
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                self?.statusItem?.isVisible = show
            }
            .store(in: &cancellables)

        SettingsStore.shared.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.powerMenuItem?.title = enabled ? "Turn NotchFlow Off" : "Turn NotchFlow On"
                self?.powerMenuItem?.state = enabled ? .on : .off
                self?.statusItem?.button?.alphaValue = enabled ? 1.0 : 0.45
                IslandCoordinator.shared.recalculateRestingState()
            }
            .store(in: &cancellables)
    }

    private func setupMenuBarStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = SettingsStore.shared.showMenuBarIcon

        if let button = item.button {
            let img = NSImage(systemSymbolName: "capsule.portrait.tophalf.filled", accessibilityDescription: "NotchFlow")
                ?? NSImage(systemSymbolName: "waveform", accessibilityDescription: "NotchFlow")
            img?.isTemplate = true
            button.image = img
            button.alphaValue = SettingsStore.shared.isEnabled ? 1.0 : 0.45
            button.toolTip = "NotchFlow — Dynamic Island for macOS"
        }

        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "NotchFlow — Dynamic Island", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        let powerItem = NSMenuItem(
            title: SettingsStore.shared.isEnabled ? "Turn NotchFlow Off" : "Turn NotchFlow On",
            action: #selector(menuTogglePower),
            keyEquivalent: "t"
        )
        powerItem.target = self
        powerItem.state = SettingsStore.shared.isEnabled ? .on : .off
        menu.addItem(powerItem)
        self.powerMenuItem = powerItem

        menu.addItem(.separator())

        let toggleExpandItem = NSMenuItem(title: "Expand / Collapse Island", action: #selector(menuToggleExpand), keyEquivalent: "e")
        toggleExpandItem.target = self
        menu.addItem(toggleExpandItem)

        let cycleItem = NSMenuItem(title: "Switch Island Activity", action: #selector(menuCycleActivity), keyEquivalent: "k")
        cycleItem.target = self
        menu.addItem(cycleItem)

        let duoItem = NSMenuItem(title: "Toggle Duo Mode", action: #selector(menuToggleDuoMode), keyEquivalent: "d")
        duoItem.target = self
        menu.addItem(duoItem)

        menu.addItem(.separator())

        let playPauseItem = NSMenuItem(title: "Play / Pause Media", action: #selector(menuPlayPause), keyEquivalent: "p")
        playPauseItem.target = self
        menu.addItem(playPauseItem)

        let nextTrackItem = NSMenuItem(title: "Next Track", action: #selector(menuNextTrack), keyEquivalent: "]")
        nextTrackItem.target = self
        menu.addItem(nextTrackItem)

        let prevTrackItem = NSMenuItem(title: "Previous Track", action: #selector(menuPreviousTrack), keyEquivalent: "[")
        prevTrackItem.target = self
        menu.addItem(prevTrackItem)

        menu.addItem(.separator())

        let demoItem = NSMenuItem(title: "Load Demo Track Preview", action: #selector(menuLoadDemoTrack), keyEquivalent: "")
        demoItem.target = self
        menu.addItem(demoItem)

        let testHUDItem = NSMenuItem(title: "Trigger Volume Glow HUD", action: #selector(menuTestVolumeHUD), keyEquivalent: "")
        testHUDItem.target = self
        menu.addItem(testHUDItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let onboardingItem = NSMenuItem(title: "Welcome Guide...", action: #selector(menuOpenOnboarding), keyEquivalent: "")
        onboardingItem.target = self
        menu.addItem(onboardingItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit NotchFlow", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    @objc private func menuTogglePower() {
        SettingsStore.shared.isEnabled.toggle()
        IslandCoordinator.shared.recalculateRestingState()
    }

    @objc private func menuToggleExpand() {
        IslandCoordinator.shared.toggleExpandCollapse()
    }

    @objc private func menuCycleActivity() {
        IslandCoordinator.shared.cycleActivity()
    }

    @objc private func menuToggleDuoMode() {
        SettingsStore.shared.enableDuoMode.toggle()
        IslandCoordinator.shared.recalculateRestingState()
    }

    @objc private func menuPlayPause() {
        MediaManager.shared.togglePlayPause()
    }

    @objc private func menuNextTrack() {
        MediaManager.shared.nextTrack()
    }

    @objc private func menuPreviousTrack() {
        MediaManager.shared.previousTrack()
    }

    @objc private func menuLoadDemoTrack() {
        MediaManager.shared.loadInteractiveDemoTrack()
        IslandCoordinator.shared.expandIsland(to: .music)
    }

    @objc private func menuTestVolumeHUD() {
        VolumeManager.shared.emitVolumeHUD()
    }

    @objc private func menuOpenSettings() {
        openSettingsWindow()
    }

    @objc private func menuOpenOnboarding() {
        openOnboardingWindow()
    }

    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }

    public func openSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView(initialSection: .general) { [weak self] in
            self?.openOnboardingWindow()
        }
        let hosting = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "NotchFlow"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 670, height: 610))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.settingsWindow = window
    }

    public func openOnboardingWindow() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = OnboardingView { [weak self] in
            self?.onboardingWindow?.close()
            self?.openSettingsWindow()
        }
        let hosting = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to NotchFlow"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 540, height: 450))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.onboardingWindow = window
    }

    // MARK: - Automated Visual Snapshot Exporter

    public func exportAppScreenshots(to directoryPath: String) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)

        let settings = SettingsStore.shared
        settings.islandStyleMode = .realNotch
        settings.cornerStyle = .classicNotch
        settings.showContrastOutline = false
        settings.coloredOutline = false
        settings.hudBarTheme = .glow
        settings.hudHideLabel = true
        settings.showHUDPercentageText = false
        MediaManager.shared.loadInteractiveDemoTrack(index: 0)

        let wallpaperGradient = LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.56, blue: 0.38),
                Color(red: 0.94, green: 0.44, blue: 0.42),
                Color(red: 0.88, green: 0.30, blue: 0.44)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // 1. Expanded Now Playing Studio (Flush at y = 0 with Concave Top Ears)
        IslandCoordinator.shared.expandIsland(to: .music)
        let musicShowcase = ZStack(alignment: .top) {
            wallpaperGradient
            IslandContainerView(targetScreen: NSScreen.main, onOpenSettings: {})
                .frame(width: 680, height: 340, alignment: .top)
        }
        renderSwiftUIViewToPNG(musicShowcase, size: CGSize(width: 680, height: 340), to: "\(directoryPath)/island-music-expanded.png")

        // 2. Expanded Calendar & Weather Studio (Flush at y = 0 with Concave Top Ears)
        IslandCoordinator.shared.expandIsland(to: .calendar)
        let calendarShowcase = ZStack(alignment: .top) {
            wallpaperGradient
            IslandContainerView(targetScreen: NSScreen.main, onOpenSettings: {})
                .frame(width: 680, height: 360, alignment: .top)
        }
        renderSwiftUIViewToPNG(calendarShowcase, size: CGSize(width: 680, height: 360), to: "\(directoryPath)/island-calendar-expanded.png")

        // 3. System Volume Glow HUD + Expanded Control Center Showcase
        VolumeManager.shared.isMuted = false
        VolumeManager.shared.volume = 0.72
        IslandCoordinator.shared.presentSystemHUD(
            SystemHUDPayload(
                kind: .volume,
                title: "Volume",
                subtitle: nil,
                symbolName: "speaker.wave.2.fill",
                progress: 0.78,
                valueText: "78%",
                tintColorName: "orange"
            )
        )
        IslandCoordinator.shared.withIslandAnimation {
            // Reset overshoot immediately for crisp static snapshot
        }
        let hudAndControlsShowcase = ZStack(alignment: .top) {
            wallpaperGradient
            VStack(spacing: 28) {
                // Top: Flush Horizontal Volume Glow HUD
                IslandContainerView(targetScreen: NSScreen.main, onOpenSettings: {})
                    .frame(width: 680, height: 60, alignment: .top)

                // Below: Expanded Control Center Bento View
                ExpandedSystemDashboardView(selectedTab: .systemHUD)
                    .padding(24)
                    .frame(width: 446)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: Color.black.opacity(0.45), radius: 22, y: 10)
            }
        }
        renderSwiftUIViewToPNG(hudAndControlsShowcase, size: CGSize(width: 680, height: 360), to: "\(directoryPath)/island-system-controls.png")

        // 4. Native macOS Settings Window (Framed on Warm Wallpaper with Traffic Lights)
        let settingsFramed = ZStack {
            wallpaperGradient
            ZStack(alignment: .topLeading) {
                SettingsView(initialSection: .display)
                    .frame(width: 660, height: 615)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
                    )
                    .shadow(color: Color.black.opacity(0.48), radius: 28, y: 14)

                // Simulated macOS Window Traffic Lights
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                    Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 12, height: 12)
                }
                .padding(.leading, 18)
                .padding(.top, 16)
            }
        }
        renderSwiftUIViewToPNG(settingsFramed, size: CGSize(width: 780, height: 685), to: "\(directoryPath)/settings-window.png")

        // 5. Onboarding Experience Window
        let onboardingFramed = ZStack {
            wallpaperGradient
            OnboardingView(onComplete: {})
                .frame(width: 540, height: 450)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.48), radius: 28, y: 14)
        }
        renderSwiftUIViewToPNG(onboardingFramed, size: CGSize(width: 660, height: 530), to: "\(directoryPath)/onboarding-window.png")
    }

    private func renderSwiftUIViewToPNG<V: View>(_ view: V, size: CGSize, to path: String) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let pngData = rep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: path))
        }
    }
}
