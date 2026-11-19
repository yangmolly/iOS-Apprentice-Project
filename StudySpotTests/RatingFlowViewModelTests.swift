//
//  RatingFlowViewModelTests.swift
//  StudySpotTests
//

import Foundation
import Testing
@testable import iOSApprenticeProject

@MainActor
struct RatingFlowViewModelTests {
    let davis = Fixtures.spot("Davis Library", noise: .quiet, outlets: true)
    let dey = Fixtures.spot("Dey Hall")
    let union = Fixtures.spot("Student Union")

    private func env(spots: [StudySpot]) async throws -> TestEnv {
        let t = TestEnv()
        t.remote.spots = spots
        try await t.env.spots.refresh()
        return t
    }

    private func flow(_ t: TestEnv, _ spot: StudySpot) -> RatingFlowViewModel {
        RatingFlowViewModel(spot: spot, reviews: t.env.reviews, spots: t.env.spots, session: t.env.session)
    }

    @Test func firstRatingSkipsComparisonsAndPrefillsFromSpot() async throws {
        let t = try await env(spots: [davis])
        let vm = flow(t, davis)
        #expect(!vm.isReRating)
        #expect(vm.noiseLevel == .quiet)
        #expect(vm.hasOutlets == true)

        vm.choose(.liked)
        #expect(vm.step == .details)
        #expect(vm.resultingScore == 8.4)

        vm.comments = "  Great on weekends  "
        await vm.save()
        #expect(vm.step == .saved(queued: false))
        let saved = try #require(t.env.reviews.myReview(for: davis.id))
        #expect(saved.score == 8.4)
        #expect(saved.bucket == .liked)
        #expect(saved.comments == "Great on weekends")
        #expect(t.remote.myReviews.count == 1)
    }

    @Test func comparisonsPlaceSpotAndRescoreOthersInOneWrite() async throws {
        let t = try await env(spots: [davis, dey, union])
        let first = flow(t, davis)
        first.choose(.liked)
        await first.save()

        let second = flow(t, dey)
        second.choose(.liked)
        #expect(second.step == .compare)
        #expect(second.comparisonName == "Davis Library")
        second.answer(newIsBetter: true)
        #expect(second.step == .details)
        await second.save()

        #expect(t.env.reviews.myReview(for: dey.id)?.score == 9.2)
        #expect(t.env.reviews.myReview(for: davis.id)?.score == 7.5)   // pushed down
        #expect(t.remote.appliedWrites.last == "upsertReviews:2")
        #expect(t.env.reviews.myReviews.map(\.spotId) == [dey.id, davis.id])
    }

    @Test func tooCloseToCallFinishesPlacement() async throws {
        let t = try await env(spots: [davis, dey])
        let first = flow(t, davis)
        first.choose(.fine)
        await first.save()

        let vm = flow(t, dey)
        vm.choose(.fine)
        vm.tie()
        #expect(vm.step == .details)
    }

    @Test func reRateKeepsReviewIdAndPrefillsPreviousAnswers() async throws {
        let t = try await env(spots: [davis])
        let first = flow(t, davis)
        first.choose(.liked)
        first.hasWifi = false
        await first.save()
        let originalId = try #require(t.env.reviews.myReview(for: davis.id)?.id)

        let again = flow(t, davis)
        #expect(again.isReRating)
        #expect(again.previousScore == 8.4)
        #expect(again.hasWifi == false)
        again.choose(.disliked)
        await again.save()
        let updated = try #require(t.env.reviews.myReview(for: davis.id))
        #expect(updated.id == originalId)
        #expect(updated.bucket == .disliked)
        #expect(updated.score == 1.7)
    }

    @Test func savesOfflineAndReportsQueued() async throws {
        let t = try await env(spots: [davis])
        t.connectivity.isOnline = false
        let vm = flow(t, davis)
        vm.choose(.liked)
        await vm.save()
        #expect(vm.step == .saved(queued: true))
        #expect(t.env.reviews.myReview(for: davis.id) != nil)
        #expect(t.env.sync.pendingCount == 1)
    }

    @Test func rejectedSaveShowsErrorAndStaysOnDetails() async throws {
        let t = try await env(spots: [davis])
        t.remote.writeErrors = [Fixtures.rlsError]
        let vm = flow(t, davis)
        vm.choose(.liked)
        await vm.save()
        #expect(vm.step == .details)
        #expect(vm.errorMessage == "You don't have permission to do that.")
        #expect(t.env.reviews.myReview(for: davis.id) == nil)
    }

    @Test func backReturnsToBucketChoice() async throws {
        let t = try await env(spots: [davis])
        let vm = flow(t, davis)
        vm.choose(.fine)
        vm.back()
        #expect(vm.step == .bucket)
        #expect(vm.placement == nil)
    }

    @Test func commentsAreCappedAt300() async throws {
        let t = try await env(spots: [davis])
        let vm = flow(t, davis)
        vm.comments = String(repeating: "a", count: 400)
        #expect(vm.comments.count == 300)
    }
}

@MainActor
struct SpotDetailViewModelTests {
    @Test func ownReviewShownFirstAndSaveToggles() async throws {
        let t = TestEnv()
        let spot = Fixtures.spot("Davis Library")
        t.remote.spots = [spot]
        let othersReview = Review(id: UUID(), spotId: spot.id, userId: Fixtures.otherUserId, bucket: .fine,
                                  score: 5.0, noiseLevel: nil, hasOutlets: nil, hasWifi: nil, seating: nil,
                                  comments: "ok", createdAt: nil)
        t.remote.reviewsBySpot[spot.id] = [othersReview]
        try await t.env.spots.refresh()

        let flow = RatingFlowViewModel(spot: spot, reviews: t.env.reviews, spots: t.env.spots, session: t.env.session)
        flow.choose(.liked)
        await flow.save()

        let vm = SpotDetailViewModel(spotId: spot.id, env: t.env)
        await vm.loadReviews()
        #expect(vm.displayedReviews.count == 2)
        #expect(vm.isMine(vm.displayedReviews[0]))
        #expect(vm.displayedReviews[1].comments == "ok")

        #expect(!vm.isSaved(in: .wantToGo))
        await vm.toggleSaved(.wantToGo)
        #expect(vm.isSaved(in: .wantToGo))
        await vm.toggleSaved(.wantToGo)
        #expect(!vm.isSaved(in: .wantToGo))
    }
}
