//
//  AppEnvironment.swift
//  iOSApprenticeProject
//
//  Builds the data layer once and hands it to views via `.environment(...)`.
//

import Foundation
import Observation
import SwiftData

@Observable
final class AppEnvironment {
    let session: UserSession
    let network: NetworkMonitor
    let sync: SyncQueue
    let spots: SpotRepository
    let reviews: ReviewRepository
    let events: EventRepository
    let saved: SavedRepository
    let profile: ProfileRepository

    private(set) var isRefreshing = false
    /// Set when the last refresh couldn't reach the server, so screens can show they're using cached data.
    private(set) var isShowingCachedData = false

    @ObservationIgnored let modelContainer: ModelContainer
    @ObservationIgnored private let cache: CacheStore

    init(modelContainer: ModelContainer, remote: RemoteDataSource,
         network: NetworkMonitor = NetworkMonitor(), isOnline: (() -> Bool)? = nil) {
        self.modelContainer = modelContainer
        self.network = network
        let context = modelContainer.mainContext
        let session = UserSession()
        let cache = CacheStore(context: context)
        let sync = SyncQueue(context: context, remote: remote,
                             isOnline: isOnline ?? { [network] in network.isOnline })
        self.session = session
        self.cache = cache
        self.sync = sync
        self.spots = SpotRepository(remote: remote, cache: cache, sync: sync)
        self.reviews = ReviewRepository(remote: remote, cache: cache, sync: sync, session: session)
        self.events = EventRepository(remote: remote, cache: cache, sync: sync, session: session)
        self.saved = SavedRepository(remote: remote, cache: cache, sync: sync, session: session)
        self.profile = ProfileRepository(remote: remote, cache: cache, session: session)

        // A queued write the server later rejected: re-sync so local state matches the server again.
        sync.onPermanentFailure = { [weak self] _ in
            guard let self else { return }
            Task { await self.refreshAll() }
        }
        network.onReconnect = { [weak self] in
            guard let self else { return }
            Task { await self.refreshAll() }
        }
    }

    static func live() -> AppEnvironment {
        let env = AppEnvironment(modelContainer: makeContainer(), remote: SupabaseRemote())
        env.network.start()
        return env
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([CachedRecord.self, PendingWrite.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        if let container = try? ModelContainer(for: schema, configurations: config) {
            return container
        }
        // The on-disk store couldn't be opened. Run with an in-memory cache rather than crash.
        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: fallback)
    }

    /// Show cached data immediately.
    func loadCached() {
        spots.loadCached()
        reviews.loadCached()
        events.loadCached()
        saved.loadCached()
        profile.loadCached()
    }

    /// Send queued writes, then refresh everything from the server.
    func refreshAll() async {
        guard session.userId != nil, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await sync.flush()
        async let a = Self.succeeded { try await self.spots.refresh() }
        async let b = Self.succeeded { try await self.reviews.refreshMine() }
        async let c = Self.succeeded { try await self.events.refresh() }
        async let d = Self.succeeded { try await self.saved.refresh() }
        async let e = Self.succeeded { try await self.profile.refresh() }
        let results = await [a, b, c, d, e]
        isShowingCachedData = results.contains(false)
    }

    /// Clear everything belonging to the signed-out user.
    func reset() {
        sync.clear()
        cache.clearAll()
        session.userId = nil
        session.email = nil
        loadCached()
        isShowingCachedData = false
    }

    private static func succeeded(_ work: () async throws -> Void) async -> Bool {
        do { try await work(); return true } catch { return false }
    }
}
