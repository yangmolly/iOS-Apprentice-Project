//
//  RatingFlowViewModel.swift
//  iOSApprenticeProject
//
//  Bucket -> comparisons -> environment details -> save.
//

import Foundation
import Observation

@Observable
final class RatingFlowViewModel: Identifiable {
    enum Step: Equatable {
        case bucket
        case compare
        case details
        case saved(queued: Bool)
    }

    static let maxCommentLength = 300

    let spot: StudySpot
    private(set) var step: Step = .bucket
    private(set) var placement: RatingEngine.Placement?
    private(set) var isSaving = false
    var errorMessage: String?

    // Environment details, prefilled from the user's previous review or the spot's consensus.
    var noiseLevel: NoiseLevel?
    var hasOutlets: Bool?
    var hasWifi: Bool?
    var seating: Seating?
    var comments: String = "" {
        didSet {
            if comments.count > Self.maxCommentLength {
                comments = String(comments.prefix(Self.maxCommentLength))
            }
        }
    }

    @ObservationIgnored private let reviews: ReviewRepository
    @ObservationIgnored private let spots: SpotRepository
    @ObservationIgnored private let session: UserSession
    @ObservationIgnored private let existing: Review?

    init(spot: StudySpot, reviews: ReviewRepository, spots: SpotRepository, session: UserSession) {
        self.spot = spot
        self.reviews = reviews
        self.spots = spots
        self.session = session
        let existing = reviews.myReview(for: spot.id)
        self.existing = existing
        noiseLevel = existing?.noiseLevel ?? spot.noiseLevel
        hasOutlets = existing?.hasOutlets ?? spot.hasOutlets
        hasWifi = existing?.hasWifi ?? spot.hasWifi
        seating = existing?.seating ?? spot.seating
        comments = existing?.comments ?? ""
    }

    var isReRating: Bool { existing != nil }
    var previousScore: Double? { existing?.score }

    /// The spot to compare against, by name, or nil when comparisons are done.
    var comparisonSpot: StudySpot? {
        placement?.comparisonSpotId.flatMap { spots.spot(id: $0) }
    }

    /// Fallback label when a compared spot isn't in the local list (shouldn't normally happen).
    var comparisonName: String {
        comparisonSpot?.name ?? "a spot you rated"
    }

    var comparisonsRemaining: Int { placement?.comparisonsRemaining ?? 0 }

    // MARK: Steps

    func choose(_ bucket: RatingBucket) {
        let ranked = RatingEngine.ranking(of: reviews.myReviews, in: bucket, excluding: spot.id)
        placement = RatingEngine.Placement(bucket: bucket, ranked: ranked)
        step = placement!.isComplete ? .details : .compare
    }

    func answer(newIsBetter: Bool) {
        placement?.answer(newIsBetter: newIsBetter)
        if placement?.isComplete == true { step = .details }
    }

    func tie() {
        placement?.tie()
        if placement?.isComplete == true { step = .details }
    }

    func back() {
        switch step {
        case .compare, .details:
            placement = nil
            step = .bucket
        case .bucket, .saved:
            break
        }
    }

    /// The score this spot will get, once placed.
    var resultingScore: Double? {
        guard let placement, placement.isComplete else { return nil }
        return RatingEngine.rescore(placing: spot.id, with: placement, existing: reviews.myReviews)[spot.id]?.score
    }

    // MARK: Save

    func save() async {
        guard let placement, placement.isComplete, !isSaving else { return }
        errorMessage = nil
        let userId: UUID
        do { userId = try session.requireUserId() } catch {
            errorMessage = error.localizedDescription
            return
        }

        let changes = RatingEngine.rescore(placing: spot.id, with: placement, existing: reviews.myReviews)
        let trimmed = comments.trimmingCharacters(in: .whitespacesAndNewlines)
        var upserts: [ReviewUpsert] = []
        for (spotId, change) in changes {
            if spotId == spot.id {
                upserts.append(ReviewUpsert(
                    id: existing?.id ?? UUID(), spotId: spot.id, userId: userId,
                    bucket: change.bucket, score: change.score,
                    noiseLevel: noiseLevel, hasOutlets: hasOutlets, hasWifi: hasWifi, seating: seating,
                    comments: trimmed.isEmpty ? nil : trimmed))
            } else if let other = reviews.myReview(for: spotId) {
                upserts.append(ReviewUpsert(rescoring: other, bucket: change.bucket, score: change.score))
            }
        }

        isSaving = true
        defer { isSaving = false }
        do {
            let result = try await reviews.submit(upserts)
            step = .saved(queued: result == .queued)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
