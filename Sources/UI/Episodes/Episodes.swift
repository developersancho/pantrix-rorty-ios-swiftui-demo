//
//  Episodes.swift
//  PantrixRortySwiftUI
//
//  Contract + view model + views for the Episodes tab.
//

import Foundation
import Observation
import Pantrix
import PantrixSwiftUI
import Resolver
import SwiftUI

// MARK: - Contract

enum EpisodesContract {
    struct State: PagedListState {
        var items: [Episode] = []
        var query = ""
        var isLoading = false
        var isLoadingMore = false
        var message: String?
        var nextURL: String?
        var total = 0
    }

    enum Intent: MviIntent {
        case appear
        case refresh
        case queryChanged(String)
        case reachedEnd
        case selected(Episode)
    }

    enum Effect: MviEffect {
        case navigate(Route)
        case showError(String)
    }
}

// MARK: - View model

@MainActor
final class EpisodesViewModel: PagedListViewModel<
    EpisodesContract.State,
    EpisodesContract.Intent,
    EpisodesContract.Effect
> {
    @ObservationIgnored @Injected private var getEpisodes: GetEpisodesUseCase

    init() { super.init(initialState: .init(), resourceName: "episode") }

    override func onHandleIntent(_ intent: EpisodesContract.Intent) {
        switch intent {
        case .appear: appearOnce(fetch)
        case .refresh: reload(fetch)
        case let .queryChanged(text): queryChanged(text, fetch)
        case .reachedEnd:
            loadMore(fetch) { [weak self] error in
                self?.setEffect { .showError(error.localizedDescription) }
            }
        case let .selected(episode):
            Pantrix.trackInteraction(.click, attributes: ["target": "episode_row", "id": episode.id])
            Pantrix.track("episode_opened", attributes: ["id": episode.id, "name": episode.name])
            setEffect { .navigate(.episodeDetail(episode)) }
        }
    }

    private func fetch(_ nextURL: String?) async throws -> Page<Episode> {
        try await getEpisodes(filter: EpisodeFilter(name: state.searchTerm), nextURL: nextURL)
    }
}

// MARK: - List

struct EpisodesView: View {

    @State private var vm = EpisodesViewModel()
    @Binding var path: [Route]
    @State private var errorMessage: String?

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
                .onAppear {
                    if episode.id == vm.state.items.suffix(5).first?.id {
                        vm.onIntent(.reachedEnd)
                    }
                }
            }

            if vm.state.isLoadingMore { LoadingMoreFooter() }
        }
        .listStyle(.plain)
        .overlay { if vm.state.isLoading && vm.state.items.isEmpty { ProgressView() } }
        .navigationTitle("Episodes")
        .searchable(text: queryBinding, prompt: "Search episodes")
        .refreshable { vm.onIntent(.refresh) }
        .task { vm.onIntent(.appear) }
        .trackScreen("Episodes")
        .onReceive(vm.effect) { effect in
            switch effect {
            case let .navigate(route): path.append(route)
            case let .showError(message): errorMessage = message
            }
        }
        .alert("Couldn't load more", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var queryBinding: Binding<String> {
        Binding(get: { vm.state.query }, set: { vm.onIntent(.queryChanged($0)) })
    }
}

// MARK: - Detail

/// No view model and no `.trackScreen` — see `CharacterDetailView` for why.
struct EpisodeDetailView: View {

    let episode: Episode
    @Binding var path: [Route]

    var body: some View {
        List {
            Section {
                DetailRow(caption: "Code", value: episode.code)
                DetailRow(caption: "Air date", value: episode.airDate)
            }

            Section {
                Button {
                    Pantrix.track("episode_characters_opened", attributes: [
                        "id": episode.id,
                        "count": episode.characterIds.count
                    ])
                    path.append(.charactersByIds(ids: episode.characterIds, title: "Characters"))
                } label: {
                    HStack {
                        Text("Characters (\(episode.characterIds.count))")
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                }
                .disabled(episode.characterIds.isEmpty)
            }
        }
        .navigationTitle(episode.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
