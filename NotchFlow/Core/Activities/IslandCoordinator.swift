import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
public final class IslandCoordinator: ObservableObject {
    public static let shared = IslandCoordinator()

    // MARK: - Published Island State
    @Published public private(set) var displayState: IslandDisplayState = .compactPill
    @Published public var primaryActivity: IslandActivityKind = .music
    @Published public var secondaryDuoActivity: IslandActivityKind = .calendar
    @Published public var expandedTab: IslandActivityKind = .music

    @Published public private(set) var activeHUD: SystemHUDPayload?
    @Published public private(set) var hudOvershootAmount: CGFloat = 0
    @Published public private(set) var currentQuickPeek: QuickPeekNotification?
    @Published public private(set) var isHoveringIsland: Bool = false
    @Published public private(set) var isFullscreenAppActive: Bool = false

    // Dependencies
    public let settings = SettingsStore.shared
    public let media = MediaManager.shared
    public let calendar = CalendarManager.shared
    public let weather = WeatherManager.shared
    public let battery = BatteryManager.shared
    public let volume = VolumeManager.shared
    public let brightness = BrightnessManager.shared
    public let connectivity = ConnectivityManager.shared
    public let focus = FocusManager.shared
    public let lockScreen = LockScreenManager.shared

    private var quickPeekQueue: [QuickPeekNotification] = []
    private var hudDismissTask: Task<Void, Never>?
    private var quickPeekDismissTask: Task<Void, Never>?
    private var hoverExpandTask: Task<Void, Never>?
    private var autoCollapseTask: Task<Void, Never>?
    private var stateBeforeTransient: IslandDisplayState?
    private var lastSwipeTimestamp: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    private init() {
        primaryActivity = settings.preferredIdleActivity
        expandedTab = (primaryActivity == .minimal) ? .music : primaryActivity

        wireSystemCallbacks()
        observeSettingsAndSystemState()
        recalculateRestingState()
    }

