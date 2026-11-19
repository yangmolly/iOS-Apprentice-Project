//
//  SpotHours.swift
//  iOSApprenticeProject
//
//  Opening hours are stored as Postgres `time` strings ("HH:mm:ss"),
//  interpreted in campus local time.
//

import Foundation

enum SpotHours {
    /// Chapel Hill.
    static let campusTimeZone = TimeZone(identifier: "America/New_York")!

    /// Minutes after midnight for "HH:mm" or "HH:mm:ss", or nil if malformed.
    static func minutes(from time: String?) -> Int? {
        guard let parts = time?.split(separator: ":"), parts.count >= 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...24).contains(h), (0..<60).contains(m) else { return nil }
        return h * 60 + m
    }

    static func timeString(minutes: Int) -> String {
        String(format: "%02d:%02d:00", minutes / 60, minutes % 60)
    }

    /// true/false when hours are known, nil when they aren't.
    static func isOpen(_ spot: StudySpot, at date: Date) -> Bool? {
        if spot.open24h { return true }
        guard let open = minutes(from: spot.opensAt), let close = minutes(from: spot.closesAt) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = campusTimeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)

        if open == close { return true }        // same open and close time: treat as all day
        if open < close { return now >= open && now < close }
        return now >= open || now < close        // overnight, e.g. 08:00–02:00
    }

    /// "8 AM – 2 AM", "Open 24 hours", or nil if unknown.
    static func label(for spot: StudySpot) -> String? {
        if spot.open24h { return "Open 24 hours" }
        guard let open = minutes(from: spot.opensAt), let close = minutes(from: spot.closesAt) else {
            return nil
        }
        return "\(format(open)) – \(format(close))"
    }

    private static func format(_ minutes: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = campusTimeZone
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1,
                                                       hour: minutes / 60, minute: minutes % 60)) ?? .now
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = campusTimeZone
        return date.formatted(style)
    }
}
