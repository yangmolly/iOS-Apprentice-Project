//
//  RepositoryTests.swift
//  StudySpotTests
//
//  Network-first with cache: cached data shows immediately, refresh replaces it,
//  optimistic writes survive refreshes while pending, and rejected writes roll back.
//

import Foundation
import SwiftData
import Testing
@testable import iOSApprenticeProject

@MainActor
struct SpotRepositoryTests {
    @Test func refreshCachesForNextLaunch() async throws {
        let t = TestEnv()
        t.remote.spots = [Fixtures.spot("Davis Library"), Fixtures.spot("Dey Hall")]
        try await t.env.spots.refresh()
        #expect(t.env.spots.spots.map(\.name) == ["Davis Library", "Dey Hall"])

        // A fresh repository over the same store sees the cached data with no network.
        t.remote.readError = Fixtures.networkError
        let reloaded = SpotRepository(remote: t.remote, cache: CacheStore(container: t.env.modelContainer),
                                      sync: t.env.sync)
        reloaded.loadCached()
        #expect(reloaded.spots.count == 2)
        await #expect(throws: (any Error).self) { try await reloaded.refresh() }
        #expect(reloaded.spots.count == 2)  // failed refresh leaves the cache alone
    }

    @Test func spotAddedOfflineSurvivesRefreshUntilSynced() async throws {
        let t = TestEnv(online: false)
        t.remote.spots = [Fixtures.spot("Davis Library")]
        let new = Fixtures.newSpot("Graham Memorial")
        #expect(try await t.env.spots.add(new) == .queued)
        #expect(t.env.spots.spot(id: new.id) != nil)

        // Server data doesn't include it yet; it must not disappear.
        try await t.env.spots.refresh()
        #expect(t.env.spots.spots.map(\.name).sorted() == ["Davis Library", "Graham Memorial"])

        t.connectivity.isOnline = true
        await t.env.refreshAll()
        #expect(t.remote.appliedWrites == ["insertSpot:Graham Memorial"])
        #expect(t.env.spots.spot(id: new.id) != nil)
    }

    @Test func rejectedSpotIsRolledBack() async {
        let t = TestEnv()
        t.remote.writeErrors = [Fixtures.duplicateSpotError]
        let new = Fixtures.newSpot("Davis Library")
        await #expect(throws: SyncError.self) { try await t.env.spots.add(new) }
        #expect(t.env.spots.spot(id: new.id) == nil)
    }

    @Test func realtimeUpdateAppliesInPlace() async throws {
        let t = TestEnv()
        var spot = Fixtures.spot("Davis Library")
        t.remote.spots = [spot]
        try await t.env.spots.refresh()
        spot.avgRating = 8.4
        spot.reviewCount = 3
        t.env.spots.apply(spot)
        #expect(t.env.spots.spot(id: spot.id)?.avgRating == 8.4)
    }

    /// Regression: repositories used to hold only a ModelContext, so writing after the
    /// AppEnvironment (the container's owner) was released trapped inside SwiftData.
    @Test func repositoriesOutliveTheirEnvironment() async throws {
        var events: EventRepository?
        do {
            let t = TestEnv()
            let event = Fixtures.event("Review", rsvps: 0)
            t.remote.events = [event]
            try await t.env.events.refresh()
            events = t.env.events
        }
        let repo = try #require(events)
        try await repo.setRSVP(eventId: repo.events[0].id, going: true)
        #expect(repo.events[0].rsvpCount == 1)
    }
}

@MainActor
struct ReviewRepositoryTests {
    private func upsert(_ spotId: UUID, score: Double, bucket: RatingBucket = .liked) -> ReviewUpsert {
        ReviewUpsert(id: UUID(), spotId: spotId, userId: Fixtures.userId, bucket: bucket, score: score,
                     noiseLevel: .quiet, hasOutlets: true, hasWifi: nil, seating: nil, comments: nil)
    }

    @Test func submitIsOptimisticAndSortedByScore() async throws {
        let t = TestEnv()
        let a = UUID(), b = UUID()
        try await t.env.reviews.submit([upsert(a, score: 7.5), upsert(b, score: 9.1)])
        #expect(t.env.reviews.myReviews.map(\.spotId) == [b, a])
        #expect(t.remote.appliedWrites == ["upsertReviews:2"])
    }

