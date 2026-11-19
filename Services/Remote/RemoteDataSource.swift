//
//  RemoteDataSource.swift
//  iOSApprenticeProject
//
//  Every table read and write the app makes. The live implementation
//  (SupabaseRemote) is the only code that talks to Supabase's REST API;
//  tests swap in a mock.
//

import Foundation

protocol RemoteDataSource: AnyObject {
    // Spots
    func fetchSpots() async throws -> [StudySpot]
    func insertSpot(_ spot: NewSpot) async throws
    func findSimilarSpots(name: String, latitude: Double, longitude: Double) async throws -> [StudySpot]

    // Reviews
    func fetchReviews(spotId: UUID) async throws -> [Review]
    func fetchReviews(userId: UUID) async throws -> [Review]
    func upsertReviews(_ reviews: [ReviewUpsert]) async throws

    // Events
    func fetchEvents() async throws -> [Event]
    func insertEvent(_ event: NewEvent) async throws
    func fetchRSVPEventIds(userId: UUID) async throws -> [UUID]
    func insertRSVP(_ rsvp: EventRSVP) async throws
    func deleteRSVP(_ rsvp: EventRSVP) async throws

    // Saved spots
    func fetchSaved(userId: UUID) async throws -> [SavedSpot]
    func insertSaved(_ saved: SavedSpot) async throws
    func deleteSaved(_ saved: SavedSpot) async throws

    // Profiles
    func fetchProfile(userId: UUID) async throws -> UserProfile
}
