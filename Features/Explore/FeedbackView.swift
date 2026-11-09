//
//  FeedbackView.swift
//  iOSApprenticeProject
//
//  Created by Molly Yang on 10/18/26.
//

import SwiftUI

struct FeedbackView: View {

    var locationName: String = "Walter Royal Davis Library"

    @Environment(\.dismiss) private var dismiss

    @AppStorage("customLikeTags") private var likeStore = "[]"
    @AppStorage("customDislikeTags") private var dislikeStore = "[]"

    @State private var rating = 0
    @State private var liked: Set<String> = []
    @State private var disliked: Set<String> = []
    @State private var comments = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @FocusState private var commentsFocused: Bool

    private let blue = Color(red: 0.02, green: 0.43, blue: 1.0)
    private let fieldBorder = Color.gray.opacity(0.25)
    private let characterLimit = 300

    private let likeOptions = ["QUIET", "VENDING", "COLLABORATIVE", "CONVENIENT", "SPACIOUS", "OUTLETS"]
    private let dislikeOptions = ["VOLUME", "CLEANLINESS", "CROWDED", "INACCESSIBLE"]
    private let ratingLabels = ["", "Poor", "Fair", "Good", "Great", "Excellent"]

    private var canSubmit: Bool { rating > 0 && !isSubmitting }

    private func listBinding(_ store: Binding<String>) -> Binding<[String]> {
        Binding(
            get: {
                (try? JSONDecoder().decode([String].self, from: Data(store.wrappedValue.utf8))) ?? []
            },
            set: { newValue in
                if let data = try? JSONEncoder().encode(newValue),
                   let string = String(data: data, encoding: .utf8) {
                    store.wrappedValue = string
                }
            }
        )
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {

                ZStack {
                    Text("Location Review")
                        .font(.system(size: 13, weight: .semibold))
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(blue)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        Text("You studied at \(locationName) today.")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.top, 32)

                        Text("How would you rate your time there?")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.top, 8)

                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                        rating = (rating == star) ? 0 : star
                                    }
                                } label: {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 24))
                                        .foregroundColor(star <= rating ? blue : Color.gray.opacity(0.4))
                                        .scaleEffect(star == rating ? 1.25 : 1)
                                }
                            }

                            if rating > 0 {
                                Text(ratingLabels[rating])
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(blue)
                                    .padding(.leading, 8)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                        .padding(.top, 14)
                        .sensoryFeedback(.selection, trigger: rating)

                        sectionTitle("What did you like about it?")
                            .padding(.top, 44)
                        TagSection(
                            options: likeOptions,
                            custom: listBinding($likeStore),
                            selection: $liked
                        )
                        .padding(.top, 14)

                        sectionTitle("What did you not enjoy?")
                            .padding(.top, 40)
                        TagSection(
                            options: dislikeOptions,
                            custom: listBinding($dislikeStore),
                            selection: $disliked
                        )
                        .padding(.top, 14)

                        HStack {
                            sectionTitle("Anything else?")
                            Spacer()
                            Text("\(comments.count)/\(characterLimit)")
                                .font(.system(size: 10))
                                .foregroundColor(comments.count >= characterLimit ? .red : .gray)
                        }
                        .padding(.top, 40)

                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $comments)
                                .focused($commentsFocused)
                                .font(.system(size: 12))
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                                .onChange(of: comments) { _, newValue in
                                    if newValue.count > characterLimit {
                                        comments = String(newValue.prefix(characterLimit))
                                    }
                                }

                            if comments.isEmpty {
                                Text("Tell us everything.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.7))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(height: 88)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(commentsFocused ? blue : fieldBorder,
                                        lineWidth: commentsFocused ? 1.5 : 1)
                        )
                        .padding(.top, 12)

                        Button {
                            submit()
                        } label: {
                            ZStack {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Submit")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(canSubmit || isSubmitting ? blue : blue.opacity(0.4))
                            .cornerRadius(8)
                        }
                        .disabled(!canSubmit)
                        .padding(.top, 32)

                        if rating == 0 {
                            Text("Choose a star rating to submit")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 10)
                        }

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color.white)
            .animation(.easeInOut(duration: 0.2), value: rating)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { commentsFocused = false }
                        .fontWeight(.semibold)
                }
            }

            if didSubmit {
                thankYou
                    .transition(.opacity)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var thankYou: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(blue)
                .symbolEffect(.bounce, value: didSubmit)
            Text("Thanks for your review!")
                .font(.system(size: 18, weight: .bold))
            Text("Your feedback helps other students find great study spots.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private func submit() {
        commentsFocused = false
        isSubmitting = true
        Task {
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.easeInOut) {
                isSubmitting = false
                didSubmit = true
            }
            try? await Task.sleep(for: .seconds(1.6))
            dismiss()
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
    }
}

struct TagSection: View {

    let options: [String]
    @Binding var custom: [String]
    @Binding var selection: Set<String>

    @State private var isAdding = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private let blue = Color(red: 0.02, green: 0.43, blue: 1.0)
    private let softBlue = Color(red: 0.92, green: 0.95, blue: 1.0)
    private let maxLength = 20

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                chip(option, isCustom: false)
            }
            ForEach(custom, id: \.self) { option in
                chip(option, isCustom: true)
            }
            addControl
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: custom)
    }

    private func chip(_ option: String, isCustom: Bool) -> some View {
        let isOn = selection.contains(option)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                if isOn {
                    selection.remove(option)
                } else {
                    selection.insert(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .heavy))
                }
                Text(option)
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(isOn ? .white : blue)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(isOn ? blue : softBlue)
            .clipShape(Capsule())
            .scaleEffect(isOn ? 1.04 : 1)
        }
        .sensoryFeedback(.selection, trigger: isOn)
        .contextMenu {
            if isCustom {
                Button(role: .destructive) {
                    remove(option)
                } label: {
                    Label("Remove category", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var addControl: some View {
        if isAdding {
            TextField("New category", text: $draft)
                .font(.system(size: 9, weight: .bold))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($fieldFocused)
                .onSubmit { commit() }
                .onChange(of: draft) { _, newValue in
                    if newValue.count > maxLength {
                        draft = String(newValue.prefix(maxLength))
                    }
                }
                .onChange(of: fieldFocused) { _, focused in
                    if !focused && isAdding { commit() }
                }
                .padding(.horizontal, 12)
                .frame(width: 130, height: 26)
                .background(Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(blue, lineWidth: 1.5))
        } else {
            Button {
                isAdding = true
                Task {
                    try? await Task.sleep(for: .seconds(0.1))
                    fieldFocused = true
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 7, weight: .heavy))
                    Text("ADD")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(blue)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .overlay(
                    Capsule()
                        .stroke(blue, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                )
            }
        }
    }

    private func commit() {
        let name = draft
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        isAdding = false
        draft = ""
        fieldFocused = false
        guard !name.isEmpty else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if !options.contains(name) && !custom.contains(name) {
                custom.append(name)
            }
            selection.insert(name)
        }
    }

    private func remove(_ option: String) {
        withAnimation {
            custom.removeAll { $0 == option }
            selection.remove(option)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    FeedbackView()
}
