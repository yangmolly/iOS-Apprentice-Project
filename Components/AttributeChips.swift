//
//  AttributeChips.swift
//  iOSApprenticeProject
//

import SwiftUI

struct Chip: View {
    let text: String
    var systemImage: String?
    var isOn = true

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(isOn ? Theme.blue : .secondary)
        .background(Capsule().fill(isOn ? Theme.softBlue : Color.gray.opacity(0.12)))
    }
}

/// A selectable chip for filters and forms.
struct ToggleChip: View {
    let text: String
    var systemImage: String?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage) }
                Text(text)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isOn ? .white : Theme.blue)
            .background(Capsule().fill(isOn ? Theme.blue : Theme.softBlue))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A spot's environment at a glance. Unknown attributes are left out.
struct AttributeChips: View {
    let spot: StudySpot
    var now: Date = .now

    var body: some View {
        FlowLayout(spacing: 6) {
            if let noise = spot.noiseLevel {
                Chip(text: noise.label, systemImage: noise.systemImage)
            }
            if let outlets = spot.hasOutlets {
                Chip(text: outlets ? "Outlets" : "No outlets", systemImage: "powerplug", isOn: outlets)
            }
            if let wifi = spot.hasWifi {
                Chip(text: wifi ? "Wi-Fi" : "No Wi-Fi", systemImage: "wifi", isOn: wifi)
            }
            if let seating = spot.seating {
                Chip(text: seating.label, systemImage: "chair")
            }
            if let open = SpotHours.isOpen(spot, at: now) {
                Chip(text: open ? "Open now" : "Closed", systemImage: "clock", isOn: open)
            }
        }
    }
}

extension NoiseLevel {
    var systemImage: String {
        switch self {
        case .quiet: return "speaker"
        case .moderate: return "speaker.wave.1"
        case .loud: return "speaker.wave.3"
        }
    }
}
