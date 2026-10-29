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

    private func observeMenuBarPreference() {
        SettingsStore.shared.$showMenuBarIcon
            .receive(on: RunLoop.main)
            .sink { [weak self] show in
                self?.statusItem?.isVisible = show
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
            button.toolTip = "NotchFlow — Dynamic Island for macOS"
        }

        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "NotchFlow — Dynamic Island", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        let toggleExpandItem = NSMenuItem(title: "Expand / Collapse Island", action: #selector(menuToggleExpand), keyEquivalent: "e")
        toggleExpandItem.target = self
        menu.addItem(toggleExpandItem)

        let cycleItem = NSMenuItem(title: "Cycle Island Activity", action: #selector(menuCycleActivity), keyEquivalent: "k")
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

        let testHUDItem = NSMenuItem(title: "Trigger Sample Volume HUD", action: #selector(menuTestVolumeHUD), keyEquivalent: "")
        testHUDItem.target = self
        menu.addItem(testHUDItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "NotchFlow Settings...", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let onboardingItem = NSMenuItem(title: "Welcome & Onboarding...", action: #selector(menuOpenOnboarding), keyEquivalent: "")
        onboardingItem.target = self
        menu.addItem(onboardingItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit NotchFlow", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
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

        let contentView = SettingsView { [weak self] in
            self?.openOnboardingWindow()
        }
        let hosting = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "NotchFlow Settings"
        window.appearance = NSAppearance(named: .darkAqua)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 780, height: 560))
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
        window.appearance = NSAppearance(named: .darkAqua)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.setContentSize(NSSize(width: 560, height: 470))
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
        settings.islandStyleMode = .simulatedPill
        settings.coloredOutline = true
        MediaManager.shared.loadInteractiveDemoTrack()

        // 1. Expanded Music Player Island Showcase
        IslandCoordinator.shared.expandIsland(to: .music)
        let musicBanner = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.14),
                    Color(red: 0.09, green: 0.12, blue: 0.24),
                    Color(red: 0.04, green: 0.05, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 16) {
                IslandContainerView(targetScreen: NSScreen.main, onOpenSettings: {})
                    .frame(width: 500, height: 265)
                Text("NotchFlow — Expanded Now Playing Studio & Live Waveform")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(24)
        }
        renderSwiftUIViewToPNG(musicBanner, size: CGSize(width: 680, height: 360), to: "\(directoryPath)/island-music-expanded.png")

        // 2. Expanded Calendar & Weather Island Showcase
        IslandCoordinator.shared.expandIsland(to: .calendar)
        let calendarBanner = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.14),
                    Color(red: 0.08, green: 0.14, blue: 0.22),
                    Color(red: 0.04, green: 0.05, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 16) {
                IslandContainerView(targetScreen: NSScreen.main, onOpenSettings: {})
                    .frame(width: 520, height: 305)
                Text("NotchFlow — Interactive Monthly Calendar & Local Weather")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(24)
        }
        renderSwiftUIViewToPNG(calendarBanner, size: CGSize(width: 680, height: 390), to: "\(directoryPath)/island-calendar-expanded.png")

        // 3. System Control Dashboard & HUD Showcase
        IslandCoordinator.shared.expandIsland(to: .systemHUD)
        let systemBanner = ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.14),
                    Color(red: 0.10, green: 0.10, blue: 0.22),
                    Color(red: 0.04, green: 0.05, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 16) {
                IslandContainerView(targetScreen: NSScreen.main, onOpenSettings: {})
                    .frame(width: 500, height: 265)
                Text("NotchFlow — System Controls, AirPods, Battery & Focus Mode")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(24)
        }
        renderSwiftUIViewToPNG(systemBanner, size: CGSize(width: 680, height: 360), to: "\(directoryPath)/island-system-controls.png")

        // 4. Settings Application Window
        let settingsView = SettingsView()
            .environment(\.colorScheme, .dark)
        renderSwiftUIViewToPNG(settingsView, size: CGSize(width: 800, height: 560), to: "\(directoryPath)/settings-window.png")

        // 5. Onboarding Experience Window
        let onboardingView = OnboardingView(onComplete: {})
            .environment(\.colorScheme, .dark)
        renderSwiftUIViewToPNG(onboardingView, size: CGSize(width: 560, height: 470), to: "\(directoryPath)/onboarding-window.png")
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
