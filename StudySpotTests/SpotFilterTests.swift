//
//  SpotFilterTests.swift
//  StudySpotTests
//

import CoreLocation
import Foundation
import Testing
@testable import iOSApprenticeProject

struct SpotFilterTests {
    let davis = Fixtures.spot("Davis Library", lat: 35.9100, lng: -79.0477, rating: 8.5,
                              noise: .quiet, outlets: true, wifi: true, seating: .both)
    let union = Fixtures.spot("Student Union", lat: 35.9104, lng: -79.0480, rating: 6.0,
                              noise: .loud, outlets: true, wifi: true, seating: .group)
    let dey = Fixtures.spot("Dey Hall", lat: 35.9107, lng: -79.0508, rating: nil,
                            noise: .moderate, outlets: false, wifi: true, seating: .solo)
    /// ~3.3 km north of campus.
    let farAway = Fixtures.spot("Far Café", lat: 35.94, lng: -79.0477, rating: 9.5,
                                noise: .quiet, outlets: nil, wifi: nil, seating: nil)

    var all: [StudySpot] { [dey, farAway, union, davis] }
    let atDavis = CLLocation(latitude: 35.9100, longitude: -79.0477)

    private func run(_ f: SpotFilter, location: CLLocation? = nil, now: Date = SpotHoursTests.campus(12)) -> [String] {
        f.apply(to: all, from: location, now: now).map(\.name)
    }

    @Test func defaultSortsByRatingWithUnratedLast() {
        #expect(run(SpotFilter()) == ["Far Café", "Davis Library", "Student Union", "Dey Hall"])
    }

    @Test func searchMatchesNameAndBuildingIgnoringCaseAndAccents() {
        var f = SpotFilter()
        f.query = "cafe"
        #expect(run(f) == ["Far Café"])
        var g = SpotFilter()
        g.query = "  LIBRARY "
        #expect(run(g) == ["Davis Library"])
    }

    @Test func noiseFilterExcludesUnknown() {
        var f = SpotFilter()
        f.noise = [.quiet, .moderate]
        #expect(run(f) == ["Far Café", "Davis Library", "Dey Hall"])
    }

    @Test func outletsAndWifiRequireKnownTrue() {
        var f = SpotFilter()
        f.needsOutlets = true
        #expect(Set(run(f)) == ["Davis Library", "Student Union"])
        f.needsWifi = true
        f.needsOutlets = false
        #expect(Set(run(f)) == ["Davis Library", "Student Union", "Dey Hall"])
    }

    @Test func seatingMatchesBoth() {
        var f = SpotFilter()
        f.seating = .solo
        #expect(Set(run(f)) == ["Davis Library", "Dey Hall"])
        f.seating = .group
        #expect(Set(run(f)) == ["Davis Library", "Student Union"])
        f.seating = .both
        #expect(run(f) == ["Davis Library"])
    }

    @Test func openNowUsesHours() {
        var open = davis
        open.opensAt = "08:00:00"; open.closesAt = "22:00:00"
        var closed = union
        closed.opensAt = "06:00:00"; closed.closesAt = "10:00:00"
        var f = SpotFilter()
        f.openNow = true
        let result = f.apply(to: [open, closed, dey], from: nil, now: SpotHoursTests.campus(12)).map(\.name)
        #expect(result == ["Davis Library"])  // Dey Hall has unknown hours, so it's excluded
    }

    @Test func distanceFilterAndSort() {
        var f = SpotFilter()
        f.maxDistance = 500
        #expect(Set(run(f, location: atDavis)) == ["Davis Library", "Student Union", "Dey Hall"])
        // Without a location the distance filter can't apply.
        #expect(run(f).count == 4)

        var g = SpotFilter()
        g.sort = .distance
        #expect(run(g, location: atDavis) == ["Davis Library", "Student Union", "Dey Hall", "Far Café"])
        // Falls back to name order without a location.
        #expect(run(g) == ["Davis Library", "Dey Hall", "Far Café", "Student Union"])
    }

    @Test func activeCountAndClearKeepSearchAndSort() {
        var f = SpotFilter()
        f.query = "davis"
        f.sort = .name
        f.noise = [.quiet]
        f.needsWifi = true
        f.maxDistance = 1000
        #expect(f.activeCount == 3)
        f.clearFilters()
        #expect(f.activeCount == 0)
        #expect(f.query == "davis")
        #expect(f.sort == .name)
    }
}

@MainActor
struct SpotsViewModelTests {
    @Test func resultsTrackRepositoryAndFilter() async throws {
        let t = TestEnv()
        t.remote.spots = [Fixtures.spot("Davis Library", rating: 8), Fixtures.spot("Dey Hall", rating: 5)]
        try await t.env.spots.refresh()

        var location: CLLocation? = nil
        let vm = SpotsViewModel(repository: t.env.spots, currentLocation: { location })
        #expect(vm.results.map(\.name) == ["Davis Library", "Dey Hall"])

        vm.filter.query = "dey"
        #expect(vm.results.map(\.name) == ["Dey Hall"])

        vm.filter.sort = .distance
        #expect(vm.needsLocationForFilter)
        #expect(vm.distanceText(to: vm.results[0]) == nil)
        location = CLLocation(latitude: 35.9100, longitude: -79.0477)
        #expect(!vm.needsLocationForFilter)
        #expect(vm.distanceText(to: vm.results[0]) != nil)
    }
}
