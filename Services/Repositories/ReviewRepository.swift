//
//  ReviewRepository.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

@Observable
final class ReviewRepository {
    /// The signed-in user's reviews, best first. This is their Beli-style ranking.
    private(set) var myReviews: [Review] = []

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

    func myReview(for spotId: UUID) -> Review? {
        myReviews.first { $0.spotId == spotId }
    }

    func loadCached() {
        myReviews = cache.load(.myReview, as: Review.self)
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
    }

    func refreshMine() async throws {
        let userId = try session.requireUserId()
        let fresh = try await remote.fetchReviews(userId: userId)
        cache.replaceAll(.myReview, with: fresh, id: { $0.spotId.uuidString },
                         keeping: sync.pendingIds(for: .myReview))
        loadCached()
    }

    /// Everyone's reviews of one spot. Not cached; falls back to just the user's own review offline.
    func reviews(for spotId: UUID) async -> [Review] {
        do {
            return try await remote.fetchReviews(spotId: spotId)
        } catch {
            return myReview(for: spotId).map { [$0] } ?? []
        }
    }

    /// Saves a rating plus any re-scored reviews in the same bucket as one write.
    /// Applied locally first; rolled back if the server rejects it.
    @discardableResult
    func submit(_ upserts: [ReviewUpsert]) async throws -> SubmitResult {
        guard !upserts.isEmpty else { return .sent }
        let previous = upserts.map { (spotId: $0.spotId, review: myReview(for: $0.spotId)) }
        for upsert in upserts {
            var review = upsert.asReview
            review.createdAt = myReview(for: upsert.spotId)?.createdAt ?? .now
            cache.upsert(.myReview, review, id: upsert.spotId.uuidString)
        }
        loadCached()
        do {
            return try await sync.submit(.upsertReviews(upserts))
        } catch {
            for item in previous {
                if let review = item.review {
                    cache.upsert(.myReview, review, id: item.spotId.uuidString)
                } else {
                    cache.delete(.myReview, id: item.spotId.uuidString)
                }
            }
            loadCached()
            throw error
        }
    }
}
