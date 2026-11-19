//
//  EventsViewModel.swift
//  iOSApprenticeProject
//

import CoreLocation
import Foundation
import Observation

@Observable
final class EventsViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case list, map
        var id: String { rawValue }
    }

    /// nil = all categories.
    var category: EventCategory?
    var mode: Mode = .list
    /// Only events the user has RSVP'd to.
    var goingOnly = false
    var errorMessage: String?

    @ObservationIgnored private let events: EventRepository
    @ObservationIgnored private let spots: SpotRepository
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    init(events: EventRepository, spots: SpotRepository,
         now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.events = events
        self.spots = spots
        self.now = now
        self.calendar = calendar
    }

    var filtered: [Event] {
        events.events.filter { event in
            (category == nil || event.category == category)
                && (!goingOnly || events.myRSVPs.contains(event.id))
        }
    }

    var sections: [(section: EventSection, events: [Event])] {
        EventGrouping.group(filtered, now: now(), calendar: calendar)
    }

    /// Upcoming filtered events that can be placed on the map.
    var mappable: [(event: Event, coordinate: CLLocationCoordinate2D)] {
        let date = now()
        return filtered.compactMap { event in
            guard !EventGrouping.isPast(event, now: date), let c = coordinate(for: event) else { return nil }
            return (event, c)
        }
    }

    var hasAnyEvents: Bool { !events.events.isEmpty }

    func isGoing(_ event: Event) -> Bool {
        events.myRSVPs.contains(event.id)
    }

    /// The event's own coordinates, else its linked spot's.
    func coordinate(for event: Event) -> CLLocationCoordinate2D? {
        if let c = event.coordinate { return c }
        return event.spotId.flatMap { spots.spot(id: $0) }?.coordinate
    }

    func spot(for event: Event) -> StudySpot? {
        event.spotId.flatMap { spots.spot(id: $0) }
    }

    func event(id: UUID) -> Event? {
        events.event(id: id)
    }

    func toggleRSVP(_ event: Event) async {
        errorMessage = nil
        do {
            try await events.setRSVP(eventId: event.id, going: !isGoing(event))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
