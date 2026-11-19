//
//  SpotDetailView.swift
//  iOSApprenticeProject
//

import SwiftUI

struct SpotDetailView: View {
    let spotId: UUID

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        if let spot = env.spots.spot(id: spotId) {
            List {
                Section {
                    header(spot)
                    AttributeChips(spot: spot)
                        .listRowSeparator(.hidden)
                    if let hours = SpotHours.label(for: spot) {
                        Label(hours, systemImage: "clock")
                            .font(.subheadline)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(spot.name)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Spot not found", systemImage: "mappin.slash")
        }
    }

    private func header(_ spot: StudySpot) -> some View {
        HStack(spacing: 14) {
            RatingBadge(score: spot.avgRating, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name).font(.title3.bold())
                if let building = spot.building, building != spot.name {
                    Text(building).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(spot.reviewCount == 0 ? "No ratings yet"
                     : "\(spot.reviewCount) rating\(spot.reviewCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
