//
//  SupabaseRemote.swift
//  iOSApprenticeProject
//
//  RemoteDataSource backed by Supabase PostgREST.
//

import Foundation
import Supabase

final class SupabaseRemote: RemoteDataSource {
    private let client: SupabaseClient

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    // MARK: - Spots

    func fetchSpots() async throws -> [StudySpot] {
        try await client.from("study_spots").select().order("name").execute().value
    }

    func insertSpot(_ spot: NewSpot) async throws {
        try await client.from("study_spots").insert(spot).execute()
    }

    func findSimilarSpots(name: String, latitude: Double, longitude: Double) async throws -> [StudySpot] {
        struct Params: Encodable {
            let p_name: String
            let p_lat: Double
            let p_lng: Double
        }
        return try await client
            .rpc("find_similar_spots", params: Params(p_name: name, p_lat: latitude, p_lng: longitude))
            .execute()
            .value
    }

    // MARK: - Reviews

    func fetchReviews(spotId: UUID) async throws -> [Review] {
        try await client.from("reviews").select()
            .eq("spot_id", value: spotId.uuidString)
            .order("created_at", ascending: false)
            .execute().value
    }

    func fetchReviews(userId: UUID) async throws -> [Review] {
        try await client.from("reviews").select()
            .eq("user_id", value: userId.uuidString)
            .order("score", ascending: false)
            .execute().value
    }

    func upsertReviews(_ reviews: [ReviewUpsert]) async throws {
        guard !reviews.isEmpty else { return }
        try await client.from("reviews")
            .upsert(reviews, onConflict: "user_id,spot_id")
            .execute()
    }

    // MARK: - Events

    func fetchEvents() async throws -> [Event] {
        try await client.from("events")
            .select("*, event_rsvps(count)")
            .order("starts_at", ascending: true)
            .execute().value
    }

    func insertEvent(_ event: NewEvent) async throws {
        try await client.from("events").insert(event).execute()
    }

    func fetchRSVPEventIds(userId: UUID) async throws -> [UUID] {
        let rows: [EventRSVP] = try await client.from("event_rsvps")
            .select("event_id, user_id")
            .eq("user_id", value: userId.uuidString)
            .execute().value
        return rows.map(\.eventId)
    }

    func insertRSVP(_ rsvp: EventRSVP) async throws {
        try await client.from("event_rsvps").insert(rsvp).execute()
    }

    func deleteRSVP(_ rsvp: EventRSVP) async throws {
        try await client.from("event_rsvps").delete()
            .eq("event_id", value: rsvp.eventId.uuidString)
            .eq("user_id", value: rsvp.userId.uuidString)
            .execute()
    }

    // MARK: - Saved

    func fetchSaved(userId: UUID) async throws -> [SavedSpot] {
        try await client.from("saved_spots").select("user_id, spot_id, list")
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute().value
    }

    func insertSaved(_ saved: SavedSpot) async throws {
        try await client.from("saved_spots").insert(saved).execute()
    }

    func deleteSaved(_ saved: SavedSpot) async throws {
        try await client.from("saved_spots").delete()
            .eq("user_id", value: saved.userId.uuidString)
            .eq("spot_id", value: saved.spotId.uuidString)
            .eq("list", value: saved.list.rawValue)
            .execute()
    }

    // MARK: - Profiles

    func fetchProfile(userId: UUID) async throws -> UserProfile {
        try await client.from("profiles").select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute().value
    }
}
