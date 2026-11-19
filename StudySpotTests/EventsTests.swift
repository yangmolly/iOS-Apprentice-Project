//
//  EventsTests.swift
//  StudySpotTests
//

import CoreLocation
import Foundation
import Testing
@testable import iOSApprenticeProject

/// Thursday Nov 19 2026, 12:00 campus time.
private let now = SpotHoursTests.campus(12)
private let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = SpotHours.campusTimeZone
    return c
}()
private func hours(_ h: Double) -> Date { now.addingTimeInterval(h * 3600) }

struct EventGroupingTests {
    @Test func sectionsAndOrdering() {
        let live = Fixtures.event("Live", startsAt: hours(-1))
        let laterToday = Fixtures.event("Tonight", startsAt: hours(6))
        let soonToday = Fixtures.event("Soon", startsAt: hours(1))
        let tomorrow = Fixtures.event("Tomorrow", startsAt: hours(24))
        let nextMonth = Fixtures.event("Next month", startsAt: hours(24 * 30))
        let tbd = Fixtures.event("TBD")
        let groups = EventGrouping.group([nextMonth, tbd, laterToday, tomorrow, live, soonToday],
                                         now: now, calendar: calendar)
        #expect(groups.map(\.section) == [.now, .today, .thisWeek, .later, .unscheduled])
        #expect(groups[1].events.map(\.title) == ["Soon", "Tonight"])
    }

    @Test func pastEventsAreDropped() {
        var ended = Fixtures.event("Ended", startsAt: hours(-3))
        ended.endsAt = hours(-1)
        // No end time: assumed 2 hours long, so started 3 hours ago means it's over.
        let noEndOld = Fixtures.event("Old", startsAt: hours(-3))
        let noEndRecent = Fixtures.event("Recent", startsAt: hours(-1))
        let groups = EventGrouping.group([ended, noEndOld, noEndRecent], now: now, calendar: calendar)
        #expect(groups.flatMap(\.events).map(\.title) == ["Recent"])
        #expect(EventGrouping.isPast(ended, now: now))
    }

    @Test func weekBoundary() {
        let sixDays = Fixtures.event("6d", startsAt: calendar.date(byAdding: .day, value: 6, to: now))
        let sevenDays = Fixtures.event("7d", startsAt: calendar.date(byAdding: .day, value: 7, to: now))
        #expect(EventGrouping.section(for: sixDays, now: now, calendar: calendar) == .thisWeek)
        #expect(EventGrouping.section(for: sevenDays, now: now, calendar: calendar) == .later)
    }

    @Test func timeLabel() {
        #expect(EventGrouping.timeLabel(for: Fixtures.event("x")) == nil)
        var e = Fixtures.event("x", startsAt: hours(3))
        #expect(EventGrouping.timeLabel(for: e)?.contains("·") == true)
        e.endsAt = hours(5)
        #expect(EventGrouping.timeLabel(for: e)?.contains("–") == true)
    }
}

@MainActor
struct EventsViewModelTests {
    private func make(_ events: [Event], spots: [StudySpot] = []) async throws -> (EventsViewModel, TestEnv) {
        let t = TestEnv()
        t.remote.events = events
        t.remote.spots = spots
        try await t.env.events.refresh()
        try await t.env.spots.refresh()
        return (EventsViewModel(events: t.env.events, spots: t.env.spots, now: { now }, calendar: calendar), t)
    }

    @Test func categoryAndGoingFilters() async throws {
        let group = Fixtures.event("Group", startsAt: hours(2), category: .studyGroup)
        let food = Fixtures.event("Pizza", startsAt: hours(3), category: .freeFood)
        let (vm, _) = try await make([group, food])
        #expect(vm.filtered.count == 2)

        vm.category = .freeFood
        #expect(vm.filtered.map(\.title) == ["Pizza"])

        vm.category = nil
        vm.goingOnly = true
        #expect(vm.filtered.isEmpty)
        await vm.toggleRSVP(group)
        #expect(vm.filtered.map(\.title) == ["Group"])
    }

    @Test func rsvpToggleUpdatesCountAndState() async throws {
        let event = Fixtures.event("Review", startsAt: hours(2), rsvps: 4)
        let (vm, t) = try await make([event])
        await vm.toggleRSVP(event)
        #expect(vm.isGoing(event))
        #expect(vm.event(id: event.id)?.rsvpCount == 5)
        await vm.toggleRSVP(vm.event(id: event.id)!)
        #expect(!vm.isGoing(event))
        #expect(vm.event(id: event.id)?.rsvpCount == 4)
        #expect(t.remote.appliedWrites == ["rsvp", "unrsvp"])
    }

