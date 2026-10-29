import SwiftUI
import AppKit

public struct OnboardingView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var calendarMgr = CalendarManager.shared
    @ObservedObject var weatherMgr = WeatherManager.shared
    @ObservedObject var coordinator = IslandCoordinator.shared
    @ObservedObject var mediaMgr = MediaManager.shared

    @State private var currentStep: Int = 0
    public var onComplete: () -> Void

    private let totalSteps = 6

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    private var accent: Color {
        settings.accentColorPreset.primaryColor
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Interactive Island Preview Banner
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.11),
                        Color(red: 0.09, green: 0.11, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 12) {
                    // Simulated Notch Preview
                    HStack(spacing: 14) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(accent.opacity(0.3))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(accent)
                                )
                            WaveformVisualizerView(
                                isPlaying: true,
                                style: settings.waveformStyle,
                                accentColor: accent,
                                barCount: 4,
                                height: 14
                            )
                        }

                        Spacer()
                            .frame(width: 80)

                        HStack(spacing: 5) {
                            Image(systemName: "cloud.sun.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.yellow)
                            Text("72°")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(width: 280, height: 34)
                    .background(Color.black, in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(accent.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: accent.opacity(0.25), radius: 14, y: 4)

                    Text("Live Dynamic Island Active at Top of Screen")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(height: 120)

            // Step Content Area
            VStack(alignment: .leading, spacing: 16) {
                stepContent(for: currentStep)
                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(red: 0.08, green: 0.09, blue: 0.13))

            Divider()
                .background(Color.white.opacity(0.12))

            // Footer Navigation Bar
            HStack {
                // Step Dots
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentStep ? accent : Color.white.opacity(0.25))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer()

                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep -= 1
                        }
                    }
                }

                Button("Skip Setup") {
                    finishOnboarding()
                }
                .foregroundStyle(.white.opacity(0.65))
                .buttonStyle(.plain)
                .padding(.horizontal, 8)

                Button(currentStep == totalSteps - 1 ? "Get Started" : "Continue") {
                    if currentStep < totalSteps - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep += 1
                        }
                    } else {
                        finishOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(red: 0.06, green: 0.07, blue: 0.10))
        }
        .frame(width: 560, height: 470)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func stepContent(for step: Int) -> some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 12) {
                Label("Welcome to NotchFlow", systemImage: "sparkles")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("NotchFlow transforms your Mac's camera notch (or top bezel on notchless monitors) into an interactive, fluid Dynamic Island.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    featureBullet(icon: "waveform", title: "Live Now Playing & Waveforms", detail: "Real-time playback controls, album art glow, and audio visualizers.")
                    featureBullet(icon: "calendar.badge.clock", title: "Schedule & Meeting Countdowns", detail: "Expandable monthly calendar with 1-click video call join buttons.")
                    featureBullet(icon: "slider.horizontal.3", title: "Sleek System HUDs & Duo Mode", detail: "Non-intrusive notch indicators for Volume, Brightness, Battery, AirPods, and Focus.")
                }
                .padding(.top, 4)
            }

        case 1:
            VStack(alignment: .leading, spacing: 12) {
                Label("Interacting with the Island", systemImage: "hand.tap.fill")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("NotchFlow is designed to stay out of your way until you need it, without ever stealing keyboard focus from your active app.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    featureBullet(icon: "cursorarrow.motionlines", title: "Hover or Click to Expand", detail: "Move your cursor over the notch or click it to open the full studio panel.")
                    featureBullet(icon: "hand.draw.fill", title: "Two-Finger Trackpad Swipes", detail: "Swipe horizontally on the island to skip tracks or cycle widgets; swipe down to expand.")
                    featureBullet(icon: "computermouse.fill", title: "Middle-Click & Duo Mode", detail: "Middle-click to cycle between Music, Calendar, Weather, and System controls.")
                }

                Toggle("Expand automatically when hovering over the island", isOn: $settings.expandOnHover)
                    .padding(.top, 4)
            }

        case 2:
            VStack(alignment: .leading, spacing: 12) {
                Label("Music & Media Integration", systemImage: "music.note.list")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("NotchFlow connects natively to Apple Music and Spotify using macOS distributed notifications and AppleEvents when those apps are running.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)

                Picker("Preferred Media Player", selection: $settings.preferredMediaProvider) {
                    ForEach(MediaProviderPreference.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }

                Picker("Waveform Visualizer Style", selection: $settings.waveformStyle) {
                    ForEach(WaveformVisualStyle.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }

                Button("Test Interactive Demo Track in Island Now") {
                    mediaMgr.loadInteractiveDemoTrack()
                    coordinator.expandIsland(to: .music)
                }
                .controlSize(.small)
            }

        case 3:
            VStack(alignment: .leading, spacing: 12) {
                Label("Calendar & Schedule Access", systemImage: "calendar")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Grant optional Calendar access so NotchFlow can show your next upcoming meeting countdown, monthly calendar grid, and 1-click Join buttons for Zoom/Meet/Teams.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)

                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("EventKit Calendar Permission")
                                .font(.system(size: 13, weight: .bold))
                            Text("Status: \(calendarMgr.permissionStatusLabel)")
                                .font(.caption)
                                .foregroundStyle(calendarMgr.hasCalendarAccess ? .green : .secondary)
                        }
                        Spacer()
                        Button(calendarMgr.hasCalendarAccess ? "Granted ✓" : "Grant Calendar Access") {
                            Task { _ = await calendarMgr.requestAccess() }
                        }
                        .disabled(calendarMgr.hasCalendarAccess)
                    }
                    .padding(6)
                }

                Text("You can skip this step if you only want Music and System HUDs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case 4:
            VStack(alignment: .leading, spacing: 12) {
                Label("Local Weather & Units", systemImage: "cloud.sun.fill")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("NotchFlow displays live local weather in Duo Mode and inside the Calendar schedule. You can enter a city name directly (no Location permission required!) or use macOS Location Services.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)

                Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }

                HStack {
                    TextField("Enter City Name (or leave blank for auto)", text: $settings.customWeatherCity)
                        .textFieldStyle(.roundedBorder)
                    Button("Use Current Location") {
                        weatherMgr.requestLocationPermission()
                    }
                }
            }

        default:
            VStack(alignment: .leading, spacing: 12) {
                Label("Ready for Takeoff", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Configure how NotchFlow starts on your Mac. You can always access Settings from the NotchFlow menu bar icon or the gear button inside the expanded Dynamic Island.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Launch NotchFlow automatically at login", isOn: $settings.launchAtLogin)
                        Toggle("Show NotchFlow icon in the macOS menu bar", isOn: $settings.showMenuBarIcon)
                        Toggle("Enable Duo Mode (Music + Calendar/Weather split view)", isOn: $settings.enableDuoMode)
                    }
                    .padding(8)
                }
            }
        }
    }

    private func featureBullet(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 24, height: 24)
                .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        Task { await weatherMgr.refreshWeather(force: true) }
        onComplete()
    }
}
