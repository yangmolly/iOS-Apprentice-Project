//
//  LiveBackendTests.swift
//  StudySpotTests
//
//  End-to-end checks against the real Supabase project, through the app's own
//  repositories, sync queue and Realtime feed. Skipped unless credentials are
//  passed in, so normal test runs never touch the backend:
//
//    TEST_RUNNER_STUDYSPOT_LIVE_EMAIL1=… TEST_RUNNER_STUDYSPOT_LIVE_PASSWORD1=… \
//    TEST_RUNNER_STUDYSPOT_LIVE_EMAIL2=… TEST_RUNNER_STUDYSPOT_LIVE_PASSWORD2=… \
//    xcodebuild … test -only-testing:StudySpotTests/LiveBackendTests
//
//  Everything these tests write (reviews, saves, RSVPs, events) is deleted at the
//  end of each test. They never insert a spot, because spots can't be deleted.
//

import Foundation
import Supabase
import Testing
@testable import iOSApprenticeProject

private enum LiveConfig {
    static let env = ProcessInfo.processInfo.environment
    static let user1 = credentials(1)
    static let user2 = credentials(2)
    static var isEnabled: Bool { user1 != nil && user2 != nil }

    static func credentials(_ n: Int) -> (email: String, password: String)? {
        guard let email = env["STUDYSPOT_LIVE_EMAIL\(n)"], let password = env["STUDYSPOT_LIVE_PASSWORD\(n)"],
              !email.isEmpty, !password.isEmpty else { return nil }
        return (email, password)
    }
}

/// Keeps each test client's session out of the Keychain (and away from the app's own session).
nonisolated private final class MemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

/// One signed-in user running the real data layer.
@MainActor
private final class LiveUser {
    let client: SupabaseClient
    let env: AppEnvironment
    let userId: UUID
    private let connectivity: Connectivity

    private init(client: SupabaseClient, env: AppEnvironment, userId: UUID, connectivity: Connectivity) {
        self.client = client
        self.env = env
        self.userId = userId
        self.connectivity = connectivity
    }

    static func signIn(_ creds: (email: String, password: String)) async throws -> LiveUser {
        let client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(auth: .init(storage: MemoryAuthStorage(),
                                                       emitLocalSessionAsInitialSession: true))
        )
        let session = try await client.auth.signIn(email: creds.email, password: creds.password)
        let connectivity = Connectivity(true)
        let env = AppEnvironment(modelContainer: AppEnvironment.makeContainer(inMemory: true),
                                 remote: SupabaseRemote(client: client),
                                 isOnline: { connectivity.isOnline },
                                 spotFeed: SupabaseSpotChangeFeed(client: client))
        env.session.userId = session.user.id
        env.session.email = session.user.email
        return LiveUser(client: client, env: env, userId: session.user.id, connectivity: connectivity)
    }

    func setOnline(_ online: Bool) { connectivity.isOnline = online }

    func rate(_ spot: StudySpot, _ bucket: RatingBucket, noise: NoiseLevel? = nil) async throws -> RatingFlowViewModel {
        let flow = RatingFlowViewModel(spot: spot, reviews: env.reviews, spots: env.spots, session: env.session)
        flow.choose(bucket)
        // First review in a bucket needs no comparisons; later ones say "the new spot is better".
        while case .compare = flow.step { flow.answer(newIsBetter: true) }
        flow.noiseLevel = noise
        await flow.save()
        return flow
    }

    /// Delete everything this user wrote. Spots are never written by these tests.
    func cleanUp(eventIds: [UUID] = []) async {
        let id = userId.uuidString
        _ = try? await client.from("event_rsvps").delete().eq("user_id", value: id).execute()
        _ = try? await client.from("saved_spots").delete().eq("user_id", value: id).execute()
        _ = try? await client.from("reviews").delete().eq("user_id", value: id).execute()
        for eventId in eventIds {
            _ = try? await client.from("events").delete().eq("id", value: eventId.uuidString).execute()
        }
        // Clear local cache and queue, but stay signed in.
        let email = env.session.email
        env.reset()
        env.session.userId = userId
        env.session.email = email
    }
}

