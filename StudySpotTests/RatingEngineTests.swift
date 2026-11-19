//
//  RatingEngineTests.swift
//  StudySpotTests
//

import Foundation
import Testing
@testable import iOSApprenticeProject

struct RatingEngineTests {
    private func review(_ spotId: UUID, _ bucket: RatingBucket, _ score: Double) -> Review {
        Review(id: UUID(), spotId: spotId, userId: Fixtures.userId, bucket: bucket, score: score,
               noiseLevel: nil, hasOutlets: nil, hasWifi: nil, seating: nil, comments: nil, createdAt: nil)
    }

    // MARK: Score spacing

    @Test func emptyAndSingle() {
        #expect(RatingEngine.scores(count: 0, in: .liked).isEmpty)
        #expect(RatingEngine.scores(count: 1, in: .liked) == [8.4])     // midpoint of 6.7–10
        #expect(RatingEngine.scores(count: 1, in: .fine) == [5.0])
        #expect(RatingEngine.scores(count: 1, in: .disliked) == [1.7])
    }

    @Test(arguments: RatingBucket.allCases, [1, 2, 3, 7, 20, 100])
    func scoresStayInBucketAndDescend(bucket: RatingBucket, count: Int) {
        let scores = RatingEngine.scores(count: count, in: bucket)
        #expect(scores.count == count)
        #expect(scores.allSatisfy { bucket.range.contains($0) })
        #expect(scores.allSatisfy { RatingBucket.containing($0) == bucket })
        #expect(zip(scores, scores.dropFirst()).allSatisfy { $0 >= $1 })
        #expect(scores.allSatisfy { ($0 * 10).rounded() == $0 * 10 })   // one decimal place
    }

    @Test func threeLikedSpreadEvenly() {
        #expect(RatingEngine.scores(count: 3, in: .liked) == [9.5, 8.4, 7.3])
    }

    // MARK: Binary insertion

    @Test func emptyBucketNeedsNoComparisons() {
        let p = RatingEngine.Placement(bucket: .liked, ranked: [])
        #expect(p.isComplete)
        #expect(p.comparisonSpotId == nil)
        #expect(p.insertionIndex == 0)
    }

    @Test func insertAtTopMiddleAndBottom() {
        let ids = (0..<7).map { _ in UUID() }

        var top = RatingEngine.Placement(bucket: .liked, ranked: ids)
        while !top.isComplete { top.answer(newIsBetter: true) }
        #expect(top.insertionIndex == 0)

        var bottom = RatingEngine.Placement(bucket: .liked, ranked: ids)
        while !bottom.isComplete { bottom.answer(newIsBetter: false) }
        #expect(bottom.insertionIndex == 7)

        // Truly between ids[3] and ids[4]: better than anything at index >= 4.
        var middle = RatingEngine.Placement(bucket: .liked, ranked: ids)
        var asked = 0
        while let compared = middle.comparisonSpotId {
            middle.answer(newIsBetter: ids.firstIndex(of: compared)! >= 4)
            asked += 1
        }
        #expect(middle.insertionIndex == 4)
        #expect(asked <= 3)   // log2(8)
    }

    @Test func comparisonCountIsLogarithmic() {
        let ids = (0..<100).map { _ in UUID() }
        var p = RatingEngine.Placement(bucket: .fine, ranked: ids)
        #expect(p.comparisonsRemaining == 7)
        var asked = 0
        while !p.isComplete { p.answer(newIsBetter: asked.isMultiple(of: 2)); asked += 1 }
        #expect(asked <= 7)
    }

    @Test func tiePlacesNextToComparedSpot() {
        let ids = (0..<5).map { _ in UUID() }
        var p = RatingEngine.Placement(bucket: .liked, ranked: ids)
        let compared = p.comparisonSpotId!
        p.tie()
        #expect(p.isComplete)
        #expect(p.finalRanking(inserting: UUID()).firstIndex(of: compared) == p.insertionIndex - 1)
    }

    // MARK: Rescoring

    @Test func firstRatingInBucket() {
        let spot = UUID()
        let p = RatingEngine.Placement(bucket: .liked, ranked: [])
        let result = RatingEngine.rescore(placing: spot, with: p, existing: [])
        #expect(result.count == 1)
        #expect(result[spot]?.score == 8.4)
        #expect(result[spot]?.bucket == .liked)
    }

    @Test func insertingRescoresOthersInBucketOnly() {
        let a = UUID(), b = UUID(), other = UUID(), new = UUID()
        let existing = [review(a, .liked, 9.0), review(b, .liked, 7.6), review(other, .fine, 5.0)]
        var p = RatingEngine.Placement(bucket: .liked, ranked: RatingEngine.ranking(of: existing, in: .liked, excluding: new))
        #expect(p.ranked == [a, b])
        p.answer(newIsBetter: true)   // better than b (the middle of [a, b] is index 1)
        p.answer(newIsBetter: false)  // worse than a
        #expect(p.insertionIndex == 1)

        let result = RatingEngine.rescore(placing: new, with: p, existing: existing)
        #expect(result[a]?.score == 9.5)
        #expect(result[new]?.score == 8.4)
        #expect(result[b]?.score == 7.3)
        #expect(result[other] == nil)   // other buckets untouched
    }

    @Test func unchangedScoresAreNotRewritten() {
        let a = UUID(), new = UUID()
        // With 2 liked spots, scores are [9.2, 7.5]. `a` is already 9.2 and stays on top.
        let existing = [review(a, .liked, 9.2)]
        var p = RatingEngine.Placement(bucket: .liked, ranked: [a])
        p.answer(newIsBetter: false)
        let result = RatingEngine.rescore(placing: new, with: p, existing: existing)
        #expect(result[a] == nil)
        #expect(result[new]?.score == 7.5)
    }

    @Test func reRateWithinBucketMovesSpot() {
        let a = UUID(), b = UUID(), c = UUID()
        let existing = [review(a, .liked, 9.5), review(b, .liked, 8.4), review(c, .liked, 7.3)]
        // Re-rate c: it's excluded from the ranking it's compared against.
        let ranked = RatingEngine.ranking(of: existing, in: .liked, excluding: c)
        #expect(ranked == [a, b])
        var p = RatingEngine.Placement(bucket: .liked, ranked: ranked)
        while !p.isComplete { p.answer(newIsBetter: true) }   // now the best
        let result = RatingEngine.rescore(placing: c, with: p, existing: existing)
        #expect(result[c]?.score == 9.5)
        #expect(result[a]?.score == 8.4)
        #expect(result[b]?.score == 7.3)
    }

    @Test func reRateIntoNewBucketRespacesOldBucket() {
        let a = UUID(), b = UUID(), c = UUID()
        let existing = [review(a, .liked, 9.5), review(b, .liked, 8.4), review(c, .liked, 7.3)]
        let p = RatingEngine.Placement(bucket: .disliked, ranked: [])
        let result = RatingEngine.rescore(placing: b, with: p, existing: existing)
        #expect(result[b]?.bucket == .disliked)
        #expect(result[b]?.score == 1.7)
        // The two left in `liked` spread back out.
        #expect(result[a]?.score == 9.2)
        #expect(result[c]?.score == 7.5)
        #expect(result[a]?.bucket == .liked)
    }
}
