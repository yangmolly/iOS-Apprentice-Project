//
//  SavedRepository.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

@Observable
final class SavedRepository {
    private(set) var saved: [SavedSpot] = []

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

    func spotIds(in list: SavedList) -> [UUID] {
        saved.filter { $0.list == list }.map(\.spotId)
    }

    func isSaved(_ spotId: UUID, in list: SavedList) -> Bool {
        saved.contains { $0.spotId == spotId && $0.list == list }
    }

    func loadCached() {
        saved = cache.load(.saved, as: SavedSpot.self)
    }

    func refresh() async throws {
        let userId = try session.requireUserId()
        let fresh = try await remote.fetchSaved(userId: userId)
        cache.replaceAll(.saved, with: fresh, id: \.id, keeping: sync.pendingIds(for: .saved))
        loadCached()
    }

    /// Add to or remove from a list. Applied locally first; rolled back if rejected.
    @discardableResult
    func setSaved(_ spotId: UUID, in list: SavedList, _ isSaved: Bool) async throws -> SubmitResult {
        let userId = try session.requireUserId()
        guard self.isSaved(spotId, in: list) != isSaved else { return .sent }
        let item = SavedSpot(userId: userId, spotId: spotId, list: list)

        apply(item, saved: isSaved)
        do {
            return try await sync.submit(isSaved ? .insertSaved(item) : .deleteSaved(item))
        } catch {
            apply(item, saved: !isSaved)
            throw error
        }
    }

    private func apply(_ item: SavedSpot, saved: Bool) {
        if saved {
            cache.upsert(.saved, item, id: item.id)
        } else {
            cache.delete(.saved, id: item.id)
        }
        loadCached()
    }
}
