//
//  RepositoryImpls.swift
//  PantrixRortySwiftUI
//
//  The Domain protocols, implemented over `RickMortyClient`.
//
//  404 is handled here rather than surfaced: this API answers a filter that matches nothing with
//  404, so translating it into an empty page is the correct reading — a "no results" list, not an
//  error banner. Every other failure propagates.
//

import Foundation

final class CharacterRepositoryImpl: CharacterRepository {
    private let client: RickMortyClient
    init(client: RickMortyClient) { self.client = client }

    func page(filter: CharacterFilter) async throws -> Page<Character> {
        try await emptyOn404 {
            let dto: PageDto<CharacterDto> = try await client.page(
                "character",
                query: ["name": filter.name, "status": filter.status?.queryValue]
            )
            return dto.toDomain { $0.toDomain() }
        }
    }

    func page(url: String) async throws -> Page<Character> {
        try await emptyOn404 {
            let dto: PageDto<CharacterDto> = try await client.page(absolute: url)
            return dto.toDomain { $0.toDomain() }
        }
    }

    func byIds(_ ids: [Int]) async throws -> [Character] {
        let dtos: [CharacterDto] = try await client.byIds("character", ids: ids)
        return dtos.map { $0.toDomain() }
    }
}

final class LocationRepositoryImpl: LocationRepository {
    private let client: RickMortyClient
    init(client: RickMortyClient) { self.client = client }

    func page(filter: LocationFilter) async throws -> Page<Location> {
        try await emptyOn404 {
            let dto: PageDto<LocationDto> = try await client.page("location", query: ["name": filter.name])
            return dto.toDomain { $0.toDomain() }
        }
    }

    func page(url: String) async throws -> Page<Location> {
        try await emptyOn404 {
            let dto: PageDto<LocationDto> = try await client.page(absolute: url)
            return dto.toDomain { $0.toDomain() }
        }
    }

    func byIds(_ ids: [Int]) async throws -> [Location] {
        let dtos: [LocationDto] = try await client.byIds("location", ids: ids)
        return dtos.map { $0.toDomain() }
    }
}

final class EpisodeRepositoryImpl: EpisodeRepository {
    private let client: RickMortyClient
    init(client: RickMortyClient) { self.client = client }

    func page(filter: EpisodeFilter) async throws -> Page<Episode> {
        try await emptyOn404 {
            let dto: PageDto<EpisodeDto> = try await client.page("episode", query: ["name": filter.name])
            return dto.toDomain { $0.toDomain() }
        }
    }

    func page(url: String) async throws -> Page<Episode> {
        try await emptyOn404 {
            let dto: PageDto<EpisodeDto> = try await client.page(absolute: url)
            return dto.toDomain { $0.toDomain() }
        }
    }

    func byIds(_ ids: [Int]) async throws -> [Episode] {
        let dtos: [EpisodeDto] = try await client.byIds("episode", ids: ids)
        return dtos.map { $0.toDomain() }
    }
}

/// Turns this API's "nothing matched" 404 into an empty page.
private func emptyOn404<Item: Hashable>(_ body: () async throws -> Page<Item>) async throws -> Page<Item> {
    do {
        return try await body()
    } catch let error as ClientError where error.isNotFound {
        return .empty
    }
}
