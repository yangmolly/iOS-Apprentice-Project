//
//  MapView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/18/26.
//

import SwiftUI
import MapKit
import PhotosUI
import Combine


struct MapPinItem: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    var imageData: Data? = nil

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func == (lhs: MapPinItem, rhs: MapPinItem) -> Bool { lhs.id == rhs.id }
}



final class PinStore: ObservableObject {

    @Published private(set) var pins: [MapPinItem] = []

    private let fileURL: URL

    init() {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = folder.appendingPathComponent("pins.json")
        load()
    }

    func add(_ pin: MapPinItem) {
        pins.append(pin)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([MapPinItem].self, from: data)
        else { return }
        pins = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(pins) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

struct MapView: View {

    @StateObject private var store = PinStore()

    @State private var selected: MapPinItem?
    @State private var position: MapCameraPosition = MapView.campusCamera

    @State private var isAddingPin = false
    @State private var draftCoordinate: CLLocationCoordinate2D?
    @State private var showAddSheet = false

    private let blue = Color(red: 0.02, green: 0.43, blue: 1.0)

    private static let campusCamera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.9100, longitude: -79.0510),
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.006)
        )
    )

    var body: some View {
        GeometryReader { geo in
            let fullHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let s = fullHeight / 812

            VStack(spacing: 0) {

                HStack(alignment: .center) {
                    Text("UNC Chapel Hill")
                        .font(.system(size: 26, weight: .bold))
                    Spacer(minLength: 8)
                    Button {
                        cancelAdding()
                        deselect(resetCamera: true)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(blue)
                    }
                    Text("\(store.pins.count) results")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24 * s)
                .padding(.bottom, 22 * s)
                .background(Color.white)

                MapReader { proxy in
                    Map(position: $position, interactionModes: .all) {
                        ForEach(store.pins) { pin in
                            Annotation(pin.name, coordinate: pin.coordinate, anchor: .bottom) {
                                Button {
                                    if !isAddingPin { select(pin) }
                                } label: {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.white, blue)
                                }
                            }
                        }

                        
                        if let draft = draftCoordinate {
                            Marker("New pin", systemImage: "plus", coordinate: draft)
                                .tint(.orange)
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .including([.university, .library, .cafe, .restaurant])))
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                    }
                    .onTapGesture { screenPoint in
                        if isAddingPin {
                            if let coordinate = proxy.convert(screenPoint, from: .local) {
                                draftCoordinate = coordinate
                                showAddSheet = true
                            }
                        } else if selected != nil {
                            // Tap empty map to close the building details
                            deselect(resetCamera: false)
                        }
                    }
                    
                    .overlay(alignment: .top) {
                        if isAddingPin {
                            banner(icon: "hand.tap.fill", text: "Tap the map to place a pin")
                        } else if store.pins.isEmpty {
                            banner(icon: "mappin.and.ellipse", text: "No pins yet. Tap Add pin to add the first one")
                        }
                    }

                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            if isAddingPin {
                                cancelAdding()
                            } else {
                                startAdding()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isAddingPin ? "xmark" : "plus")
                                Text(isAddingPin ? "Cancel" : "Add pin")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isAddingPin ? .red : blue)
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
                        }
                        .padding(12)
                    }
                }
                .frame(height: selected == nil ? nil : 173 * s)
                .frame(maxHeight: selected == nil ? .infinity : nil)

                if let spot = selected {
                    detailCard(for: spot, scale: s)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color.white)
        .sheet(isPresented: $showAddSheet, onDismiss: {
            
            draftCoordinate = nil
        }) {
            AddPinSheet { name, address, imageData in
                guard let coordinate = draftCoordinate else { return }
                let newPin = MapPinItem(
                    name: name,
                    address: address.isEmpty ? "Chapel Hill, North Carolina" : address,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    imageData: imageData
                )
                store.add(newPin)
                draftCoordinate = nil
                isAddingPin = false
                showAddSheet = false
                select(newPin)
            }
            .presentationDetents([.height(560), .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func banner(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(blue)
        .clipShape(Capsule())
        .padding(.top, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func select(_ pin: MapPinItem) {
        withAnimation(.easeInOut) {
            selected = pin
            position = .region(
                MKCoordinateRegion(
                    center: pin.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                )
            )
        }
    }

    private func deselect(resetCamera: Bool) {
        withAnimation(.easeInOut) {
            selected = nil
            if resetCamera { position = MapView.campusCamera }
        }
    }

    private func startAdding() {
        withAnimation(.easeInOut) {
            selected = nil
            isAddingPin = true
        }
    }

    private func cancelAdding() {
        withAnimation(.easeInOut) {
            isAddingPin = false
            draftCoordinate = nil
        }
    }


    private func detailCard(for spot: MapPinItem, scale s: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            Group {
                if let data = spot.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color(white: 0.92)
                        Image(systemName: "building.2")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            .frame(height: 187 * s)
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 0) {
                Text(spot.name)
                    .font(.system(size: 16, weight: .bold))
                    .padding(.top, 18 * s)

                Text("ABOUT")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.top, 24 * s)

                Text(spot.address)
                    .font(.system(size: 11))
                    .foregroundColor(Color(white: 0.3))
                    .padding(.top, 6)

                Text("YOUR REVIEW")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.top, 24 * s)

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 0.88, green: 0.94, blue: 1.0))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(red: 0.6, green: 0.8, blue: 1.0))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ram Sey")
                            .font(.system(size: 10, weight: .semibold))
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(blue)
                            Text("4.8")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.top, 10)

                Spacer(minLength: 12)

                Button {
                    // TODO: navigate to details
                } label: {
                    Text("See details")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(blue, lineWidth: 1.5)
                        )
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .background(Color.white)
    }
}


