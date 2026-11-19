//
//  ProfileViewModel.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

@Observable
final class ProfileViewModel {
    struct RankedReview: Identifiable {
        let rank: Int
        let review: Review
        let spot: StudySpot?
        var id: UUID { review.id }
    }

    @ObservationIgnored private let env: AppEnvironment

    init(env: AppEnvironment) {
        self.env = env
    }

    var name: String {
        let n = env.profile.profile?.name.trimmingCharacters(in: .whitespaces) ?? ""
        return n.isEmpty ? "UNC student" : n
    }

    var email: String {
        env.profile.profile?.email ?? env.session.email ?? ""
    }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    /// The user's Beli-style ranking: every rated spot, best first.
    var ranking: [RankedReview] {
        env.reviews.myReviews.enumerated().map { index, review in
            RankedReview(rank: index + 1, review: review, spot: env.spots.spot(id: review.spotId))
        }
    }

    var spotsAdded: [StudySpot] {
        guard let userId = env.session.userId else { return [] }
        return env.spots.spots.filter { $0.createdBy == userId }
    }

    var savedCount: Int { env.saved.saved.count }
    var pendingCount: Int { env.sync.pendingCount }
    var isOnline: Bool { env.network.isOnline }
    var isSyncing: Bool { env.isRefreshing || env.sync.isFlushing }
    var lastSyncFailure: String? { env.sync.lastFailureMessage }

    func syncNow() async {
        await env.refreshAll()
    }

    func dismissSyncFailure() {
        env.sync.lastFailureMessage = nil
    }

    /// Shown before signing out: unsynced changes are lost on sign-out.
    var signOutWarning: String? {
        guard pendingCount > 0 else { return nil }
        return "\(pendingCount) change\(pendingCount == 1 ? " hasn't" : "s haven't") synced yet and will be lost."
    }
}
