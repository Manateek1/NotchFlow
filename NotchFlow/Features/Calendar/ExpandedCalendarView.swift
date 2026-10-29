import SwiftUI
import AppKit

public struct ExpandedCalendarView: View {
    @ObservedObject var calendarMgr = CalendarManager.shared
    @ObservedObject var weatherMgr = WeatherManager.shared
    @ObservedObject var settings = SettingsStore.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    public init() {}

    private var accent: Color {
        settings.accentColorPreset.primaryColor
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left Column: Interactive Monthly Calendar Grid
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(monthYearTitle(for: calendarMgr.displayedMonth))
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: 6) {
                        Button {
                            calendarMgr.navigateMonth(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 18, height: 18)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            calendarMgr.jumpToToday()
                        } label: {
                            Text("Today")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            calendarMgr.navigateMonth(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(width: 18, height: 18)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Weekday headers
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<7, id: \.self) { idx in
                        Text(weekdaySymbols[idx])
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                            .frame(maxWidth: .infinity)
                    }
                }

                // Days Grid
                let days = generateDaysInMonth(for: calendarMgr.displayedMonth)
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, dateOpt in
                        if let date = dateOpt {
                            dayCell(for: date)
                        } else {
                            Color.clear
                                .frame(height: 22)
                        }
                    }
                }
            }
            .frame(width: 188)

            Divider()
                .background(Color.white.opacity(0.12))

            // Right Column: Selected Date Events + Weather Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(selectedDateHeader(for: calendarMgr.selectedDate))
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if let next = calendarMgr.currentOrNextEvent, settings.showEventCountdown {
                            Text("Next: \(next.countdownText())")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                    }

                    Spacer()

                    if settings.enableWeather, let weather = weatherMgr.currentWeather {
                        HStack(spacing: 4) {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 11.5))
                                .foregroundStyle(weather.symbolColor)
                            Text(weather.formattedTemperature(unit: settings.temperatureUnit))
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    Button {
                        calendarMgr.openInCalendarApp(date: calendarMgr.selectedDate)
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .help("Open macOS Calendar")
                }

                if !calendarMgr.hasCalendarAccess {
                    permissionPromptCard
                } else if calendarMgr.selectedDateEvents.isEmpty {
                    emptyDayCard
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(calendarMgr.selectedDateEvents) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dayCell(for date: Date) -> some View {
        let cal = Calendar.current
        let dayNum = cal.component(.day, from: date)
        let isToday = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: calendarMgr.selectedDate)
        let hasEvents = calendarMgr.activeDaysInDisplayedMonth.contains(dayNum)

        return Button {
            calendarMgr.selectDate(date)
        } label: {
            VStack(spacing: 1.5) {
                Text("\(dayNum)")
                    .font(.system(size: 10.5, weight: (isToday || isSelected) ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isToday ? .black : (isSelected ? accent : .white.opacity(0.86)))

                Circle()
                    .fill(isToday ? Color.black.opacity(0.75) : (hasEvents ? accent : Color.clear))
                    .frame(width: 3.5, height: 3.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .background(
                ZStack {
                    if isToday {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accent)
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(accent, lineWidth: 1.2)
                            .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func eventRow(_ event: CalendarEventItem) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Capsule()
                .fill(event.color)
                .frame(width: 3.5, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Text(event.timeRangeString)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))

                    if settings.showEventCountdown {
                        Text("• \(event.countdownText())")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }
            }

            Spacer(minLength: 2)

            if settings.showMeetingJoinButton, let url = event.meetingURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                        Text("Join")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(accent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var emptyDayCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                Text("Clear Schedule")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text("No events scheduled for this day.")
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.55))

            if settings.enableWeather && settings.showWeatherOnEmptyCalendarDay,
               let weather = weatherMgr.currentWeather {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 2)

                HStack(spacing: 8) {
                    Image(systemName: weather.symbolName)
                        .font(.system(size: 18))
                        .foregroundStyle(weather.symbolColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(weather.locationName) • \(weather.conditionDescription)")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("\(weather.formattedTemperature(unit: settings.temperatureUnit)) (\(weather.formattedHighLow(unit: settings.temperatureUnit)))")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var permissionPromptCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Text("Calendar Permission Needed")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Allow Calendar access to see upcoming meetings and live countdowns.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    let granted = await calendarMgr.requestAccess()
                    if !granted {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            } label: {
                Text("Enable Calendar Access")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func monthYearTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func selectedDateHeader(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let f = DateFormatter()
            f.dateFormat = "'Today,' MMM d"
            return f.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func generateDaysInMonth(for date: Date) -> [Date?] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = cal.component(.weekday, from: firstOfMonth) // 1 = Sun
        let leadingEmpty = firstWeekday - 1

        var result: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                result.append(d)
            }
        }
        return result
    }
}
