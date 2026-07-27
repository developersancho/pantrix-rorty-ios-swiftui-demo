//
//  CharactersContract.swift
//  PantrixRortySwiftUI
//

import Foundation

/// The Characters list, as one closed description of what the screen can show and what can happen
/// to it. Mirrors the admin panel's `sealed interface XContract`.
enum CharactersContract {

    struct State: MviState {
        var items: [Character] = []

        /// The live text field value. Kept in state (not `@State` in the view) because the debounce
        /// and the filter tracking both read it — two sources of truth for one string is how the
        /// query and the results drift apart.
        var query = ""
        var status: CharacterStatus?

        /// First load or a filter change — the whole list is replaced, so the view shows a spinner
        /// instead of rows.
        var isLoading = false
        /// Appending a page — rows stay, a footer spinner appears.
        var isLoadingMore = false

        /// Full-screen message for "no results" / "couldn't load". Non-nil only when `items` is
        /// empty: a failed *next* page must not blank out rows the user is already reading.
        var message: String?

        /// Absolute URL of the next page, or nil when there are none left.
        var nextURL: String?

        var total = 0

        var canLoadMore: Bool { nextURL != nil && !isLoading && !isLoadingMore }
    }

    enum Intent: MviIntent {
        case appear
        case refresh
        case queryChanged(String)
        case statusSelected(CharacterStatus?)
        /// The list scrolled close enough to the end to fetch the next page.
        case reachedEnd
        case selected(Character)
    }

    enum Effect: MviEffect {
        case navigate(Route)
        case showError(String)
    }
}
