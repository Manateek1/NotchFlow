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

    private var accent: Color {
        settings.accentColorPreset.primaryColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Row: Interactive Volume & Brightness Sliders
            HStack(spacing: 12) {
                // Volume Slider Card
                HStack(spacing: 8) {
                    Button {
                        volumeMgr.toggleMute(triggerHUD: false)
                    } label: {
                        Image(systemName: volumeMgr.volumeSymbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(volumeMgr.isMuted ? .red : accent)
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)

                    Slider(
                        value: Binding(
                            get: { volumeMgr.isMuted ? 0 : volumeMgr.volume },
                            set: { volumeMgr.setSystemVolume($0, triggerHUD: false) }
                        ),
                        in: 0...1
                    )
                    .tint(accent)
                    .controlSize(.small)

                    Text("\(Int((volumeMgr.isMuted ? 0 : volumeMgr.volume) * 100))%")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Brightness Slider Card
                HStack(spacing: 8) {
                    Image(systemName: brightnessMgr.brightnessSymbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.yellow)
                        .frame(width: 20)

                    Slider(
                        value: Binding(
                            get: { brightnessMgr.brightness },
                            set: { brightnessMgr.setBrightness($0, triggerHUD: false) }
                        ),
                        in: 0.05...1.0
                    )
                    .tint(.yellow)
                    .controlSize(.small)

                    Text("\(Int(brightnessMgr.brightness * 100))%")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Middle Row: Contextual Details Based on Active Tab
            HStack(spacing: 10) {
                // Weather Card
                if let weather = weatherMgr.currentWeather {
                    HStack(spacing: 10) {
                        Image(systemName: weather.symbolName)
                            .font(.system(size: 24))
                            .foregroundStyle(weather.symbolColor)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(weather.formattedTemperature(unit: settings.temperatureUnit))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(weather.conditionDescription)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                            Text("\(weather.locationName) • \(weather.formattedHighLow(unit: settings.temperatureUnit)) • Precip \(weather.precipitationProbability)%")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // Battery Card
                HStack(spacing: 10) {
                    Image(systemName: batteryMgr.state.symbolName)
                        .font(.system(size: 20))
                        .foregroundStyle(batteryMgr.state.statusColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(batteryMgr.state.percentage)% Battery")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(batteryMgr.state.statusSummary)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(9)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Bottom Row: Connected Audio Devices & Focus Mode Selector
            HStack(spacing: 10) {
                // Active Audio / AirPods Card
                HStack(spacing: 8) {
                    let dev = connectivityMgr.primaryAudioDevice
                    Image(systemName: dev?.symbolName ?? volumeMgr.outputDeviceSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 24, height: 24)
                        .background(accent.opacity(0.16), in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(dev?.name ?? volumeMgr.outputDeviceName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(dev?.batteryPercentage != nil ? "Connected • \(dev!.batteryPercentage!)% Battery" : (dev?.transportDescription ?? "Active Audio Output"))
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Focus Mode Quick Switcher
                Button {
                    focusMgr.cycleFocusProfile()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: focusMgr.activeProfile.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(focusMgr.isFocusActive ? .black : .white)
                            .frame(width: 24, height: 24)
                            .background(
                                focusMgr.isFocusActive ? focusMgr.activeProfile.tintColor : Color.white.opacity(0.12),
                                in: Circle()
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(focusMgr.activeProfile.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("Click to cycle Focus")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.white.opacity(0.52))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        focusMgr.isFocusActive
                            ? focusMgr.activeProfile.tintColor.opacity(0.18)
                            : Color.white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
