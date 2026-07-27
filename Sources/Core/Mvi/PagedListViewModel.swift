//
//  PagedListViewModel.swift
//  PantrixRortySwiftUI
//
//  The three list screens (characters, locations, episodes) differ only in which entity they hold
//  and which use case they call. Their *mechanics* — debounced search, a generation guard against
//  out-of-order responses, first-page-vs-next-page, where a failure is allowed to blank the list —
//  are identical and subtle. Three copies of subtle logic is how one of them silently ends up wrong;
//  this session has already found that shape three times in this codebase.
//

import Foundation
import Observation
import Pantrix

/// The slice of state every paged list has. A feature's `State` adds its own fields on top.
protocol PagedListState: MviState {
    associatedtype Item: Hashable & Identifiable

    var items: [Item] { get set }
    var query: String { get set }
    /// First load or a filter change — the whole list is replaced.
    var isLoading: Bool { get set }
    /// Appending a page — rows stay put.
    var isLoadingMore: Bool { get set }
    /// Full-screen message. Only ever set while `items` is empty.
    var message: String? { get set }
    var nextURL: String? { get set }
    var total: Int { get set }
}

extension PagedListState {
    var canLoadMore: Bool { nextURL != nil && !isLoading && !isLoadingMore }
    /// Trimmed search text, or nil — what a filter wants.
    var searchTerm: String? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
class PagedListViewModel<S: PagedListState, I: MviIntent, E: MviEffect>: MviViewModel<S, I, E> {

    /// What the subclass is listing — used for the `page_loaded` event and the empty message.
    private let resourceName: String

    /// Rises on every reload so a slow page resolving after a newer one cannot overwrite it. Typing
    /// "ri" then "ric" issues two requests; without this the "ri" results win if they land last.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var hasAppeared = false

    init(initialState: S, resourceName: String) {
        self.resourceName = resourceName
        super.init(initialState: initialState)
    }

    // MARK: - For subclasses

    /// Loads the first page unless it has already been loaded for this view's lifetime.
    ///
    /// `.task` re-runs whenever SwiftUI re-creates the view — a tab switch does — and reloading
    /// there would throw away the user's scroll position every time they come back.
    func appearOnce(_ fetch: @escaping (String?) async throws -> Page<S.Item>) {
        guard !hasAppeared else { return }
        hasAppeared = true
        reload(fetch)
    }

    /// Search text changed: store it, then reload after a pause.
    ///
    /// 400 ms matches the UIKit demo, so the two apps generate comparable request volume — otherwise
    /// comparing their dashboards would mostly measure the debounce.
    func queryChanged(_ text: String, _ fetch: @escaping (String?) async throws -> Page<S.Item>) {
        guard text != state.query else { return }
        setState { $0.query = text }
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            self.trackFilterChange()
            self.reload(fetch)
        }
    }

    /// Replaces the list. `fetch` receives `nil` — there is no next-page URL for a fresh load.
    func reload(_ fetch: @escaping (String?) async throws -> Page<S.Item>) {
        generation += 1
        let token = generation

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
            request: { try await fetch(nil) },
            onSuccess: { [weak self] page in
                guard let self, token == self.generation else { return }
                self.setState {
                    $0.items = page.items
                    $0.nextURL = page.nextURL
                    $0.total = page.total
                    $0.message = page.items.isEmpty ? "No \(self.resourceName)s." : nil
                }
                self.trackPageLoaded(page.items.count)
            }
        )
    }

    /// Appends the next page. A failure here surfaces as an effect and leaves the rows alone —
    /// replacing a list the user has already scrolled through with an error would lose their place.
    func loadMore(_ fetch: @escaping (String?) async throws -> Page<S.Item>, onFailure: @escaping (Error) -> Void) {
        guard state.canLoadMore, let next = state.nextURL else { return }
        let token = generation

        sendRequest(
            onLoading: { [weak self] loading in
                guard let self, token == self.generation else { return }
                self.setState { $0.isLoadingMore = loading }
            },
            onError: { error in onFailure(error) },
            request: { try await fetch(next) },
            onSuccess: { [weak self] page in
                guard let self, token == self.generation else { return }
                self.setState {
                    $0.items += page.items
                    $0.nextURL = page.nextURL
                }
                self.trackPageLoaded(page.items.count)
            }
        )
    }

    /// Emitted when a filter actually changes — not per keystroke, which is why it lives after the
    /// debounce rather than in `queryChanged`'s first line.
    func trackFilterChange(extra: [String: Any] = [:]) {
        var attributes: [String: Any] = ["name": state.query]
        attributes.merge(extra) { _, new in new }
        Pantrix.track("\(resourceName)_list_filtered", attributes: attributes)
    }

    private func trackPageLoaded(_ count: Int) {
        Pantrix.track("page_loaded", attributes: ["resource": resourceName, "loaded": count])
    }
}
