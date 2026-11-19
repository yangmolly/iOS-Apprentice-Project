//
//  AddSpotTests.swift
//  StudySpotTests
//

import CoreLocation
import Foundation
import Testing
@testable import iOSApprenticeProject

struct DuplicateDetectorTests {
    @Test func trigramSimilarityMatchesPgTrgm() {
        // pg_trgm: similarity('word', 'two words') = 0.36363637 (4 shared of 11 trigrams).
        #expect(abs(DuplicateDetector.similarity("word", "two words") - 4.0 / 11.0) < 1e-9)
        #expect(DuplicateDetector.trigrams("word") == ["  w", " wo", "wor", "ord", "rd "])
        #expect(DuplicateDetector.similarity("Davis Library", "davis   LIBRARY!") == 1.0)
        #expect(DuplicateDetector.similarity("", "") == 0)
    }

    let davis = Fixtures.spot("Davis Library", lat: 35.9100, lng: -79.0477)
    let cube2 = Fixtures.spot("Davis Collaboration Cube #2", lat: 35.9100, lng: -79.0477)

    @Test func sameNameNearbyBlocks() {
        let m = DuplicateDetector.matches(name: "davis library", latitude: 35.91003, longitude: -79.04772, among: [davis, cube2])
        #expect(m.first?.spot.name == "Davis Library")
        #expect(m.first?.isBlocking == true)
    }

    @Test func typoNearbySuggests() {
        let m = DuplicateDetector.matches(name: "Davis Libary", latitude: 35.9101, longitude: -79.0478, among: [davis])
        #expect(m.count == 1)
        #expect(m[0].similarity >= DuplicateDetector.suggestThreshold)
    }

    @Test func differentRoomNumberSuggestsButDoesNotBlock() {
        let m = DuplicateDetector.matches(name: "Davis Collaboration Cube #3", latitude: 35.9100, longitude: -79.0477, among: [cube2])
        #expect(m.count == 1)
        #expect(m[0].similarity >= DuplicateDetector.blockThreshold)
        #expect(!m[0].isBlocking)
    }

    @Test func farAwayOrUnrelatedIsIgnored() {
        // Same name ~1.1 km away.
        #expect(DuplicateDetector.matches(name: "Davis Library", latitude: 35.92, longitude: -79.0477, among: [davis]).isEmpty)
        // Unrelated name at the same spot (a different room in the building).
        #expect(DuplicateDetector.matches(name: "Map Room", latitude: 35.9100, longitude: -79.0477, among: [davis]).isEmpty)
    }
}

@MainActor
struct AddSpotViewModelTests {
    let davis = Fixtures.spot("Davis Library", lat: 35.9100, lng: -79.0477)
    let here = CLLocationCoordinate2D(latitude: 35.9100, longitude: -79.0477)

    private func make(online: Bool = true) async throws -> (AddSpotViewModel, TestEnv) {
        let t = TestEnv()
        t.remote.spots = [davis]
        try await t.env.spots.refresh()
        t.connectivity.isOnline = online
        if !online { t.remote.readError = Fixtures.networkError }
        return (AddSpotViewModel(spots: t.env.spots, session: t.env.session, coordinate: here), t)
    }

    @Test func validation() async throws {
        let (vm, _) = try await make()
        #expect(!vm.canSave)
        #expect(vm.validationHint == "Give the spot a name.")
        vm.name = "  Graham Memorial "
        #expect(vm.canSave)
        vm.coordinate = nil
        #expect(vm.validationHint == "Place the spot on the map.")
    }

    @Test func blockingDuplicatePreventsSave() async throws {
        let (vm, t) = try await make()
        vm.name = "Davis library"
        await vm.checkForDuplicates()
        #expect(vm.blockingMatch?.spot.id == davis.id)
        #expect(!vm.canSave)
        await vm.save()
        #expect(t.remote.appliedWrites.isEmpty)
        vm.useExisting(davis)
        #expect(vm.outcome == .usedExisting(spotId: davis.id))
    }

    @Test func suggestionNeedsDecisionThenSaves() async throws {
        let (vm, t) = try await make()
        vm.name = "Davis Libary Annex"
        await vm.checkForDuplicates()
        #expect(!vm.suggestions.isEmpty)
        #expect(vm.blockingMatch == nil)
        #expect(vm.needsSuggestionDecision)

        await vm.save()
        #expect(t.remote.appliedWrites.isEmpty)   // waits for a decision

        vm.acknowledgedSuggestions = true
        vm.noiseLevel = .quiet
        vm.hoursMode = .custom
        vm.opensAtMinutes = 7 * 60 + 30
        await vm.save()
        guard case .created(let id, let queued)? = vm.outcome else {
            Issue.record("expected created"); return
        }
        #expect(!queued)
        let saved = try #require(t.env.spots.spot(id: id))
        #expect(saved.name == "Davis Libary Annex")
        #expect(saved.noiseLevel == .quiet)
        #expect(saved.opensAt == "07:30:00")
        #expect(saved.closesAt == "22:00:00")
        #expect(saved.createdBy == Fixtures.userId)
    }

    @Test func remoteSuggestionsAreMerged() async throws {
        let (vm, t) = try await make()
        // A spot another user just added that isn't in the local cache yet.
        let fresh = Fixtures.spot("Graham Memorial Lounge", lat: 35.9101, lng: -79.0478)
        t.remote.similar = [fresh]
        vm.name = "Graham Memorial"
        await vm.checkForDuplicates()
        #expect(vm.suggestions.map(\.spot.id) == [fresh.id])
    }

    @Test func savesOfflineAsQueued() async throws {
        let (vm, t) = try await make(online: false)
        vm.name = "Graham Memorial"
        await vm.checkForDuplicates()   // remote lookup fails quietly offline
        await vm.save()
        guard case .created(let id, let queued)? = vm.outcome else {
            Issue.record("expected created"); return
        }
        #expect(queued)
        #expect(t.env.spots.spot(id: id) != nil)
        #expect(t.env.sync.pendingCount == 1)
    }

    @Test func serverDuplicateRejectionRollsBack() async throws {
        let (vm, t) = try await make()
        t.remote.writeErrors = [Fixtures.duplicateSpotError]
        vm.name = "Totally New Name"
        await vm.save()
        #expect(vm.outcome == nil)
        #expect(vm.errorMessage?.contains("similar spot already exists") == true)
        #expect(t.env.spots.spots.count == 1)
    }
}
