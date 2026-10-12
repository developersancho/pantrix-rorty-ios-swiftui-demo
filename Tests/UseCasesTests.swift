//
//  UseCasesTests.swift
//  PantrixRortySwiftUITests
//
//  The use cases own one decision each: the first page or the next one, and whether a batch is worth
//  a request at all. That decision is what three list screens would otherwise each copy.
//

import XCTest
@testable import PantrixRortySwiftUI

final class UseCasesTests: XCTestCase {
    private let repository = RecordingRepository()
    private let nextURL = "https://rickandmortyapi.com/api/character?page=2&name=rick"

    func testAListStartsOverWithItsFilterWhenThereIsNoCursor() async throws {
        let filter = CharacterFilter(name: "rick", status: .alive)

        let page = try await GetCharactersUseCase(repository: repository)(filter: filter, nextURL: nil)

        XCTAssertEqual(repository.asked, ["page(filter: rick, alive)"])
        XCTAssertEqual(page.total, 1)
    }

    func testAListFollowsTheCursorAndLeavesTheFilterAlone() async throws {
        let filter = CharacterFilter(name: "morty", status: nil)

        _ = try await GetCharactersUseCase(repository: repository)(filter: filter, nextURL: nextURL)

        XCTAssertEqual(repository.asked, ["page(url: \(nextURL))"])
    }

    func testAnEmptyBatchAsksNobody() async throws {
        let characters = try await GetCharactersByIdsUseCase(repository: repository)([])

        XCTAssertEqual(characters, [])
        XCTAssertEqual(repository.asked, [])
    }

    func testABatchAsksForItsIds() async throws {
        let characters = try await GetCharactersByIdsUseCase(repository: repository)([1, 2, 3])

        XCTAssertEqual(characters.map(\.id), [1])
        XCTAssertEqual(repository.asked, ["byIds([1, 2, 3])"])
    }
}

/// Answers every question with the same character and remembers what it was asked. The tests ask
/// one thing at a time, so nothing here needs a lock.
private final class RecordingRepository: CharacterRepository, @unchecked Sendable {
    private(set) var asked: [String] = []

    private let rick = Character(
        id: 1,
        name: "Rick Sanchez",
        status: .alive,
        species: "Human",
        type: "",
        gender: .male,
        originName: "Earth (C-137)",
        locationName: "Citadel of Ricks",
        imageURL: nil,
        episodeIds: [1]
    )

    func page(filter: CharacterFilter) async throws -> Page<Character> {
        asked.append("page(filter: \(filter.name ?? "-"), \(filter.status?.rawValue ?? "-"))")
        return Page(items: [rick], nextURL: nil, total: 1)
    }

    func page(url: String) async throws -> Page<Character> {
        asked.append("page(url: \(url))")
        return Page(items: [rick], nextURL: nil, total: 1)
    }

    func byIds(_ ids: [Int]) async throws -> [Character] {
        asked.append("byIds(\(ids))")
        return [rick]
    }
}
