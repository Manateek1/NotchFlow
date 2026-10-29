import Foundation
import EventKit
import SwiftUI
import AppKit
import Combine

public struct CalendarEventItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let calendarTitle: String
    public let calendarID: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let meetingURL: URL?
    public let color: Color

    public init(
        id: String,
        title: String,
        calendarTitle: String,
        calendarID: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        meetingURL: URL?,
        color: Color
    ) {
        self.id = id
        self.title = title
        self.calendarTitle = calendarTitle
        self.calendarID = calendarID
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.meetingURL = meetingURL
        self.color = color
    }

    public func isOngoing(at date: Date = Date()) -> Bool {
        !isAllDay && startDate <= date && endDate > date
    }

    public func countdownText(from now: Date = Date()) -> String {
        if isAllDay {
            return "All Day"
        }
        if isOngoing(at: now) {
            let remainingMins = max(1, Int(endDate.timeIntervalSince(now) / 60))
            if remainingMins >= 60 {
                return "Now • \(remainingMins / 60)h \(remainingMins % 60)m left"
            }
            return "Now • \(remainingMins)m left"
        }
        let diff = startDate.timeIntervalSince(now)
        if diff <= 0 {
            return "Starting now"
        }
        let mins = Int(ceil(diff / 60.0))
        if mins < 60 {
            return "in \(mins)m"
        }
        let hours = mins / 60
        let remMins = mins % 60
        if hours < 24 {
            return remMins > 0 ? "in \(hours)h \(remMins)m" : "in \(hours)h"
        }
        let days = hours / 24
        return "in \(days)d"
    }

    public var timeRangeString: String {
        if isAllDay { return "All-day event" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
}

public struct CalendarSourceInfo: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let sourceTitle: String
    public let isSubscribed: Bool
    public let color: Color
}

@MainActor
public final class CalendarManager: ObservableObject {
    public static let shared = CalendarManager()

    private let eventStore = EKEventStore()

    @Published public private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published public private(set) var availableCalendars: [CalendarSourceInfo] = []
    @Published public private(set) var upcomingEvents: [CalendarEventItem] = []
    @Published public private(set) var currentOrNextEvent: CalendarEventItem?
    @Published public var displayedMonth: Date = Date()
    @Published public var selectedDate: Date = Date()
    @Published public private(set) var selectedDateEvents: [CalendarEventItem] = []
    @Published public private(set) var activeDaysInDisplayedMonth: Set<Int> = []

    public var onUpcomingMeetingAlert: ((CalendarEventItem) -> Void)?