/// Fetch one spot straight from the server, bypassing every cache.
@MainActor
private func serverSpot(_ id: UUID, via user: LiveUser) async throws -> StudySpot {
    try await user.client.from("study_spots").select().eq("id", value: id.uuidString).single().execute().value
}

@MainActor
@Suite(.serialized, .enabled(if: LiveConfig.isEnabled, "Set STUDYSPOT_LIVE_* credentials to run"))
struct LiveBackendTests {

    @Test func signInLoadsSpotsAndProfile() async throws {
        let alice = try await LiveUser.signIn(LiveConfig.user1!)
        defer { alice.env.reset() }
        await alice.env.refreshAll()

        #expect(!alice.env.isShowingCachedData, "every refresh should succeed against the live schema")
        #expect(alice.env.spots.spots.count >= 1)
        #expect(alice.env.profile.profile?.id == alice.userId)
    }

    @Test func ratingUpdatesAverageAndReachesOtherUserLive() async throws {
        let alice = try await LiveUser.signIn(LiveConfig.user1!)
        let bob = try await LiveUser.signIn(LiveConfig.user2!)
        await alice.cleanUp(); await bob.cleanUp()

        // Alice is watching; Bob rates.
        alice.env.startSession()
        await bob.env.refreshAll()
        try await waitUntil(timeout: .seconds(10)) { !alice.env.spots.spots.isEmpty && !alice.env.isRefreshing }
        let spot = try #require(bob.env.spots.spots.first { $0.name == "Dey Hall" } ?? bob.env.spots.spots.first)
        // Give the Realtime channel time to join before the change happens.
        try await Task.sleep(for: .seconds(3))

        let bobFlow = try await bob.rate(spot, .liked, noise: .quiet)
        #expect(bobFlow.errorMessage == nil)
        #expect(bobFlow.step == .saved(queued: false))

        // Trigger: average and count on the row.
        let afterBob = try await serverSpot(spot.id, via: bob)
        #expect(afterBob.reviewCount == 1)
        #expect(afterBob.avgRating == 8.4, "single liked review is placed mid-bucket")
        #expect(afterBob.noiseLevel == .quiet, "consensus attribute from the only review")

        // Realtime: Alice's repository sees it without refreshing.
        try await waitUntil(timeout: .seconds(15)) { alice.env.spots.spot(id: spot.id)?.reviewCount == 1 }
        #expect(alice.env.spots.spot(id: spot.id)?.avgRating == 8.4)

        // Second rating averages in.
        let aliceFlow = try await alice.rate(spot, .fine)
        #expect(aliceFlow.errorMessage == nil)
        let afterBoth = try await serverSpot(spot.id, via: alice)
        #expect(afterBoth.reviewCount == 2)
        #expect(afterBoth.avgRating == 6.7, "mean of 8.4 and 5.0")
        try await waitUntil(timeout: .seconds(15)) { bob.env.spots.spot(id: spot.id) != nil }

        await alice.cleanUp(); await bob.cleanUp()
        let afterCleanup = try await serverSpot(spot.id, via: alice)
        #expect(afterCleanup.reviewCount == 0)
        #expect(afterCleanup.avgRating == nil)
    }

