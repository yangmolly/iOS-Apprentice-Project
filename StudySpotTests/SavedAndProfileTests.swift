//
//  SavedAndProfileTests.swift
//  StudySpotTests
//

import Foundation
import Testing
@testable import iOSApprenticeProject

@MainActor
struct SavedViewModelTests {
    let davis = Fixtures.spot("Davis Library")
    let dey = Fixtures.spot("Dey Hall")

    private func make() async throws -> (SavedViewModel, TestEnv) {
        let t = TestEnv()
        t.remote.spots = [dey, davis]
        try await t.env.spots.refresh()
        return (SavedViewModel(saved: t.env.saved, spots: t.env.spots), t)
    }

    @Test func listsAreSeparateAndSorted() async throws {
        let (vm, t) = try await make()
        try await t.env.saved.setSaved(dey.id, in: .wantToGo, true)
        try await t.env.saved.setSaved(davis.id, in: .wantToGo, true)
        try await t.env.saved.setSaved(davis.id, in: .favorite, true)

        #expect(vm.items.map(\.name) == ["Davis Library", "Dey Hall"])
        #expect(vm.count(in: .wantToGo) == 2)
        vm.list = .favorite
        #expect(vm.items.map(\.name) == ["Davis Library"])
    }

    @Test func removeAndMoveToFavorites() async throws {
        let (vm, t) = try await make()
        try await t.env.saved.setSaved(dey.id, in: .wantToGo, true)
        try await t.env.saved.setSaved(davis.id, in: .wantToGo, true)

        await vm.remove(dey)
        #expect(vm.items.map(\.name) == ["Davis Library"])

        await vm.moveToFavorites(davis)
        #expect(vm.items.isEmpty)
        #expect(t.env.saved.isSaved(davis.id, in: .favorite))
    }

    @Test func failedMoveKeepsWantToGo() async throws {
        let (vm, t) = try await make()
        try await t.env.saved.setSaved(davis.id, in: .wantToGo, true)
        t.remote.writeErrors = [Fixtures.rlsError]
        await vm.moveToFavorites(davis)
        #expect(vm.errorMessage != nil)
        #expect(t.env.saved.isSaved(davis.id, in: .wantToGo))
        #expect(!t.env.saved.isSaved(davis.id, in: .favorite))
    }

    @Test func savedIdsWithoutLoadedSpotAreSkipped() async throws {
        let (vm, t) = try await make()
        try await t.env.saved.setSaved(UUID(), in: .wantToGo, true)
        #expect(vm.items.isEmpty)
    }
}

@MainActor
struct ProfileViewModelTests {
    @Test func headerFallsBackWithoutProfile() async throws {
        let t = TestEnv()
        let vm = ProfileViewModel(env: t.env)
        #expect(vm.name == "UNC student")
        #expect(vm.email == "alice@unc.edu")
        #expect(vm.initials == "US")

        try await t.env.profile.refresh()
        #expect(vm.name == "Alice")
        #expect(vm.initials == "A")
    }

    @Test func rankingAndSpotsAdded() async throws {
        let t = TestEnv()
        let mine = StudySpot(name: "Graham Lounge", latitude: 35.91, longitude: -79.05, createdBy: Fixtures.userId)
        let theirs = StudySpot(name: "Davis Library", latitude: 35.91, longitude: -79.0477, createdBy: Fixtures.otherUserId)
        t.remote.spots = [mine, theirs]
        try await t.env.spots.refresh()

        for (spot, bucket) in [(theirs, RatingBucket.fine), (mine, .liked)] {
            let flow = RatingFlowViewModel(spot: spot, reviews: t.env.reviews, spots: t.env.spots, session: t.env.session)
            flow.choose(bucket)
            await flow.save()
        }

        let vm = ProfileViewModel(env: t.env)
        #expect(vm.ranking.map(\.rank) == [1, 2])
        #expect(vm.ranking.map { $0.spot?.name } == ["Graham Lounge", "Davis Library"])
        #expect(vm.spotsAdded.map(\.name) == ["Graham Lounge"])
    }

    @Test func signOutWarningOnlyWithPendingChanges() async throws {
        let t = TestEnv(online: false)
        let vm = ProfileViewModel(env: t.env)
        #expect(vm.signOutWarning == nil)
        try await t.env.saved.setSaved(UUID(), in: .favorite, true)
        #expect(vm.pendingCount == 1)
        #expect(vm.signOutWarning == "1 change hasn't synced yet and will be lost.")
        try await t.env.saved.setSaved(UUID(), in: .favorite, true)
        #expect(vm.signOutWarning == "2 changes haven't synced yet and will be lost.")
    }

    @Test func syncNowFlushesQueue() async throws {
        let t = TestEnv(online: false)
        try await t.env.saved.setSaved(UUID(), in: .wantToGo, true)
        let vm = ProfileViewModel(env: t.env)
        t.connectivity.isOnline = true
        await vm.syncNow()
        #expect(vm.pendingCount == 0)
        #expect(t.remote.appliedWrites == ["save:want_to_go"])
    }
}
