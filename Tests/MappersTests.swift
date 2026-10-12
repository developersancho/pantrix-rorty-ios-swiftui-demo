//
//  MappersTests.swift
//  PantrixRortySwiftUITests
//
//  The mappers are the only code that knows both the wire shape and the entities, so a field that
//  ends up in the wrong place is caught here or nowhere.
//

import XCTest
@testable import PantrixRortySwiftUI

final class MappersTests: XCTestCase {
    private let api = "https://rickandmortyapi.com/api"

    private func character(status: String = "Alive", gender: String = "Male", episode: [String] = []) -> CharacterDto {
        CharacterDto(
            id: 1,
            name: "Rick Sanchez",
            status: status,
            species: "Human",
            type: "",
            gender: gender,
            origin: ResourceRefDto(name: "Earth (C-137)", url: "\(api)/location/1"),
            location: ResourceRefDto(name: "Citadel of Ricks", url: "\(api)/location/3"),
            image: "\(api)/character/avatar/1.jpeg",
            episode: episode
        )
    }

    func testAResourceURLGivesTheIdAtItsEnd() {
        XCTAssertEqual("\(api)/episode/28".resourceId, 28)
        XCTAssertEqual("\(api)/episode/28/".resourceId, 28)
        XCTAssertEqual("7".resourceId, 7)
        XCTAssertNil("\(api)/episode/".resourceId)
        XCTAssertNil("not a url".resourceId)
        XCTAssertNil("".resourceId)
    }

    func testAURLWithoutAnIdIsDroppedAndTheOthersStayInOrder() {
        let urls = ["\(api)/episode/12", "", "\(api)/episode/", "not a url", "\(api)/episode/3"]
        XCTAssertEqual(urls.resourceIds, [12, 3])
        XCTAssertEqual([String]().resourceIds, [])
    }

    func testACharacterKeepsItsFieldsAndTakesItsEpisodeIdsOutOfTheURLs() {
        let dto = character(episode: ["\(api)/episode/1", "\(api)/episode/28"])

        let expected = Character(
            id: 1,
            name: "Rick Sanchez",
            status: .alive,
            species: "Human",
            type: "",
            gender: .male,
            originName: "Earth (C-137)",
            locationName: "Citadel of Ricks",
            imageURL: URL(string: "\(api)/character/avatar/1.jpeg"),
            episodeIds: [1, 28]
        )
        XCTAssertEqual(dto.toDomain(), expected)
    }

    func testAStatusOrAGenderTheAppDoesNotKnowIsUnknownNotALostRecord() {
        XCTAssertEqual(character(status: "Dead").toDomain().status, .dead)
        XCTAssertEqual(character(status: "ALIVE").toDomain().status, .alive)
        XCTAssertEqual(character(status: "Presumed dead").toDomain().status, .unknown)
        XCTAssertEqual(character(status: "").toDomain().status, .unknown)
        XCTAssertEqual(character(gender: "Genderless").toDomain().gender, .genderless)
        XCTAssertEqual(character(gender: "Female").toDomain().gender, .female)
        XCTAssertEqual(character(gender: "n/a").toDomain().gender, .unknown)
    }

    func testALocationTakesTheIdsOfItsResidents() {
        let dto = LocationDto(
            id: 3,
            name: "Citadel of Ricks",
            type: "Space station",
            dimension: "unknown",
            residents: ["\(api)/character/8", "\(api)/character/14"]
        )

        let expected = Location(id: 3, name: "Citadel of Ricks", type: "Space station", dimension: "unknown", residentIds: [8, 14])
        XCTAssertEqual(dto.toDomain(), expected)
    }

    func testAnEpisodeTakesItsCodeFromTheFieldTheAPICallsEpisode() {
        let dto = EpisodeDto(
            id: 28,
            name: "The Ricklantis Mixup",
            airDate: "September 10, 2017",
            episode: "S03E07",
            characters: ["\(api)/character/1", "\(api)/character/2"]
        )

        let expected = Episode(
            id: 28,
            name: "The Ricklantis Mixup",
            airDate: "September 10, 2017",
            code: "S03E07",
            characterIds: [1, 2]
        )
        XCTAssertEqual(dto.toDomain(), expected)
    }

    func testAPageKeepsTheCursorAndTheNumberOfAllMatchesNotOfThisPage() {
        let next = "\(api)/character?page=2&name=rick"
        let dto = PageDto(info: InfoDto(count: 107, pages: 6, next: next, prev: nil), results: [character()])

        let page = dto.toDomain { $0.toDomain() }

        XCTAssertEqual(page.items.map(\.name), ["Rick Sanchez"])
        XCTAssertEqual(page.nextURL, next)
        XCTAssertEqual(page.total, 107)
    }
}
