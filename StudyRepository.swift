//
//  StudyRepository.swift
//  iOSApprenticeProject
//
//  All database reads and writes go through here so the views stay simple.
//

import Foundation
import Supabase

enum StudyRepository {

    // MARK: - Study spots

    static func fetchSpots() async throws -> [StudySpot] {
        try await supabase
            .from("study_spots")
            .select()
            .order("name")
            .execute()
            .value
    }

    // MARK: - Events / study groups

    static func fetchEvents(category: EventCategory? = nil) async throws -> [Event] {
        var query = supabase.from("events").select()
        if let category {
            query = query.eq("category", value: category.rawValue)
        }
        return try await query
            .order("starts_at", ascending: true)
            .execute()
            .value
    }

    static func createEvent(_ event: NewEvent) async throws {
        try await supabase.from("events").insert(event).execute()
    }

    static func joinEvent(eventId: UUID, userId: UUID) async throws {
        try await supabase
            .from("event_members")
            .insert(["event_id": eventId.uuidString, "user_id": userId.uuidString])
            .execute()
    }

    static func leaveEvent(eventId: UUID, userId: UUID) async throws {
        try await supabase
            .from("event_members")
            .delete()
            .eq("event_id", value: eventId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    // MARK: - Reviews

    static func submitReview(_ review: NewReview) async throws {
        try await supabase.from("reviews").insert(review).execute()
    }

    static func fetchReviews(spotId: UUID) async throws -> [Review] {
        try await supabase
            .from("reviews")
            .select()
            .eq("spot_id", value: spotId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Favorites

    static func fetchFavoriteSpotIds(userId: UUID) async throws -> [UUID] {
        struct Row: Decodable {
            let spotId: UUID
            enum CodingKeys: String, CodingKey { case spotId = "spot_id" }
        }
        let rows: [Row] = try await supabase
            .from("favorites")
            .select("spot_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.map(\.spotId)
    }

    static func addFavorite(spotId: UUID, userId: UUID) async throws {
        try await supabase
            .from("favorites")
            .insert(["user_id": userId.uuidString, "spot_id": spotId.uuidString])
            .execute()
    }

    static func removeFavorite(spotId: UUID, userId: UUID) async throws {
        try await supabase
            .from("favorites")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("spot_id", value: spotId.uuidString)
            .execute()
    }

    // MARK: - Summaries and profile

    static func fetchSpotRatings() async throws -> [SpotRating] {
        try await supabase.from("spot_ratings").select().execute().value
    }

    /// IDs of events the user has joined.
    static func fetchJoinedEventIds(userId: UUID) async throws -> [UUID] {
        struct Row: Decodable {
            let eventId: UUID
            enum CodingKeys: String, CodingKey { case eventId = "event_id" }
        }
        let rows: [Row] = try await supabase
            .from("event_members")
            .select("event_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        return rows.map(\.eventId)
    }

    static func fetchProfile(userId: UUID) async throws -> UserProfile {
        try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    static func updateProfileName(userId: UUID, name: String) async throws {
        try await supabase
            .from("profiles")
            .update(["name": name])
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
