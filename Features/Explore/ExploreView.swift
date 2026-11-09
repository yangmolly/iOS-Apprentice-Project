//
//  ExploreView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/10/26.
//

import SwiftUI

struct ExploreEventItem: Identifiable {
    let id = UUID()
    let title: String
    let location: String
    let date: String?   // e.g. "MAR 05"
}

struct ExploreView: View {

    @State private var selectedCategory = "STUDY GROUP"

    private let blue = Color(red: 0.02, green: 0.43, blue: 1.0)
    private let softBlue = Color(red: 0.92, green: 0.95, blue: 1.0)

    private let categories = ["CLE EVENT", "STUDY GROUP", "FREE FOOD", "CLUBS"]

    private let nearYou: [ExploreEventItem] = [
        ExploreEventItem(title: "COMP 550 Midterm 2 Review", location: "Davis Collaboration Cube #2", date: "MAR 05"),
        ExploreEventItem(title: "SPAN 203 Study Group", location: "Dey Hall Rm. 206", date: "MAR 05")
    ]

    private let yourEvents: [ExploreEventItem] = [
        ExploreEventItem(title: "COMP 433 Group Project", location: "Sitterson Lobby", date: nil),
        ExploreEventItem(title: "STOR 455 Study Session", location: "Gardener Hall Rm. 106", date: nil)
    ]

    private let happeningSoon: [ExploreEventItem] = [
        ExploreEventItem(title: "Event Title", location: "Location", date: "MAR 05"),
        ExploreEventItem(title: "Event Title", location: "Location", date: "MAR 06")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Search
                Button {
                    // TODO: open search
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Category chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(categories, id: \.self) { category in
                            chip(category)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 18)

                // Near you
                sectionHeader("Near you", showSeeMore: true)
                    .padding(.top, 32)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(nearYou) { event in
                            eventCard(event, showJoin: true)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 12)

                // Your events
                sectionHeader("Your events", showSeeMore: false)
                    .padding(.top, 32)

                VStack(spacing: 12) {
                    ForEach(yourEvents) { event in
                        eventRow(event)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Happening soon
                sectionHeader("Happening Soon", showSeeMore: true)
                    .padding(.top, 32)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(happeningSoon) { event in
                            eventCard(event, showJoin: false)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(Color.white)
    }

    // MARK: - Pieces

    private func chip(_ title: String) -> some View {
        let isSelected = title == selectedCategory

        return Button {
            selectedCategory = title
        } label: {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isSelected ? .white : blue)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(isSelected ? blue : softBlue)
                .clipShape(Capsule())
        }
    }

    private func sectionHeader(_ title: String, showSeeMore: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .bold))

            Spacer()

            if showSeeMore {
                Button("See more") {
                    // TODO: see more
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(blue)
            }
        }
        .padding(.horizontal, 24)
    }

    private func imagePlaceholder() -> some View {
        ZStack {
            softBlue

            Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundColor(Color(red: 0.7, green: 0.82, blue: 1.0))
        }
    }

    private func eventCard(_ event: ExploreEventItem, showJoin: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Image + date badge
            ZStack(alignment: .topTrailing) {
                imagePlaceholder()
                    .frame(height: 120)

                if let date = event.date {
                    Text(date)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 20)
                        .background(blue)
                        .clipShape(Capsule())
                        .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)

                Text(event.location)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                if showJoin {
                    Button {
                        // TODO: join group
                    } label: {
                        Text("Join Group")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(blue, lineWidth: 1.5)
                            )
                    }
                    .padding(.top, 14)
                }
            }
            .padding(14)
        }
        .frame(width: 200)
        .background(softBlue.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func eventRow(_ event: ExploreEventItem) -> some View {
        HStack(spacing: 0) {
            imagePlaceholder()
                .frame(width: 80, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 12, weight: .bold))

                Text(event.location)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(.leading, 14)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.trailing, 14)
        }
        .frame(height: 64)
        .background(softBlue.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ExploreView()
}
