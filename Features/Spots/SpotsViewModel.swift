//
//  SpotsViewModel.swift
//  iOSApprenticeProject
//

import CoreLocation
import Foundation
import Observation

@Observable
final class SpotsViewModel {
    var filter = SpotFilter()

    @ObservationIgnored private let repository: SpotRepository
    @ObservationIgnored private let currentLocation: () -> CLLocation?
    @ObservationIgnored private let now: () -> Date

    init(repository: SpotRepository, currentLocation: @escaping () -> CLLocation?,
         now: @escaping () -> Date = { .now }) {
        self.repository = repository
        self.currentLocation = currentLocation
        self.now = now
    }

    var results: [StudySpot] {
        filter.apply(to: repository.spots, from: currentLocation(), now: now())
    }

    var hasAnySpots: Bool { !repository.spots.isEmpty }

    /// Distance filtering and sorting need the user's location.
    var needsLocationForFilter: Bool {
        currentLocation() == nil && (filter.maxDistance != nil || filter.sort == .distance)
    }

    func distanceText(to spot: StudySpot) -> String? {
        guard let location = currentLocation() else { return nil }
        let meters = SpotFilter.distance(from: location, to: spot)
        return Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
