//
//  StudyGroup.swift
//  iOSApprenticeProject
//
//  Created by Sarayu Pesala on 10/11/26.
//

import Foundation
import CoreLocation

/// Matches the `event_category` enum in the database.
enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case cleEvent = "cle_event"
    case studyGroup = "study_group"
    case freeFood = "free_food"
    case club

    var id: String { rawValue }

    /// Label shown on the filter chips.
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
    var endsAt: Date?
    var description: String?
    var latitude: Double?
    var longitude: Double?
    let createdBy: UUID
    /// Number of RSVPs. Read from the embedded `event_rsvps(count)` select.
    var rsvpCount: Int

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, category, location, description, latitude, longitude
        case spotId = "spot_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case createdBy = "created_by"
        case rsvpCount = "rsvp_count"
        case eventRsvps = "event_rsvps"
    }

    private struct CountRow: Codable { let count: Int }

    init(id: UUID = UUID(), title: String, category: EventCategory, location: String,
         spotId: UUID? = nil, startsAt: Date? = nil, endsAt: Date? = nil, description: String? = nil,
         latitude: Double? = nil, longitude: Double? = nil, createdBy: UUID, rsvpCount: Int = 0) {
        self.id = id
        self.title = title
        self.category = category
        self.location = location
        self.spotId = spotId
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.createdBy = createdBy
        self.rsvpCount = rsvpCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        category = try c.decode(EventCategory.self, forKey: .category)
        location = try c.decode(String.self, forKey: .location)
        spotId = try c.decodeIfPresent(UUID.self, forKey: .spotId)
        startsAt = try c.decodeIfPresent(Date.self, forKey: .startsAt)
        endsAt = try c.decodeIfPresent(Date.self, forKey: .endsAt)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        createdBy = try c.decode(UUID.self, forKey: .createdBy)
        // Server rows carry `event_rsvps: [{count: n}]`; cached rows carry `rsvp_count`.
        if let rows = try c.decodeIfPresent([CountRow].self, forKey: .eventRsvps) {
            rsvpCount = rows.first?.count ?? 0
        } else {
            rsvpCount = try c.decodeIfPresent(Int.self, forKey: .rsvpCount) ?? 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(category, forKey: .category)
        try c.encode(location, forKey: .location)
        try c.encodeIfPresent(spotId, forKey: .spotId)
        try c.encodeIfPresent(startsAt, forKey: .startsAt)
        try c.encodeIfPresent(endsAt, forKey: .endsAt)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(latitude, forKey: .latitude)
        try c.encodeIfPresent(longitude, forKey: .longitude)
        try c.encode(createdBy, forKey: .createdBy)
        try c.encode(rsvpCount, forKey: .rsvpCount)
    }
}

/// What the app sends when creating an event or study group. The id is generated
/// on the device so an event created offline can be RSVP'd to before it syncs.
struct NewEvent: Codable, Hashable {
    let id: UUID
    let title: String
    let category: EventCategory
    let location: String
    let spotId: UUID?
    let startsAt: Date?
    let endsAt: Date?
    let description: String?
    let latitude: Double?
    let longitude: Double?
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case id, title, category, location, description, latitude, longitude
        case spotId = "spot_id"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case createdBy = "created_by"
    }

    var asEvent: Event {
        Event(id: id, title: title, category: category, location: location, spotId: spotId,
              startsAt: startsAt, endsAt: endsAt, description: description,
              latitude: latitude, longitude: longitude, createdBy: createdBy)
    }
}

/// A row in the `event_rsvps` table.
struct EventRSVP: Codable, Hashable {
    let eventId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case userId = "user_id"
    }
}