    private var refreshTimer: Timer?
    private var alertedEventIDs: Set<String> = []
    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAll()
            }
        }

        updateAuthorizationStatus()
        if hasCalendarAccess {
            refreshAll()
        }

        // Refresh countdowns once per minute
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAll()
            }
        }
    }

    public var hasCalendarAccess: Bool {
        if #available(macOS 14.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    public var permissionStatusLabel: String {
        switch authorizationStatus {
        case .fullAccess, .authorized: return "Authorized"
        case .writeOnly: return "Write Only (Full Access Needed)"
        case .denied: return "Denied in System Settings"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Requested Yet"
        @unknown default: return "Unknown"
        }
    }

    public func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    public func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            updateAuthorizationStatus()
            if granted {
                refreshAll()
            }
            return granted
        } catch {
            updateAuthorizationStatus()
            return false
        }
    }

    public func refreshAll() {
        updateAuthorizationStatus()
        guard hasCalendarAccess else {
            availableCalendars = []
            upcomingEvents = []
            currentOrNextEvent = nil
            selectedDateEvents = []
            activeDaysInDisplayedMonth = []
            return
        }

        let ekCalendars = eventStore.calendars(for: .event)
        availableCalendars = ekCalendars.map { cal in
            CalendarSourceInfo(
                id: cal.calendarIdentifier,
                title: cal.title,
                sourceTitle: cal.source?.title ?? "Calendar",
                isSubscribed: cal.type == .subscription,
                color: cal.cgColor.map { Color(cgColor: $0) } ?? .cyan
            )
        }

        let filteredCalendars = filteredEKCalendars(from: ekCalendars)
        guard !filteredCalendars.isEmpty else {
            upcomingEvents = []
            currentOrNextEvent = nil
            selectedDateEvents = []
            activeDaysInDisplayedMonth = []
            return
        }

        let now = Date()
        let endWindow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(86400 * 7)
        let predicate = eventStore.predicateForEvents(withStart: now.addingTimeInterval(-1800), end: endWindow, calendars: filteredCalendars)
        let rawEvents = eventStore.events(matching: predicate)

        let mapped = rawEvents
            .filter { shouldInclude(event: $0) }
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .map { mapEvent($0) }

        upcomingEvents = mapped
        currentOrNextEvent = mapped.first(where: { !$0.isAllDay }) ?? mapped.first

        // Check if an event starts within 5 minutes for QuickPeek notification
        if let next = currentOrNextEvent, !next.isAllDay {
            let minsUntil = next.startDate.timeIntervalSince(now) / 60.0
            if minsUntil > 0 && minsUntil <= 5.0 && !alertedEventIDs.contains(next.id) {
                alertedEventIDs.insert(next.id)
                onUpcomingMeetingAlert?(next)
            }
        }

        refreshSelectedDateEvents(calendars: filteredCalendars)
        refreshDisplayedMonthIndicators(calendars: filteredCalendars)
    }

    public func selectDate(_ date: Date) {
        selectedDate = date
        if hasCalendarAccess {
            let filtered = filteredEKCalendars(from: eventStore.calendars(for: .event))
            refreshSelectedDateEvents(calendars: filtered)
        }
    }

    public func navigateMonth(by offset: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: displayedMonth) {
            displayedMonth = newMonth
            if hasCalendarAccess {
                let filtered = filteredEKCalendars(from: eventStore.calendars(for: .event))
                refreshDisplayedMonthIndicators(calendars: filtered)
            }
        }
    }

    public func jumpToToday() {
        let now = Date()
        displayedMonth = now
        selectDate(now)
    }

    public func openInCalendarApp(date: Date? = nil) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func refreshSelectedDateEvents(calendars: [EKCalendar]) {
        guard !calendars.isEmpty else {
            selectedDateEvents = []
            return
        }
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: selectedDate)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let pred = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        selectedDateEvents = eventStore.events(matching: pred)
            .filter { shouldInclude(event: $0) }
            .sorted { $0.startDate < $1.startDate }
            .map { mapEvent($0) }
    }

    private func refreshDisplayedMonthIndicators(calendars: [EKCalendar]) {
        guard !calendars.isEmpty else {
            activeDaysInDisplayedMonth = []
            return
        }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        guard let startOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: startOfMonth),
              let endOfMonth = cal.date(byAdding: .day, value: range.count, to: startOfMonth) else {
            return
        }

        let pred = eventStore.predicateForEvents(withStart: startOfMonth, end: endOfMonth, calendars: calendars)
        let events = eventStore.events(matching: pred).filter { shouldInclude(event: $0) }
        var days = Set<Int>()
        for ev in events {
            let day = cal.component(.day, from: ev.startDate)
            days.insert(day)
        }
        activeDaysInDisplayedMonth = days
    }

    private func filteredEKCalendars(from all: [EKCalendar]) -> [EKCalendar] {
        let settings = SettingsStore.shared
        return all.filter { cal in
            if settings.excludeSubscribedCalendars && cal.type == .subscription {
                return false
            }
            if !settings.selectedCalendarIDs.isEmpty {
                return settings.selectedCalendarIDs.contains(cal.calendarIdentifier)
            }
            return true
        }
    }

    private func shouldInclude(event: EKEvent) -> Bool {
        if !SettingsStore.shared.showDeclinedEvents {
            if event.status == .canceled { return false }
            if let attendees = event.attendees {
                for att in attendees where att.isCurrentUser && att.participantStatus == .declined {
                    return false
                }
            }
        }
        return true
    }

    private func mapEvent(_ event: EKEvent) -> CalendarEventItem {
        let color = event.calendar?.cgColor.map { Color(cgColor: $0) } ?? .cyan
        let meetingURL = extractMeetingURL(from: event)
        return CalendarEventItem(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: (event.title?.isEmpty == false) ? event.title! : "Untitled Event",
            calendarTitle: event.calendar?.title ?? "Calendar",
            calendarID: event.calendar?.calendarIdentifier ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location,
            meetingURL: meetingURL,
            color: color
        )
    }

    private func extractMeetingURL(from event: EKEvent) -> URL? {
        if let url = event.url, isVideoConferenceURL(url) {
            return url
        }
        let searchStrings = [event.location, event.notes].compactMap { $0 }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return event.url
        }
        for text in searchStrings {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = detector.matches(in: text, options: [], range: range)
            for match in matches {
                if let url = match.url, isVideoConferenceURL(url) {
                    return url
                }
            }
        }
        return nil
    }

    private func isVideoConferenceURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let domains = ["zoom.us", "meet.google.com", "teams.microsoft.com", "webex.com", "facetime.apple.com", "around.co"]
        return domains.contains { host.contains($0) }
    }
}
