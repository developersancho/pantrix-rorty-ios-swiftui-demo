//
//  Repositories.swift
//  PantrixRortySwiftUI
//
//  The Domain layer's view of the outside world. `Data` implements these; `UI` never sees anything
//  else. Nothing here mentions URLs, JSON, or URLSession — that is the whole point of the boundary.
//

import Foundation

protocol CharacterRepository: Sendable {
    /// First page for a filter.
    func page(filter: CharacterFilter) async throws -> Page<Character>
    /// A subsequent page, from the absolute URL the previous page returned.
    func page(url: String) async throws -> Page<Character>
    /// Batch fetch — used by the cross-navigation lists ("characters in this episode").
    func byIds(_ ids: [Int]) async throws -> [Character]
}

protocol LocationRepository: Sendable {
    func page(filter: LocationFilter) async throws -> Page<Location>
    func page(url: String) async throws -> Page<Location>
    func byIds(_ ids: [Int]) async throws -> [Location]
}

protocol EpisodeRepository: Sendable {
    func page(filter: EpisodeFilter) async throws -> Page<Episode>
    func page(url: String) async throws -> Page<Episode>
    func byIds(_ ids: [Int]) async throws -> [Episode]
}