    private func wireSystemCallbacks() {
        // 1. Track change -> QuickPeek notification
        media.onTrackChangedQuickPeek = { [weak self] track in
            guard let self, self.settings.enableMusic else { return }
            let peek = QuickPeekNotification(
                category: .music,
                priority: IslandActivityKind.music.defaultPriority,
                title: track.title,
                subtitle: track.artist,
                badgeText: track.isDolbyAtmos ? "ATMOS" : (track.isLossless ? "LOSSLESS" : "NOW PLAYING"),
                symbolName: "waveform",
                accentColor: "cyan",
                duration: self.settings.quickPeekDuration
            )
            self.enqueueQuickPeek(peek)
        }

        // 2. Upcoming Calendar meeting -> QuickPeek notification
        calendar.onUpcomingMeetingAlert = { [weak self] event in
            guard let self, self.settings.enableCalendar else { return }
            let peek = QuickPeekNotification(
                category: .calendar,
                priority: IslandActivityKind.calendar.defaultPriority + 15,
                title: event.title,
                subtitle: "Starts \(event.countdownText()) • \(event.calendarTitle)",
                badgeText: event.meetingURL != nil ? "JOIN" : "UPCOMING",
                symbolName: "calendar.badge.clock",
                accentColor: "orange",
                duration: max(4.0, self.settings.quickPeekDuration)
            )
            self.enqueueQuickPeek(peek)
        }

        // 3. Volume HUD
        volume.onVolumeHUDTriggered = { [weak self] payload in
            self?.presentSystemHUD(payload)
        }

        // 4. Brightness HUD
        brightness.onBrightnessHUDTriggered = { [weak self] payload in
            self?.presentSystemHUD(payload)
        }

        // 5. Battery HUD
        battery.onBatteryHUDTriggered = { [weak self] payload in
            self?.presentSystemHUD(payload)
        }

        // 6. Connectivity / Audio Device HUD
        connectivity.onConnectivityHUDTriggered = { [weak self] payload in
            self?.presentSystemHUD(payload)
        }

        // 7. Focus HUD
        focus.onFocusHUDTriggered = { [weak self] payload in
            self?.presentSystemHUD(payload)
        }

        // 8. Lock Screen & Screen Saver transitions
        lockScreen.onLockStateChanged = { [weak self] isLocked in
            guard let self else { return }
            if isLocked {
                self.hudDismissTask?.cancel()
                self.quickPeekDismissTask?.cancel()
                if self.settings.enableLockScreenAnimation {
                    self.withIslandAnimation {
                        self.displayState = .locked
                    }
                } else {
                    self.recalculateRestingState()
                }
            } else {
                if self.settings.enableLockScreenAnimation {
                    self.withIslandAnimation {
                        self.displayState = .locked
                    }
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        self?.recalculateRestingState()
                    }
                } else {
                    self.recalculateRestingState()
                }
            }
        }
    }

    private func observeSettingsAndSystemState() {
        settings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recalculateRestingState()
                }
            }
            .store(in: &cancellables)

        media.$currentTrack
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.displayState != .expanded && self.displayState != .systemHUD && self.displayState != .quickPeek {
                        self.recalculateRestingState()
                    }
                }
            }
            .store(in: &cancellables)

        calendar.$currentOrNextEvent
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if self.displayState != .expanded && self.displayState != .systemHUD && self.displayState != .quickPeek {
                        self.recalculateRestingState()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - State Calculation

    public func recalculateRestingState(forceCollapseExpanded: Bool = false) {
        guard settings.isEnabled else {
            withIslandAnimation { displayState = .hidden }
            return
        }

        if settings.hideInFullscreen && isFullscreenAppActive {
            withIslandAnimation { displayState = .hidden }
            return
        }

        if lockScreen.isScreenLocked && settings.enableLockScreenAnimation {
            withIslandAnimation { displayState = .locked }
            return
        }

        if activeHUD != nil {
            withIslandAnimation { displayState = .systemHUD }
            return
        }

        if currentQuickPeek != nil {
            withIslandAnimation { displayState = .quickPeek }
            return
        }

        if displayState == .expanded && !forceCollapseExpanded {
            return
        }

        // Determine if Duo Mode should be active
        let hasMusic = settings.enableMusic && (media.currentTrack.isPlaying || media.currentTrack.hasActiveTrack)
        let hasSecondary = (settings.enableCalendar && calendar.currentOrNextEvent != nil) ||
                           (settings.enableWeather && weather.currentWeather != nil)

        if settings.enableDuoMode && hasMusic && hasSecondary && settings.idleVisibility == .alwaysVisible {
            primaryActivity = .music
            secondaryDuoActivity = (settings.enableCalendar && calendar.currentOrNextEvent != nil) ? .calendar : .weather
            withIslandAnimation { displayState = .duoMode }
            return
        }

        switch settings.idleVisibility {
        case .autoHideWhenInactive:
            if hasMusic || (settings.enableCalendar && calendar.currentOrNextEvent != nil) {
                withIslandAnimation { displayState = .compactPill }
            } else {
                withIslandAnimation { displayState = .minimalIdle }
            }
        case .minimalPill:
            if media.currentTrack.isPlaying {
                primaryActivity = .music
                withIslandAnimation { displayState = .compactPill }
            } else {
                withIslandAnimation { displayState = .minimalIdle }
            }
        case .alwaysVisible:
            withIslandAnimation { displayState = .compactPill }
        }
    }

    public func updateFullscreenState(_ isFullscreen: Bool) {
        guard isFullscreenAppActive != isFullscreen else { return }
        isFullscreenAppActive = isFullscreen
        recalculateRestingState()
    }

    // MARK: - System HUD Presentation

    public func presentSystemHUD(_ payload: SystemHUDPayload) {
        guard settings.isEnabled else { return }
        if settings.hideInFullscreen && isFullscreenAppActive { return }

        hudDismissTask?.cancel()

        if displayState != .systemHUD && displayState != .quickPeek {
            stateBeforeTransient = displayState
        }

        withIslandAnimation {
            activeHUD = payload
            displayState = .systemHUD
            if settings.enableHUDOvershoot {
                hudOvershootAmount = 8.0
            }
        }

        if settings.enableHUDOvershoot {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 140_000_000)
                guard let self else { return }
                self.withIslandAnimation {
                    self.hudOvershootAmount = 0
                }
            }
        }

        hudDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_100_000_000)
            guard !Task.isCancelled, let self else { return }
            self.withIslandAnimation {
                self.activeHUD = nil
            }
            if let prev = self.stateBeforeTransient, prev == .expanded {
                self.withIslandAnimation { self.displayState = .expanded }
            } else {
                self.recalculateRestingState()
            }
            self.stateBeforeTransient = nil
        }
    }

    // MARK: - QuickPeek Priority Queue

    public func enqueueQuickPeek(_ notification: QuickPeekNotification) {
        guard settings.isEnabled else { return }
        if settings.hideInFullscreen && isFullscreenAppActive { return }
        if displayState == .expanded { return }

        // Insert sorted by priority descending
        quickPeekQueue.append(notification)
        quickPeekQueue.sort { $0.priority > $1.priority }

        if let current = currentQuickPeek {
            if notification.priority > current.priority {
                quickPeekDismissTask?.cancel()
                showNextQuickPeek()
            }
        } else {
            showNextQuickPeek()
        }
    }

    public func dismissQuickPeek() {
        quickPeekDismissTask?.cancel()
        withIslandAnimation {
            currentQuickPeek = nil
        }
        if !quickPeekQueue.isEmpty {
            showNextQuickPeek()
        } else {
            recalculateRestingState()
        }
    }

    private func showNextQuickPeek() {
        guard !quickPeekQueue.isEmpty else {
            withIslandAnimation { currentQuickPeek = nil }
            recalculateRestingState()
            return
        }

        let next = quickPeekQueue.removeFirst()
        withIslandAnimation {
            currentQuickPeek = next
            displayState = .quickPeek
        }

        let nanos = UInt64(max(1.5, next.duration) * 1_000_000_000)
        quickPeekDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled, let self else { return }
            self.withIslandAnimation {
                self.currentQuickPeek = nil
            }
            if !self.quickPeekQueue.isEmpty {
                self.showNextQuickPeek()
            } else {
                self.recalculateRestingState()
            }
        }
    }

    // MARK: - User Interactions (Hover, Click, Gestures)

    public func onMouseEntered() {
        isHoveringIsland = true
        autoCollapseTask?.cancel()

        guard settings.expandOnHover, displayState != .expanded, displayState != .hidden else { return }

        hoverExpandTask?.cancel()
        let delayNanos = UInt64(max(0.05, settings.hoverDelay) * 1_000_000_000)
        hoverExpandTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard !Task.isCancelled, let self, self.isHoveringIsland else { return }
            self.expandIsland()
        }
    }

    public func onMouseExited() {
        isHoveringIsland = false
        hoverExpandTask?.cancel()

        guard displayState == .expanded else { return }
        scheduleAutoCollapse()
    }

    private func scheduleAutoCollapse() {
        autoCollapseTask?.cancel()
        let delayNanos = UInt64(max(1.5, settings.autoDismissDelay) * 1_000_000_000)
        autoCollapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard !Task.isCancelled, let self, !self.isHoveringIsland else { return }
            self.collapseIsland()
        }
    }

    public func toggleExpandCollapse() {
        if displayState == .expanded {
            collapseIsland()
        } else {
            expandIsland()
        }
    }

    public func expandIsland(to tab: IslandActivityKind? = nil) {
        hoverExpandTask?.cancel()
        hudDismissTask?.cancel()
        quickPeekDismissTask?.cancel()
        activeHUD = nil
        currentQuickPeek = nil

        if let tab {
            expandedTab = tab
        } else if primaryActivity != .minimal {
            expandedTab = primaryActivity
        } else {
            expandedTab = .music
        }

        withIslandAnimation {
            displayState = .expanded
        }
    }

    public func collapseIsland() {
        hoverExpandTask?.cancel()
        autoCollapseTask?.cancel()
        withIslandAnimation {
            activeHUD = nil
            currentQuickPeek = nil
        }
        recalculateRestingState(forceCollapseExpanded: true)
    }

    public func handleOutsideClick() {
        guard settings.clickOutsideToDismiss, displayState == .expanded else { return }
        collapseIsland()
    }

    public func handleMiddleClick() {
        switch settings.middleClickAction {
        case .cycleActivities:
            cycleActivity()
        case .playPauseMedia:
            media.togglePlayPause()
        case .toggleExpand:
            toggleExpandCollapse()
        case .none:
            break
        }
    }

    public func cycleActivity() {
        let cycleOrder: [IslandActivityKind] = [.music, .calendar, .weather, .battery, .connectivity, .focus]
        if displayState == .expanded {
            if let idx = cycleOrder.firstIndex(of: expandedTab) {
                withIslandAnimation {
                    expandedTab = cycleOrder[(idx + 1) % cycleOrder.count]
                }
            } else {
                withIslandAnimation { expandedTab = .music }
            }
        } else {
            if let idx = cycleOrder.firstIndex(of: primaryActivity) {
                withIslandAnimation {
                    primaryActivity = cycleOrder[(idx + 1) % cycleOrder.count]
                    expandedTab = primaryActivity
                    if displayState == .minimalIdle || displayState == .duoMode {
                        displayState = .compactPill
                    }
                }
            } else {
                withIslandAnimation {
                    primaryActivity = .music
                    displayState = .compactPill
                }
            }
        }
    }

    public func handleScrollSwipe(deltaX: CGFloat, deltaY: CGFloat) {
        guard settings.enableSwipeGestures else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSwipeTimestamp > 0.38 else { return }

        let threshold: CGFloat = 18.0
        if abs(deltaX) > abs(deltaY) && abs(deltaX) > threshold {
            lastSwipeTimestamp = now
            let goNext = settings.naturalSwipeDirection ? (deltaX < 0) : (deltaX > 0)
            if (displayState == .compactPill && primaryActivity == .music) ||
               (displayState == .expanded && expandedTab == .music) {
                if goNext {
                    media.nextTrack()
                } else {
                    media.previousTrack()
                }
            } else {
                cycleActivity()
            }
        } else if abs(deltaY) > threshold {
            lastSwipeTimestamp = now
            if deltaY > 0 && displayState != .expanded {
                expandIsland()
            } else if deltaY < 0 && displayState == .expanded {
                collapseIsland()
            } else if deltaY < 0 && displayState == .quickPeek {
                dismissQuickPeek()
            }
        }
    }

    // MARK: - Animation Wrapper

    public func withIslandAnimation(_ body: () -> Void) {
        let reduceMotion = settings.respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion || settings.animationSpeed == .instant {
            withAnimation(.easeInOut(duration: 0.12), body)
        } else {
            let preset = settings.animationSpeed
            withAnimation(.spring(response: preset.response, dampingFraction: preset.dampingFraction, blendDuration: 0.12), body)
        }
    }

    // MARK: - Geometry Computation for Hit-Testing & Layout

    public func currentIslandSize(for screen: NSScreen?) -> CGSize {
        let baseNotch = screen?.notchSize ?? CGSize(width: 188, height: 32)
        let widthAdj = CGFloat(settings.compactWidthAdjustment)
        let heightAdj = CGFloat(settings.compactHeightAdjustment)
        let scale = CGFloat(settings.expandedScale)

        switch displayState {
        case .hidden:
            return CGSize(width: 1, height: 1)
        case .minimalIdle:
            return CGSize(
                width: max(140, baseNotch.width + 16 + widthAdj * 0.5),
                height: max(28, baseNotch.height + heightAdj * 0.5)
            )
        case .compactPill:
            return CGSize(
                width: max(220, baseNotch.width + 104 + widthAdj),
                height: max(32, baseNotch.height + 4 + heightAdj)
            )
        case .duoMode:
            return CGSize(
                width: max(296, baseNotch.width + 168 + widthAdj),
                height: max(34, baseNotch.height + 6 + heightAdj)
            )
        case .systemHUD:
            return CGSize(
                width: max(280, baseNotch.width + 148 + hudOvershootAmount * 2),
                height: max(42, baseNotch.height + 16 + hudOvershootAmount * 0.4)
            )
        case .quickPeek:
            return CGSize(
                width: max(336, baseNotch.width + 184),
                height: max(58, baseNotch.height + 30)
            )
        case .locked:
            return CGSize(
                width: max(240, baseNotch.width + 92),
                height: max(40, baseNotch.height + 12)
            )
        case .expanded:
            let baseW: CGFloat = (expandedTab == .calendar) ? 470 : 436
            let baseH: CGFloat = (expandedTab == .calendar) ? 286 : 238
            return CGSize(width: baseW * scale, height: baseH * scale)
        }
    }
}
