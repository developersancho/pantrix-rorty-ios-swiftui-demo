//
//  Faz1Probe.swift
//  PantrixRortySwiftUI
//
//  Faz 1 scaffolding — the first real exercise of the MVI base and the whole Data→Domain chain,
//  before any list screen exists. Replaced by the real Lab in Faz 5.
//
//  It deliberately includes a **failing** request: the URLSession path reports failures (reason,
//  description, no status), while the Alamofire monitor in the UIKit demo drops them entirely
//  because it needs a response to build an event. That difference is one of the two reasons this
//  demo exists, and it should be visible from the first phase.
//

import Observation
import Resolver
import SwiftUI

// MARK: - Contract

enum ProbeContract {
    struct State: MviState {
        var lines: [String] = []
        var isLoading = false
    }

    enum Intent: MviIntent {
        case fetchPage
        case fetchByIds
        case fetchFailing
        case clear
    }

    enum Effect: MviEffect {
        case showError(String)
    }
}

// MARK: - View model

@MainActor
final class ProbeViewModel: MviViewModel<ProbeContract.State, ProbeContract.Intent, ProbeContract.Effect> {

    // Collaborators, not state — hence @ObservationIgnored. A stored property on a subclass is not
    // observed by SwiftUI (see MviViewModel), so anything the view reads must live in State.
    @ObservationIgnored @Injected private var characters: GetCharactersUseCase
    @ObservationIgnored @Injected private var episodesByIds: GetEpisodesByIdsUseCase
    @ObservationIgnored @Injected private var client: RickMortyClient

    init() { super.init(initialState: .init()) }

    override func onHandleIntent(_ intent: ProbeContract.Intent) {
        switch intent {
        case .fetchPage:
            sendRequest(
                onLoading: { [weak self] loading in self?.setState { $0.isLoading = loading } },
                onError: { [weak self] error in self?.log("page FAILED — \(error.localizedDescription)") },
                request: { [characters] in try await characters(filter: .none, nextURL: nil) },
                onSuccess: { [weak self] page in
                    self?.log("page ok — \(page.items.count) of \(page.total), next: \(page.nextURL != nil ? "yes" : "no")")
                    if let first = page.items.first {
                        self?.log("  first: \(first.name) · \(first.status.display) · \(first.episodeIds.count) episodes")
                    }
                }
            )

        case .fetchByIds:
            sendRequest(
                onLoading: { [weak self] loading in self?.setState { $0.isLoading = loading } },
                onError: { [weak self] error in self?.log("byIds FAILED — \(error.localizedDescription)") },
                // 1 id and 2+ ids take different endpoint shapes; both are exercised.
                request: { [episodesByIds] in
                    let one = try await episodesByIds([1])
                    let many = try await episodesByIds([1, 2, 3])
                    return (one.count, many.count)
                },
                onSuccess: { [weak self] counts in
                    self?.log("byIds ok — single: \(counts.0), batch: \(counts.1)")
                }
            )

        case .fetchFailing:
            sendRequest(
                onLoading: { [weak self] loading in self?.setState { $0.isLoading = loading } },
                onError: { [weak self] error in
                    // Expected. The point is what the SDK recorded, not what we show.
                    self?.log("failing ok — errored as designed: \(error.localizedDescription)")
                },
                request: { [client] in
                    let _: PageDto<CharacterDto> = try await client.page(absolute: "https://rickandmortyapi.invalid/api/character")
                },
                onSuccess: { [weak self] _ in self?.log("failing UNEXPECTEDLY succeeded") }
            )

        case .clear:
            setState { $0.lines = [] }
        }
    }

    private func log(_ line: String) {
        setState { $0.lines.insert(line, at: 0) }
    }
}

// MARK: - View

struct Faz1ProbeView: View {
    @State private var vm = ProbeViewModel()
    @State private var alert: String?

    var body: some View {
        List {
            Section("Faz 1 — Data + Domain") {
                row("Fetch first page", "GetCharactersUseCase → URLSession") { vm.onIntent(.fetchPage) }
                row("Fetch by ids", "single-id and batch endpoints") { vm.onIntent(.fetchByIds) }
                row("Fetch a failing URL", "URLSession reports it; Alamofire would drop it") { vm.onIntent(.fetchFailing) }
                row("Clear log", "") { vm.onIntent(.clear) }
            }

            Section {
                if vm.state.lines.isEmpty {
                    Text("Tap an action — results appear here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(vm.state.lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.caption, design: .monospaced))
                    }
                }
            } header: {
                HStack {
                    Text("Activity")
                    if vm.state.isLoading { ProgressView().controlSize(.mini) }
                }
            }
        }
        .navigationTitle("Lab")
        .trackScreen("Lab")
        .onReceive(vm.effect) { effect in
            if case let .showError(message) = effect { alert = message }
        }
        .alert("Error", isPresented: .constant(alert != nil)) {
            Button("OK") { alert = nil }
        } message: {
            Text(alert ?? "")
        }
    }

    private func row(_ title: String, _ subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                // Concrete colours: a Button tints its label, and the hierarchical `.primary` /
                // `.secondary` resolve against that tint rather than the label colour.
                Text(title).foregroundStyle(Color.primary)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(Color.secondary)
                }
            }
        }
    }
}
