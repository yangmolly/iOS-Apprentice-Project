//
//  RatingEngine.swift
//  iOSApprenticeProject
//
//  Beli-style rating: pick a bucket (liked / fine / disliked), then place the
//  spot in your personal ranking for that bucket with a few "which is better?"
//  comparisons (binary insertion). Scores are spread evenly across the bucket's
//  range by rank, so every placement can re-score the other spots in that bucket.
//

import Foundation

enum RatingEngine {

    /// Scores for `count` ranked items (index 0 = best), evenly spaced inside the bucket and rounded to 0.1.
    /// Item i gets `hi − (hi − lo)·(i + 0.5)/n`, so no item sits exactly on a bucket edge.
    static func scores(count: Int, in bucket: RatingBucket) -> [Double] {
        guard count > 0 else { return [] }
        // Work in integer tenths so binary floating point can't nudge a .x5 the wrong way.
        let lo = Int((bucket.range.lowerBound * 10).rounded())
        let hi = Int((bucket.range.upperBound * 10).rounded())
        return (0..<count).map { i in
            let offset = Double((hi - lo) * (2 * i + 1)) / Double(2 * count)
            let tenths = (Double(hi) - offset).rounded(.toNearestOrAwayFromZero)
            return min(max(tenths, Double(lo)), Double(hi)) / 10
        }
    }

    /// The user's existing ranking for a bucket, best first, without `excluding`.
    static func ranking(of reviews: [Review], in bucket: RatingBucket, excluding spotId: UUID) -> [UUID] {
        reviews
            .filter { $0.bucket == bucket && $0.spotId != spotId }
            .sorted { a, b in
                let (sa, sb) = (a.score ?? 0, b.score ?? 0)
                return sa != sb ? sa > sb : a.spotId.uuidString < b.spotId.uuidString
            }
            .map(\.spotId)
    }

    /// One binary-insertion session.
    struct Placement: Equatable {
        let bucket: RatingBucket
        /// Other spots already in this bucket, best first.
        let ranked: [UUID]
        private(set) var low = 0
        private(set) var high: Int

        init(bucket: RatingBucket, ranked: [UUID]) {
            self.bucket = bucket
            self.ranked = ranked
            self.high = ranked.count
        }

        var isComplete: Bool { low >= high }

        /// The spot to compare against next, or nil when placement is done.
        var comparisonSpotId: UUID? {
            isComplete ? nil : ranked[(low + high) / 2]
        }

        /// Upper bound on how many more questions there are.
        var comparisonsRemaining: Int {
            var n = high - low, count = 0
            while n > 0 { n /= 2; count += 1 }
            return count
        }

        /// The new spot is better (true) or worse (false) than `comparisonSpotId`.
        mutating func answer(newIsBetter: Bool) {
            guard !isComplete else { return }
            let mid = (low + high) / 2
            if newIsBetter { high = mid } else { low = mid + 1 }
        }

        /// "Too close to call": place it right next to the compared spot and stop.
        mutating func tie() {
            guard !isComplete else { return }
            let mid = (low + high) / 2
            low = mid + 1
            high = mid + 1
        }

        /// Where the new spot goes in `ranked` once complete.
        var insertionIndex: Int { low }

        /// The full bucket ranking with the new spot inserted.
        func finalRanking(inserting spotId: UUID) -> [UUID] {
            var result = ranked
            result.insert(spotId, at: min(insertionIndex, result.count))
            return result
        }
    }

    /// New scores for every spot whose score changes when `spotId` is placed.
    /// Covers the target bucket and, on a re-rate that changes bucket, the bucket the spot left.
    static func rescore(placing spotId: UUID, with placement: Placement,
                        existing reviews: [Review]) -> [UUID: (bucket: RatingBucket, score: Double)] {
        var result: [UUID: (RatingBucket, Double)] = [:]

        let newRanking = placement.finalRanking(inserting: spotId)
        for (id, score) in zip(newRanking, scores(count: newRanking.count, in: placement.bucket)) {
            let current = reviews.first { $0.spotId == id }
            if id == spotId || current?.score != score || current?.bucket != placement.bucket {
                result[id] = (placement.bucket, score)
            }
        }

        if let previous = reviews.first(where: { $0.spotId == spotId })?.bucket, previous != placement.bucket {
            let left = ranking(of: reviews, in: previous, excluding: spotId)
            for (id, score) in zip(left, scores(count: left.count, in: previous)) {
                if reviews.first(where: { $0.spotId == id })?.score != score {
                    result[id] = (previous, score)
                }
            }
        }
        return result.mapValues { (bucket: $0.0, score: $0.1) }
    }
}
