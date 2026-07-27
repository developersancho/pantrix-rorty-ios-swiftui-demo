//
//  CharactersByIds.swift
//  PantrixRortySwiftUI
//
//  "The characters in this episode" / "the residents of this location" — a batch fetch, reached from
//  two different detail screens. No pagination, no search.
//

import Foundation
import Observation
import Pantrix
import Resolver
import SwiftUI

// MARK: - Contract

enum CharactersByIdsContract {
    struct State: MviState {
        var items: [Character] = []
        var isLoading = false
        var message: String?
    }

    enum Intent: MviIntent {
        case appear
        case selected(Character)
    }

    enum Effect: MviEffect {
        case navigate(Route)
    }
}

// MARK: - View model

@MainActor
final class CharactersByIdsViewModel: MviViewModel<
    CharactersByIdsContract.State,
    CharactersByIdsContract.Intent,
    CharactersByIdsContract.Effect
> {
    @ObservationIgnored @Injected private var getCharacters: GetCharactersByIdsUseCase
    @ObservationIgnored private let ids: [Int]
    @ObservationIgnored private var hasAppeared = false

    init(ids: [Int]) {
        self.ids = ids
        super.init(initialState: .init())
    }

    override func onHandleIntent(_ intent: CharactersByIdsContract.Intent) {
        switch intent {
        case .appear:
            guard !hasAppeared else { return }
            hasAppeared = true
            load()

        case let .selected(character):
            Pantrix.trackInteraction(.click, attributes: ["target": "related_character", "id": character.id])
            Pantrix.track("character_opened", attributes: ["id": character.id, "name": character.name])
            setEffect { .navigate(.characterDetail(character)) }
        }
    }

    private func load() {
        sendRequest(
            onLoading: { [weak self] loading in self?.setState { $0.isLoading = loading } },
            onError: { [weak self] error in
                self?.setState { $0.message = "Couldn't load.\n\(error.localizedDescription)" }
            },
            request: { [getCharacters, ids] in try await getCharacters(ids) },
            onSuccess: { [weak self] characters in
                self?.setState {
                    $0.items = characters
                    $0.message = characters.isEmpty ? "No characters." : nil
                }
                Pantrix.track("page_loaded", attributes: ["resource": "character", "loaded": characters.count])
            }
        )
    }
}

// MARK: - View

struct CharactersByIdsView: View {

    @State private var vm: CharactersByIdsViewModel
    @Binding var path: [Route]
    private let title: String

    init(ids: [Int], title: String, path: Binding<[Route]>) {
        // `@State` with a parameterised initial value: SwiftUI keeps the FIRST instance for this
        // view's identity, so a re-render must not restart the fetch.
        _vm = State(initialValue: CharactersByIdsViewModel(ids: ids))
        _path = path
        self.title = title
    }

    var body: some View {
        List {
            if let message = vm.state.message {
                StateMessage(text: message)
            }
            ForEach(vm.state.items) { character in
                Button {
                    vm.onIntent(.selected(character))
                } label: {
                    CharacterRow(character: character)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .overlay { if vm.state.isLoading { ProgressView() } }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { vm.onIntent(.appear) }
        .onReceive(vm.effect) { effect in
            if case let .navigate(route) = effect { path.append(route) }
        }
    }
}
