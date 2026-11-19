//
//  SavedSpot.swift
//  iOSApprenticeProject
//

import Foundation

/// Matches the `saved_list` enum in the database.
enum SavedList: String, Codable, CaseIterable, Identifiable, Hashable {
    case wantToGo = "want_to_go"
    case favorite

    var id: String { rawValue }
    var title: String {
        switch self {
        case .wantToGo: return "Want to go"
        case .favorite: return "Favorites"
        }
    }
    var systemImage: String {
        switch self {
        case .wantToGo: return "bookmark"
        case .favorite: return "heart"
        }
    }
}

/// A row in the `saved_spots` table.
struct SavedSpot: Codable, Hashable, Identifiable {
    let userId: UUID
    let spotId: UUID
    let list: SavedList

    var id: String { "\(spotId.uuidString)-\(list.rawValue)" }

    enum CodingKeys: String, CodingKey {
        case list
        case userId = "user_id"
        case spotId = "spot_id"
    }
}
