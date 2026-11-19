//
//  SpotFilter.swift
//  iOSApprenticeProject
//
//  Search, filter and sort for the Spots list. Pure, so it is unit-tested directly.
//

import CoreLocation
import Foundation

struct SpotFilter: Equatable {
    enum Sort: String, CaseIterable, Identifiable {
        case rating, distance, name
        var id: String { rawValue }
        var label: String {
            switch self {
            case .rating: return "Top rated"
            case .distance: return "Nearest"
            case .name: return "Name"
            }
        }
    }

    static let distanceOptions: [Double] = [250, 500, 1000, 2000]

    var query = ""
    /// Empty means any noise level.
    var noise: Set<NoiseLevel> = []
    var needsOutlets = false
    var needsWifi = false
    /// `.solo` matches solo and both, `.group` matches group and both, `.both` needs both.
    var seating: Seating?
    var openNow = false
    /// Meters. Ignored when the user's location isn't known.
    var maxDistance: Double?
    var sort: Sort = .rating

    /// Number of filters set, for the toolbar badge. Search and sort don't count.
    var activeCount: Int {
        (noise.isEmpty ? 0 : 1) + (needsOutlets ? 1 : 0) + (needsWifi ? 1 : 0)
            + (seating == nil ? 0 : 1) + (openNow ? 1 : 0) + (maxDistance == nil ? 0 : 1)
    }

    mutating func clearFilters() {
        let keep = (query, sort)
        self = SpotFilter()
        (query, sort) = keep
    }

    func apply(to spots: [StudySpot], from location: CLLocation?, now: Date) -> [StudySpot] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = spots.filter { spot in
            if !needle.isEmpty {
                let haystack = [spot.name, spot.building ?? ""].joined(separator: " ")
                guard haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                else { return false }
            }
            if !noise.isEmpty {
                guard let level = spot.noiseLevel, noise.contains(level) else { return false }
            }
            if needsOutlets && spot.hasOutlets != true { return false }
            if needsWifi && spot.hasWifi != true { return false }
            if let seating, !Self.seating(spot.seating, satisfies: seating) { return false }
            if openNow && SpotHours.isOpen(spot, at: now) != true { return false }
            if let maxDistance, let location {
                guard Self.distance(from: location, to: spot) <= maxDistance else { return false }
            }
            return true
        }
        return sorted(filtered, from: location)
    }

    static func distance(from location: CLLocation, to spot: StudySpot) -> CLLocationDistance {
        location.distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
    }

    static func seating(_ actual: Seating?, satisfies wanted: Seating) -> Bool {
        guard let actual else { return false }
        switch wanted {
        case .solo: return actual == .solo || actual == .both
        case .group: return actual == .group || actual == .both
        case .both: return actual == .both
        }
    }

    private func sorted(_ spots: [StudySpot], from location: CLLocation?) -> [StudySpot] {
        let byName: (StudySpot, StudySpot) -> Bool = {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        switch sort {
        case .name:
            return spots.sorted(by: byName)
        case .rating:
            return spots.sorted { a, b in
                switch (a.avgRating, b.avgRating) {
                case let (x?, y?) where x != y: return x > y
                case (_?, nil): return true      // rated before unrated
                case (nil, _?): return false
                default: return byName(a, b)
                }
            }
        case .distance:
            guard let location else { return spots.sorted(by: byName) }
            return spots.sorted {
                Self.distance(from: location, to: $0) < Self.distance(from: location, to: $1)
            }
        }
    }
}
