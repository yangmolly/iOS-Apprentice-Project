//
//  StudySpot.swift
//  iOSApprenticeProject
//
//  Created by Sarayu Pesala on 10/11/26.
//

import Foundation

/// A row in the `study_spots` table.
struct StudySpot: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var building: String?
    var latitude: Double
    var longitude: Double
}

/// A row in the `reviews` table.
struct Review: Identifiable, Codable, Hashable {
    let id: UUID
    let spotId: UUID
    let userId: UUID
    var rating: Int
    var likedTags: [String]
    var dislikedTags: [String]
    var comments: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, rating, comments
        case spotId = "spot_id"
        case userId = "user_id"
        case likedTags = "liked_tags"
        case dislikedTags = "disliked_tags"
        case createdAt = "created_at"
    }
}

/// What the app sends when submitting a new review.
struct NewReview: Encodable {
    let spotId: UUID
    let userId: UUID
    let rating: Int
    let likedTags: [String]
    let dislikedTags: [String]
    let comments: String?

    enum CodingKeys: String, CodingKey {
        case rating, comments
        case spotId = "spot_id"
        case userId = "user_id"
        case likedTags = "liked_tags"
        case dislikedTags = "disliked_tags"
    }
}
