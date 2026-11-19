//
//  DuplicateDetector.swift
//  iOSApprenticeProject
//
//  Client-side twin of the database's near-duplicate guard
//  (supabase/migrations/20261120000000_studyspot_v2.sql), so the app can warn
//  before saving and works offline. Keep the thresholds in sync with the SQL.
//

import CoreLocation
import Foundation

enum DuplicateDetector {
    /// Spots this close are compared by name.
    static let radiusMeters: Double = 75
    /// "Did you mean...?" suggestions (matches `find_similar_spots`).
    static let suggestThreshold: Double = 0.4
    /// The server rejects these (matches `prevent_duplicate_spot`), when the digits also match.
    static let blockThreshold: Double = 0.7

    struct Match: Equatable {
        let spot: StudySpot
        let distance: Double
        let similarity: Double
        /// The server would reject a new spot with this name and location.
        let isBlocking: Bool
    }

    static func matches(name: String, latitude: Double, longitude: Double,
                        among spots: [StudySpot]) -> [Match] {
        let here = CLLocation(latitude: latitude, longitude: longitude)
        let digits = nameDigits(name)
        return spots.compactMap { spot -> Match? in
            let distance = here.distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
            guard distance <= radiusMeters else { return nil }
            let score = similarity(name, spot.name)
            guard score >= suggestThreshold else { return nil }
            let blocking = score >= blockThreshold && nameDigits(spot.name) == digits
            return Match(spot: spot, distance: distance, similarity: score, isBlocking: blocking)
        }
        .sorted { $0.similarity > $1.similarity }
    }

    /// Digits in a name: "Rm 206" and "Cube #2" are different places from "Rm 207" and "Cube #3".
    static func nameDigits(_ name: String) -> String {
        String(name.filter(\.isASCIIDigit))
    }

    /// pg_trgm `similarity()`: shared trigrams / all trigrams, over lowercased alphanumeric words,
    /// each padded with two leading spaces and one trailing space.
    static func similarity(_ a: String, _ b: String) -> Double {
        let ta = trigrams(a), tb = trigrams(b)
        guard !ta.isEmpty || !tb.isEmpty else { return 0 }
        let union = ta.union(tb).count
        return union == 0 ? 0 : Double(ta.intersection(tb).count) / Double(union)
    }

    static func trigrams(_ text: String) -> Set<String> {
        let words = text.lowercased()
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
        var result = Set<String>()
        for word in words {
            let padded = Array("  " + word + " ")
            guard padded.count >= 3 else { continue }
            for i in 0...(padded.count - 3) {
                result.insert(String(padded[i..<(i + 3)]))
            }
        }
        return result
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
