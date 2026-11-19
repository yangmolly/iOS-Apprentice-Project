//
//  EventRepository.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

@Observable
final class EventRepository {
    private(set) var events: [Event] = []
    /// Ids of events the signed-in user has RSVP'd to.
    private(set) var myRSVPs: Set<UUID> = []

    @ObservationIgnored private let remote: RemoteDataSource
    @ObservationIgnored private let cache: CacheStore
    @ObservationIgnored private let sync: SyncQueue
    @ObservationIgnored private let session: UserSession

    init(remote: RemoteDataSource, cache: CacheStore, sync: SyncQueue, session: UserSession) {
        self.remote = remote
        self.cache = cache
        self.sync = sync
        self.session = session
    }

    func event(id: UUID) -> Event? {
        events.first { $0.id == id }
    }

    func loadCached() {
        events = cache.load(.event, as: Event.self)
            .sorted { ($0.startsAt ?? .distantFuture) < ($1.startsAt ?? .distantFuture) }
        myRSVPs = Set(cache.load(.myRSVP, as: EventRSVP.self).map(\.eventId))
    }

    func refresh() async throws {
        let userId = try session.requireUserId()
        async let freshEvents = remote.fetchEvents()
        async let freshRSVPs = remote.fetchRSVPEventIds(userId: userId)
        let (events, rsvpIds) = try await (freshEvents, freshRSVPs)

        let pendingRSVPs = sync.pendingIds(for: .myRSVP)
        // Keep local RSVP counts for events with RSVP changes still waiting to sync.
        let merged = events.map { event -> Event in
            guard pendingRSVPs.contains(event.id.uuidString),
                  let local = self.event(id: event.id) else { return event }
            var e = event
            e.rsvpCount = local.rsvpCount
            return e
        }
        cache.replaceAll(.event, with: merged, id: { $0.id.uuidString }, keeping: sync.pendingIds(for: .event))
        cache.replaceAll(.myRSVP, with: rsvpIds.map { EventRSVP(eventId: $0, userId: userId) },
                         id: { $0.eventId.uuidString }, keeping: pendingRSVPs)
        loadCached()
    }

    @discardableResult
    func create(_ event: NewEvent) async throws -> SubmitResult {
        cache.upsert(.event, event.asEvent, id: event.id.uuidString)
        loadCached()
        do {
            return try await sync.submit(.insertEvent(event))
        } catch {
            cache.delete(.event, id: event.id.uuidString)
            loadCached()
            throw error
        }
    }

    /// RSVP or cancel. Updates the RSVP state and count right away; rolls back if rejected.
    @discardableResult
    func setRSVP(eventId: UUID, going: Bool) async throws -> SubmitResult {
        let userId = try session.requireUserId()
        guard myRSVPs.contains(eventId) != going else { return .sent }
        let rsvp = EventRSVP(eventId: eventId, userId: userId)

        applyLocalRSVP(rsvp, going: going)
        do {
            return try await sync.submit(going ? .insertRSVP(rsvp) : .deleteRSVP(rsvp))
        } catch {
            applyLocalRSVP(rsvp, going: !going)
            throw error
        }
    }

    private func applyLocalRSVP(_ rsvp: EventRSVP, going: Bool) {
        if going {
            cache.upsert(.myRSVP, rsvp, id: rsvp.eventId.uuidString)
        } else {
            cache.delete(.myRSVP, id: rsvp.eventId.uuidString)
        }
        if var event = event(id: rsvp.eventId) {
            event.rsvpCount = max(0, event.rsvpCount + (going ? 1 : -1))
            cache.upsert(.event, event, id: event.id.uuidString)
        }
        loadCached()
    }
}
