//
//  CreateEventView.swift
//  iOSApprenticeProject
//

import SwiftUI

struct CreateEventView: View {
    @State var viewModel: CreateEventViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            Form {
                Section {
                    TextField("Title (e.g. COMP 550 midterm review)", text: $vm.title)
                    Picker("Type", selection: $vm.category) {
                        ForEach(EventCategory.allCases) { Label($0.label, systemImage: $0.systemImage).tag($0) }
                    }
                }

                Section {
                    Picker("Study spot", selection: $vm.spotId) {
                        Text("None").tag(UUID?.none)
                        ForEach(viewModel.availableSpots) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    TextField(viewModel.selectedSpot == nil ? "Location (e.g. Dey Hall Rm 206)"
                                                            : "Room or details (optional)",
                              text: $vm.locationText)
                } header: {
                    Text("Where")
                } footer: {
                    Text("Linking a study spot puts the event on the map.")
                }

                Section("When") {
                    DatePicker("Starts", selection: $vm.startsAt, in: Date.now...)
                    DatePicker("Ends", selection: $vm.endsAt, in: viewModel.startsAt...)
                }

                Section("Details") {
                    TextField("What to bring, who it's for…", text: $vm.details, axis: .vertical)
                        .lineLimit(3...8)
                }

                if let message = viewModel.errorMessage ?? viewModel.validationMessage {
                    Section { Text(message).foregroundStyle(viewModel.errorMessage == nil ? Color.secondary : .red) }
                }
            }
            .navigationTitle("New event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Create") { Task { await viewModel.save() } }
                            .disabled(!viewModel.canSave)
                    }
                }
            }
            .onChange(of: viewModel.startsAt) { old, new in
                // Keep the same duration when the start moves.
                vm.endsAt = vm.endsAt.addingTimeInterval(new.timeIntervalSince(old))
            }
            .onChange(of: viewModel.createdEventId) { _, id in
                if id != nil { dismiss() }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }
}
