//
//  UseCases.swift
//  PantrixRortySwiftUI
//
//  One use case per meaningful operation, callable as a function.
//
//  These are not pass-throughs: each one owns the decision a view model would otherwise have to make
//  — "first page or next page?" — which is exactly the rule that gets copied wrong when three list
//  screens each implement it. The repository stays dumb about pagination flow; the use case owns it.
//

import Foundation

// MARK: - Lists

struct GetCharactersUseCase: Sendable {
    private let repository: CharacterRepository
    init(repository: CharacterRepository) { self.repository = repository }

    /// `nextURL == nil` means "start over with this filter"; otherwise the filter is already baked
    /// into the URL the API gave us and re-applying it would be wrong.
    func callAsFunction(filter: CharacterFilter, nextURL: String?) async throws -> Page<Character> {
        if let nextURL { return try await repository.page(url: nextURL) }
        return try await repository.page(filter: filter)
    }
}

struct GetLocationsUseCase: Sendable {
    private let repository: LocationRepository
    init(repository: LocationRepository) { self.repository = repository }

    func callAsFunction(filter: LocationFilter, nextURL: String?) async throws -> Page<Location> {
        if let nextURL { return try await repository.page(url: nextURL) }
        return try await repository.page(filter: filter)
    }
}

struct GetEpisodesUseCase: Sendable {
    private let repository: EpisodeRepository
    init(repository: EpisodeRepository) { self.repository = repository }

    func callAsFunction(filter: EpisodeFilter, nextURL: String?) async throws -> Page<Episode> {
        if let nextURL { return try await repository.page(url: nextURL) }
        return try await repository.page(filter: filter)
    }
}

// MARK: - Cross-navigation batches

struct GetCharactersByIdsUseCase: Sendable {
    private let repository: CharacterRepository
    init(repository: CharacterRepository) { self.repository = repository }

    func callAsFunction(_ ids: [Int]) async throws -> [Character] {
        guard !ids.isEmpty else { return [] }
        return try await repository.byIds(ids)
    }
}

struct GetEpisodesByIdsUseCase: Sendable {
    private let repository: EpisodeRepository
    init(repository: EpisodeRepository) { self.repository = repository }

    func callAsFunction(_ ids: [Int]) async throws -> [Episode] {
        guard !ids.isEmpty else { return [] }
        return try await repository.byIds(ids)
    }
}
