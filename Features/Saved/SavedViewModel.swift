//
//  SavedViewModel.swift
//  iOSApprenticeProject
//

import Foundation
import Observation

@Observable
final class SavedViewModel {
    var list: SavedList = .wantToGo
    var errorMessage: String?

    @ObservationIgnored private let saved: SavedRepository
    @ObservationIgnored private let spots: SpotRepository

    init(saved: SavedRepository, spots: SpotRepository) {
        self.saved = saved
        self.spots = spots
    }

    /// Spots in the selected list, alphabetically. Saved ids whose spot isn't loaded yet are skipped.
    var items: [StudySpot] {
        saved.spotIds(in: list)
            .compactMap { spots.spot(id: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func count(in list: SavedList) -> Int {
        saved.spotIds(in: list).count
    }

    func remove(_ spot: StudySpot) async {
        await set(spot, in: list, false)
    }

    /// "Been there": move from want-to-go to favorites.
    func moveToFavorites(_ spot: StudySpot) async {
        await set(spot, in: .favorite, true)
        if errorMessage == nil { await set(spot, in: .wantToGo, false) }
    }

    private func set(_ spot: StudySpot, in list: SavedList, _ isSaved: Bool) async {
        errorMessage = nil
        do {
            try await saved.setSaved(spot.id, in: list, isSaved)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
