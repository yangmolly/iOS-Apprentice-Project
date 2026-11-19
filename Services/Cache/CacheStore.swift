//
//  CacheStore.swift
//  iOSApprenticeProject
//
//  SwiftData-backed cache of server data so screens can render immediately
//  (and offline) before the network refresh finishes.
//
//  Records are stored generically as JSON keyed by (kind, id), so the cache
//  never needs its own schema migration when a domain model gains a field.
//

import Foundation
import SwiftData

enum CacheKind: String, CaseIterable {
    case spot, myReview, event, myRSVP, saved, profile
}

@Model
final class CachedRecord {
    /// "kind:id", unique per record.
    @Attribute(.unique) var key: String
    var kind: String
    var payload: Data
    var updatedAt: Date

    init(kind: CacheKind, id: String, payload: Data) {
        self.key = "\(kind.rawValue):\(id)"
        self.kind = kind.rawValue
        self.payload = payload
        self.updatedAt = .now
    }
}

final class CacheStore {
    /// Held so the store outlives whoever created it: a ModelContext doesn't keep its container alive,
    /// and using a context after its container is freed traps inside SwiftData.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(container: ModelContainer) {
        self.container = container
    }

    func load<T: Decodable>(_ kind: CacheKind, as type: T.Type = T.self) -> [T] {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<CachedRecord>(predicate: #Predicate { $0.kind == raw })
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { try? decoder.decode(T.self, from: $0.payload) }
    }

    func loadOne<T: Decodable>(_ kind: CacheKind, id: String, as type: T.Type = T.self) -> T? {
        guard let record = record(kind, id: id) else { return nil }
        return try? decoder.decode(T.self, from: record.payload)
    }

    /// Replace every record of `kind` with `items`, except records whose id is in `keeping`
    /// (local changes still waiting to sync, which the server doesn't know about yet).
    func replaceAll<T: Encodable>(_ kind: CacheKind, with items: [T], id: (T) -> String,
                                  keeping: Set<String> = []) {
        let raw = kind.rawValue
        let descriptor = FetchDescriptor<CachedRecord>(predicate: #Predicate { $0.kind == raw })
        let existing = (try? context.fetch(descriptor)) ?? []
        let incomingIds = Set(items.map(id))
        let prefix = "\(raw):"
        for record in existing {
            let recordId = String(record.key.dropFirst(prefix.count))
            if !incomingIds.contains(recordId) && !keeping.contains(recordId) {
                context.delete(record)
            }
        }
        for item in items {
            upsert(kind, item, id: id(item), save: false)
        }
        save()
    }

    func upsert<T: Encodable>(_ kind: CacheKind, _ item: T, id: String) {
        upsert(kind, item, id: id, save: true)
    }

    func delete(_ kind: CacheKind, id: String) {
        if let record = record(kind, id: id) {
            context.delete(record)
            save()
        }
    }

    func clearAll() {
        try? context.delete(model: CachedRecord.self)
        save()
    }

    // MARK: - Private

    private func upsert<T: Encodable>(_ kind: CacheKind, _ item: T, id: String, save shouldSave: Bool) {
        guard let data = try? encoder.encode(item) else { return }
        if let record = record(kind, id: id) {
            record.payload = data
            record.updatedAt = .now
        } else {
            context.insert(CachedRecord(kind: kind, id: id, payload: data))
        }
        if shouldSave { save() }
    }

    private func record(_ kind: CacheKind, id: String) -> CachedRecord? {
        let key = "\(kind.rawValue):\(id)"
        var descriptor = FetchDescriptor<CachedRecord>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func save() {
        try? context.save()
    }
}
