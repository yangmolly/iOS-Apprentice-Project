//
//  AddSpotViewModel.swift
//  iOSApprenticeProject
//

import CoreLocation
import Foundation
import Observation

@Observable
final class AddSpotViewModel: Identifiable {
    enum HoursMode: String, CaseIterable, Identifiable {
        case unknown, open24h, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .unknown: return "Not sure"
            case .open24h: return "24 hours"
            case .custom: return "Set hours"
            }
        }
    }

    enum Outcome: Equatable {
        case created(spotId: UUID, queued: Bool)
        /// The user picked an existing spot from "Did you mean...?".
        case usedExisting(spotId: UUID)
    }

    var name = ""
    var building = ""
    var coordinate: CLLocationCoordinate2D?
    var noiseLevel: NoiseLevel?
    var hasOutlets: Bool?
    var hasWifi: Bool?
    var seating: Seating?
    var hoursMode: HoursMode = .unknown
    /// Minutes after midnight, campus time.
    var opensAtMinutes = 8 * 60
    var closesAtMinutes = 22 * 60

    private(set) var suggestions: [DuplicateDetector.Match] = []
    /// The user said the suggestions are different places.
    var acknowledgedSuggestions = false
    private(set) var isSaving = false
    private(set) var outcome: Outcome?
    var errorMessage: String?

    @ObservationIgnored private let spots: SpotRepository
    @ObservationIgnored private let session: UserSession

    init(spots: SpotRepository, session: UserSession, coordinate: CLLocationCoordinate2D?) {
        self.spots = spots
        self.session = session
        self.coordinate = coordinate
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var blockingMatch: DuplicateDetector.Match? { suggestions.first { $0.isBlocking } }

    /// Non-blocking suggestions still waiting for "use this" or "it's different".
    var needsSuggestionDecision: Bool {
        !suggestions.isEmpty && blockingMatch == nil && !acknowledgedSuggestions
    }

    var canSave: Bool {
        trimmedName.count >= 2 && coordinate != nil && blockingMatch == nil && !isSaving
    }

    var validationHint: String? {
        if trimmedName.count < 2 { return "Give the spot a name." }
        if coordinate == nil { return "Place the spot on the map." }
        if let match = blockingMatch { return "\"\(match.spot.name)\" is already here." }
        return nil
    }

    /// Recompute "Did you mean...?" from cached spots, then the server when online.
    func checkForDuplicates() async {
        guard let coordinate, trimmedName.count >= 2 else {
            suggestions = []
            return
        }
        let name = trimmedName
        let local = DuplicateDetector.matches(name: name, latitude: coordinate.latitude,
                                              longitude: coordinate.longitude, among: spots.spots)
        update(local)

        let remote = await spots.remoteSimilarSpots(name: name, latitude: coordinate.latitude,
                                                    longitude: coordinate.longitude)
        // The name or pin may have changed while the request was in flight.
        guard name == trimmedName, coordinate == self.coordinate else { return }
        let unseen = remote.filter { r in !local.contains { $0.spot.id == r.id } }
        let remoteMatches = DuplicateDetector.matches(name: name, latitude: coordinate.latitude,
                                                      longitude: coordinate.longitude, among: unseen)
        update(local + remoteMatches)
    }

    private func update(_ matches: [DuplicateDetector.Match]) {
        let changed = matches.map(\.spot.id) != suggestions.map(\.spot.id)
        suggestions = matches.sorted { $0.similarity > $1.similarity }
        if changed { acknowledgedSuggestions = false }
    }

    func useExisting(_ spot: StudySpot) {
        outcome = .usedExisting(spotId: spot.id)
    }

    func save() async {
        errorMessage = nil
        guard canSave, let coordinate else {
            errorMessage = validationHint
            return
        }
        guard !needsSuggestionDecision else { return }
        let userId: UUID
        do { userId = try session.requireUserId() } catch {
            errorMessage = error.localizedDescription
            return
        }

        let custom = hoursMode == .custom
        let building = building.trimmingCharacters(in: .whitespacesAndNewlines)
        let spot = NewSpot(
            id: UUID(), name: trimmedName, building: building.isEmpty ? nil : building,
            latitude: coordinate.latitude, longitude: coordinate.longitude, createdBy: userId,
            noiseLevel: noiseLevel, hasOutlets: hasOutlets, hasWifi: hasWifi, seating: seating,
            opensAt: custom ? SpotHours.timeString(minutes: opensAtMinutes) : nil,
            closesAt: custom ? SpotHours.timeString(minutes: closesAtMinutes) : nil,
            open24h: hoursMode == .open24h)

        isSaving = true
        defer { isSaving = false }
        do {
            let result = try await spots.add(spot)
            outcome = .created(spotId: spot.id, queued: result == .queued)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
