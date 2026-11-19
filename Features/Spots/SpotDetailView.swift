//
//  SpotDetailView.swift
//  iOSApprenticeProject
//

import SwiftUI

struct SpotDetailView: View {
    let spotId: UUID

    @Environment(AppEnvironment.self) private var env
    @State private var viewModel: SpotDetailViewModel?
    @State private var ratingFlow: RatingFlowViewModel?

    var body: some View {
        Group {
            if let viewModel, let spot = viewModel.spot {
                content(viewModel, spot: spot)
            } else if viewModel == nil {
                ProgressView()
            } else {
                ContentUnavailableView("Spot not found", systemImage: "mappin.slash")
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = SpotDetailViewModel(spotId: spotId, env: env) }
        }
        .task { await viewModel?.loadReviews() }
        .sheet(item: $ratingFlow, onDismiss: {
            Task { await viewModel?.loadReviews() }
        }) { flow in
            RatingFlowView(viewModel: flow)
        }
    }

    private func content(_ vm: SpotDetailViewModel, spot: StudySpot) -> some View {
        List {
            Section {
                header(spot)
                AttributeChips(spot: spot)
                    .listRowSeparator(.hidden)
                if let hours = SpotHours.label(for: spot) {
                    Label(hours, systemImage: "clock").font(.subheadline)
                }
            }

            Section {
                Button {
                    ratingFlow = vm.makeRatingFlow()
                } label: {
                    HStack {
                        Label(vm.myReview == nil ? "Rate this spot" : "Re-rate", systemImage: "star.bubble")
                        Spacer()
                        if let mine = vm.myReview?.score {
                            Text("You: \(Theme.formatScore(mine))").foregroundStyle(.secondary)
                        }
                    }
                }
                HStack(spacing: 12) {
                    ForEach(SavedList.allCases) { list in
                        saveButton(vm, list)
                    }
                }
                .buttonStyle(.borderless)
                if let error = vm.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }

            Section("Ratings") {
                if vm.displayedReviews.isEmpty {
                    Text(vm.isLoadingReviews ? "Loading…" : "No ratings yet. Be the first!")
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.displayedReviews) { review in
                    ReviewRow(review: review, isMine: vm.isMine(review))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(spot.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await vm.loadReviews() }
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
                     : "Average of \(spot.reviewCount) rating\(spot.reviewCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func saveButton(_ vm: SpotDetailViewModel, _ list: SavedList) -> some View {
        let isOn = vm.isSaved(in: list)
        return Button {
            Task { await vm.toggleSaved(list) }
        } label: {
            Label(list.title, systemImage: isOn ? "\(list.systemImage).fill" : list.systemImage)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(isOn ? .white : Theme.blue)
                .background(RoundedRectangle(cornerRadius: 8).fill(isOn ? Theme.blue : Theme.softBlue))
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct ReviewRow: View {
    let review: Review
    let isMine: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RatingBadge(score: review.score, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(isMine ? "You" : "UNC student").font(.subheadline.bold())
                    Spacer()
                    if let date = review.createdAt {
                        Text(date, format: .relative(presentation: .named))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                FlowLayout(spacing: 6) {
                    if let noise = review.noiseLevel { Chip(text: noise.label, systemImage: noise.systemImage) }
                    if review.hasOutlets == true { Chip(text: "Outlets", systemImage: "powerplug") }
                    if review.hasWifi == true { Chip(text: "Wi-Fi", systemImage: "wifi") }
                    if let seating = review.seating { Chip(text: seating.label, systemImage: "chair") }
                }
                if let comments = review.comments, !comments.isEmpty {
                    Text(comments).font(.subheadline)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
