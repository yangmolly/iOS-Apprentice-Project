//
//  SpotHoursTests.swift
//  StudySpotTests
//

import Foundation
import Testing
@testable import iOSApprenticeProject

struct SpotHoursTests {
    /// A date at the given campus-local time.
    static func campus(_ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SpotHours.campusTimeZone
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: hour, minute: minute))!
    }

    private func spot(opens: String?, closes: String?, open24h: Bool = false) -> StudySpot {
        StudySpot(name: "X", latitude: 0, longitude: 0, opensAt: opens, closesAt: closes, open24h: open24h)
    }

    @Test func parsesPostgresTimes() {
        #expect(SpotHours.minutes(from: "08:30:00") == 510)
        #expect(SpotHours.minutes(from: "23:59") == 1439)
        #expect(SpotHours.minutes(from: "nonsense") == nil)
        #expect(SpotHours.minutes(from: "25:00:00") == nil)
        #expect(SpotHours.minutes(from: nil) == nil)
        #expect(SpotHours.timeString(minutes: 510) == "08:30:00")
    }

    @Test func daytimeHours() {
        let s = spot(opens: "08:00:00", closes: "22:00:00")
        #expect(SpotHours.isOpen(s, at: Self.campus(7, 59)) == false)
        #expect(SpotHours.isOpen(s, at: Self.campus(8)) == true)
        #expect(SpotHours.isOpen(s, at: Self.campus(21, 59)) == true)
        #expect(SpotHours.isOpen(s, at: Self.campus(22)) == false)
    }

    @Test func overnightHours() {
        let s = spot(opens: "08:00:00", closes: "02:00:00")
        #expect(SpotHours.isOpen(s, at: Self.campus(1, 30)) == true)
        #expect(SpotHours.isOpen(s, at: Self.campus(3)) == false)
        #expect(SpotHours.isOpen(s, at: Self.campus(23)) == true)
    }

    @Test func unknownAnd24h() {
        #expect(SpotHours.isOpen(spot(opens: nil, closes: nil), at: Self.campus(12)) == nil)
        #expect(SpotHours.isOpen(spot(opens: "08:00", closes: nil), at: Self.campus(12)) == nil)
        #expect(SpotHours.isOpen(spot(opens: nil, closes: nil, open24h: true), at: Self.campus(3)) == true)
        #expect(SpotHours.label(for: spot(opens: nil, closes: nil, open24h: true)) == "Open 24 hours")
        #expect(SpotHours.label(for: spot(opens: nil, closes: nil)) == nil)
    }
}

struct RatingBucketTests {
    @Test func bucketsCoverZeroToTenWithoutGaps() {
        var score = 0.0
        while score <= 10.0 {
            let rounded = (score * 10).rounded() / 10
            let bucket = RatingBucket.containing(rounded)
            #expect(bucket.range.contains(rounded), "\(rounded) not in \(bucket)")
            score += 0.1
        }
    }

    @Test func boundaries() {
        #expect(RatingBucket.containing(6.7) == .liked)
        #expect(RatingBucket.containing(6.6) == .fine)
        #expect(RatingBucket.containing(3.4) == .fine)
        #expect(RatingBucket.containing(3.3) == .disliked)
    }
}
