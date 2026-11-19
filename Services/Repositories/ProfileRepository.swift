//
//  ProfileRepository.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

@Observable
final class ProfileRepository {
    private(set) var profile: UserProfile?

    @ObservationIgnored private let remote: RemoteDataSource
    @ObservationIgnored private let cache: CacheStore
    @ObservationIgnored private let session: UserSession

    init(remote: RemoteDataSource, cache: CacheStore, session: UserSession) {
        self.remote = remote
        self.cache = cache
        self.session = session
    }

    func loadCached() {
        guard let userId = session.userId else { profile = nil; return }
        profile = cache.loadOne(.profile, id: userId.uuidString, as: UserProfile.self)
    }

    func refresh() async throws {
        let userId = try session.requireUserId()
        let fresh = try await remote.fetchProfile(userId: userId)
        cache.upsert(.profile, fresh, id: userId.uuidString)
        profile = fresh
    }
}
