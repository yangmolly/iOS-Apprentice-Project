//
//  ProfileView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/10/26.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel: ProfileViewModel?
    @State private var confirmSignOut = false
    @State private var showAllRankings = false

    private let rankingPreviewCount = 5

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel { content(viewModel) } else { ProgressView() }
            }
            .navigationTitle("Profile")
            .navigationDestination(for: StudySpot.ID.self) { id in
                SpotDetailView(spotId: id)
            }
        }
        .onAppear {
            if viewModel == nil { viewModel = ProfileViewModel(env: env) }
        }
    }

    private func content(_ vm: ProfileViewModel) -> some View {
        let ranking = vm.ranking
        let added = vm.spotsAdded
        return List {
            Section {
                HStack(spacing: 14) {
                    Text(vm.initials)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Theme.blue))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.name).font(.title3.bold())
                        Text(vm.email).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                HStack {
                    stat("\(ranking.count)", "Rated")
                    Divider()
                    stat("\(added.count)", "Added")
                    Divider()
                    stat("\(vm.savedCount)", "Saved")
                }
            }

            syncSection(vm)

            Section {
                if ranking.isEmpty {
                    Text("Rate a spot to start your ranking.").foregroundStyle(.secondary)
                }
                ForEach(showAllRankings ? ranking : Array(ranking.prefix(rankingPreviewCount))) { item in
                    rankingRow(item)
                }
                if ranking.count > rankingPreviewCount {
                    Button(showAllRankings ? "Show less" : "Show all \(ranking.count)") {
                        withAnimation { showAllRankings.toggle() }
                    }
                }
            } header: {
                Text("My ranking")
            }

            Section("Spots I added") {
                if added.isEmpty {
                    Text("Spots you add from the map show up here.").foregroundStyle(.secondary)
                }
                ForEach(added) { spot in
                    NavigationLink(value: spot.id) {
                        HStack {
                            Text(spot.name)
                            Spacer()
                            RatingBadge(score: spot.avgRating, size: 28)
                        }
                    }
                }
            }

            Section {
                Button("Sign out", role: .destructive) { confirmSignOut = true }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await vm.syncNow() }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await auth.signOut() }
            }
        } message: {
            if let warning = vm.signOutWarning { Text(warning) }
        }
    }

    @ViewBuilder
    private func syncSection(_ vm: ProfileViewModel) -> some View {
        if !vm.isOnline || vm.pendingCount > 0 || vm.lastSyncFailure != nil {
            Section("Sync") {
                if !vm.isOnline {
                    Label("Offline. Changes are saved on this phone.", systemImage: "wifi.slash")
                }
                if vm.pendingCount > 0 {
                    HStack {
                        Label("\(vm.pendingCount) change\(vm.pendingCount == 1 ? "" : "s") waiting to sync",
                              systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if vm.isSyncing {
                            ProgressView()
                        } else if vm.isOnline {
                            Button("Sync now") { Task { await vm.syncNow() } }
                                .buttonStyle(.borderless)
                        }
                    }
                }
                if let failure = vm.lastSyncFailure {
                    HStack(alignment: .top) {
                        Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                        Spacer()
                        Button("Dismiss", systemImage: "xmark") { vm.dismissSyncFailure() }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private func rankingRow(_ item: ProfileViewModel.RankedReview) -> some View {
        NavigationLink(value: item.review.spotId) {
            HStack(spacing: 12) {
                Text("\(item.rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
                VStack(alignment: .leading) {
                    Text(item.spot?.name ?? "Spot").font(.body)
                    if let building = item.spot?.building {
                        Text(building).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                RatingBadge(score: item.review.score, size: 32)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
