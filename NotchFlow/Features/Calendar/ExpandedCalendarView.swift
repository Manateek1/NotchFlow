import SwiftUI
import AppKit

public struct ExpandedCalendarView: View {
    @ObservedObject var calendarMgr = CalendarManager.shared
    @ObservedObject var weatherMgr = WeatherManager.shared
    @ObservedObject var settings = SettingsStore.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private let calendarRed = Color(red: 1.0, green: 0.27, blue: 0.23)

    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Left Column: Compact Apple Calendar Monthly Grid
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    Text(monthYearTitle(for: calendarMgr.displayedMonth))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 4)

                    HStack(spacing: 4) {
                        Button {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                                calendarMgr.navigateMonth(by: -1)
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white.opacity(0.60))
                                .frame(width: 19, height: 19)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                                calendarMgr.jumpToToday()
                            }
                        } label: {
                            Text("Today")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                                calendarMgr.navigateMonth(by: 1)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white.opacity(0.60))
                                .frame(width: 19, height: 19)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Weekday Header Row
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<7, id: \.self) { idx in
                        Text(weekdaySymbols[idx])
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.36))
                            .frame(maxWidth: .infinity)
                    }
                }

                // Month Days Grid
                let days = generateDaysInMonth(for: calendarMgr.displayedMonth)
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, dateOpt in
                        if let date = dateOpt {
                            dayCell(for: date)
                        } else {
                            Color.clear
                                .frame(height: 21)
                        }
                    }
                }
            }
            .frame(width: 184)

            // Hairline Vertical Divider
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 0.5)
                .padding(.vertical, 2)

            // Right Column: Schedule Timeline & Weather
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text(selectedDateHeader(for: calendarMgr.selectedDate))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    if settings.enableWeather, let weather = weatherMgr.currentWeather {
                        HStack(spacing: 4) {
                            Image(systemName: weather.symbolName)
                                .font(.system(size: 11))
                                .foregroundStyle(weather.symbolColor)
                            Text(weather.formattedTemperature(unit: settings.temperatureUnit))
                                .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.90))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    Button {
                        calendarMgr.openInCalendarApp(date: calendarMgr.selectedDate)
                    } label: {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Open in macOS Calendar")
                }

                let displayedEvents = effectiveEventsForDisplay
                if displayedEvents.isEmpty {
                    emptyDayCard
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(displayedEvents) { event in
                                eventRow(event)
                            }
                        }
                    }
                }

                if !calendarMgr.hasCalendarAccess {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                        Text("Preview")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 4)
                        Button {
                            Task {
                                let granted = await calendarMgr.requestAccess()
                                if !granted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        } label: {
                            Text("Connect Calendar")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var effectiveEventsForDisplay: [CalendarEventItem] {
        if calendarMgr.hasCalendarAccess {
            return calendarMgr.selectedDateEvents
        }
        // Provide realistic preview schedule when Calendar permission hasn't been granted yet
        let now = Date()
        let cal = Calendar.current
        let start1 = cal.date(byAdding: .minute, value: 14, to: now) ?? now
        let end1 = cal.date(byAdding: .minute, value: 59, to: now) ?? now
        let start2 = cal.date(byAdding: .hour, value: 2, to: now) ?? now
        let end2 = cal.date(byAdding: .hour, value: 3, to: now) ?? now

        return [
            CalendarEventItem(
                id: "preview-1",
                title: "Design Sync",
                calendarTitle: "Work",
                calendarID: "work",
                startDate: start1,
                endDate: end1,
                isAllDay: false,
                location: "FaceTime / Meet",
                meetingURL: URL(string: "https://meet.google.com"),
                color: Color(red: 0.22, green: 0.74, blue: 0.97)
            ),
            CalendarEventItem(
                id: "preview-2",
                title: "Architecture Review",
                calendarTitle: "Engineering",
                calendarID: "eng",
                startDate: start2,
                endDate: end2,
                isAllDay: false,
                location: "Studio B",
                meetingURL: nil,
                color: Color(red: 0.66, green: 0.33, blue: 0.97)
            )
        ]
    }

    private func dayCell(for date: Date) -> some View {
        let cal = Calendar.current
        let dayNum = cal.component(.day, from: date)
        let isToday = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: calendarMgr.selectedDate)
        let hasEvents = calendarMgr.activeDaysInDisplayedMonth.contains(dayNum) || isToday

        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                calendarMgr.selectDate(date)
            }
        } label: {
            VStack(spacing: 1.5) {
                Text("\(dayNum)")
                    .font(.system(size: 10.5, weight: (isToday || isSelected) ? .bold : .medium).monospacedDigit())
                    .foregroundStyle(isToday ? .white : (isSelected ? .white : .white.opacity(0.82)))

                Circle()
                    .fill(isToday ? Color.white.opacity(0.9) : (hasEvents ? calendarRed : Color.clear))
                    .frame(width: 3, height: 3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 21)
            .background(
                ZStack {
                    if isToday {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(calendarRed)
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.16))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func eventRow(_ event: CalendarEventItem) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Capsule(style: .continuous)
                .fill(event.color)
                .frame(width: 3.5, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    let hasJoin = (settings.showMeetingJoinButton && event.meetingURL != nil)
                    Text(hasJoin ? conciseStartTime(for: event) : event.timeRangeString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(1)

                    if settings.showEventCountdown {
                        Text("• \(event.countdownText())")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(red: 0.98, green: 0.64, blue: 0.28))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }

            Spacer(minLength: 4)

            if settings.showMeetingJoinButton, let url = event.meetingURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                        Text("Join")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.20, green: 0.72, blue: 0.46), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var emptyDayCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.29, green: 0.85, blue: 0.50))
                Text("No Events Scheduled")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.90))
            }

            Text("Your schedule is clear for the rest of the day.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func conciseStartTime(for event: CalendarEventItem) -> String {
        if event.isAllDay { return "All Day" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: event.startDate)
    }

    private func monthYearTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func selectedDateHeader(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let f = DateFormatter()
            f.dateFormat = "'Today,' MMM d"
            return f.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func generateDaysInMonth(for date: Date) -> [Date?] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
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
