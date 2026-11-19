//
//  Theme.swift
//  iOSApprenticeProject
//

import SwiftUI

enum Theme {
    static let blue = Color(red: 0.02, green: 0.43, blue: 1.0)
    static let softBlue = Color(red: 0.92, green: 0.95, blue: 1.0)
    static let fieldBorder = Color.gray.opacity(0.25)

    /// Center of UNC's campus (Polk Place).
    static let campusCenter = (latitude: 35.9105, longitude: -79.0490)

    /// Color for a 0–10 score, matching the rating buckets.
    static func ratingColor(_ score: Double?) -> Color {
        guard let score else { return .gray }
        switch RatingBucket.containing(score) {
        case .liked: return Color(red: 0.13, green: 0.62, blue: 0.33)
        case .fine: return Color(red: 0.93, green: 0.6, blue: 0.1)
        case .disliked: return Color(red: 0.85, green: 0.25, blue: 0.2)
        }
    }

    static func formatScore(_ score: Double?) -> String {
        guard let score else { return "–" }
        return score.formatted(.number.precision(.fractionLength(1)))
    }
}
