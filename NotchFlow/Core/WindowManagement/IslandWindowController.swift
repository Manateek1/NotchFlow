import AppKit
import SwiftUI
import Combine

@MainActor
public final class IslandWindowController: ObservableObject {
    public static let shared = IslandWindowController()

    private var panels: [CGDirectDisplayID: NotchIslandPanel] = [:]
    private var globalMouseMoveMonitor: Any?
    private var localMouseMoveMonitor: Any?
    private var globalClickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    public var onRequestOpenSettings: (() -> Void)?

    private init() {
        setupScreenAndSpaceObservers()
        setupMouseMonitors()
        setupSettingsBinding()
    }

    public func start() {
        rebuildPanels()
        checkFullscreenState()
    }

    private func setupSettingsBinding() {
        let settings = SettingsStore.shared

        Publishers.CombineLatest3(
            settings.$isEnabled,
            settings.$preferredDisplayID,
            settings.$showOnAllDisplays
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _ in
            self?.rebuildPanels()
        }
        .store(in: &cancellables)
    }

    private func setupScreenAndSpaceObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rebuildPanels()
                BrightnessManager.shared.refreshFromHardware()
            }
        }

        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkFullscreenState()
            }
        }

        wsnc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkFullscreenState()
            }
        }
    }

    public func rebuildPanels() {
        let settings = SettingsStore.shared
        guard settings.isEnabled else {
            for (_, panel) in panels {
                panel.orderOut(nil)
            }
            return
        }

        let targetScreens = resolveTargetScreens()
        let activeIDs = Set(targetScreens.map { $0.displayID })

        // Remove panels for disconnected or deselected screens
        for (id, panel) in panels where !activeIDs.contains(id) {
            panel.orderOut(nil)
            panels.removeValue(forKey: id)
        }

        // Create or reposition panels for active screens
        for screen in targetScreens {
            let id = screen.displayID
            if let existing = panels[id] {
                existing.reposition(on: screen) { [weak self] in
                    self?.onRequestOpenSettings?()
                }
                existing.orderFrontRegardless()
            } else {
                let panel = NotchIslandPanel(screen: screen) { [weak self] in
                    self?.onRequestOpenSettings?()
                }
                panel.orderFrontRegardless()
                panels[id] = panel
            }
        }
    }

    private func resolveTargetScreens() -> [NSScreen] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return [] }

        let settings = SettingsStore.shared
        if settings.showOnAllDisplays {
            return screens
        }

        let pref = settings.preferredDisplayID
        if pref == "builtIn", let builtIn = screens.first(where: { $0.isBuiltInDisplay }) {
            return [builtIn]
        }
        if let matched = screens.first(where: { $0.persistentDisplayID == pref }) {
            return [matched]
        }
        // Prefer notched screen or main screen
        if let notched = screens.first(where: { $0.hasPhysicalNotch }) {
            return [notched]
        }
        return [NSScreen.main ?? screens[0]]
    }

    private func setupMouseMonitors() {
        let handleCursorPosition: () -> Void = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let mouseLoc = NSEvent.mouseLocation
                let isInsideAny = self.panels.values.contains { $0.isScreenPointInsideActiveIsland(mouseLoc) }

                let coord = IslandCoordinator.shared
                if isInsideAny && !coord.isHoveringIsland {
                    coord.onMouseEntered()
                } else if !isInsideAny && coord.isHoveringIsland {
                    coord.onMouseExited()
                }
            }
        }

        globalMouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { _ in
            handleCursorPosition()
        }

        localMouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { event in
            handleCursorPosition()
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let mouseLoc = NSEvent.mouseLocation
                let isInsideAny = self.panels.values.contains { $0.isScreenPointInsideActiveIsland(mouseLoc) }
                if !isInsideAny {
                    IslandCoordinator.shared.handleOutsideClick()
                }
            }
        }
    }

    public func checkFullscreenState() {
        // Check if the active space has a fullscreen window covering the primary screen
        guard let screen = resolveTargetScreens().first else { return }
        let screenFrame = screen.frame

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            IslandCoordinator.shared.updateFullscreenState(false)
            return
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        var foundFullscreenWindow = false

        for info in windowInfoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID != myPID,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let w = boundsDict["Width"],
                  let h = boundsDict["Height"] else {
                continue
            }

            if abs(w - screenFrame.width) < 2 && abs(h - screenFrame.height) < 2 {
                // Verify menu bar is hidden / fullscreen space active
                let ownerName = (info[kCGWindowOwnerName as String] as? String) ?? ""
                if ownerName != "Dock" && ownerName != "WindowManager" && ownerName != "SystemUIServer" {
                    foundFullscreenWindow = true
                    break
                }
            }
        }

        IslandCoordinator.shared.updateFullscreenState(foundFullscreenWindow)
    }
}
