import Foundation
import IOKit
import CoreAudio
import SwiftUI
import Combine

public struct ConnectedAudioDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let symbolName: String
    public let isConnected: Bool
    public let isActiveOutput: Bool
    public let batteryPercentage: Int?
    public let caseBatteryPercentage: Int?
    public let transportDescription: String

    public init(
        id: String,
        name: String,
        symbolName: String,
        isConnected: Bool,
        isActiveOutput: Bool,
        batteryPercentage: Int? = nil,
        caseBatteryPercentage: Int? = nil,
        transportDescription: String = "Bluetooth"
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.isConnected = isConnected
        self.isActiveOutput = isActiveOutput
        self.batteryPercentage = batteryPercentage
        self.caseBatteryPercentage = caseBatteryPercentage
        self.transportDescription = transportDescription
    }
}

@MainActor
public final class ConnectivityManager: ObservableObject {
    public static let shared = ConnectivityManager()

    @Published public private(set) var connectedDevices: [ConnectedAudioDevice] = []
    @Published public private(set) var primaryAudioDevice: ConnectedAudioDevice?

    public var onConnectivityHUDTriggered: ((SystemHUDPayload) -> Void)?

    private var knownConnectedIDs: Set<String> = []
    private var hasInitialized = false

    private init() {
        refreshConnectedDevices(emitNotifications: false)
        hasInitialized = true

        // Hook into VolumeManager's audio output change callback
        VolumeManager.shared.onAudioOutputChanged = { [weak self] name, symbol in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshConnectedDevices(emitNotifications: true)
                if SettingsStore.shared.enableAudioDeviceHUD {
                    let payload = SystemHUDPayload(
                        kind: .audioOutput,
                        title: name,
                        subtitle: "Audio Output Connected",
                        symbolName: symbol,
                        progress: self.primaryAudioDevice?.batteryPercentage.map { Double($0) / 100.0 },
                        valueText: self.primaryAudioDevice?.batteryPercentage.map { "\($0)%" } ?? "Active",
                        tintColorName: "cyan"
                    )
                    self.onConnectivityHUDTriggered?(payload)
                }
            }
        }
    }

    public func refreshConnectedDevices(emitNotifications: Bool = false) {
        let registryBatteries = readIORegistryBluetoothBatteries()
        let activeOutputName = VolumeManager.shared.outputDeviceName
        var results: [ConnectedAudioDevice] = []

        // Enumerate CoreAudio output devices and classify transport (Bluetooth, AirPlay, USB, Built-in)
        let audioDevices = enumerateCoreAudioOutputDevices()
        for dev in audioDevices {
            let symbol = Self.symbolForDeviceName(dev.name)
            let battery = registryBatteries.first(where: {
                dev.name.localizedCaseInsensitiveContains($0.key) || $0.key.localizedCaseInsensitiveContains(dev.name)
            })?.value
            let isActive = activeOutputName.localizedCaseInsensitiveContains(dev.name)

            results.append(
                ConnectedAudioDevice(
                    id: "audio-\(dev.id)",
                    name: dev.name,
                    symbolName: symbol,
                    isConnected: true,
                    isActiveOutput: isActive,
                    batteryPercentage: battery,
                    transportDescription: dev.transportName
                )
            )
        }

        // Also include any Bluetooth HID devices with battery levels from IORegistry not already listed
        for (prodName, pct) in registryBatteries {
            if !results.contains(where: { $0.name.localizedCaseInsensitiveContains(prodName) }) {
                results.append(
                    ConnectedAudioDevice(
                        id: "bt-\(prodName)",
                        name: prodName,
                        symbolName: Self.symbolForDeviceName(prodName),
                        isConnected: true,
                        isActiveOutput: false,
                        batteryPercentage: pct,
                        transportDescription: "Bluetooth"
                    )
                )
            }
        }

        // Always ensure at least the primary active output device is present
        if results.isEmpty {
            let symbol = VolumeManager.shared.outputDeviceSymbol
            results.append(
                ConnectedAudioDevice(
                    id: "coreaudio-default",
                    name: activeOutputName,
                    symbolName: symbol,
                    isConnected: true,
                    isActiveOutput: true,
                    batteryPercentage: registryBatteries[activeOutputName],
                    transportDescription: "System Output"
                )
            )
        }

        let currentIDs = Set(results.map { $0.id })
        if emitNotifications && hasInitialized && SettingsStore.shared.enableConnectivityHUD {
            let newlyConnected = results.filter { !knownConnectedIDs.contains($0.id) && $0.id != "coreaudio-default" }
            if let firstNew = newlyConnected.first {
                let pctText = firstNew.batteryPercentage.map { "\($0)%" } ?? "Connected"
                let payload = SystemHUDPayload(
                    kind: .connectivity,
                    title: firstNew.name,
                    subtitle: firstNew.batteryPercentage != nil ? "Connected • Battery \(pctText)" : "\(firstNew.transportDescription) Connected",
                    symbolName: firstNew.symbolName,
                    progress: firstNew.batteryPercentage.map { Double($0) / 100.0 },
                    valueText: pctText,
                    tintColorName: "cyan"
                )
                onConnectivityHUDTriggered?(payload)
            }
        }

        knownConnectedIDs = currentIDs
        connectedDevices = results
        primaryAudioDevice = results.first(where: { $0.isActiveOutput }) ?? results.first
    }

    public static func symbolForDeviceName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods.gen3" }
        if lower.contains("homepod") { return "homepod.fill" }
        if lower.contains("beats") { return "beats.headphones" }
        if lower.contains("headphone") || lower.contains("buds") || lower.contains("sony") || lower.contains("bose") {
            return "headphones"
        }
        if lower.contains("mouse") || lower.contains("trackpad") {
            return "magicmouse.fill"
        }
        if lower.contains("keyboard") {
            return "keyboard.fill"
        }
        if lower.contains("display") || lower.contains("hdmi") {
            return "display"
        }
        return "speaker.wave.2.fill"
    }

    private func enumerateCoreAudioOutputDevices() -> [(id: AudioObjectID, name: String, transportName: String)] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr,
              dataSize > 0 else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return []
        }

        var outputDevices: [(id: AudioObjectID, name: String, transportName: String)] = []

        for id in deviceIDs {
            // Check if device has output streams
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streamAddress, 0, nil, &streamSize) == noErr,
                  streamSize > 0 else {
                continue
            }

            // Read name
            var name: CFString = "Audio Device" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            let nameStatus = withUnsafeMutablePointer(to: &name) { ptr in
                AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, ptr)
            }
            let deviceName = (nameStatus == noErr) ? (name as String) : "Audio Device"

            // Read transport type
            var transport: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            var transportAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectGetPropertyData(id, &transportAddress, 0, nil, &transportSize, &transport)

            let transportDesc: String
            switch transport {
            case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
                transportDesc = "Bluetooth Audio"
            case kAudioDeviceTransportTypeAirPlay:
                transportDesc = "AirPlay"
            case kAudioDeviceTransportTypeUSB:
                transportDesc = "USB Audio"
            case kAudioDeviceTransportTypeDisplayPort, kAudioDeviceTransportTypeHDMI:
                transportDesc = "Display Audio"
            default:
                transportDesc = "Built-in Audio"
            }

            outputDevices.append((id: id, name: deviceName, transportName: transportDesc))
        }

        return outputDevices
    }

    private func readIORegistryBluetoothBatteries() -> [String: Int] {
        var map: [String: Int] = [:]
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("AppleDeviceManagementHIDEventService"),
            &iterator
        )
        guard result == kIOReturnSuccess else { return map }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            var propsRef: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &propsRef, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let props = propsRef?.takeRetainedValue() as? [String: Any] {
                let product = (props["Product"] as? String) ?? "Bluetooth Device"
                if let pct = props["BatteryPercent"] as? Int {
                    map[product] = pct
                } else if let left = props["BatteryPercentLeft"] as? Int,
                          let right = props["BatteryPercentRight"] as? Int {
                    map[product] = min(left > 0 ? left : 100, right > 0 ? right : 100)
                }
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return map
    }
}