    @Test func offlineWritesQueueAndFlushOnReconnect() async throws {
        let alice = try await LiveUser.signIn(LiveConfig.user1!)
        await alice.cleanUp()
        await alice.env.refreshAll()
        let spots = alice.env.spots.spots
        let save = try #require(spots.first { $0.name == "Davis Library" } ?? spots.first)
        let rate = try #require(spots.first { $0.name == "Gardner Hall" } ?? spots.last)

        alice.setOnline(false)
        #expect(try await alice.env.saved.setSaved(save.id, in: .wantToGo, true) == .queued)
        let flow = try await alice.rate(rate, .disliked)
        #expect(flow.step == .saved(queued: true))
        #expect(alice.env.sync.pendingCount == 2)
        #expect(alice.env.saved.isSaved(save.id, in: .wantToGo), "optimistic")

        let remote = SupabaseRemote(client: alice.client)
        #expect(try await remote.fetchSaved(userId: alice.userId).isEmpty, "nothing sent while offline")

        alice.setOnline(true)
        await alice.env.refreshAll()
        #expect(alice.env.sync.pendingCount == 0)
        #expect(alice.env.sync.lastFailureMessage == nil)
        #expect(try await remote.fetchSaved(userId: alice.userId).map(\.spotId) == [save.id])
        let server = try await serverSpot(rate.id, via: alice)
        #expect(server.reviewCount == 1)
        #expect(server.avgRating == 1.7)

        await alice.cleanUp()
    }

    @Test func eventsCreateRSVPAndCount() async throws {
        let alice = try await LiveUser.signIn(LiveConfig.user1!)
        let bob = try await LiveUser.signIn(LiveConfig.user2!)
        await alice.env.refreshAll()
        let start = Date.now.addingTimeInterval(86_400)
        let event = NewEvent(id: UUID(), title: "StudySpot test event (deleted after test)", category: .studyGroup,
                             location: "Davis Library", spotId: nil, startsAt: start,
                             endsAt: start.addingTimeInterval(3_600), description: nil,
                             latitude: nil, longitude: nil, createdBy: alice.userId)
        do {
            #expect(try await alice.env.events.create(event) == .sent)
            await bob.env.refreshAll()
            #expect(bob.env.events.event(id: event.id) != nil)

            #expect(try await bob.env.events.setRSVP(eventId: event.id, going: true) == .sent)
            await alice.env.refreshAll()
            #expect(alice.env.events.event(id: event.id)?.rsvpCount == 1)

            try await bob.env.events.setRSVP(eventId: event.id, going: false)
            await alice.env.refreshAll()
            #expect(alice.env.events.event(id: event.id)?.rsvpCount == 0)
        } catch {
            Issue.record(error)
        }
        await bob.cleanUp()
        await alice.cleanUp(eventIds: [event.id])
    }

    @Test func rlsBlocksWritingAsSomeoneElse() async throws {
        let alice = try await LiveUser.signIn(LiveConfig.user1!)
        let bob = try await LiveUser.signIn(LiveConfig.user2!)
        await alice.env.refreshAll()
        let spot = try #require(alice.env.spots.spots.first)
        let remote = SupabaseRemote(client: alice.client)

        await #expect(throws: (any Error).self) {
            try await remote.insertSaved(SavedSpot(userId: bob.userId, spotId: spot.id, list: .favorite))
        }
        await #expect(throws: (any Error).self) {
            try await remote.upsertReviews([ReviewUpsert(id: UUID(), spotId: spot.id, userId: bob.userId,
                                                         bucket: .liked, score: 9.9, noiseLevel: nil,
                                                         hasOutlets: nil, hasWifi: nil, seating: nil, comments: nil)])
        }
        // Spots have no delete policy: the delete matches zero rows.
        _ = try? await alice.client.from("study_spots").delete().eq("id", value: spot.id.uuidString).execute()
        #expect(try await serverSpot(spot.id, via: alice).id == spot.id)

        await alice.cleanUp(); await bob.cleanUp()
    }

    @Test func similarSpotsRPC() async throws {
        let alice = try await LiveUser.signIn(LiveConfig.user1!)
        defer { alice.env.reset() }
        await alice.env.refreshAll()
        let davis = try #require(alice.env.spots.spots.first { $0.name == "Davis Library" })
        let similar = await alice.env.spots.remoteSimilarSpots(name: "davis library", latitude: davis.latitude,
                                                               longitude: davis.longitude)
        #expect(similar.contains { $0.id == davis.id })
    }
}
