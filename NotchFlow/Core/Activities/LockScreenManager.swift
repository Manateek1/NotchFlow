import Foundation
import AppKit
import Combine

@MainActor
public final class LockScreenManager: ObservableObject {
    public static let shared = LockScreenManager()

    @Published public private(set) var isScreenLocked: Bool = false
    @Published public private(set) var isScreenSaverActive: Bool = false
    @Published public private(set) var isUnlockTransitioning: Bool = false

    public var onLockStateChanged: ((Bool) -> Void)?
    public var onScreenSaverChanged: ((Bool) -> Void)?

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        let dnc = DistributedNotificationCenter.default()

        dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isScreenLocked = true
                self.isUnlockTransitioning = false
                self.onLockStateChanged?(true)
            }
        }

        dnc.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isScreenLocked = false
                self.isScreenSaverActive = false
                self.isUnlockTransitioning = true
                self.onLockStateChanged?(false)

                try? await Task.sleep(nanoseconds: 1_800_000_000)
                self.isUnlockTransitioning = false
            }
        }

        dnc.addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isScreenSaverActive = true
                self?.onScreenSaverChanged?(true)
            }
        }

        dnc.addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isScreenSaverActive = false
                self?.onScreenSaverChanged?(false)
            }
        }

        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isScreenLocked = true
                self?.onLockStateChanged?(true)
            }
        }

        wsnc.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.isScreenLocked {
                    self.onLockStateChanged?(false)
                }
            }
        }
    }

    public func simulateUnlockAnimationPreview() {
        guard SettingsStore.shared.enableLockScreenAnimation else { return }
        isUnlockTransitioning = true
        onLockStateChanged?(false)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.isUnlockTransitioning = false
        }
    }
}
