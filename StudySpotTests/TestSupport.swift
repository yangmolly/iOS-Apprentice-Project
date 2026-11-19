//
//  TestSupport.swift
//  StudySpotTests
//
//  Mock remote + in-memory environment so repositories and view models can be
//  tested end-to-end without a network.
//

import Foundation
import Supabase
@testable import iOSApprenticeProject

enum Fixtures {
    static let userId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let otherUserId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    static func spot(_ name: String, lat: Double = 35.9100, lng: Double = -79.0477,
                     rating: Double? = nil, noise: NoiseLevel? = nil, outlets: Bool? = nil,
                     wifi: Bool? = nil, seating: Seating? = nil) -> StudySpot {
        StudySpot(name: name, latitude: lat, longitude: lng, noiseLevel: noise,
                  hasOutlets: outlets, hasWifi: wifi, seating: seating,
                  avgRating: rating, reviewCount: rating == nil ? 0 : 1)
    }

    static func newSpot(_ name: String, lat: Double = 35.91, lng: Double = -79.05) -> NewSpot {
        NewSpot(id: UUID(), name: name, building: nil, latitude: lat, longitude: lng, createdBy: userId,
                noiseLevel: .quiet, hasOutlets: true, hasWifi: true, seating: .solo,
                opensAt: nil, closesAt: nil, open24h: false)
    }

    static func event(_ title: String, startsAt: Date? = nil, category: EventCategory = .studyGroup,
                      rsvps: Int = 0) -> Event {
        Event(title: title, category: category, location: "Davis", startsAt: startsAt,
              createdBy: otherUserId, rsvpCount: rsvps)
    }

    static let duplicateSpotError = PostgrestError(code: "P0001", message: "duplicate_spot: \"Davis Library\" already exists nearby")
    static let rlsError = PostgrestError(code: "42501", message: "new row violates row-level security policy")
    static let networkError = URLError(.notConnectedToInternet)
}

final class MockRemote: RemoteDataSource {
    var spots: [StudySpot] = []
    var similar: [StudySpot] = []
    var reviewsBySpot: [UUID: [Review]] = [:]
    var myReviews: [Review] = []
    var events: [Event] = []
    var rsvpEventIds: [UUID] = []
    var saved: [SavedSpot] = []
    var profile = UserProfile(id: Fixtures.userId, name: "Alice", email: "alice@unc.edu", createdAt: nil)

    /// Errors to throw from the next write calls, consumed in order. Empty = succeed.
    var writeErrors: [Error] = []
    /// Error thrown from every read while set (simulates being offline).
    var readError: Error?
    /// Writes that reached the "server", in order.
    private(set) var appliedWrites: [String] = []

    private func write(_ label: String) throws {
        if !writeErrors.isEmpty { throw writeErrors.removeFirst() }
        appliedWrites.append(label)
    }

    private func read() throws {
        if let readError { throw readError }
    }

    func fetchSpots() async throws -> [StudySpot] { try read(); return spots }
    func insertSpot(_ spot: NewSpot) async throws { try write("insertSpot:\(spot.name)"); spots.append(spot.asSpot) }
    func findSimilarSpots(name: String, latitude: Double, longitude: Double) async throws -> [StudySpot] { try read(); return similar }
    func fetchReviews(spotId: UUID) async throws -> [Review] { try read(); return reviewsBySpot[spotId] ?? [] }
    func fetchReviews(userId: UUID) async throws -> [Review] { try read(); return myReviews }
    func upsertReviews(_ reviews: [ReviewUpsert]) async throws {
        try write("upsertReviews:\(reviews.count)")
        for r in reviews {
            myReviews.removeAll { $0.spotId == r.spotId }
            myReviews.append(r.asReview)
        }
    }
    func fetchEvents() async throws -> [Event] { try read(); return events }
    func insertEvent(_ event: NewEvent) async throws { try write("insertEvent:\(event.title)"); events.append(event.asEvent) }
    func fetchRSVPEventIds(userId: UUID) async throws -> [UUID] { try read(); return rsvpEventIds }
    func insertRSVP(_ rsvp: EventRSVP) async throws { try write("rsvp"); rsvpEventIds.append(rsvp.eventId) }
    func deleteRSVP(_ rsvp: EventRSVP) async throws { try write("unrsvp"); rsvpEventIds.removeAll { $0 == rsvp.eventId } }
    func fetchSaved(userId: UUID) async throws -> [SavedSpot] { try read(); return saved }
    func insertSaved(_ s: SavedSpot) async throws { try write("save:\(s.list.rawValue)"); saved.append(s) }
    func deleteSaved(_ s: SavedSpot) async throws { try write("unsave:\(s.list.rawValue)"); saved.removeAll { $0 == s } }
    func fetchProfile(userId: UUID) async throws -> UserProfile { try read(); return profile }
}

final class MockSpotFeed: SpotChangeFeed {
    private(set) var isRunning = false
    private var onChange: ((StudySpot) -> Void)?

    func start(onChange: @escaping (StudySpot) -> Void) {
        isRunning = true
        self.onChange = onChange
    }

    func stop() {
        isRunning = false
        onChange = nil
    }

    /// Simulates a Realtime message.
    func send(_ spot: StudySpot) {
        onChange?(spot)
    }
}

/// Lets a test flip connectivity.
final class Connectivity {
    var isOnline: Bool
    init(_ isOnline: Bool) { self.isOnline = isOnline }
}

struct TestEnv {
    let env: AppEnvironment
    let remote: MockRemote
    let connectivity: Connectivity
    let feed: MockSpotFeed

    init(online: Bool = true, signedIn: Bool = true) {
        let remote = MockRemote()
        let connectivity = Connectivity(online)
        let feed = MockSpotFeed()
        env = AppEnvironment(modelContainer: AppEnvironment.makeContainer(inMemory: true),
                             remote: remote, isOnline: { connectivity.isOnline }, spotFeed: feed)
        self.feed = feed
        if signedIn {
            env.session.userId = Fixtures.userId
            env.session.email = "alice@unc.edu"
        }
        self.remote = remote
        self.connectivity = connectivity
    }
}
