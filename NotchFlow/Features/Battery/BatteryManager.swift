import Foundation
import IOKit.ps
import SwiftUI
import Combine

public struct BatteryStateSnapshot: Equatable, Sendable {
    public var percentage: Int
    public var isCharging: Bool
    public var isPluggedIn: Bool
    public var isCharged: Bool
    public var isLowPowerMode: Bool
    public var timeToEmptyMinutes: Int?
    public var timeToFullMinutes: Int?
    public var powerSourceName: String

    public init(
        percentage: Int = 100,
        isCharging: Bool = false,
        isPluggedIn: Bool = true,
        isCharged: Bool = true,
        isLowPowerMode: Bool = false,
        timeToEmptyMinutes: Int? = nil,
        timeToFullMinutes: Int? = nil,
        powerSourceName: String = "AC Power"
    ) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.isCharged = isCharged
        self.isLowPowerMode = isLowPowerMode
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.timeToFullMinutes = timeToFullMinutes
        self.powerSourceName = powerSourceName
    }

    public var isLowBattery: Bool {
        percentage <= 20 && !isPluggedIn
    }

    public var symbolName: String {
        if isCharging {
            return "battery.100percent.bolt"
        }
        switch percentage {
        case 88...100: return "battery.100percent"
        case 63..<88: return "battery.75percent"
        case 38..<63: return "battery.50percent"
        case 15..<38: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    public var statusColor: Color {
        if isLowPowerMode { return .yellow }
        if isCharging || isCharged && isPluggedIn { return .green }
        if isLowBattery { return .red }
        return .white
    }

    public var statusSummary: String {
        if isCharging {
            if let mins = timeToFullMinutes, mins > 0 {
                return "Charging • \(mins / 60)h \(mins % 60)m to full"
            }
            return "Charging (\(powerSourceName))"
        }
        if isPluggedIn && isCharged {
            return "Fully Charged • Plugged In"
        }
        if let mins = timeToEmptyMinutes, mins > 0 {
            return "\(mins / 60)h \(mins % 60)m remaining"
        }
        return isPluggedIn ? "Plugged In" : "On Battery Power"
    }
}

@MainActor
public final class BatteryManager: ObservableObject {
    public static let shared = BatteryManager()

    @Published public private(set) var state: BatteryStateSnapshot = BatteryStateSnapshot()

    public var onBatteryHUDTriggered: ((SystemHUDPayload) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var hasInitialized = false

    private init() {
        refreshBatteryState(emitNotifications: false)
        hasInitialized = true
        setupPowerSourceNotification()

        NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshBatteryState(emitNotifications: true)
            }
        }
    }

    private func setupPowerSourceNotification() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let mgr = Unmanaged<BatteryManager>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in
                mgr.refreshBatteryState(emitNotifications: true)
            }
        }, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    public func refreshBatteryState(emitNotifications: Bool = false) {
        let previous = state
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let firstSource = list.first,
              let desc = IOPSGetPowerSourceDescription(blob, firstSource)?.takeUnretainedValue() as? [String: Any] else {
            // Desktop Mac without internal battery
            state = BatteryStateSnapshot(
                percentage: 100,
                isCharging: false,
                isPluggedIn: true,
                isCharged: true,
                isLowPowerMode: lowPower,
                powerSourceName: "AC Power"
            )
            return
        }

        let currentCap = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 100
        let maxCap = max(1, desc[kIOPSMaxCapacityKey as String] as? Int ?? 100)
        let pct = min(100, max(0, Int((Double(currentCap) / Double(maxCap)) * 100.0)))

        let powerState = desc[kIOPSPowerSourceStateKey as String] as? String ?? (kIOPSACPowerValue as String)
        let isPluggedIn = (powerState == (kIOPSACPowerValue as String))
        let isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
        let isCharged = (desc[kIOPSIsChargedKey as String] as? Bool) ?? (pct >= 100 && isPluggedIn)
        let timeToEmpty = desc[kIOPSTimeToEmptyKey as String] as? Int
        let timeToFull = desc[kIOPSTimeToFullChargeKey as String] as? Int

        let next = BatteryStateSnapshot(
            percentage: pct,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            isCharged: isCharged,
            isLowPowerMode: lowPower,
            timeToEmptyMinutes: (timeToEmpty ?? -1) > 0 ? timeToEmpty : nil,
            timeToFullMinutes: (timeToFull ?? -1) > 0 ? timeToFull : nil,
            powerSourceName: isPluggedIn ? "AC Power" : "Battery"
        )

        state = next

        guard emitNotifications && hasInitialized else { return }
        let settings = SettingsStore.shared

        // 1. Charger connected / disconnected
        if previous.isPluggedIn != next.isPluggedIn && settings.enableChargingNotifications {
            let payload = SystemHUDPayload(
                kind: .batteryCharging,
                title: next.isPluggedIn ? "Charging Connected" : "On Battery Power",
                subtitle: "\(next.percentage)% Battery",
                symbolName: next.symbolName,
                progress: Double(next.percentage) / 100.0,
                valueText: "\(next.percentage)%",
                tintColorName: next.isPluggedIn ? "green" : "orange"
            )
            onBatteryHUDTriggered?(payload)
        }
        // 2. Low battery threshold crossed
        else if !previous.isLowBattery && next.isLowBattery && settings.enableBatteryHUD {
            let payload = SystemHUDPayload(
                kind: .batteryLow,
                title: "Low Battery",
                subtitle: "\(next.percentage)% remaining",
                symbolName: "battery.25percent",
                progress: Double(next.percentage) / 100.0,
                valueText: "\(next.percentage)%",
                tintColorName: "red"
            )
            onBatteryHUDTriggered?(payload)
        }
        // 3. Fully charged reached
        else if !previous.isCharged && next.isCharged && next.isPluggedIn && settings.enableChargingNotifications {
            let payload = SystemHUDPayload(
                kind: .batteryFull,
                title: "Battery Fully Charged",
                subtitle: "100% • MagSafe / USB-C",
                symbolName: "battery.100percent.bolt",
                progress: 1.0,
                valueText: "100%",
                tintColorName: "green"
            )
            onBatteryHUDTriggered?(payload)
        }
        // 4. Low Power Mode toggled
        else if previous.isLowPowerMode != next.isLowPowerMode && settings.enableBatteryHUD {
            let payload = SystemHUDPayload(
                kind: .powerMode,
                title: next.isLowPowerMode ? "Low Power Mode On" : "Low Power Mode Off",
                subtitle: "\(next.percentage)% Battery",
                symbolName: "battery.100percent",
                progress: Double(next.percentage) / 100.0,
                valueText: next.isLowPowerMode ? "On" : "Off",
                tintColorName: next.isLowPowerMode ? "yellow" : "green"
            )
            onBatteryHUDTriggered?(payload)
        }
    }
}
