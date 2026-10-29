import XCTest
import SwiftUI
import AppKit

@MainActor
final class NotchFlowTests: XCTestCase {

    func testSettingsStorePersistenceAndReset() {
        let suiteName = "com.dillonnagar.NotchFlowTests.\(UUID().uuidString)"
        let customDefaults = UserDefaults(suiteName: suiteName)!
        defer { customDefaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: customDefaults)
        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.islandStyleMode, .automatic)
        XCTAssertEqual(store.temperatureUnit, .fahrenheit)

        store.islandStyleMode = .simulatedPill
        store.compactWidthAdjustment = 24.0
        store.temperatureUnit = .celsius
        store.enableDuoMode = false

        // Re-instantiate with the same UserDefaults to verify persistence
        let reloaded = SettingsStore(defaults: customDefaults)
        XCTAssertEqual(reloaded.islandStyleMode, .simulatedPill)
        XCTAssertEqual(reloaded.compactWidthAdjustment, 24.0, accuracy: 0.01)
        XCTAssertEqual(reloaded.temperatureUnit, .celsius)
        XCTAssertFalse(reloaded.enableDuoMode)

        reloaded.resetToDefaults()
        XCTAssertEqual(reloaded.islandStyleMode, .automatic)
        XCTAssertEqual(reloaded.compactWidthAdjustment, 0.0, accuracy: 0.01)
        XCTAssertTrue(reloaded.enableDuoMode)
    }

    func testNowPlayingTrackTimeAndProgressCalculations() {
        let track = NowPlayingTrack(
            title: "Solar Winds",
            artist: "NotchFlow",
            album: "Horizons",
            duration: 200,
            elapsedTime: 50,
            isPlaying: true
        )

        XCTAssertTrue(track.hasActiveTrack)
        XCTAssertEqual(track.progress, 0.25, accuracy: 0.001)
        XCTAssertEqual(track.formattedElapsed, "0:50")
        XCTAssertEqual(track.formattedRemaining, "-2:30")
        XCTAssertEqual(NowPlayingTrack.formatTime(3665), "1:01:05")
    }

    func testCalendarEventCountdowns() {
        let now = Date()
        let upcoming = CalendarEventItem(
            id: "ev-1",
            title: "Architecture Sync",
            calendarTitle: "Work",
            calendarID: "cal-1",
            startDate: now.addingTimeInterval(14 * 60),
            endDate: now.addingTimeInterval(44 * 60),
            isAllDay: false,
            location: nil,
            meetingURL: URL(string: "https://meet.google.com/abc-defg-hij"),
            color: .cyan
        )

        XCTAssertFalse(upcoming.isOngoing(at: now))
        XCTAssertEqual(upcoming.countdownText(from: now), "in 14m")

        let ongoing = CalendarEventItem(
            id: "ev-2",
            title: "Standup",
            calendarTitle: "Work",
            calendarID: "cal-1",
            startDate: now.addingTimeInterval(-5 * 60),
            endDate: now.addingTimeInterval(20 * 60),
            isAllDay: false,
            location: nil,
            meetingURL: nil,
            color: .orange
        )

        XCTAssertTrue(ongoing.isOngoing(at: now))
        XCTAssertEqual(ongoing.countdownText(from: now), "Now • 20m left")
    }

    func testWeatherSnapshotUnitConversionAndSymbols() {
        let snapshot = WeatherSnapshot(
            locationName: "San Francisco",
            temperatureCelsius: 20.0,
            highCelsius: 25.0,
            lowCelsius: 15.0,
            weatherCode: 0,
            isDaylight: true,
            windSpeedKmh: 12.0,
            precipitationProbability: 5,
            updatedAt: Date()
        )

        XCTAssertEqual(snapshot.formattedTemperature(unit: .celsius), "20°")
        XCTAssertEqual(snapshot.formattedTemperature(unit: .fahrenheit), "68°")
        XCTAssertEqual(snapshot.formattedHighLow(unit: .fahrenheit), "H:77° L:59°")
        XCTAssertEqual(snapshot.conditionDescription, "Clear Sky")
        XCTAssertEqual(snapshot.symbolName, "sun.max.fill")
    }

    func testBatteryStateSnapshotFormatting() {
        let lowBattery = BatteryStateSnapshot(
            percentage: 15,
            isCharging: false,
            isPluggedIn: false,
            isCharged: false,
            isLowPowerMode: false,
            timeToEmptyMinutes: 45,
            powerSourceName: "Battery"
        )
        XCTAssertTrue(lowBattery.isLowBattery)
        XCTAssertEqual(lowBattery.symbolName, "battery.25percent")
        XCTAssertEqual(lowBattery.statusSummary, "0h 45m remaining")

        let charging = BatteryStateSnapshot(
            percentage: 82,
            isCharging: true,
            isPluggedIn: true,
            isCharged: false,
            isLowPowerMode: false,
            timeToFullMinutes: 30,
            powerSourceName: "AC Power"
        )
        XCTAssertFalse(charging.isLowBattery)
        XCTAssertEqual(charging.symbolName, "battery.100percent.bolt")
    }

    func testIslandCoordinatorTransitionsAndPriorityQueue() {
        let coord = IslandCoordinator.shared
        SettingsStore.shared.isEnabled = true
        SettingsStore.shared.hideInFullscreen = true
        coord.updateFullscreenState(false)

        coord.expandIsland(to: .calendar)
        XCTAssertEqual(coord.displayState, .expanded)
        XCTAssertEqual(coord.expandedTab, .calendar)

        let expandedSize = coord.currentIslandSize(for: nil)
        XCTAssertGreaterThan(expandedSize.width, 400)
        XCTAssertGreaterThan(expandedSize.height, 220)

        coord.collapseIsland()
        XCTAssertNotEqual(coord.displayState, .expanded)

        // Test QuickPeek Priority Queue
        let lowPriorityPeek = QuickPeekNotification(
            category: .weather,
            priority: 20,
            title: "Weather Updated",
            subtitle: "72° Clear",
            symbolName: "sun.max.fill"
        )
        let highPriorityPeek = QuickPeekNotification(
            category: .battery,
            priority: 95,
            title: "Low Battery",
            subtitle: "15% Remaining",
            symbolName: "battery.25percent"
        )

        coord.enqueueQuickPeek(lowPriorityPeek)
        XCTAssertEqual(coord.displayState, .quickPeek)
        XCTAssertEqual(coord.currentQuickPeek?.title, "Weather Updated")

        // Higher priority notification should preempt current lower-priority QuickPeek immediately
        coord.enqueueQuickPeek(highPriorityPeek)
        XCTAssertEqual(coord.currentQuickPeek?.title, "Low Battery")

        coord.dismissQuickPeek()

        // Test System HUD presentation
        let hud = SystemHUDPayload(
            kind: .volume,
            title: "MacBook Pro Speakers",
            symbolName: "speaker.wave.2.fill",
            progress: 0.65,
            valueText: "65%"
        )
        coord.presentSystemHUD(hud)
        XCTAssertEqual(coord.displayState, .systemHUD)
        XCTAssertEqual(coord.activeHUD?.valueText, "65%")

        // Test Fullscreen auto-hide
        coord.updateFullscreenState(true)
        XCTAssertEqual(coord.displayState, .hidden)
        coord.updateFullscreenState(false)
    }

    func testNotchShapeAndDominantColorExtraction() {
        let shape = NotchIslandShape(topShoulderRadius: 10, bottomCornerRadius: 18)
        let path = shape.path(in: CGRect(x: 0, y: 0, width: 260, height: 38))
        XCTAssertFalse(path.isEmpty)

        let image = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
            NSColor(srgbRed: 0.1, green: 0.7, blue: 0.95, alpha: 1.0).setFill()
            rect.fill()
            return true
        }
        let dominant = image.extractDominantColor()
        XCTAssertNotNil(dominant)
    }
}
