//
//  SpotsListView.swift
//  iOSApprenticeProject
//

import SwiftUI

struct SpotsListView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(LocationService.self) private var location

    @State private var viewModel: SpotsViewModel?
    @State private var showFilters = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Spots")
            .navigationDestination(for: StudySpot.ID.self) { id in
                SpotDetailView(spotId: id)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = SpotsViewModel(repository: env.spots, currentLocation: { [location] in location.location })
            }
            location.start()
        }
    }

    @ViewBuilder
    private func content(_ vm: SpotsViewModel) -> some View {
        @Bindable var vm = vm
        let results = vm.results

        List {
            if vm.needsLocationForFilter {
                Label("Turn on location to filter or sort by distance.", systemImage: "location.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(results) { spot in
                NavigationLink(value: spot.id) {
                    SpotRow(spot: spot, distance: vm.distanceText(to: spot))
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if results.isEmpty {
                if !vm.hasAnySpots {
                    ContentUnavailableView("No spots yet", systemImage: "mappin.slash",
                                           description: Text("Pull to refresh, or add one from the map."))
                } else if !vm.filter.query.isEmpty {
                    ContentUnavailableView.search(text: vm.filter.query)
                } else {
                    ContentUnavailableView {
                        Label("No matching spots", systemImage: "line.3.horizontal.decrease.circle")
                    } actions: {
                        Button("Clear filters") { vm.filter.clearFilters() }
                    }
                }
            }
        }
        .searchable(text: $vm.filter.query, prompt: "Search spots or buildings")
        .refreshable { await env.refreshAll() }
        .safeAreaInset(edge: .top) { StatusBanner() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $vm.filter.sort) {
                        ForEach(SpotFilter.Sort.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Label("Filters", systemImage: vm.filter.activeCount > 0
                          ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .badge(vm.filter.activeCount)
            }
        }
        .sheet(isPresented: $showFilters) {
            SpotFilterSheet(filter: $vm.filter, hasLocation: location.location != nil)
                .presentationDetents([.medium, .large])
        }
    }
}

struct SpotRow: View {
    let spot: StudySpot
    var distance: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RatingBadge(score: spot.avgRating, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(spot.name).font(.headline)
                    Spacer()
                    if let distance {
                        Text(distance).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let building = spot.building, building != spot.name {
                    Text(building).font(.subheadline).foregroundStyle(.secondary)
                }
                AttributeChips(spot: spot)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SpotFilterSheet: View {
    @Binding var filter: SpotFilter
    let hasLocation: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Noise") {
                    FlowLayout {
                        ForEach(NoiseLevel.allCases) { level in
                            ToggleChip(text: level.label, systemImage: level.systemImage,
                                       isOn: filter.noise.contains(level)) {
                                if filter.noise.contains(level) { filter.noise.remove(level) }
                                else { filter.noise.insert(level) }
                            }
                        }
                    }
                }
                Section("Amenities") {
                    Toggle("Outlets", systemImage: "powerplug", isOn: $filter.needsOutlets)
                    Toggle("Wi-Fi", systemImage: "wifi", isOn: $filter.needsWifi)
                    Toggle("Open now", systemImage: "clock", isOn: $filter.openNow)
                }
                Section("Seating") {
                    Picker("Seating", selection: $filter.seating) {
                        Text("Any").tag(Seating?.none)
                        ForEach(Seating.allCases) { Text($0.label).tag(Seating?.some($0)) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Picker("Within", selection: $filter.maxDistance) {
                        Text("Any distance").tag(Double?.none)
                        ForEach(SpotFilter.distanceOptions, id: \.self) { meters in
                            Text(Measurement(value: meters, unit: UnitLength.meters)
                                .formatted(.measurement(width: .abbreviated, usage: .road)))
                                .tag(Double?.some(meters))
                        }
                    }
                } header: {
                    Text("Distance")
                } footer: {
                    if !hasLocation { Text("Needs your location.") }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { filter.clearFilters() }
                        .disabled(filter.activeCount == 0)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
