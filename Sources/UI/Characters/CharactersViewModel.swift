//
//  CharactersViewModel.swift
//  PantrixRortySwiftUI
//

import Foundation
import Observation
import Pantrix
import Resolver

@MainActor
final class CharactersViewModel: MviViewModel<
    CharactersContract.State,
    CharactersContract.Intent,
    CharactersContract.Effect
> {
    // Collaborators, never read by the view — so `@ObservationIgnored`. Anything the view displays
    // must live in `State`; a stored property here is invisible to SwiftUI (see MviViewModel).
    @ObservationIgnored @Injected private var getCharacters: GetCharactersUseCase

    /// The in-flight debounce, cancelled whenever a newer keystroke arrives.
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    /// Rises on every reload so a slow page that resolves after a newer one cannot overwrite it.
    /// Without this, typing "ri" then "ric" can leave the "ri" results on screen if they land last.
    @ObservationIgnored private var generation = 0

    @ObservationIgnored private var hasAppeared = false

    init() { super.init(initialState: .init()) }

    override func onHandleIntent(_ intent: CharactersContract.Intent) {
        switch intent {
        case .appear:
            // `.task` re-runs when the view is re-created (tab switches do this), and reloading the
            // list every time the user comes back would throw away their scroll position.
            guard !hasAppeared else { return }
            hasAppeared = true
            reload()

        case .refresh:
            reload()

        case let .queryChanged(text):
            guard text != state.query else { return }
            setState { $0.query = text }
            debounceReload()

        case let .statusSelected(status):
            guard status != state.status else { return }
            setState { $0.status = status }
            trackFilterChange()
            reload()

        case .reachedEnd:
            loadMore()

        case let .selected(character):
            Pantrix.trackInteraction(.click, attributes: ["target": "character_row", "id": character.id])
            Pantrix.track("character_opened", attributes: ["id": character.id, "name": character.name])
            setEffect { .navigate(.characterDetail(character)) }
        }
    }

    // MARK: - Loading

    /// A search should not fire a request per keystroke. 400 ms matches the UIKit demo so the two
    /// apps produce comparable request volume in the dashboard.
    private func debounceReload() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            self.trackFilterChange()
            self.reload()
        }
    }

    private func reload() {
        generation += 1
        let token = generation
        let filter = currentFilter

        sendRequest(
            onLoading: { [weak self] loading in
                guard let self, token == self.generation else { return }
                self.setState { $0.isLoading = loading }
            },
            onError: { [weak self] error in
                guard let self, token == self.generation else { return }
                self.setState {
                    $0.items = []
                    $0.nextURL = nil
                    $0.message = "Couldn't load.\n\(error.localizedDescription)\n\nPull to retry."
                }
            },
            request: { [getCharacters] in try await getCharacters(filter: filter, nextURL: nil) },
            onSuccess: { [weak self] page in
                guard let self, token == self.generation else { return }
                self.setState {
                    $0.items = page.items
                    $0.nextURL = page.nextURL
                    $0.total = page.total
                    $0.message = page.items.isEmpty ? "No characters." : nil
                }
                Pantrix.track("page_loaded", attributes: ["resource": "character", "loaded": page.items.count])
            }
        )
    }

    private func loadMore() {
        guard state.canLoadMore, let next = state.nextURL else { return }
        let token = generation
        let filter = currentFilter

        sendRequest(
            onLoading: { [weak self] loading in
                guard let self, token == self.generation else { return }
                self.setState { $0.isLoadingMore = loading }
            },
            // A failed *next* page leaves the rows alone — replacing them with an error would throw
            // away everything the user has already scrolled through.
            onError: { [weak self] error in
                self?.setEffect { .showError(error.localizedDescription) }
            },
            request: { [getCharacters] in try await getCharacters(filter: filter, nextURL: next) },
            onSuccess: { [weak self] page in
                guard let self, token == self.generation else { return }
                self.setState {
                    $0.items += page.items
                    $0.nextURL = page.nextURL
                }
                Pantrix.track("page_loaded", attributes: ["resource": "character", "loaded": page.items.count])
            }
        )
    }

    private var currentFilter: CharacterFilter {
        CharacterFilter(
            name: state.query.trimmingCharacters(in: .whitespaces).isEmpty ? nil : state.query,
            status: state.status
        )
    }

    private func trackFilterChange() {
        Pantrix.track("character_list_filtered", attributes: [
            "name": state.query,
            "status": state.status?.queryValue ?? "all"
        ])
    }
}
