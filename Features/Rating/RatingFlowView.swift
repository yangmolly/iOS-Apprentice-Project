//
//  RatingFlowView.swift
//  iOSApprenticeProject
//

import SwiftUI

struct RatingFlowView: View {
    @State var viewModel: RatingFlowViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .bucket: bucketStep
                case .compare: compareStep
                case .details: detailsStep
                case .saved(let queued): savedStep(queued: queued)
                }
            }
            .animation(.default, value: viewModel.step)
            .navigationTitle(viewModel.spot.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .saved = viewModel.step {
                        EmptyView()
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
                if viewModel.step == .compare || viewModel.step == .details {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left") { viewModel.back() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    // MARK: Step 1: bucket

    private var bucketStep: some View {
        VStack(spacing: 16) {
            Text(viewModel.isReRating ? "How was it this time?" : "How was it?")
                .font(.title2.bold())
                .padding(.top, 32)
            if let previous = viewModel.previousScore {
                Text("Your current score: \(Theme.formatScore(previous))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(RatingBucket.allCases) { bucket in
                Button {
                    viewModel.choose(bucket)
                } label: {
                    HStack {
                        Circle().fill(Theme.ratingColor(bucket.range.upperBound)).frame(width: 14, height: 14)
                        Text(bucket.label).font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.softBlue))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: Step 2: comparisons

    private var compareStep: some View {
        VStack(spacing: 20) {
            Text("Which did you prefer?")
                .font(.title2.bold())
                .padding(.top, 32)
            Text("About \(viewModel.comparisonsRemaining) more")
                .font(.caption).foregroundStyle(.secondary)

            compareCard(title: viewModel.spot.name, subtitle: "This spot") {
                viewModel.answer(newIsBetter: true)
            }
            Text("or").foregroundStyle(.secondary)
            compareCard(title: viewModel.comparisonName,
                        subtitle: viewModel.comparisonSpot?.building ?? "Rated earlier") {
                viewModel.answer(newIsBetter: false)
            }

            Button("Too close to call") { viewModel.tie() }
                .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func compareCard(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title).font(.headline).multilineTextAlignment(.center)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.softBlue))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.blue.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Step 3: details

    private var detailsStep: some View {
        @Bindable var vm = viewModel
        return Form {
            if let score = viewModel.resultingScore {
                Section {
                    HStack {
                        RatingBadge(score: score, size: 48)
                        Text("Your score").font(.headline)
                    }
                }
            }
            Section("Noise") {
                Picker("Noise", selection: $vm.noiseLevel) {
                    Text("Not sure").tag(NoiseLevel?.none)
                    ForEach(NoiseLevel.allCases) { Text($0.label).tag(NoiseLevel?.some($0)) }
                }
                .pickerStyle(.segmented)
            }
            Section("Amenities") {
                TriStatePicker(title: "Outlets", systemImage: "powerplug", value: $vm.hasOutlets)
                TriStatePicker(title: "Wi-Fi", systemImage: "wifi", value: $vm.hasWifi)
            }
            Section("Seating") {
                Picker("Seating", selection: $vm.seating) {
                    Text("Not sure").tag(Seating?.none)
                    ForEach(Seating.allCases) { Text($0.label).tag(Seating?.some($0)) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                TextField("What should others know?", text: $vm.comments, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("Comments")
            } footer: {
                Text("\(viewModel.comments.count)/\(RatingFlowViewModel.maxCommentLength)")
            }
            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
            Section {
                Button {
                    Task { await viewModel.save() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isSaving { ProgressView() } else { Text("Save rating").bold() }
                        Spacer()
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
    }

    // MARK: Done

    private func savedStep(queued: Bool) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: queued ? "icloud.and.arrow.up" : "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(queued ? .orange : .green)
            Text(queued ? "Saved offline" : "Rating saved").font(.title2.bold())
            if queued {
                Text("It will sync when you're back online.")
                    .foregroundStyle(.secondary)
            }
            if let score = viewModel.resultingScore {
                RatingBadge(score: score, size: 56)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Yes / No / Not sure for an optional Bool.
struct TriStatePicker: View {
    let title: String
    let systemImage: String
    @Binding var value: Bool?

    var body: some View {
        Picker(selection: $value) {
            Text("Not sure").tag(Bool?.none)
            Text("Yes").tag(Bool?.some(true))
            Text("No").tag(Bool?.some(false))
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}
