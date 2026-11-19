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
                SpotsListView()
            }
            SwiftUI.Tab("Events", systemImage: "calendar", value: Tab.events) {
                EventsView()
            }
            SwiftUI.Tab("Saved", systemImage: "bookmark", value: Tab.saved) {
                SavedView()
            }
            SwiftUI.Tab("Profile", systemImage: "person.crop.circle", value: Tab.profile) {
                ProfileView()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(AuthViewModel.preview())
        .environment(AppEnvironment.preview())
        .environment(LocationService())
}