    @Test func rejectedSubmitRestoresPreviousScores() async throws {
        let t = TestEnv()
        let a = UUID()
        try await t.env.reviews.submit([upsert(a, score: 8.0)])
        t.remote.writeErrors = [Fixtures.rlsError]
        await #expect(throws: SyncError.self) {
            try await t.env.reviews.submit([upsert(a, score: 3.0, bucket: .disliked), upsert(UUID(), score: 5.0)])
        }
        #expect(t.env.reviews.myReviews.count == 1)
        #expect(t.env.reviews.myReview(for: a)?.score == 8.0)
    }

    @Test func spotReviewsFallBackToOwnReviewOffline() async throws {
        let t = TestEnv()
        let a = UUID()
        try await t.env.reviews.submit([upsert(a, score: 8.0)])
        t.remote.readError = Fixtures.networkError
        let reviews = await t.env.reviews.reviews(for: a)
        #expect(reviews.map(\.score) == [8.0])
    }
}

@MainActor
struct EventRepositoryTests {
    @Test func rsvpUpdatesCountOptimistically() async throws {
        let t = TestEnv()
        let event = Fixtures.event("COMP 550 review", rsvps: 2)
        t.remote.events = [event]
        try await t.env.events.refresh()

        try await t.env.events.setRSVP(eventId: event.id, going: true)
        #expect(t.env.events.myRSVPs.contains(event.id))
        #expect(t.env.events.event(id: event.id)?.rsvpCount == 3)

        try await t.env.events.setRSVP(eventId: event.id, going: false)
        #expect(!t.env.events.myRSVPs.contains(event.id))
        #expect(t.env.events.event(id: event.id)?.rsvpCount == 2)
        #expect(t.remote.appliedWrites == ["rsvp", "unrsvp"])
    }

    @Test func offlineRSVPSurvivesRefreshAndThenSyncs() async throws {
        let t = TestEnv()
        let event = Fixtures.event("STOR 455", rsvps: 1)
        t.remote.events = [event]
        try await t.env.events.refresh()

        t.connectivity.isOnline = false
        #expect(try await t.env.events.setRSVP(eventId: event.id, going: true) == .queued)
        try await t.env.events.refresh()  // server still says 1 RSVP and not going
        #expect(t.env.events.myRSVPs.contains(event.id))
        #expect(t.env.events.event(id: event.id)?.rsvpCount == 2)

        t.connectivity.isOnline = true
        await t.env.refreshAll()
        #expect(t.remote.rsvpEventIds == [event.id])
    }

    @Test func rejectedRSVPRollsBack() async throws {
        let t = TestEnv()
        let event = Fixtures.event("Club fair", rsvps: 0)
        t.remote.events = [event]
        try await t.env.events.refresh()
        t.remote.writeErrors = [Fixtures.rlsError]
        await #expect(throws: SyncError.self) { try await t.env.events.setRSVP(eventId: event.id, going: true) }
        #expect(!t.env.events.myRSVPs.contains(event.id))
        #expect(t.env.events.event(id: event.id)?.rsvpCount == 0)
    }

    @Test func decodesEmbeddedRSVPCountFromServerJSON() throws {
        let json = """
        {"id":"44444444-4444-4444-4444-444444444444","title":"Review","category":"study_group",
         "location":"Davis","created_by":"11111111-1111-1111-1111-111111111111",
         "event_rsvps":[{"count":5}]}
        """.data(using: .utf8)!
        let event = try JSONDecoder().decode(Event.self, from: json)
        #expect(event.rsvpCount == 5)
        // Round-trips through the cache encoding.
        let cached = try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event))
        #expect(cached.rsvpCount == 5)
    }
}

@MainActor
struct SavedRepositoryTests {
    @Test func saveAndUnsavePerList() async throws {
        let t = TestEnv()
        let spot = UUID()
        try await t.env.saved.setSaved(spot, in: .wantToGo, true)
        try await t.env.saved.setSaved(spot, in: .favorite, true)
        #expect(t.env.saved.isSaved(spot, in: .wantToGo))
        #expect(t.env.saved.spotIds(in: .favorite) == [spot])

        try await t.env.saved.setSaved(spot, in: .wantToGo, false)
        #expect(!t.env.saved.isSaved(spot, in: .wantToGo))
        #expect(t.env.saved.isSaved(spot, in: .favorite))
        #expect(t.remote.appliedWrites == ["save:want_to_go", "save:favorite", "unsave:want_to_go"])
    }

    @Test func signOutResetClearsCacheAndQueue() async throws {
        let t = TestEnv(online: false)
        try await t.env.saved.setSaved(UUID(), in: .favorite, true)
        #expect(t.env.sync.pendingCount == 1)
        t.env.reset()
        #expect(t.env.saved.saved.isEmpty)
        #expect(t.env.sync.pendingCount == 0)
        #expect(t.env.session.userId == nil)
    }
}
