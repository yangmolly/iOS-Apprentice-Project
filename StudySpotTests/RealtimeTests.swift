//
//  RealtimeTests.swift
//  StudySpotTests
//

import Foundation
import Testing
@testable import iOSApprenticeProject

@MainActor
struct RealtimeTests {
    @Test func liveUpdatesRunForTheSignedInSession() async throws {
        let t = TestEnv()
        var spot = Fixtures.spot("Davis Library", rating: 7.0)
        t.remote.spots = [spot]
        #expect(!t.feed.isRunning)

        t.env.startSession()
        #expect(t.feed.isRunning)
        try await waitUntil { !t.env.spots.spots.isEmpty }

        // Someone else rates it; the trigger updates the row and Realtime delivers it.
        spot.avgRating = 8.6
        spot.reviewCount = 2
        t.feed.send(spot)
        #expect(t.env.spots.spot(id: spot.id)?.avgRating == 8.6)
        #expect(t.env.spots.spot(id: spot.id)?.reviewCount == 2)

        // A spot someone else just added appears without a refresh.
        let added = Fixtures.spot("Graham Memorial", lat: 35.913, lng: -79.051)
        t.feed.send(added)
        #expect(t.env.spots.spot(id: added.id) != nil)

        t.env.reset()
        #expect(!t.feed.isRunning)
    }

    @Test func liveUpdatesPersistToCache() async throws {
        let t = TestEnv()
        var spot = Fixtures.spot("Dey Hall", rating: 5.0)
        t.remote.spots = [spot]
        try await t.env.spots.refresh()
        t.env.startSession()
        spot.avgRating = 6.1
        t.feed.send(spot)

        t.env.spots.loadCached()   // re-read from SwiftData
        #expect(t.env.spots.spot(id: spot.id)?.avgRating == 6.1)
    }

    @Test func decodesRealtimeRecordShape() throws {
        // Realtime sends the full row: numeric avg_rating, Postgres time strings, nulls for unknowns.
        let json = """
        {"id":"8f0c6b1e-2b7a-4b5e-9a57-3e1f6c2d9a10","name":"Davis Library","building":null,
         "latitude":35.91,"longitude":-79.0477,"created_by":null,"noise_level":"quiet",
         "has_outlets":true,"has_wifi":null,"seating":"both","opens_at":"08:00:00","closes_at":"02:00:00",
         "open_24h":false,"avg_rating":8.6,"review_count":2,"created_at":"2026-11-07T12:00:00+00:00"}
        """.data(using: .utf8)!
        let spot = try JSONDecoder().decode(StudySpot.self, from: json)
        #expect(spot.avgRating == 8.6)
        #expect(spot.noiseLevel == .quiet)
        #expect(spot.hasWifi == nil)
        #expect(spot.opensAt == "08:00:00")
    }
}
