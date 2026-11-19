//
//  SyncTests.swift
//  StudySpotTests
//

import Foundation
import Testing
@testable import iOSApprenticeProject

struct SyncFailureTests {
    @Test func networkErrorsAreTransient() {
        #expect(SyncFailure.classify(Fixtures.networkError) == .transient)
        #expect(SyncFailure.classify(code: nil, message: "", isNetworkError: true) == .transient)
    }

    @Test func duplicateSpotIsPermanentWithReadableMessage() {
        let failure = SyncFailure.classify(Fixtures.duplicateSpotError)
        #expect(failure == .permanent(message: "A similar spot already exists: \"Davis Library\" already exists nearby."))
    }

    @Test func rlsIsPermanent() {
        #expect(SyncFailure.classify(Fixtures.rlsError) == .permanent(message: "You don't have permission to do that."))
    }

    @Test func primaryKeyConflictMeansAlreadyApplied() {
        let failure = SyncFailure.classify(code: "23505",
            message: "duplicate key value violates unique constraint \"event_rsvps_pkey\"", isNetworkError: false)
        #expect(failure == .alreadyApplied)
    }

    @Test func otherUniqueConflictIsPermanent() {
        let failure = SyncFailure.classify(code: "23505",
            message: "duplicate key value violates unique constraint \"study_spots_name_key\"", isNetworkError: false)
        #expect(failure == .permanent(message: "That already exists."))
    }

    @Test func serverErrorsAreTransient() {
        #expect(SyncFailure.classify(code: "PGRST000", message: "timeout", isNetworkError: false) == .transient)
        #expect(SyncFailure.classify(code: nil, message: "Bad gateway", isNetworkError: false) == .transient)
    }
}

@MainActor
struct SyncQueueTests {
    @Test func sendsImmediatelyWhenOnline() async throws {
        let t = TestEnv(online: true)
        let result = try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("A")))
        #expect(result == .sent)
        #expect(t.remote.appliedWrites == ["insertSpot:A"])
        #expect(t.env.sync.pendingCount == 0)
    }

    @Test func queuesWhenOfflineAndFlushesInOrder() async throws {
        let t = TestEnv(online: false)
        #expect(try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("A"))) == .queued)
        #expect(try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("B"))) == .queued)
        #expect(t.env.sync.pendingCount == 2)
        #expect(t.remote.appliedWrites.isEmpty)

        t.connectivity.isOnline = true
        await t.env.sync.flush()
        #expect(t.remote.appliedWrites == ["insertSpot:A", "insertSpot:B"])
        #expect(t.env.sync.pendingCount == 0)
    }

    @Test func newWritesQueueBehindPendingOnesToKeepOrder() async throws {
        let t = TestEnv(online: false)
        try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("A")))
        t.connectivity.isOnline = true
        // Online now, but A hasn't flushed yet, so B must not jump ahead of it.
        #expect(try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("B"))) == .queued)
        await t.env.sync.flush()
        #expect(t.remote.appliedWrites == ["insertSpot:A", "insertSpot:B"])
    }

    @Test func transientFailureQueuesAndStopsFlush() async throws {
        let t = TestEnv(online: true)
        t.remote.writeErrors = [Fixtures.networkError]
        #expect(try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("A"))) == .queued)

        try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("B")))  // queued behind A
        t.remote.writeErrors = [Fixtures.networkError]
        await t.env.sync.flush()
        #expect(t.remote.appliedWrites.isEmpty)  // stopped at A, B not attempted
        #expect(t.env.sync.pendingCount == 2)

        await t.env.sync.flush()
        #expect(t.remote.appliedWrites == ["insertSpot:A", "insertSpot:B"])
    }

    @Test func permanentFailureOnSubmitThrows() async {
        let t = TestEnv(online: true)
        t.remote.writeErrors = [Fixtures.duplicateSpotError]
        await #expect(throws: SyncError.self) {
            try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("Davis Library")))
        }
        #expect(t.env.sync.pendingCount == 0)
    }

    @Test func permanentFailureDuringFlushIsDroppedAndReported() async throws {
        let t = TestEnv(online: false)
        var dropped: [WriteOperation] = []
        t.env.sync.onPermanentFailure = { dropped.append($0) }
        let bad = Fixtures.newSpot("Davis Library")
        try await t.env.sync.submit(.insertSpot(bad))
        try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("Good")))

        t.connectivity.isOnline = true
        t.remote.writeErrors = [Fixtures.duplicateSpotError]
        await t.env.sync.flush()

        #expect(dropped == [.insertSpot(bad)])
        #expect(t.env.sync.lastFailureMessage?.contains("similar spot") == true)
        #expect(t.remote.appliedWrites == ["insertSpot:Good"])  // the queue kept going
        #expect(t.env.sync.pendingCount == 0)
    }

    @Test func giveUpAfterMaxTransientAttempts() async throws {
        let t = TestEnv(online: false)
        try await t.env.sync.submit(.insertSpot(Fixtures.newSpot("A")))
        t.connectivity.isOnline = true
        for _ in 0..<SyncQueue.maxAttempts {
            t.remote.writeErrors = [Fixtures.networkError]
            await t.env.sync.flush()
        }
        #expect(t.env.sync.pendingCount == 0)
        #expect(t.env.sync.lastFailureMessage != nil)
    }

    @Test func pendingIdsCoverTouchedEntities() async throws {
        let t = TestEnv(online: false)
        let spot = Fixtures.newSpot("A")
        try await t.env.sync.submit(.insertSpot(spot))
        #expect(t.env.sync.pendingIds(for: .spot) == [spot.id.uuidString])
        #expect(t.env.sync.pendingIds(for: .event).isEmpty)
    }
}
