import Foundation
import CoreLocation
import SwiftUI
import Combine

public struct WeatherSnapshot: Codable, Equatable, Sendable {
    public let locationName: String
    public let temperatureCelsius: Double
    public let highCelsius: Double
    public let lowCelsius: Double
    public let weatherCode: Int
    public let isDaylight: Bool
    public let windSpeedKmh: Double
    public let precipitationProbability: Int
    public let updatedAt: Date

    public func formattedTemperature(unit: TemperatureUnit) -> String {
        let val = convert(temperatureCelsius, to: unit)
        return "\(Int(val.rounded()))°"
    }

    public func formattedHighLow(unit: TemperatureUnit) -> String {
        let h = Int(convert(highCelsius, to: unit).rounded())
        let l = Int(convert(lowCelsius, to: unit).rounded())
        return "H:\(h)° L:\(l)°"
    }

    private func convert(_ celsius: Double, to unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius: return celsius
        case .fahrenheit: return (celsius * 9.0 / 5.0) + 32.0
        }
    }

    public var conditionDescription: String {
        switch weatherCode {
        case 0: return isDaylight ? "Clear Sky" : "Clear Night"
        case 1, 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55, 56, 57: return "Drizzle"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "Rain"
        case 71, 73, 75, 77, 85, 86: return "Snow"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Fair"
        }
    }

    public var symbolName: String {
        switch weatherCode {
        case 0: return isDaylight ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return isDaylight ? "sun.max.fill" : "moon.stars.fill"
        }
    }

    public var symbolColor: Color {
        switch weatherCode {
        case 0: return isDaylight ? .yellow : .indigo
        case 1, 2: return isDaylight ? .orange : .cyan
        case 51...67, 80...82: return .cyan
        case 71...86: return .white
        case 95...99: return .purple
        default: return .cyan
        }
    }
}

