//
//  EpisodesByIds.swift
//  PantrixRortySwiftUI
//
//  "The episodes this character appears in" — a batch fetch, no pagination, no search.
//

import Foundation
import Observation
import Pantrix
import PantrixSwiftUI
import Resolver
import SwiftUI

// MARK: - Contract

enum EpisodesByIdsContract {
    struct State: MviState {
        var items: [Episode] = []
        var isLoading = false
        var message: String?
    }

    enum Intent: MviIntent {
        case appear
        case selected(Episode)
    }

    enum Effect: MviEffect {
        case navigate(Route)
    }
}

// MARK: - View model

@MainActor
final class EpisodesByIdsViewModel: MviViewModel<
    EpisodesByIdsContract.State,
    EpisodesByIdsContract.Intent,
    EpisodesByIdsContract.Effect
> {
    @ObservationIgnored @Injected private var getEpisodes: GetEpisodesByIdsUseCase
    @ObservationIgnored private let ids: [Int]
    @ObservationIgnored private var hasAppeared = false

    init(ids: [Int]) {
        self.ids = ids
        super.init(initialState: .init())
    }

    override func onHandleIntent(_ intent: EpisodesByIdsContract.Intent) {
        switch intent {
        case .appear:
            guard !hasAppeared else { return }
            hasAppeared = true
            load()

        case let .selected(episode):
            Pantrix.trackInteraction(.click, attributes: ["target": "related_episode", "id": episode.id])
            Pantrix.track("episode_opened", attributes: ["id": episode.id, "name": episode.name])
            setEffect { .navigate(.episodeDetail(episode)) }
        }
    }

    private func load() {
        sendRequest(
            onLoading: { [weak self] loading in self?.setState { $0.isLoading = loading } },
            onError: { [weak self] error in
                self?.setState { $0.message = "Couldn't load.\n\(error.localizedDescription)" }
            },
            request: { [getEpisodes, ids] in try await getEpisodes(ids) },
            onSuccess: { [weak self] episodes in
                self?.setState {
                    $0.items = episodes
                    $0.message = episodes.isEmpty ? "No episodes." : nil
                }
                Pantrix.track("page_loaded", attributes: ["resource": "episode", "loaded": episodes.count])
            }
        )
    }
}

// MARK: - View

struct EpisodesByIdsView: View {

    @State private var vm: EpisodesByIdsViewModel
    @Binding var path: [Route]
    private let title: String

    init(ids: [Int], title: String, path: Binding<[Route]>) {
        // `@State` with a parameterised initial value: SwiftUI keeps the FIRST instance for this
        // view's identity, which is what we want — a re-render must not restart the fetch.
        _vm = State(initialValue: EpisodesByIdsViewModel(ids: ids))
        _path = path
        self.title = title
    }

    var body: some View {
        List {
            if let message = vm.state.message {
                StateMessage(text: message)
            }
            ForEach(vm.state.items) { episode in
                Button {
                    vm.onIntent(.selected(episode))
                } label: {
                    EpisodeRow(episode: episode)
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
