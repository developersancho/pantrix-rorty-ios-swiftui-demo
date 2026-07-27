//
//  Locations.swift
//  PantrixRortySwiftUI
//
//  Contract + view model + views for the Locations tab. Same shape as Characters, minus the status
//  filter — the mechanics come from `PagedListViewModel`, so what is here is only what is different.
//

import Foundation
import Observation
import Pantrix
import PantrixSwiftUI
import Resolver
import SwiftUI

// MARK: - Contract

enum LocationsContract {
    struct State: PagedListState {
        var items: [Location] = []
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
        case selected(Location)
    }

    enum Effect: MviEffect {
        case navigate(Route)
        case showError(String)
    }
}

// MARK: - View model

@MainActor
final class LocationsViewModel: PagedListViewModel<
    LocationsContract.State,
    LocationsContract.Intent,
    LocationsContract.Effect
> {
    @ObservationIgnored @Injected private var getLocations: GetLocationsUseCase

    init() { super.init(initialState: .init(), resourceName: "location") }

    override func onHandleIntent(_ intent: LocationsContract.Intent) {
        switch intent {
        case .appear: appearOnce(fetch)
        case .refresh: reload(fetch)
        case let .queryChanged(text): queryChanged(text, fetch)
        case .reachedEnd:
            loadMore(fetch) { [weak self] error in
                self?.setEffect { .showError(error.localizedDescription) }
            }
        case let .selected(location):
            Pantrix.trackInteraction(.click, attributes: ["target": "location_row", "id": location.id])
            Pantrix.track("location_opened", attributes: ["id": location.id, "name": location.name])
            setEffect { .navigate(.locationDetail(location)) }
        }
    }

    private func fetch(_ nextURL: String?) async throws -> Page<Location> {
        try await getLocations(filter: LocationFilter(name: state.searchTerm), nextURL: nextURL)
    }
}

// MARK: - List

struct LocationsView: View {

    @State private var vm = LocationsViewModel()
    @Binding var path: [Route]
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let message = vm.state.message {
                StateMessage(text: message)
            }

            ForEach(vm.state.items) { location in
                Button {
                    vm.onIntent(.selected(location))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.name).font(.headline).lineLimit(1)
                        Text("\(location.type.isEmpty ? "Unknown" : location.type) • \(location.dimension.isEmpty ? "unknown dimension" : location.dimension)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .onAppear {
                    if location.id == vm.state.items.suffix(5).first?.id {
                        vm.onIntent(.reachedEnd)
                    }
                }
            }

            if vm.state.isLoadingMore { LoadingMoreFooter() }
        }
        .listStyle(.plain)
        .overlay { if vm.state.isLoading && vm.state.items.isEmpty { ProgressView() } }
        .navigationTitle("Locations")
        .searchable(text: queryBinding, prompt: "Search locations")
        .refreshable { vm.onIntent(.refresh) }
        .task { vm.onIntent(.appear) }
        .trackScreen("Locations")
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
struct LocationDetailView: View {

    let location: Location
    @Binding var path: [Route]

    var body: some View {
        List {
            Section {
                DetailRow(caption: "Type", value: location.type)
                DetailRow(caption: "Dimension", value: location.dimension)
            }

            Section {
                Button {
                    Pantrix.track("location_residents_opened", attributes: [
                        "id": location.id,
                        "count": location.residentIds.count
                    ])
                    path.append(.charactersByIds(ids: location.residentIds, title: "Residents"))
                } label: {
                    HStack {
                        Text("Residents (\(location.residentIds.count))")
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                }
                .disabled(location.residentIds.isEmpty)
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
