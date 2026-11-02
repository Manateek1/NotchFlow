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

    private let totalSteps = 5
    private let switchMint = Color(red: 0.24, green: 0.78, blue: 0.70)

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Simulated MacBook Bezel + Live Notch Preview Card
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.52, blue: 0.36),
                        Color(red: 0.88, green: 0.34, blue: 0.46),
                        Color(red: 0.32, green: 0.20, blue: 0.44)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Top-Anchored Hardware Notch Preview (Concave Top Ears, Pure Black, Soft Drop Shadow)
                HStack(spacing: 0) {
                    if let art = mediaMgr.currentTrack.artworkImage {
                        Image(nsImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 21, height: 21)
                            .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                            .fill(Color.white.opacity(0.20))
                            .frame(width: 21, height: 21)
                    }

                    Spacer()
                        .frame(width: 146)

                    WaveformVisualizerView(
                        isPlaying: true,
                        style: .bars,
                        accentColor: Color(red: 0.48, green: 0.72, blue: 0.86),
                        barCount: 4,
                        height: 15
                    )
                }
                .padding(.horizontal, 20)
                .frame(width: 256, height: 38)
                .background(Color.black)
                .clipShape(NotchIslandShape(topShoulderRadius: 10, bottomCornerRadius: 15))
                .shadow(color: Color.black.opacity(0.45), radius: 16, y: 8)
            }
            .frame(height: 128)
            .clipped()

            // Main Step Content Area
            VStack(alignment: .leading, spacing: 16) {
                stepContent(for: currentStep)
                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(red: 0.22, green: 0.22, blue: 0.23))

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Bottom Navigation Footer
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { idx in
                        Capsule(style: .continuous)
                            .fill(idx == currentStep ? Color.white.opacity(0.90) : Color.white.opacity(0.22))
                            .frame(width: idx == currentStep ? 16 : 6, height: 6)
                    }
                }

                Spacer()

                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(OnboardingPillButtonStyle(isPrimary: false))
                }

                Button("Skip") {
                    finishOnboarding()
                }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
                .buttonStyle(.plain)
                .padding(.horizontal, 8)

                Button(currentStep == totalSteps - 1 ? "Get Started" : "Continue") {
                    if currentStep < totalSteps - 1 {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            currentStep += 1
                        }
                    } else {
                        finishOnboarding()
                    }
                }
                .buttonStyle(OnboardingPillButtonStyle(isPrimary: true))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(red: 0.19, green: 0.19, blue: 0.20))
        }
        .background(Color(red: 0.22, green: 0.22, blue: 0.23))
        .tint(switchMint)
        .frame(width: 540, height: 450)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func stepContent(for step: Int) -> some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 14) {
                Text("Dynamic Island. Now for your Mac.")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)

                Text("Turns your MacBook's camera cutout into a fluid, native Dynamic Island.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    featureRow(color: Color(red: 0.96, green: 0.28, blue: 0.36), icon: "play.fill", title: "Now Playing & Live Waveforms", detail: "Album artwork, dynamic color accents, and trackpad swipe controls.")
                    featureRow(color: Color(red: 0.64, green: 0.36, blue: 0.96), icon: "sun.max.fill", title: "Sleek System HUDs", detail: "Replaces Volume, Brightness, Battery, and AirPods overlays in the notch.")
                    featureRow(color: Color(red: 0.98, green: 0.38, blue: 0.24), icon: "calendar", title: "Calendar & Duo Mode", detail: "Upcoming meeting countdowns, monthly calendar, and 1-click call join.")
                }
                .padding(.top, 2)
            }

        case 1:
            VStack(alignment: .leading, spacing: 14) {
                Text("Effortless Gestures")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("Hover or click the notch to expand. Use two-finger horizontal trackpad swipes on the island to skip songs or switch between Music and Calendar.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))

                VStack(spacing: 10) {
                    onboardingToggleCard("Expand automatically on cursor hover", isOn: $settings.expandOnHover)
                    onboardingToggleCard("Enable two-finger trackpad swipe gestures", isOn: $settings.enableSwipeGestures)
                    onboardingToggleCard("Enable Duo Mode (Music + Calendar split view)", isOn: $settings.enableDuoMode)
                }
            }

        case 2:
            VStack(alignment: .leading, spacing: 14) {
                Text("Customizable System HUDs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("Choose how Volume, Display Brightness, and Battery indicators appear inside the notch.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))

                VStack(spacing: 10) {
                    onboardingToggleCard("Volume & Sound HUD", isOn: $settings.enableVolumeHUD)
                    onboardingToggleCard("Display Brightness HUD", isOn: $settings.enableBrightnessHUD)
                    onboardingToggleCard("AirPods & Battery Connection HUDs", isOn: $settings.enableConnectivityHUD)
                }
            }

        case 3:
            VStack(alignment: .leading, spacing: 14) {
                Text("Calendar & Weather")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("Optionally connect your macOS Calendar to see live meeting countdowns and 1-click video call Join buttons.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calendar Access (EventKit)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(calendarMgr.permissionStatusLabel)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                    Spacer()
                    Button(calendarMgr.hasCalendarAccess ? "Connected ✓" : "Grant Access") {
                        Task { _ = await calendarMgr.requestAccess() }
                    }
                    .buttonStyle(OnboardingPillButtonStyle(isPrimary: !calendarMgr.hasCalendarAccess))
                    .disabled(calendarMgr.hasCalendarAccess)
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

        default:
            VStack(alignment: .leading, spacing: 14) {
                Text("All Set")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text("NotchFlow runs quietly in the background using 0% idle CPU. You can open Settings anytime from the menu bar icon.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))

                VStack(spacing: 10) {
                    onboardingToggleCard("Launch NotchFlow at Login", isOn: $settings.launchAtLogin)
                    onboardingToggleCard("Show NotchFlow icon in Menu Bar", isOn: $settings.showMenuBarIcon)
                }
            }
        }
    }

    private func featureRow(color: Color, icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color)
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func onboardingToggleCard(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.90))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        Task { await weatherMgr.refreshWeather(force: true) }
        onComplete()
    }
}

private struct OnboardingPillButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(isPrimary ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        isPrimary
                            ? Color.white.opacity(configuration.isPressed ? 0.82 : 0.96)
                            : Color.white.opacity(configuration.isPressed ? 0.18 : 0.10)
                    )
            )
    }
}
