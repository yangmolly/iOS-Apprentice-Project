//
//  SpotRepository.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

@Observable
final class SpotRepository {
    private(set) var spots: [StudySpot] = []

    @ObservationIgnored private let remote: RemoteDataSource
    @ObservationIgnored private let cache: CacheStore
    @ObservationIgnored private let sync: SyncQueue

    init(remote: RemoteDataSource, cache: CacheStore, sync: SyncQueue) {
        self.remote = remote
        self.cache = cache
        self.sync = sync
    }

    func spot(id: UUID) -> StudySpot? {
        spots.first { $0.id == id }
    }

    /// Show whatever is cached right away.
    func loadCached() {
        spots = cache.load(.spot, as: StudySpot.self)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Fetch from the server and update the cache. Spots added offline stay until they sync.
    func refresh() async throws {
        let fresh = try await remote.fetchSpots()
        cache.replaceAll(.spot, with: fresh, id: { $0.id.uuidString }, keeping: sync.pendingIds(for: .spot))
        loadCached()
    }

    /// Adds the spot locally right away, then sends or queues it. Rolls back if the server rejects it.
    @discardableResult
    func add(_ spot: NewSpot) async throws -> SubmitResult {
        cache.upsert(.spot, spot.asSpot, id: spot.id.uuidString)
        loadCached()
        do {
            return try await sync.submit(.insertSpot(spot))
        } catch {
            cache.delete(.spot, id: spot.id.uuidString)
            loadCached()
            throw error
        }
    }

    /// Apply a server-side change to one spot, such as a Realtime rating update.
    func apply(_ spot: StudySpot) {
        cache.upsert(.spot, spot, id: spot.id.uuidString)
        if let index = spots.firstIndex(where: { $0.id == spot.id }) {
            spots[index] = spot
        } else {
            loadCached()
        }
    }

    /// Server-side "Did you mean...?" candidates. Empty when offline or on error.
    func remoteSimilarSpots(name: String, latitude: Double, longitude: Double) async -> [StudySpot] {
        (try? await remote.findSimilarSpots(name: name, latitude: latitude, longitude: longitude)) ?? []
    }
}
