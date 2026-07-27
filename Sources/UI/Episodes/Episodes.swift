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
            // No `trackInteraction(.click, …)` here: the row's `trackTaps` already emitted the
            // `ui_click`, and repeating it would double-count every tap. The business event is this
            // layer's to send — the interaction is the view's.
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
        // A `ScrollView` + `LazyVStack`, not a `List` — and that is what makes `trackScroll` possible
        // here. The modifier measures ONE content view's offset inside the container's coordinate
        // space, so it needs a single view that spans the whole scrollable extent. A `List` never
        // offers one: its rows are separate, lazily built, and recycled as they leave the screen, so
        // there is nothing to attach to. Characters and Locations stay `List`s so both shapes are in
        // the app side by side.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let message = vm.state.message {
                    StateMessage(text: message)
                }

                ForEach(vm.state.items) { episode in
                    EpisodeRow(episode: episode)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Without this the row is only tappable on its text, not across the gap to
                        // the trailing edge — a `List` row gives that for free, a `VStack` child does not.
                        .contentShape(Rectangle())
                        .trackTaps("episode_row", metadata: ["id": episode.id]) {
                            vm.onIntent(.selected(episode))
                        }
                        .padding(.horizontal)
                        .onAppear {
                            if episode.id == vm.state.items.suffix(5).first?.id {
                                vm.onIntent(.reachedEnd)
                            }
                        }
                    Divider().padding(.leading)
                }

                if vm.state.isLoadingMore { LoadingMoreFooter() }
            }
            // The documented placement — and, measured on iOS 26.5, currently a silent no-op.
            //
            // `trackScroll` reads the offset through a `GeometryReader` background and ships it up
            // with `preference` + `onPreferenceChange`. The read is fine: probing this exact spot by
            // hand, the geometry updated 162 times across one swipe, 0 → 822pt. The delivery is not:
            // `onPreferenceChange` fired **once**, with 0, and never again. `onGeometryChange` wired
            // into the same position fired 151 times and followed the scroll. So the preference path
            // no longer propagates during ScrollView scrolling, and the modifier reports nothing at
            // all — no warning, no event, nothing to notice.
            //
            // Left in place deliberately: it is the correct call, it costs one `GeometryReader`, and
            // when the SDK moves to `onGeometryChange` this screen starts working without an edit.
            .trackScroll("episodes_feed")

            // `.trackDrag("episodes_feed")` belongs here — the leading edge of the gesture whose
            // trailing edge `trackScroll` reports — and is deliberately absent.
            //
            // Its doc says `simultaneousGesture` keeps it from stealing an enclosing ScrollView's
            // scrolling. Measured here, it does steal it: with the modifier on, three full swipes
            // moved the list by nothing and emitted three `ui_drag`s; with it off, one identical
            // swipe scrolled from S01E01 to S03E09. A tracking call that breaks scrolling is not
            // something to ship to make a point.
        }
        // Without this the content has no named coordinate space to measure against and `trackScroll`
        // silently reports nothing — no warning, no event.
        .pantrixScrollContainer()
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
