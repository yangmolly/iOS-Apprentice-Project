//
//  WriteOperation.swift
//  iOSApprenticeProject
//
//  A single write to the server that can be persisted and replayed later.
//

import Foundation

enum WriteOperation: Codable, Hashable {
    case insertSpot(NewSpot)
    case upsertReviews([ReviewUpsert])
    case insertEvent(NewEvent)
    case insertRSVP(EventRSVP)
    case deleteRSVP(EventRSVP)
    case insertSaved(SavedSpot)
    case deleteSaved(SavedSpot)

    /// Cache entries this write touches. While it is pending, a network refresh
    /// must not overwrite those entries with server data that predates it.
    var entityKeys: [(CacheKind, String)] {
        switch self {
        case .insertSpot(let s): return [(.spot, s.id.uuidString)]
        case .upsertReviews(let rs): return rs.map { (.myReview, $0.spotId.uuidString) }
        case .insertEvent(let e): return [(.event, e.id.uuidString)]
        case .insertRSVP(let r), .deleteRSVP(let r): return [(.myRSVP, r.eventId.uuidString)]
        case .insertSaved(let s), .deleteSaved(let s): return [(.saved, s.id)]
        }
    }

    func apply(to remote: RemoteDataSource) async throws {
        switch self {
        case .insertSpot(let s): try await remote.insertSpot(s)
        case .upsertReviews(let rs): try await remote.upsertReviews(rs)
        case .insertEvent(let e): try await remote.insertEvent(e)
        case .insertRSVP(let r): try await remote.insertRSVP(r)
        case .deleteRSVP(let r): try await remote.deleteRSVP(r)
        case .insertSaved(let s): try await remote.insertSaved(s)
        case .deleteSaved(let s): try await remote.deleteSaved(s)
        }
    }
}
