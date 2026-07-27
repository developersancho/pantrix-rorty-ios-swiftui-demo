//
//  CharactersViewModel.swift
//  PantrixRortySwiftUI
//

import Foundation
import Observation
import Pantrix
import Resolver

/// Everything mechanical — debounce, generation guard, first-vs-next page — lives in
/// `PagedListViewModel`. What is left here is what makes this screen *Characters*: its filter and
/// what a tap means.
@MainActor
final class CharactersViewModel: PagedListViewModel<
    CharactersContract.State,
    CharactersContract.Intent,
    CharactersContract.Effect
> {
    // A collaborator, never read by the view — so `@ObservationIgnored`. Anything displayed must
    // live in `State`; a stored property here is invisible to SwiftUI (see MviViewModel).
    @ObservationIgnored @Injected private var getCharacters: GetCharactersUseCase

    init() { super.init(initialState: .init(), resourceName: "character") }

    override func onHandleIntent(_ intent: CharactersContract.Intent) {
        switch intent {
        case .appear:
            appearOnce(fetch)

        case .refresh:
            reload(fetch)

        case let .queryChanged(text):
            queryChanged(text, fetch)

        case let .statusSelected(status):
            guard status != state.status else { return }
            setState { $0.status = status }
            // A segment tap is deliberate, so it reloads at once — unlike typing, which waits.
            trackFilterChange(extra: ["status": status?.queryValue ?? "all"])
            reload(fetch)

        case .reachedEnd:
            loadMore(fetch) { [weak self] error in
                self?.setEffect { .showError(error.localizedDescription) }
            }

        case let .selected(character):
            Pantrix.trackInteraction(.click, attributes: ["target": "character_row", "id": character.id])
            Pantrix.track("character_opened", attributes: ["id": character.id, "name": character.name])
            setEffect { .navigate(.characterDetail(character)) }
        }
    }

    /// The screen's one data dependency, in the shape the base expects: `nil` means first page,
    /// otherwise follow the URL the API returned.
    private func fetch(_ nextURL: String?) async throws -> Page<Character> {
        let filter = CharacterFilter(name: state.searchTerm, status: state.status)
        return try await getCharacters(filter: filter, nextURL: nextURL)
    }
}
