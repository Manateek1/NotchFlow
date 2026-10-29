import AppKit
import CoreGraphics

public extension NSScreen {
    /// Unique CoreGraphics DirectDisplayID for this screen.
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }

    /// String identifier suitable for persistence in SettingsStore.
    var persistentDisplayID: String {
        "\(displayID)"
    }

    /// True if this screen is the built-in laptop panel.
    var isBuiltInDisplay: Bool {
        CGDisplayIsBuiltin(displayID) != 0
    }

    /// True if this screen has a physical camera housing notch at the top.
    var hasPhysicalNotch: Bool {
        if #available(macOS 12.0, *) {
            return safeAreaInsets.top > 0
        }
        return false
    }

    /// Returns the exact width and height of the physical camera notch, or standard simulated dimensions if notchless.
    var notchSize: CGSize {
        if hasPhysicalNotch,
           let leftArea = auxiliaryTopLeftArea,
           let rightArea = auxiliaryTopRightArea {
            let calculatedWidth = frame.width - (leftArea.width + rightArea.width)
            let width = max(160, min(260, calculatedWidth))
            let height = max(30, safeAreaInsets.top)
            return CGSize(width: width, height: height)
        }
        // Standard sleek pill/notch baseline dimensions on notchless displays
        return CGSize(width: 188, height: 32)
    }

    /// Human-readable display label for Settings.
    var displayLabel: String {
        let suffix = hasPhysicalNotch ? " (Notch)" : (isBuiltInDisplay ? " (Built-in)" : "")
        return "\(localizedName)\(suffix)"
    }
}
