//
//  RatingBadge.swift
//  iOSApprenticeProject
//

import SwiftUI

/// A circle showing a 0–10 score, colored by bucket. Used on map pins and in lists.
struct RatingBadge: View {
    let score: Double?
    var size: CGFloat = 36

    var body: some View {
        Text(Theme.formatScore(score))
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.ratingColor(score)))
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .accessibilityLabel(score.map { "Rated \(Theme.formatScore($0)) out of 10" } ?? "Not rated yet")
    }
}

/// Map annotation: a rating badge with a pointer.
struct RatingPin: View {
    let score: Double?
    var isSelected = false

    var body: some View {
        VStack(spacing: -2) {
            RatingBadge(score: score, size: isSelected ? 44 : 34)
            Image(systemName: "triangle.fill")
                .font(.system(size: 9))
                .rotationEffect(.degrees(180))
                .foregroundStyle(Theme.ratingColor(score))
        }
        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        .animation(.snappy, value: isSelected)
    }
}

#Preview {
    HStack {
        RatingPin(score: 8.7)
        RatingPin(score: 5.1, isSelected: true)
        RatingPin(score: 2.0)
        RatingPin(score: nil)
    }
}
