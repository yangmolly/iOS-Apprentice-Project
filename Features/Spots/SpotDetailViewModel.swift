//
//  SpotDetailViewModel.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

@Observable
final class SpotDetailViewModel {
    let spotId: UUID
    private(set) var reviews: [Review] = []
    private(set) var isLoadingReviews = false
    var errorMessage: String?

    @ObservationIgnored private let env: AppEnvironment

    init(spotId: UUID, env: AppEnvironment) {
        self.spotId = spotId
        self.env = env
    }

    var spot: StudySpot? { env.spots.spot(id: spotId) }
    var myReview: Review? { env.reviews.myReview(for: spotId) }

    /// Everyone's reviews, with the user's own (possibly just changed or not yet synced) version first.
    var displayedReviews: [Review] {
        let userId = env.session.userId
        let others = reviews.filter { $0.userId != userId }
        return (myReview.map { [$0] } ?? []) + others
    }

    func isMine(_ review: Review) -> Bool {
        review.userId == env.session.userId
    }

    func isSaved(in list: SavedList) -> Bool {
        env.saved.isSaved(spotId, in: list)
    }

    func loadReviews() async {
        isLoadingReviews = true
        defer { isLoadingReviews = false }
        reviews = await env.reviews.reviews(for: spotId)
    }

    func toggleSaved(_ list: SavedList) async {
        errorMessage = nil
        do {
            try await env.saved.setSaved(spotId, in: list, !isSaved(in: list))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func makeRatingFlow() -> RatingFlowViewModel? {
        guard let spot else { return nil }
        return RatingFlowViewModel(spot: spot, reviews: env.reviews, spots: env.spots, session: env.session)
    }
}
