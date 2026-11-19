//
//  SavedView.swift
//  iOSApprenticeProject
//

import SwiftUI

struct SavedView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var viewModel: SavedViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel { content(viewModel) } else { ProgressView() }
            }
            .navigationTitle("Saved")
            .navigationDestination(for: StudySpot.ID.self) { id in
                SpotDetailView(spotId: id)
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = SavedViewModel(saved: env.saved, spots: env.spots) }
        }
    }

    @ViewBuilder
    private func content(_ vm: SavedViewModel) -> some View {
        @Bindable var vm = vm
        let items = vm.items
        List {
            Section {
                Picker("List", selection: $vm.list) {
                    ForEach(SavedList.allCases) { list in
                        Text("\(list.title) (\(vm.count(in: list)))").tag(list)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if let error = vm.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            Section {
                ForEach(items) { spot in
                    NavigationLink(value: spot.id) {
                        SpotRow(spot: spot)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Remove", systemImage: "trash", role: .destructive) {
                            Task { await vm.remove(spot) }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if vm.list == .wantToGo {
                            Button("Been there", systemImage: "heart") {
                                Task { await vm.moveToFavorites(spot) }
                            }
                            .tint(.pink)
                        }
                    }
                }
            }
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView {
                    Label(vm.list == .wantToGo ? "Nothing on your list" : "No favorites yet",
                          systemImage: vm.list.systemImage)
                } description: {
                    Text(vm.list == .wantToGo
                         ? "Tap Want to go on a spot to save it for later."
                         : "Tap Favorites on a spot you love.")
                }
            }
        }
        .safeAreaInset(edge: .top) { StatusBanner() }
        .refreshable { await env.refreshAll() }
    }
}
