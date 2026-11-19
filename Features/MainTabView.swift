//
//  MainTabView.swift
//  iOSApprenticeProject
//

import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case map, spots, events, saved, profile
    }

    @State private var selection: Tab = .map

    var body: some View {
        TabView(selection: $selection) {
            SwiftUI.Tab("Map", systemImage: "map", value: Tab.map) {
                MapTabView()
            }
            SwiftUI.Tab("Spots", systemImage: "list.bullet", value: Tab.spots) {
                PlaceholderTab(title: "Spots")
            }
            SwiftUI.Tab("Events", systemImage: "calendar", value: Tab.events) {
                PlaceholderTab(title: "Events")
            }
            SwiftUI.Tab("Saved", systemImage: "bookmark", value: Tab.saved) {
                PlaceholderTab(title: "Saved")
            }
            SwiftUI.Tab("Profile", systemImage: "person.crop.circle", value: Tab.profile) {
                ProfilePlaceholder()
            }
        }
    }
}

private struct PlaceholderTab: View {
    let title: String
    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer", description: Text("Coming soon"))
                .navigationTitle(title)
        }
    }
}

/// Temporary until the Profile tab is built: lets testers sign out.
private struct ProfilePlaceholder: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        NavigationStack {
            List {
                Section("Signed in as") {
                    Text(env.session.email ?? "Unknown")
                }
                Section {
                    Button("Sign out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel.preview())
        .environment(AppEnvironment.preview())
        .environment(LocationService())
}
