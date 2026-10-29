import Foundation
import CoreAudio
import AudioToolbox
import SwiftUI
import Combine

@MainActor
public final class VolumeManager: ObservableObject {
    public static let shared = VolumeManager()

    @Published public private(set) var volume: Double = 0.5 // 0.0 ... 1.0
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var outputDeviceName: String = "Mac Speakers"
    @Published public private(set) var outputDeviceSymbol: String = "speaker.wave.2.fill"

    public var onVolumeHUDTriggered: ((SystemHUDPayload) -> Void)?
    public var onAudioOutputChanged: ((String, String) -> Void)?

    private var currentDeviceID: AudioObjectID = kAudioObjectUnknown
    private var isInternalUpdate = false
    private var hasInitialized = false

    private init() {
        updateDefaultOutputDevice(emitNotification: false)
        registerSystemDefaultDeviceListener()
        hasInitialized = true
    }

    public var volumeSymbolName: String {
        if isMuted || volume <= 0.001 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private func registerSystemDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateDefaultOutputDevice(emitNotification: true)
            }
        }
    }

    private func updateDefaultOutputDevice(emitNotification: Bool) {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else { return }

        let deviceChanged = (currentDeviceID != deviceID)
        currentDeviceID = deviceID

        let name = readDeviceName(deviceID: deviceID)
        let symbol = classifyDeviceSymbol(name: name, deviceID: deviceID)
        outputDeviceName = name
        outputDeviceSymbol = symbol

        readVolumeAndMute(deviceID: deviceID, emitHUD: false)

        if deviceChanged {
            registerDevicePropertyListeners(deviceID: deviceID)
            if emitNotification && hasInitialized && SettingsStore.shared.enableAudioDeviceHUD {
                onAudioOutputChanged?(name, symbol)
            }
        }
    }

    private func registerDevicePropertyListeners(deviceID: AudioObjectID) {
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &volAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isInternalUpdate else { return }
                self.readVolumeAndMute(deviceID: deviceID, emitHUD: true)
            }
        }

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &muteAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isInternalUpdate else { return }
                self.readVolumeAndMute(deviceID: deviceID, emitHUD: true)
            }
        }
    }

    private func readVolumeAndMute(deviceID: AudioObjectID, emitHUD: Bool) {
        let prevVol = volume
        let prevMute = isMuted

        // Read Virtual Main Volume
        var vol: Float32 = Float32(volume)
        var volSize = UInt32(MemoryLayout<Float32>.size)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(deviceID, &volAddress) {
            let status = AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &vol)
            if status == noErr {
                volume = Double(max(0.0, min(1.0, vol)))
            }
        }

        // Read Mute
        var muteVal: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(deviceID, &muteAddress) {
            let status = AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &muteVal)
            if status == noErr {
                isMuted = (muteVal != 0)
            }
        }

        if emitHUD && SettingsStore.shared.enableVolumeHUD {
            let changed = abs(prevVol - volume) > 0.005 || (prevMute != isMuted)
            if changed {
                emitVolumeHUD()
            }
        }
    }

    public func setSystemVolume(_ newVolume: Double, triggerHUD: Bool = false) {
        let clamped = max(0.0, min(1.0, newVolume))
        volume = clamped
        if clamped > 0.005 && isMuted {
            isMuted = false
        }

        guard currentDeviceID != kAudioObjectUnknown else {
            if triggerHUD { emitVolumeHUD() }
            return
        }

        isInternalUpdate = true
        defer {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                self.isInternalUpdate = false
            }
        }

        var vol = Float32(clamped)
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectHasProperty(currentDeviceID, &address) {
            AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, size, &vol)
        }

        if triggerHUD && SettingsStore.shared.enableVolumeHUD {
            emitVolumeHUD()
        }
    }

    public func toggleMute(triggerHUD: Bool = true) {
        let targetMute = !isMuted
        isMuted = targetMute

        if currentDeviceID != kAudioObjectUnknown {
            isInternalUpdate = true
            defer {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    self.isInternalUpdate = false
                }
            }

            var muteVal: UInt32 = targetMute ? 1 : 0
            let size = UInt32(MemoryLayout<UInt32>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectHasProperty(currentDeviceID, &address) {
                AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, size, &muteVal)
            }
        }

        if triggerHUD && SettingsStore.shared.enableVolumeHUD {
            emitVolumeHUD()
        }
    }

    public func emitVolumeHUD() {
        let pct = isMuted ? 0 : Int((volume * 100.0).rounded())
        let payload = SystemHUDPayload(
            kind: isMuted ? .mute : .volume,
            title: isMuted ? "Muted" : outputDeviceName,
            subtitle: outputDeviceName,
            symbolName: volumeSymbolName,
            progress: isMuted ? 0.0 : volume,
            valueText: isMuted ? "Mute" : "\(pct)%",
            tintColorName: isMuted ? "red" : "cyan"
        )
        onVolumeHUDTriggered?(payload)
    }

    private func readDeviceName(deviceID: AudioObjectID) -> String {
        var name: CFString = "Audio Output" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = withUnsafeMutablePointer(to: &name) { ptr in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
        }
        if status == noErr {
            return name as String
        }
        return "Mac Speakers"
    }

    private func classifyDeviceSymbol(name: String, deviceID: AudioObjectID) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods.gen3" }
        if lower.contains("homepod") { return "homepod.fill" }
        if lower.contains("beats") || lower.contains("headphone") { return "headphones" }
        if lower.contains("display") || lower.contains("hdmi") { return "display" }
        return "speaker.wave.2.fill"
    }
}
