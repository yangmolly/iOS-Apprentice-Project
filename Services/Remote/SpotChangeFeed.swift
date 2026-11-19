//
//  SpotChangeFeed.swift
//  iOSApprenticeProject
//
//  Live spot changes over Supabase Realtime. When anyone's rating changes a
//  spot's average, the database trigger updates the study_spots row, and that
//  update is broadcast here.
//

import Foundation
import Supabase

protocol SpotChangeFeed: AnyObject {
    /// Start listening. `onChange` is called on the main actor with each inserted or updated spot.
    func start(onChange: @escaping (StudySpot) -> Void)
    func stop()
}

final class SupabaseSpotChangeFeed: SpotChangeFeed {
    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var tasks: [Task<Void, Never>] = []

    init(client: SupabaseClient = supabase) {
        self.client = client
    }

    func start(onChange: @escaping (StudySpot) -> Void) {
        guard channel == nil else { return }
        let channel = client.channel("public:study_spots")
        self.channel = channel

        let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "study_spots")
        let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "study_spots")
        let decoder = JSONDecoder()

        tasks = [
            Task {
                for await change in updates {
                    if let spot = try? change.decodeRecord(as: StudySpot.self, decoder: decoder) {
                        onChange(spot)
                    }
                }
            },
            Task {
                for await change in inserts {
                    if let spot = try? change.decodeRecord(as: StudySpot.self, decoder: decoder) {
                        onChange(spot)
                    }
                }
            },
            Task {
                // If subscribing fails (offline), the app still works; refreshes cover the gap.
                try? await channel.subscribeWithError()
            },
        ]
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        if let channel {
            self.channel = nil
            Task { await client.removeChannel(channel) }
        }
    }
}
