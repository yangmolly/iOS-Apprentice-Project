//
//  EventDetailView.swift
//  iOSApprenticeProject
//

import MapKit
import SwiftUI

struct EventDetailView: View {
    let eventId: UUID

    @Environment(AppEnvironment.self) private var env
    @State private var viewModel: EventsViewModel?
    @State private var isUpdating = false

    var body: some View {
        Group {
            if let viewModel, let event = viewModel.event(id: eventId) {
                content(viewModel, event)
            } else if viewModel == nil {
                ProgressView()
            } else {
                ContentUnavailableView("Event not found", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = EventsViewModel(events: env.events, spots: env.spots) }
        }
    }

    private func content(_ vm: EventsViewModel, _ event: Event) -> some View {
        let going = vm.isGoing(event)
        return List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label(event.category.label, systemImage: event.category.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.blue)
                    Text(event.title).font(.title2.bold())
                }
                .padding(.vertical, 4)
                if let time = EventGrouping.timeLabel(for: event) {
                    Label(time, systemImage: "clock")
                } else {
                    Label("Time to be announced", systemImage: "clock").foregroundStyle(.secondary)
                }
                Label(event.location, systemImage: "mappin.and.ellipse")
                if let spot = vm.spot(for: event) {
                    NavigationLink {
                        SpotDetailView(spotId: spot.id)
                    } label: {
                        Label("At \(spot.name)", systemImage: "building.2")
                    }
                }
                Label("\(event.rsvpCount) going", systemImage: "person.2")
            }

            if let description = event.description, !description.isEmpty {
                Section("Details") { Text(description) }
            }

            if let coordinate = vm.coordinate(for: event) {
                Section {
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 400,
                                                                     longitudinalMeters: 400))) {
                        Marker(event.title, systemImage: event.category.systemImage, coordinate: coordinate)
                    }
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                    .allowsHitTesting(false)
                }
            }

            Section {
                if EventGrouping.isPast(event, now: .now) {
                    Text("This event has ended.").foregroundStyle(.secondary)
                } else {
                    Button {
                        Task {
                            isUpdating = true
                            await vm.toggleRSVP(event)
                            isUpdating = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isUpdating {
                                ProgressView()
                            } else {
                                Label(going ? "You're going · Cancel RSVP" : "RSVP",
                                      systemImage: going ? "xmark.circle" : "checkmark.circle")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .tint(going ? .red : Theme.blue)
                    .disabled(isUpdating)
                }
                if let error = vm.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
    }
}
