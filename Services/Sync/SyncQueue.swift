//
//  SyncQueue.swift
//  iOSApprenticeProject
//
//  Offline write queue. Writes are attempted immediately when online; otherwise
//  (or on a transient failure) they are persisted with SwiftData and replayed in
//  order when connectivity returns.
//

import Foundation
import Observation
import SwiftData

@Model
final class PendingWrite {
    var id: UUID
    var createdAt: Date
    var payload: Data
    /// "kind:id" cache keys this write touches, comma-separated.
    var entityKeys: String
    var attempts: Int
    var lastError: String?

    init(operation: WriteOperation, payload: Data) {
        self.id = UUID()
        self.createdAt = .now
        self.payload = payload
        self.entityKeys = operation.entityKeys.map { "\($0.0.rawValue):\($0.1)" }.joined(separator: ",")
        self.attempts = 0
    }
}

enum SubmitResult: Equatable {
    case sent
    case queued
}

struct SyncError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

@Observable
final class SyncQueue {
    /// After this many transient failures, a write is treated as permanent so it can't block the queue forever.
    static let maxAttempts = 5

    private(set) var pendingCount = 0
    private(set) var isFlushing = false
    /// The most recent write the server permanently rejected while flushing in the background.
    var lastFailureMessage: String?

    /// Called after a background flush permanently drops a write, so repositories can roll back their optimistic change.
    var onPermanentFailure: ((WriteOperation) -> Void)?

    /// Held (not just its context) so the queue keeps its store alive; see CacheStore.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let remote: RemoteDataSource
    private let isOnline: () -> Bool
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(container: ModelContainer, remote: RemoteDataSource, isOnline: @escaping () -> Bool) {
        self.container = container
        self.remote = remote
        self.isOnline = isOnline
        refreshCount()
    }

    /// Try the write now if online and nothing older is waiting; otherwise queue it.
    /// Throws `SyncError` only when the server permanently rejects it, so the caller can roll back.
    @discardableResult
    func submit(_ operation: WriteOperation) async throws -> SubmitResult {
        // Preserve ordering: if older writes are waiting, this one goes behind them.
        guard isOnline(), pendingCount == 0 else {
            enqueue(operation)
            return .queued
        }
        do {
            try await operation.apply(to: remote)
            return .sent
        } catch {
            switch SyncFailure.classify(error) {
            case .alreadyApplied:
                return .sent
            case .permanent(let message):
                throw SyncError(message: message)
            case .transient:
                enqueue(operation)
                return .queued
            }
        }
    }

    /// Replay queued writes oldest-first. Stops at the first transient failure to keep order.
    func flush() async {
        guard !isFlushing, isOnline() else { return }
        isFlushing = true
        defer {
            isFlushing = false
            refreshCount()
        }

        for write in pendingWrites() {
            guard let operation = try? decoder.decode(WriteOperation.self, from: write.payload) else {
                context.delete(write)  // Unreadable (from an older app version): nothing can replay it.
                continue
            }
            do {
                try await operation.apply(to: remote)
                context.delete(write)
            } catch {
                switch SyncFailure.classify(error) {
                case .alreadyApplied:
                    context.delete(write)
                case .permanent(let message):
                    context.delete(write)
                    lastFailureMessage = message
                    onPermanentFailure?(operation)
                case .transient:
                    write.attempts += 1
                    write.lastError = error.localizedDescription
                    if write.attempts >= Self.maxAttempts {
                        context.delete(write)
                        lastFailureMessage = "Couldn't sync a change after several tries: \(error.localizedDescription)"
                        onPermanentFailure?(operation)
                        continue
                    }
                    try? context.save()
                    return
                }
            }
            try? context.save()
        }
    }

    /// Cache ids (for one kind) that have writes waiting. Refreshes must not overwrite these.
    func pendingIds(for kind: CacheKind) -> Set<String> {
        let prefix = "\(kind.rawValue):"
        var ids = Set<String>()
        for write in pendingWrites() {
            for key in write.entityKeys.split(separator: ",") where key.hasPrefix(prefix) {
                ids.insert(String(key.dropFirst(prefix.count)))
            }
        }
        return ids
    }

    func pendingOperations() -> [WriteOperation] {
        pendingWrites().compactMap { try? decoder.decode(WriteOperation.self, from: $0.payload) }
    }

    /// Drops every queued write (used on sign-out).
    func clear() {
        try? context.delete(model: PendingWrite.self)
        try? context.save()
        refreshCount()
    }

    // MARK: - Private

    private func enqueue(_ operation: WriteOperation) {
        guard let data = try? encoder.encode(operation) else { return }
        context.insert(PendingWrite(operation: operation, payload: data))
        try? context.save()
        refreshCount()
    }

    private func pendingWrites() -> [PendingWrite] {
        let descriptor = FetchDescriptor<PendingWrite>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func refreshCount() {
        pendingCount = (try? context.fetchCount(FetchDescriptor<PendingWrite>())) ?? 0
    }
}
