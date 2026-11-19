//
//  MapTabView.swift
//  iOSApprenticeProject
//

import MapKit
import SwiftUI

struct MapTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(LocationService.self) private var location

    @State private var position: MapCameraPosition = MapTabView.campusCamera
    @State private var selectedSpotId: UUID?

    static let campusCamera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: Theme.campusCenter.latitude,
                                           longitude: Theme.campusCenter.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.010)
        )
    )

    var body: some View {
        NavigationStack {
            Map(position: $position, selection: $selectedSpotId) {
                ForEach(env.spots.spots) { spot in
                    Annotation(spot.name, coordinate: spot.coordinate, anchor: .bottom) {
                        RatingPin(score: spot.avgRating, isSelected: spot.id == selectedSpotId)
                    }
                    .tag(spot.id)
                }
                UserAnnotation()
            }
            .mapStyle(.standard(pointsOfInterest: .including([.university, .library, .cafe])))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .overlay(alignment: .top) {
                StatusBanner()
            }
            .overlay(alignment: .bottom) {
                if env.spots.spots.isEmpty && !env.isRefreshing {
                    Text("No spots yet.")
                        .font(.footnote)
                        .padding(10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("UNC Chapel Hill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Campus", systemImage: "building.columns") {
                        withAnimation { position = Self.campusCamera }
                    }
                }
            }
            .sheet(item: selectedSpotBinding) { spot in
                NavigationStack {
                    SpotDetailView(spotId: spot.id)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .refreshable { await env.refreshAll() }
            .onAppear { location.start() }
        }
    }

    /// Sheet binding derived from the map selection, always reading the latest spot data.
    private var selectedSpotBinding: Binding<StudySpot?> {
        Binding(
            get: { selectedSpotId.flatMap { env.spots.spot(id: $0) } },
            set: { selectedSpotId = $0?.id }
        )
    }
}

/// Shows when the app is working from cached data or has writes waiting to sync.
struct StatusBanner: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if !env.network.isOnline {
                label("Offline — showing saved data", systemImage: "wifi.slash")
            } else if env.sync.pendingCount > 0 {
                label("Syncing \(env.sync.pendingCount) change\(env.sync.pendingCount == 1 ? "" : "s")…",
                      systemImage: "arrow.triangle.2.circlepath")
            } else if env.isShowingCachedData {
                label("Couldn't refresh — showing saved data", systemImage: "exclamationmark.icloud")
            }
        }
        .padding(.top, 8)
        .animation(.default, value: env.network.isOnline)
        .animation(.default, value: env.sync.pendingCount)
    }

    private func label(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    MapTabView()
        .environment(AppEnvironment.preview())
        .environment(LocationService())
}
