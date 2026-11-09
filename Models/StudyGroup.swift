//
//  StudyGroup.swift
//  iOSApprenticeProject
//
//  Created by Sarayu Pesala on 10/11/26.
//

import Foundation

/// Matches the `event_category` enum in the database.
enum EventCategory: String, Codable, CaseIterable {
    case cleEvent = "cle_event"
    case studyGroup = "study_group"
    case freeFood = "free_food"
    case club

    /// Label shown on the Explore filter chips.
    var chipTitle: String {
        switch self {
        case .cleEvent: return "CLE EVENT"
        case .studyGroup: return "STUDY GROUP"
        case .freeFood: return "FREE FOOD"
        case .club: return "CLUBS"
        }
    }
}

/// A row in the `events` table. Study groups are events with category `.studyGroup`.
struct Event: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var category: EventCategory
    var location: String
    var spotId: UUID?
    var startsAt: Date?
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case id, title, category, location
        case spotId = "spot_id"
        case startsAt = "starts_at"
        case createdBy = "created_by"
    }
}

/// What the app sends when creating an event or study group.
struct NewEvent: Encodable {
    let title: String
    let category: EventCategory
    let location: String
    let spotId: UUID?
    let startsAt: Date?
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case title, category, location
        case spotId = "spot_id"
        case startsAt = "starts_at"
        case createdBy = "created_by"
    }
}
