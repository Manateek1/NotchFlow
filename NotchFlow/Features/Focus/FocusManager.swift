import Foundation
import SwiftUI
import Combine

public enum FocusProfile: String, CaseIterable, Codable, Identifiable, Sendable {
    case off = "off"
    case doNotDisturb = "doNotDisturb"
    case work = "work"
    case personal = "personal"
    case sleep = "sleep"
    case coding = "coding"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: return "Focus Off"
        case .doNotDisturb: return "Do Not Disturb"
        case .work: return "Work"
        case .personal: return "Personal"
        case .sleep: return "Sleep"
        case .coding: return "Deep Coding"
        }
    }

    public var symbolName: String {
        switch self {
        case .off: return "moon"
        case .doNotDisturb: return "moon.fill"
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .sleep: return "bed.double.fill"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        }
    }

    public var tintColorName: String {
        switch self {
        case .off: return "white"
        case .doNotDisturb: return "indigo"
        case .work: return "cyan"
        case .personal: return "purple"
        case .sleep: return "orange"
        case .coding: return "green"
        }
    }

    public var tintColor: Color {
        switch self {
        case .off: return .secondary
        case .doNotDisturb: return .indigo
        case .work: return .cyan
        case .personal: return .purple
        case .sleep: return .orange
        case .coding: return .green
        }
    }
}

@MainActor
public final class FocusManager: ObservableObject {
    public static let shared = FocusManager()

    @Published public private(set) var activeProfile: FocusProfile = .off

    public var onFocusHUDTriggered: ((SystemHUDPayload) -> Void)?

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "nf.activeFocusProfile"),
           let profile = FocusProfile(rawValue: saved) {
            activeProfile = profile
        }
        setupDistributedFocusListeners()
    }

    public var isFocusActive: Bool {
        activeProfile != .off
    }

    private func setupDistributedFocusListeners() {
        let dnc = DistributedNotificationCenter.default()

        dnc.addObserver(
            forName: NSNotification.Name("_NSDoNotDisturbEnabledNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setFocusProfile(.doNotDisturb, triggerHUD: true)
            }
        }

        dnc.addObserver(
            forName: NSNotification.Name("_NSDoNotDisturbDisabledNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.setFocusProfile(.off, triggerHUD: true)
            }
        }
    }

    public func setFocusProfile(_ profile: FocusProfile, triggerHUD: Bool = true) {
        let changed = (activeProfile != profile)
        activeProfile = profile
        UserDefaults.standard.set(profile.rawValue, forKey: "nf.activeFocusProfile")

        guard changed && triggerHUD && SettingsStore.shared.enableFocusHUD else { return }

        let payload = SystemHUDPayload(
            kind: .focusMode,
            title: profile == .off ? "Focus Turned Off" : "\(profile.title) On",
            subtitle: profile == .off ? "Notifications Resumed" : "Focus Mode Active",
            symbolName: profile.symbolName,
            progress: nil,
            valueText: profile == .off ? "Off" : "On",
            tintColorName: profile.tintColorName
        )
        onFocusHUDTriggered?(payload)
    }

    public func cycleFocusProfile() {
        let all = FocusProfile.allCases
        if let idx = all.firstIndex(of: activeProfile) {
            let next = all[(idx + 1) % all.count]
            setFocusProfile(next, triggerHUD: true)
        }
    }
}
