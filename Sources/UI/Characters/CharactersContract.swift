//
//  CharactersContract.swift
//  PantrixRortySwiftUI
//

import Foundation

/// The Characters list, as one closed description of what the screen can show and what can happen
/// to it. Mirrors the admin panel's `sealed interface XContract`.
enum CharactersContract {

    struct State: PagedListState {
        // The paged-list slice. Every list screen has these; the base drives them.
        var items: [Character] = []
        var query = ""
        var isLoading = false
        var isLoadingMore = false
        var message: String?
        var nextURL: String?
        var total = 0

        /// This screen's own filter — the one thing Characters has that the other two lists do not.
        var status: CharacterStatus?
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
