import SwiftUI
import AppKit

public struct ExpandedSystemDashboardView: View {
    public let selectedTab: IslandActivityKind

    @ObservedObject var volumeMgr = VolumeManager.shared
    @ObservedObject var brightnessMgr = BrightnessManager.shared
    @ObservedObject var batteryMgr = BatteryManager.shared
    @ObservedObject var connectivityMgr = ConnectivityManager.shared
    @ObservedObject var weatherMgr = WeatherManager.shared
    @ObservedObject var focusMgr = FocusManager.shared
    @ObservedObject var settings = SettingsStore.shared

    public init(selectedTab: IslandActivityKind) {
        self.selectedTab = selectedTab
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Row: Thumb-less iOS Control Center Volume & Display Sliders
            HStack(spacing: 10) {
                // Sound / Volume Pill Card
                ControlCenterSliderCard(
                    symbol: volumeMgr.volumeSymbolName,
                    symbolColor: volumeMgr.isMuted ? Color(red: 0.96, green: 0.36, blue: 0.36) : .white,
                    value: Binding(
                        get: { volumeMgr.isMuted ? 0 : volumeMgr.volume },
                        set: { volumeMgr.setSystemVolume($0, triggerHUD: false) }
                    ),
                    barColor: volumeBarColor(for: volumeMgr.isMuted ? 0 : volumeMgr.volume),
                    glow: settings.hudBarTheme == .glow,
                    onIconTap: { volumeMgr.toggleMute(triggerHUD: false) }
                )

                // Display Brightness Pill Card
                ControlCenterSliderCard(
                    symbol: brightnessMgr.brightnessSymbolName,
                    symbolColor: Color(red: 0.98, green: 0.82, blue: 0.32),
                    value: Binding(
                        get: { brightnessMgr.brightness },
                        set: { brightnessMgr.setBrightness($0, triggerHUD: false) }
                    ),
                    range: 0.05...1.0,
                    barColor: brightnessBarColor,
                    glow: settings.hudBarTheme == .glow,
                    onIconTap: nil
                )
            }

            // Middle Row: Weather & Battery Bento Tiles
            HStack(spacing: 10) {
                // Weather Tile
                HStack(spacing: 10) {
                    let w = weatherMgr.currentWeather
                    Image(systemName: w?.symbolName ?? "cloud.sun.fill")
                        .font(.system(size: 21))
                        .foregroundStyle(w?.symbolColor ?? Color(red: 0.98, green: 0.80, blue: 0.28))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(w?.formattedTemperature(unit: settings.temperatureUnit) ?? "72°")
                                .font(.system(size: 15, weight: .bold).monospacedDigit())
                                .foregroundStyle(.white)
                            Text(w?.conditionDescription ?? "Partly Cloudy")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.68))
                                .lineLimit(1)
                        }
                        Text("\(w?.locationName ?? "Local") • \(w?.formattedHighLow(unit: settings.temperatureUnit) ?? "H:74° L:58°")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.44))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Battery Tile
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(batteryMgr.state.statusColor.opacity(0.24), lineWidth: 2.5)
                            .frame(width: 26, height: 26)
                        Circle()
                            .trim(from: 0, to: CGFloat(batteryMgr.state.percentage) / 100.0)
                            .stroke(batteryMgr.state.statusColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 26, height: 26)
                        Image(systemName: batteryMgr.state.isCharging ? "bolt.fill" : "battery.100")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(batteryMgr.state.statusColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(batteryMgr.state.percentage)% Battery")
                            .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                        Text(batteryMgr.state.statusSummary)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.46))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Bottom Row: Audio Route / AirPods & Focus Mode Bento Tiles
            HStack(spacing: 10) {
                // Audio / AirPods Tile
                HStack(spacing: 10) {
                    let dev = connectivityMgr.primaryAudioDevice
                    let cleanName = cleanDeviceName(dev?.name ?? volumeMgr.outputDeviceName)
                    Image(systemName: dev?.symbolName ?? volumeMgr.outputDeviceSymbol)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(cleanName)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(dev?.batteryPercentage != nil ? "Connected • \(dev!.batteryPercentage!)%" : "Audio Output")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Focus Mode Tile
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        focusMgr.cycleFocusProfile()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: focusMgr.activeProfile.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(focusMgr.isFocusActive ? .white : .white.opacity(0.75))
                            .frame(width: 26, height: 26)
                            .background(
                                focusMgr.isFocusActive
                                    ? Color(red: 0.46, green: 0.40, blue: 0.94)
                                    : Color.white.opacity(0.12),
                                in: Circle()
                            )
                            .contentTransition(.symbolEffect(.replace))

                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(focusMgr.activeProfile.title)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(focusMgr.isFocusActive ? "Active Focus" : "Click to enable")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.45))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        focusMgr.isFocusActive
                            ? Color(red: 0.46, green: 0.40, blue: 0.94).opacity(0.22)
                            : Color.white.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cleanDeviceName(_ raw: String) -> String {
        // Strip verbose Bluetooth suffixes like " - Find My" so device names fit cleanly
        var name = raw
        if let range = name.range(of: " - ") {
            name = String(name[..<range.lowerBound])
        }
        if name.localizedCaseInsensitiveContains("MacBook") && name.localizedCaseInsensitiveContains("Speaker") {
            return "MacBook Speakers"
        }
        return name
    }

    private func volumeBarColor(for level: Double) -> Color {
        switch settings.hudBarTheme {
        case .white:
            return .white
        case .accent:
            return settings.accentColorPreset.primaryColor
        case .glow:
            if level > 0.80 {
                return Color(red: 0.96, green: 0.46, blue: 0.34)
            }
            return Color(red: 0.94, green: 0.56, blue: 0.36)
        }
    }

    private var brightnessBarColor: Color {
        switch settings.hudBarTheme {
        case .white:
            return .white
        case .accent:
            return settings.accentColorPreset.primaryColor
        case .glow:
            return Color(red: 0.98, green: 0.80, blue: 0.34)
        }
    }
}

private struct ControlCenterSliderCard: View {
    let symbol: String
    let symbolColor: Color
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    let barColor: Color
    let glow: Bool
    let onIconTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let onIconTap {
                Button(action: onIconTap) {
                    Image(systemName: symbol)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(symbolColor)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(symbolColor)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 20)
            }

            TouchPillSlider(
                value: $value,
                range: range,
                fillColor: barColor,
                height: 6.5,
                glowEffect: glow
            )

            Text("\(Int(round(value * 100)))%")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.56))
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
