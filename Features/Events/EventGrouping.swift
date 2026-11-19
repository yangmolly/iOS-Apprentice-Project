//
//  EventGrouping.swift
//  iOSApprenticeProject
//
//  Upcoming events bucketed for the Events list. Pure, so it is unit-tested directly.
//

import Foundation

enum EventSection: String, CaseIterable, Identifiable {
    case now, today, thisWeek, later, unscheduled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .now: return "Happening now"
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .later: return "Later"
        case .unscheduled: return "No date yet"
        }
    }
}

enum EventGrouping {
    /// Events without an end time are treated as this long.
    static let defaultDuration: TimeInterval = 2 * 60 * 60

    static func effectiveEnd(of event: Event) -> Date? {
        event.endsAt ?? event.startsAt?.addingTimeInterval(defaultDuration)
    }

    static func isPast(_ event: Event, now: Date) -> Bool {
        guard let end = effectiveEnd(of: event) else { return false }
        return end <= now
    }

    static func section(for event: Event, now: Date, calendar: Calendar) -> EventSection? {
        guard let start = event.startsAt else { return .unscheduled }
        if isPast(event, now: now) { return nil }
        if start <= now { return .now }
        if calendar.isDate(start, inSameDayAs: now) { return .today }
        let startOfToday = calendar.startOfDay(for: now)
        if let weekOut = calendar.date(byAdding: .day, value: 7, to: startOfToday), start < weekOut {
            return .thisWeek
        }
        return .later
    }

    /// Non-empty sections in display order, each sorted by start time. Past events are dropped.
    static func group(_ events: [Event], now: Date, calendar: Calendar = .current) -> [(section: EventSection, events: [Event])] {
        var buckets: [EventSection: [Event]] = [:]
        for event in events {
            if let section = section(for: event, now: now, calendar: calendar) {
                buckets[section, default: []].append(event)
            }
        }
        return EventSection.allCases.compactMap { section in
            guard let items = buckets[section], !items.isEmpty else { return nil }
            let sorted = items.sorted {
                ($0.startsAt ?? .distantFuture, $0.title) < ($1.startsAt ?? .distantFuture, $1.title)
            }
            return (section, sorted)
        }
    }

    /// "Thu, Nov 20 · 3:00 PM – 5:00 PM", "Thu, Nov 20 · 3:00 PM", or nil without a start.
    static func timeLabel(for event: Event) -> String? {
        guard let start = event.startsAt else { return nil }
        let day = start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let startTime = start.formatted(date: .omitted, time: .shortened)
        guard let end = event.endsAt else { return "\(day) · \(startTime)" }
        let endText = Calendar.current.isDate(start, inSameDayAs: end)
            ? end.formatted(date: .omitted, time: .shortened)
            : end.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        return "\(day) · \(startTime) – \(endText)"
    }
}
