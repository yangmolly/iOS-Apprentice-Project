//
//  AddSpotView.swift
//  iOSApprenticeProject
//

import MapKit
import SwiftUI

struct AddSpotView: View {
    @State var viewModel: AddSpotViewModel
    /// Called with the spot to show after saving or choosing an existing one.
    var onFinish: (UUID) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var location
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            Form {
                Section("Spot") {
                    TextField("Name (e.g. Davis Library 3rd floor)", text: $vm.name)
                        .textInputAutocapitalization(.words)
                    TextField("Building (optional)", text: $vm.building)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    pinPicker
                    Button("Use my location", systemImage: "location.fill") {
                        if let here = location.location?.coordinate {
                            viewModel.coordinate = here
                            camera = .region(MKCoordinateRegion(center: here, latitudinalMeters: 250, longitudinalMeters: 250))
                        } else {
                            location.start()
                        }
                    }
                    .disabled(!location.isAuthorized && location.authorization != .notDetermined)
                } header: {
                    Text("Location")
                } footer: {
                    Text("Tap the map to move the pin.")
                }

                suggestionsSection

                Section("Environment") {
                    Picker("Noise", selection: $vm.noiseLevel) {
                        Text("Not sure").tag(NoiseLevel?.none)
                        ForEach(NoiseLevel.allCases) { Text($0.label).tag(NoiseLevel?.some($0)) }
                    }
                    TriStatePicker(title: "Outlets", systemImage: "powerplug", value: $vm.hasOutlets)
                    TriStatePicker(title: "Wi-Fi", systemImage: "wifi", value: $vm.hasWifi)
                    Picker("Seating", selection: $vm.seating) {
                        Text("Not sure").tag(Seating?.none)
                        ForEach(Seating.allCases) { Text($0.label).tag(Seating?.some($0)) }
                    }
                }

                Section("Hours") {
                    Picker("Hours", selection: $vm.hoursMode) {
                        ForEach(AddSpotViewModel.HoursMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if viewModel.hoursMode == .custom {
                        Group {
                            DatePicker("Opens", selection: timeBinding(\.opensAtMinutes), displayedComponents: .hourAndMinute)
                            DatePicker("Closes", selection: timeBinding(\.closesAtMinutes), displayedComponents: .hourAndMinute)
                        }
                        .environment(\.timeZone, SpotHours.campusTimeZone)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Add a spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await viewModel.save() } }
                            .disabled(!viewModel.canSave || viewModel.needsSuggestionDecision)
                    }
                }
            }
            // Re-check for duplicates when the name or pin changes (debounced).
            .task(id: DuplicateCheckKey(name: viewModel.trimmedName, coordinate: viewModel.coordinate)) {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await viewModel.checkForDuplicates()
            }
            .onChange(of: viewModel.outcome) { _, outcome in
                switch outcome {
                case .created(let id, _), .usedExisting(let id):
                    onFinish(id)
                    dismiss()
                case nil:
                    break
                }
            }
            .onAppear {
                if let c = viewModel.coordinate {
                    camera = .region(MKCoordinateRegion(center: c, latitudinalMeters: 300, longitudinalMeters: 300))
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private var pinPicker: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let c = viewModel.coordinate {
                    Marker(viewModel.trimmedName.isEmpty ? "New spot" : viewModel.trimmedName, coordinate: c)
                        .tint(.orange)
                }
                ForEach(viewModel.suggestions, id: \.spot.id) { match in
                    Marker(match.spot.name, coordinate: match.spot.coordinate).tint(Theme.blue)
                }
                UserAnnotation()
            }
            .onTapGesture { point in
                if let c = proxy.convert(point, from: .local) { viewModel.coordinate = c }
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        if let blocking = viewModel.blockingMatch {
            Section {
                Label("\"\(blocking.spot.name)\" is already here.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Go to \(blocking.spot.name)") { viewModel.useExisting(blocking.spot) }
            } footer: {
                Text("Spots need a different name, or must be more than \(Int(DuplicateDetector.radiusMeters)) m apart.")
            }
        } else if !viewModel.suggestions.isEmpty {
            Section {
                ForEach(viewModel.suggestions, id: \.spot.id) { match in
                    Button {
                        viewModel.useExisting(match.spot)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(match.spot.name)
                                Text("\(Int(match.distance.rounded())) m away")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Use this").font(.subheadline.weight(.medium))
                        }
                    }
                }
                if viewModel.acknowledgedSuggestions {
                    Label("Saving as a new spot", systemImage: "checkmark")
                        .foregroundStyle(.secondary)
                } else {
                    Button("No, mine is a different spot") { viewModel.acknowledgedSuggestions = true }
                }
            } header: {
                Text("Did you mean…?")
            }
        }
    }

    private func timeBinding(_ keyPath: ReferenceWritableKeyPath<AddSpotViewModel, Int>) -> Binding<Date> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = SpotHours.campusTimeZone
        return Binding(
            get: {
                let minutes = viewModel[keyPath: keyPath]
                return calendar.date(from: DateComponents(year: 2026, month: 1, day: 1,
                                                          hour: minutes / 60, minute: minutes % 60)) ?? .now
            },
            set: { date in
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                viewModel[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

private struct DuplicateCheckKey: Equatable {
    let name: String
    let coordinate: CLLocationCoordinate2D?
}
