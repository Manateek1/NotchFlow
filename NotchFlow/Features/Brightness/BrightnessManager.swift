import Foundation
import IOKit
import IOKit.graphics
import AppKit
import SwiftUI
import Combine

@MainActor
public final class BrightnessManager: ObservableObject {
    public static let shared = BrightnessManager()

    @Published public private(set) var brightness: Double = 0.80 // 0.0 ... 1.0
    @Published public private(set) var isHardwareSupported: Bool = true
    @Published public private(set) var activeDisplayName: String = "Built-in Display"

    public var onBrightnessHUDTriggered: ((SystemHUDPayload) -> Void)?

    private init() {
        refreshFromHardware()
    }

    public var brightnessSymbolName: String {
        brightness < 0.45 ? "sun.min.fill" : "sun.max.fill"
    }

    public func refreshFromHardware() {
        activeDisplayName = NSScreen.main?.localizedName ?? "Display"
        if let hwVal = readIOKitBrightness() {
            brightness = Double(max(0.0, min(1.0, hwVal)))
            isHardwareSupported = true
        } else {
            isHardwareSupported = NSScreen.main?.isBuiltInDisplay ?? false
        }
    }

    public func setBrightness(_ newValue: Double, triggerHUD: Bool = true) {
        let clamped = max(0.02, min(1.0, newValue))
        brightness = clamped
        _ = writeIOKitBrightness(Float(clamped))

        if triggerHUD && SettingsStore.shared.enableBrightnessHUD {
            emitBrightnessHUD()
        }
    }

    public func stepBrightness(by delta: Double) {
        setBrightness(brightness + delta, triggerHUD: true)
    }

    public func emitBrightnessHUD() {
        let pct = Int((brightness * 100.0).rounded())
        let payload = SystemHUDPayload(
            kind: .brightness,
            title: activeDisplayName,
            subtitle: "Brightness",
            symbolName: brightnessSymbolName,
            progress: brightness,
            valueText: "\(pct)%",
            tintColorName: "yellow"
        )
        onBrightnessHUDTriggered?(payload)
    }

    private func readIOKitBrightness() -> Float? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var value: Float = 0
            let err = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &value)
            IOObjectRelease(service)
            if err == kIOReturnSuccess {
                return value
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    private func writeIOKitBrightness(_ value: Float) -> Bool {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == kIOReturnSuccess else { return false }
        defer { IOObjectRelease(iterator) }

        var wroteAny = false
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let err = IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, value)
            IOObjectRelease(service)
            if err == kIOReturnSuccess {
                wroteAny = true
            }
            service = IOIteratorNext(iterator)
        }
        return wroteAny
    }
}