struct AddPinSheet: View {

    var onSave: (_ name: String, _ address: String, _ imageData: Data?) -> Void

    @State private var name = ""
    @State private var address = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @FocusState private var focus: Field?

    private enum Field { case name, address }

    private let blue = Color(red: 0.02, green: 0.43, blue: 1.0)
    private let fieldBorder = Color.gray.opacity(0.25)

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                Text("Add a pin")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 24)

                Text("Give this spot a name so others can find it")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.top, 6)

                Text("Name")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.top, 24)
                TextField("e.g. Davis Library 3rd floor", text: $name)
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .address }
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(focus == .name ? blue : fieldBorder,
                                    lineWidth: focus == .name ? 1.5 : 1)
                    )
                    .padding(.top, 8)

                Text("Address (optional)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.top, 16)
                TextField("Street address", text: $address)
                    .focused($focus, equals: .address)
                    .submitLabel(.done)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(focus == .address ? blue : fieldBorder,
                                    lineWidth: focus == .address ? 1.5 : 1)
                    )
                    .padding(.top, 8)

                Text("Photo (optional)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.top, 16)

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Group {
                        if let data = imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 22))
                                Text("Choose a photo")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(blue)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(fieldBorder, lineWidth: 1)
                    )
                }
                .padding(.top, 8)
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let raw = try? await newItem?.loadTransferable(type: Data.self) {
                            imageData = AddPinSheet.compress(raw)
                        }
                    }
                }

                Button {
                    onSave(name.trimmingCharacters(in: .whitespaces),
                           address.trimmingCharacters(in: .whitespaces),
                           imageData)
                } label: {
                    Text("Save pin")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(canSave ? blue : blue.opacity(0.4))
                        .cornerRadius(8)
                }
                .disabled(!canSave)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
        .onAppear { focus = .name }
    }

    /// Shrinks big camera photos so saved pins stay small
    private static func compress(_ data: Data, maxSide: CGFloat = 1200) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / longest)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}

#Preview {
    MapView()
}
