//
//  Page.swift
//  PantrixRortySwiftUI
//

import Foundation

/// One page of a paginated resource.
///
/// `nextURL` is an absolute URL the API hands back, not a page number. Following it verbatim is what
/// keeps the client from having to re-encode the caller's filters on every page — get that wrong and
/// page 2 silently drops the search term.
struct Page<Item: Hashable>: Hashable {
    let items: [Item]
    let nextURL: String?
    let total: Int

    static var empty: Page<Item> { Page(items: [], nextURL: nil, total: 0) }
}

/// Filters the list screens can apply. Only the fields the UI actually sets are modelled — the API
/// supports more (species, type, dimension…), and adding an unused field here would suggest a screen
/// exists for it.
struct CharacterFilter: Equatable {
    var name: String?
    var status: CharacterStatus?

    static let none = CharacterFilter()
}

struct LocationFilter: Equatable {
    var name: String?

    static let none = LocationFilter()
}

struct EpisodeFilter: Equatable {
    var name: String?

    static let none = EpisodeFilter()
}
