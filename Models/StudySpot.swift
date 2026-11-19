//
//  StudySpot.swift
//  iOSApprenticeProject
//
//  Created by Sarayu Pesala on 10/11/26.
//

import Foundation
import CoreLocation

/// Matches the `noise_level` enum in the database.
enum NoiseLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case quiet, moderate, loud
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Matches the `seating_type` enum in the database.
enum Seating: String, Codable, CaseIterable, Identifiable, Hashable {
    case solo, group, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .solo: return "Solo"
        case .group: return "Group"
        case .both: return "Solo + group"
        }
    }
}

/// A row in the `study_spots` table.
/// `avgRating`, `reviewCount` and the environment attributes are kept current by a database trigger.
struct StudySpot: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var building: String?
    var latitude: Double
    var longitude: Double
    var createdBy: UUID?
    var noiseLevel: NoiseLevel?
    var hasOutlets: Bool?
    var hasWifi: Bool?
    var seating: Seating?
    /// "HH:mm:ss" (Postgres `time`), local campus time.
    var opensAt: String?
    var closesAt: String?
    var open24h: Bool
    var avgRating: Double?
    var reviewCount: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, building, latitude, longitude, seating
        case createdBy = "created_by"
        case noiseLevel = "noise_level"
        case hasOutlets = "has_outlets"
        case hasWifi = "has_wifi"
        case opensAt = "opens_at"
        case closesAt = "closes_at"
        case open24h = "open_24h"
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
    }

    init(id: UUID = UUID(), name: String, building: String? = nil,
         latitude: Double, longitude: Double, createdBy: UUID? = nil,
         noiseLevel: NoiseLevel? = nil, hasOutlets: Bool? = nil, hasWifi: Bool? = nil,
         seating: Seating? = nil, opensAt: String? = nil, closesAt: String? = nil,
         open24h: Bool = false, avgRating: Double? = nil, reviewCount: Int = 0) {
        self.id = id
        self.name = name
        self.building = building
        self.latitude = latitude
        self.longitude = longitude
        self.createdBy = createdBy
        self.noiseLevel = noiseLevel
        self.hasOutlets = hasOutlets
        self.hasWifi = hasWifi
        self.seating = seating
        self.opensAt = opensAt
        self.closesAt = closesAt
        self.open24h = open24h
        self.avgRating = avgRating
        self.reviewCount = reviewCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        building = try c.decodeIfPresent(String.self, forKey: .building)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        createdBy = try c.decodeIfPresent(UUID.self, forKey: .createdBy)
        noiseLevel = try c.decodeIfPresent(NoiseLevel.self, forKey: .noiseLevel)
        hasOutlets = try c.decodeIfPresent(Bool.self, forKey: .hasOutlets)
        hasWifi = try c.decodeIfPresent(Bool.self, forKey: .hasWifi)
        seating = try c.decodeIfPresent(Seating.self, forKey: .seating)
        opensAt = try c.decodeIfPresent(String.self, forKey: .opensAt)
        closesAt = try c.decodeIfPresent(String.self, forKey: .closesAt)
        open24h = try c.decodeIfPresent(Bool.self, forKey: .open24h) ?? false
        avgRating = try c.decodeIfPresent(Double.self, forKey: .avgRating)
        reviewCount = try c.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
    }
}

/// What the app sends when adding a spot. The id is generated on the device
/// so a spot added offline can be referenced (rated, saved) before it syncs.
struct NewSpot: Codable, Hashable {
    let id: UUID
    let name: String
    let building: String?
    let latitude: Double
    let longitude: Double
    let createdBy: UUID
    let noiseLevel: NoiseLevel?
    let hasOutlets: Bool?
    let hasWifi: Bool?
    let seating: Seating?
    let opensAt: String?
    let closesAt: String?
    let open24h: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, building, latitude, longitude, seating
        case createdBy = "created_by"
        case noiseLevel = "noise_level"
        case hasOutlets = "has_outlets"
        case hasWifi = "has_wifi"
        case opensAt = "opens_at"
        case closesAt = "closes_at"
        case open24h = "open_24h"
    }

    /// The spot as it should appear locally before the server confirms it.
    var asSpot: StudySpot {
        StudySpot(id: id, name: name, building: building, latitude: latitude, longitude: longitude,
                  createdBy: createdBy, noiseLevel: noiseLevel, hasOutlets: hasOutlets, hasWifi: hasWifi,
                  seating: seating, opensAt: opensAt, closesAt: closesAt, open24h: open24h)
    }
}

/// Matches the `review_bucket` enum: the first step of a Beli-style rating.
enum RatingBucket: String, Codable, CaseIterable, Identifiable, Hashable {
    case liked, fine, disliked
    var id: String { rawValue }
    var label: String {
        switch self {
        case .liked: return "I liked it"
        case .fine: return "It was fine"
        case .disliked: return "I didn't like it"
        }
    }
}

/// A row in the `reviews` table. One per user per spot.
struct Review: Identifiable, Codable, Hashable {
    let id: UUID
    let spotId: UUID
    let userId: UUID
    var bucket: RatingBucket?
    var score: Double?
    var noiseLevel: NoiseLevel?
    var hasOutlets: Bool?
    var hasWifi: Bool?
    var seating: Seating?
    var comments: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, bucket, score, seating, comments
        case spotId = "spot_id"
        case userId = "user_id"
        case noiseLevel = "noise_level"
        case hasOutlets = "has_outlets"
        case hasWifi = "has_wifi"
        case createdAt = "created_at"
    }
}

/// What the app upserts for a review (conflict target: user_id, spot_id).
/// Placing a spot in a bucket can re-score the user's other reviews in that bucket,
/// so these are sent in batches.
struct ReviewUpsert: Codable, Hashable {
    let id: UUID
    let spotId: UUID
    let userId: UUID
    let bucket: RatingBucket
    let score: Double
    let noiseLevel: NoiseLevel?
    let hasOutlets: Bool?
    let hasWifi: Bool?
    let seating: Seating?
    let comments: String?

    enum CodingKeys: String, CodingKey {
        case id, bucket, score, seating, comments
        case spotId = "spot_id"
        case userId = "user_id"
        case noiseLevel = "noise_level"
        case hasOutlets = "has_outlets"
        case hasWifi = "has_wifi"
    }

    init(id: UUID, spotId: UUID, userId: UUID, bucket: RatingBucket, score: Double,
         noiseLevel: NoiseLevel?, hasOutlets: Bool?, hasWifi: Bool?, seating: Seating?, comments: String?) {
        self.id = id
        self.spotId = spotId
        self.userId = userId
        self.bucket = bucket
        self.score = score
        self.noiseLevel = noiseLevel
        self.hasOutlets = hasOutlets
        self.hasWifi = hasWifi
        self.seating = seating
        self.comments = comments
    }

    /// Re-score an existing review, keeping its other fields.
    init(rescoring review: Review, bucket: RatingBucket, score: Double) {
        self.init(id: review.id, spotId: review.spotId, userId: review.userId, bucket: bucket, score: score,
                  noiseLevel: review.noiseLevel, hasOutlets: review.hasOutlets, hasWifi: review.hasWifi,
                  seating: review.seating, comments: review.comments)
    }

    var asReview: Review {
        Review(id: id, spotId: spotId, userId: userId, bucket: bucket, score: score,
               noiseLevel: noiseLevel, hasOutlets: hasOutlets, hasWifi: hasWifi,
               seating: seating, comments: comments, createdAt: nil)
    }
}
