//
//  CreateEventViewModel.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

@Observable
final class CreateEventViewModel: Identifiable {
    static let maxTitleLength = 100
    static let maxDescriptionLength = 1000

    var title = ""
    var category: EventCategory = .studyGroup
    /// Linking a spot gives the event a map location; otherwise `locationText` is used.
    var spotId: UUID?
    var locationText = ""
    var startsAt: Date
    var endsAt: Date
    var details = ""

    private(set) var isSaving = false
    private(set) var createdEventId: UUID?
    private(set) var wasQueued = false
    var errorMessage: String?

    @ObservationIgnored private let events: EventRepository
    @ObservationIgnored private let spots: SpotRepository
    @ObservationIgnored private let session: UserSession
    @ObservationIgnored private let now: () -> Date

    init(events: EventRepository, spots: SpotRepository, session: UserSession, now: @escaping () -> Date = { .now }) {
        self.events = events
        self.spots = spots
        self.session = session
        self.now = now
        // Default: the next full hour, for two hours.
        let start = Calendar.current.nextDate(after: now(), matching: DateComponents(minute: 0),
                                              matchingPolicy: .nextTime) ?? now()
        startsAt = start
        endsAt = start.addingTimeInterval(EventGrouping.defaultDuration)
    }

    var availableSpots: [StudySpot] { spots.spots }
    var selectedSpot: StudySpot? { spotId.flatMap { spots.spot(id: $0) } }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedLocation: String { locationText.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// What the event's location will say.
    var resolvedLocation: String {
        if !trimmedLocation.isEmpty { return trimmedLocation }
        return selectedSpot?.name ?? ""
    }

    var validationMessage: String? {
        if trimmedTitle.isEmpty { return "Give the event a title." }
        if trimmedTitle.count > Self.maxTitleLength { return "Keep the title under \(Self.maxTitleLength) characters." }
        if resolvedLocation.isEmpty { return "Pick a spot or type a location." }
        if endsAt <= startsAt { return "The event has to end after it starts." }
        if endsAt <= now() { return "That time has already passed." }
        if details.count > Self.maxDescriptionLength { return "Keep the details under \(Self.maxDescriptionLength) characters." }
        return nil
    }

    var canSave: Bool { validationMessage == nil && !isSaving }

    func save() async {
        errorMessage = nil
        if let problem = validationMessage {
            errorMessage = problem
            return
        }
        let userId: UUID
        do { userId = try session.requireUserId() } catch {
            errorMessage = error.localizedDescription
            return
        }
        let spot = selectedSpot
        let detailsText = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let event = NewEvent(
            id: UUID(), title: trimmedTitle, category: category, location: resolvedLocation,
            spotId: spot?.id, startsAt: startsAt, endsAt: endsAt,
            description: detailsText.isEmpty ? nil : detailsText,
            latitude: spot?.latitude, longitude: spot?.longitude, createdBy: userId)

        isSaving = true
        defer { isSaving = false }
        do {
            let result = try await events.create(event)
            wasQueued = result == .queued
            createdEventId = event.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