    @Test func rejectedRSVPShowsErrorAndRollsBack() async throws {
        let event = Fixtures.event("Review", startsAt: hours(2), rsvps: 0)
        let (vm, t) = try await make([event])
        t.remote.writeErrors = [Fixtures.rlsError]
        await vm.toggleRSVP(event)
        #expect(!vm.isGoing(event))
        #expect(vm.event(id: event.id)?.rsvpCount == 0)
        #expect(vm.errorMessage != nil)
    }

    @Test func mapUsesEventOrSpotCoordinatesAndSkipsPast() async throws {
        let spot = Fixtures.spot("Davis Library", lat: 35.91, lng: -79.0477)
        var atSpot = Fixtures.event("At spot", startsAt: hours(1))
        atSpot.spotId = spot.id
        var ownCoords = Fixtures.event("Own coords", startsAt: hours(1))
        ownCoords.latitude = 35.912
        ownCoords.longitude = -79.05
        let noWhere = Fixtures.event("Nowhere", startsAt: hours(1))
        var past = Fixtures.event("Past", startsAt: hours(-5))
        past.latitude = 35.9
        past.longitude = -79.0
        let (vm, _) = try await make([atSpot, ownCoords, noWhere, past], spots: [spot])
        let titles = Set(vm.mappable.map(\.event.title))
        #expect(titles == ["At spot", "Own coords"])
        #expect(vm.coordinate(for: atSpot)?.latitude == 35.91)
    }
}

@MainActor
struct CreateEventViewModelTests {
    private func make(online: Bool = true) async throws -> (CreateEventViewModel, TestEnv, StudySpot) {
        let t = TestEnv()
        let spot = Fixtures.spot("Davis Library", lat: 35.91, lng: -79.0477)
        t.remote.spots = [spot]
        try await t.env.spots.refresh()
        t.connectivity.isOnline = online
        return (CreateEventViewModel(events: t.env.events, spots: t.env.spots, session: t.env.session, now: { now }), t, spot)
    }

    @Test func defaultsToNextHourForTwoHours() async throws {
        let (vm, _, _) = try await make()
        #expect(vm.startsAt == hours(1))
        #expect(vm.endsAt == hours(3))
    }

    @Test func validation() async throws {
        let (vm, _, spot) = try await make()
        #expect(vm.validationMessage == "Give the event a title.")
        vm.title = "  COMP 550 review "
        #expect(vm.validationMessage == "Pick a spot or type a location.")
        vm.spotId = spot.id
        #expect(vm.validationMessage == nil)
        #expect(vm.resolvedLocation == "Davis Library")
        vm.locationText = "Room 214"
        #expect(vm.resolvedLocation == "Room 214")
        vm.endsAt = vm.startsAt
        #expect(vm.validationMessage == "The event has to end after it starts.")
        vm.startsAt = hours(-3)
        vm.endsAt = hours(-1)
        #expect(vm.validationMessage == "That time has already passed.")
    }

    @Test func createWithSpotGetsCoordinatesAndAppearsImmediately() async throws {
        let (vm, t, spot) = try await make()
        vm.title = "COMP 550 review"
        vm.spotId = spot.id
        vm.details = "  Bring practice exams  "
        await vm.save()
        let id = try #require(vm.createdEventId)
        let event = try #require(t.env.events.event(id: id))
        #expect(event.title == "COMP 550 review")
        #expect(event.latitude == 35.91)
        #expect(event.description == "Bring practice exams")
        #expect(event.createdBy == Fixtures.userId)
        #expect(!vm.wasQueued)
        #expect(t.remote.appliedWrites == ["insertEvent:COMP 550 review"])
    }

    @Test func createOfflineIsQueuedAndCanBeRSVPdBeforeSync() async throws {
        let (vm, t, _) = try await make(online: false)
        vm.title = "Late night grind"
        vm.locationText = "Undergrad library"
        await vm.save()
        let id = try #require(vm.createdEventId)
        #expect(vm.wasQueued)
        try await t.env.events.setRSVP(eventId: id, going: true)
        #expect(t.env.sync.pendingCount == 2)

        t.connectivity.isOnline = true
        await t.env.refreshAll()
        // Replayed in order: the event exists before the RSVP that references it.
        #expect(t.remote.appliedWrites == ["insertEvent:Late night grind", "rsvp"])
    }
}