@MainActor
public final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = WeatherManager()

    @Published public private(set) var currentWeather: WeatherSnapshot?
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public private(set) var isLoading: Bool = false

    private let locationManager = CLLocationManager()
    private var lastCoordinates: CLLocationCoordinate2D?
    private var lastFetchDate: Date?
    private let cacheInterval: TimeInterval = 20 * 60 // 20 minutes

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        authorizationStatus = locationManager.authorizationStatus

        // Load cached weather from UserDefaults if available
        if let data = UserDefaults.standard.data(forKey: "nf.cachedWeather"),
           let snapshot = try? JSONDecoder().decode(WeatherSnapshot.self, from: data) {
            currentWeather = snapshot
        }

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            Task {
                await refreshWeather(force: false)
            }
        }
    }

    public var permissionStatusLabel: String {
        switch authorizationStatus {
        case .authorizedAlways, .authorized: return "Authorized"
        case .denied: return "Denied (Using City / Timezone Fallback)"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Requested (Optional)"
        @unknown default: return "Unknown"
        }
    }

    public func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    public func refreshWeather(force: Bool = false) async {
        guard SettingsStore.shared.enableWeather else { return }

        if !force,
           let lastFetchDate,
           Date().timeIntervalSince(lastFetchDate) < cacheInterval,
           currentWeather != nil {
            return
        }

        isLoading = true
        defer { isLoading = false }

        let customCity = SettingsStore.shared.customWeatherCity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !customCity.isEmpty {
            if let resolved = await geocodeCity(customCity) {
                await fetchOpenMeteo(latitude: resolved.lat, longitude: resolved.lon, locationName: resolved.name)
                return
            }
        }

        if let coord = lastCoordinates ?? locationManager.location?.coordinate {
            await fetchOpenMeteo(latitude: coord.latitude, longitude: coord.longitude, locationName: "Current Location")
            return
        }

        // Fallback coordinates derived from system timezone so weather works out of the box without forcing location prompts
        let fallback = fallbackLocationForSystemTimeZone()
        await fetchOpenMeteo(latitude: fallback.lat, longitude: fallback.lon, locationName: fallback.name)
    }

    private func geocodeCity(_ city: String) async -> (lat: Double, lon: Double, name: String)? {
        guard let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else {
            return nil
        }

        struct GeoResponse: Decodable {
            struct Result: Decodable {
                let name: String
                let latitude: Double
                let longitude: Double
            }
            let results: [Result]?
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(GeoResponse.self, from: data)
            if let first = decoded.results?.first {
                return (first.latitude, first.longitude, first.name)
            }
        } catch {
            return nil
        }
        return nil
    }

    private func fetchOpenMeteo(latitude: Double, longitude: Double, locationName: String) async {
        let urlStr = String(
            format: "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=temperature_2m,is_day,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto",
            latitude,
            longitude
        )
        guard let url = URL(string: urlStr) else { return }

        struct ForecastResponse: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double
                let is_day: Int
                let weather_code: Int
                let wind_speed_10m: Double
            }
            struct Daily: Decodable {
                let temperature_2m_max: [Double]
                let temperature_2m_min: [Double]
                let precipitation_probability_max: [Int]?
            }
            let current: Current
            let daily: Daily
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ForecastResponse.self, from: data)
            let high = decoded.daily.temperature_2m_max.first ?? (decoded.current.temperature_2m + 3)
            let low = decoded.daily.temperature_2m_min.first ?? (decoded.current.temperature_2m - 4)
            let precip = decoded.daily.precipitation_probability_max?.first ?? 0

            let snapshot = WeatherSnapshot(
                locationName: locationName,
                temperatureCelsius: decoded.current.temperature_2m,
                highCelsius: high,
                lowCelsius: low,
                weatherCode: decoded.current.weather_code,
                isDaylight: decoded.current.is_day == 1,
                windSpeedKmh: decoded.current.wind_speed_10m,
                precipitationProbability: precip,
                updatedAt: Date()
            )
            self.currentWeather = snapshot
            self.lastFetchDate = Date()
            if let encoded = try? JSONEncoder().encode(snapshot) {
                UserDefaults.standard.set(encoded, forKey: "nf.cachedWeather")
            }
        } catch {
            // If offline and no cached weather exists yet, provide a clean baseline snapshot so UI never breaks
            if currentWeather == nil {
                currentWeather = WeatherSnapshot(
                    locationName: locationName,
                    temperatureCelsius: 21.0,
                    highCelsius: 24.0,
                    lowCelsius: 15.0,
                    weatherCode: 1,
                    isDaylight: true,
                    windSpeedKmh: 11.0,
                    precipitationProbability: 10,
                    updatedAt: Date()
                )
            }
        }
    }

    private func fallbackLocationForSystemTimeZone() -> (lat: Double, lon: Double, name: String) {
        let tz = TimeZone.current.identifier
        if tz.contains("Los_Angeles") || tz.contains("Pacific") {
            return (37.7749, -122.4194, "San Francisco")
        } else if tz.contains("New_York") || tz.contains("Eastern") {
            return (40.7128, -74.0060, "New York")
        } else if tz.contains("Chicago") || tz.contains("Central") {
            return (41.8781, -87.6298, "Chicago")
        } else if tz.contains("Denver") || tz.contains("Mountain") {
            return (39.7392, -104.9903, "Denver")
        } else if tz.contains("London") {
            return (51.5072, -0.1276, "London")
        } else if tz.contains("Tokyo") {
            return (35.6762, 139.6503, "Tokyo")
        } else if tz.contains("Berlin") || tz.contains("Paris") {
            return (48.8566, 2.3522, "Paris")
        }
        let city = tz.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? "Cupertino"
        return (37.3230, -122.0322, city)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorized || status == .authorizedAlways {
                self.locationManager.startUpdatingLocation()
            }
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = loc.coordinate
        Task { @MainActor in
            self.lastCoordinates = coord
            self.locationManager.stopUpdatingLocation()
            await self.refreshWeather(force: true)
        }
    }
}
