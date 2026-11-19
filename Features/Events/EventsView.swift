//
//  EventsView.swift
//  iOSApprenticeProject
//

import MapKit
import SwiftUI

struct EventsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel: EventsViewModel?
    @State private var mapSelection: UUID?
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel { content(viewModel) } else { ProgressView() }
            }
            .navigationTitle("Events")
            .navigationDestination(for: Event.ID.self) { id in
                EventDetailView(eventId: id)
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = EventsViewModel(events: env.events, spots: env.spots) }
        }
    }

    @ViewBuilder
    private func content(_ vm: EventsViewModel) -> some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            filterBar(vm)
            switch vm.mode {
            case .list: list(vm)
            case .map: map(vm)
            }
        }
        .safeAreaInset(edge: .top) { StatusBanner() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $vm.mode) {
                    Label("List", systemImage: "list.bullet").tag(EventsViewModel.Mode.list)
                    Label("Map", systemImage: "map").tag(EventsViewModel.Mode.map)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("New event", systemImage: "plus") { showCreate = true }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateEventView(viewModel: CreateEventViewModel(events: env.events, spots: env.spots, session: env.session))
        }
    }

    private func filterBar(_ vm: EventsViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ToggleChip(text: "ALL", isOn: vm.category == nil) { vm.category = nil }
                ForEach(EventCategory.allCases) { category in
                    ToggleChip(text: category.chipTitle, isOn: vm.category == category) {
                        vm.category = vm.category == category ? nil : category
                    }
                }
                Divider().frame(height: 24)
                ToggleChip(text: "GOING", systemImage: "checkmark", isOn: vm.goingOnly) {
                    vm.goingOnly.toggle()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func list(_ vm: EventsViewModel) -> some View {
        let sections = vm.sections
        return List {
            ForEach(sections, id: \.section) { group in
                Section(group.section.title) {
                    ForEach(group.events) { event in
                        NavigationLink(value: event.id) {
                            EventRow(event: event, isGoing: vm.isGoing(event))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if sections.isEmpty {
                if !vm.hasAnyEvents {
                    ContentUnavailableView("No events yet", systemImage: "calendar",
                                           description: Text("Start a study session with the + button."))
                } else {
                    ContentUnavailableView("No upcoming events", systemImage: "calendar.badge.exclamationmark",
                                           description: Text("Try another category."))
                }
            }
        }
        .refreshable { await env.refreshAll() }
    }

    private func map(_ vm: EventsViewModel) -> some View {
        Map(initialPosition: MapTabView.campusCamera, selection: $mapSelection) {
            ForEach(vm.mappable, id: \.event.id) { item in
                Marker(item.event.title, systemImage: item.event.category.systemImage, coordinate: item.coordinate)
                    .tint(vm.isGoing(item.event) ? .green : Theme.blue)
                    .tag(item.event.id)
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .bottom) {
            if vm.mappable.isEmpty {
                Text("No upcoming events with a location.")
                    .font(.footnote)
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 24)
            }
        }
        .sheet(item: Binding(get: { mapSelection.flatMap { vm.event(id: $0) } },
                             set: { mapSelection = $0?.id })) { event in
            NavigationStack { EventDetailView(eventId: event.id) }
                .presentationDetents([.medium, .large])
        }
    }
}

struct EventRow: View {
    let event: Event
    let isGoing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.category.systemImage)
                .font(.system(size: 18))
                .foregroundStyle(Theme.blue)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.softBlue))
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).font(.headline)
                if let time = EventGrouping.timeLabel(for: event) {
                    Text(time).font(.subheadline)
                }
                Label(event.location, systemImage: "mappin")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text("\(event.rsvpCount) going").font(.caption).foregroundStyle(.secondary)
                    if isGoing {
                        Label("You're going", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

extension EventCategory {
    var systemImage: String {
        switch self {
        case .cleEvent: return "building.columns"
        case .studyGroup: return "person.3"
        case .freeFood: return "fork.knife"
        case .club: return "star"
        }
    }

    var label: String {
        switch self {
        case .cleEvent: return "CLE event"
        case .studyGroup: return "Study group"
        case .freeFood: return "Free food"
        case .club: return "Club"
        }
    }
}
