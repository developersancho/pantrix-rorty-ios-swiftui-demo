//
//  DtosTests.swift
//  PantrixRortySwiftUITests
//
//  The DTOs mirror the API exactly, on purpose: a change on the server is meant to show up as a
//  decode failure and not as a wrong value on a screen. These pin both halves of that.
//

import XCTest
@testable import PantrixRortySwiftUI

final class DtosTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testAPageIsReadWithItsCursor() throws {
        let json = """
        {
          "info": {"count": 826, "pages": 42, "next": "https://rickandmortyapi.com/api/location?page=2", "prev": null},
          "results": [
            {"id": 1, "name": "Earth (C-137)", "type": "Planet", "dimension": "Dimension C-137",
             "residents": ["https://rickandmortyapi.com/api/character/38"], "created": "2017-11-10T12:42:04.162Z"}
          ]
        }
        """

        let page = try decode(PageDto<LocationDto>.self, from: json)

        XCTAssertEqual(page.info.count, 826)
        XCTAssertEqual(page.info.pages, 42)
        XCTAssertEqual(page.info.next, "https://rickandmortyapi.com/api/location?page=2")
        XCTAssertNil(page.info.prev)
        XCTAssertEqual(page.results.map(\.name), ["Earth (C-137)"])
        XCTAssertEqual(page.results.first?.residents.count, 1)
    }

    func testTheAirDateOfAnEpisodeComesFromASnakeCaseField() throws {
        let json = """
        {"id": 1, "name": "Pilot", "air_date": "December 2, 2013", "episode": "S01E01", "characters": []}
        """

        let episode = try decode(EpisodeDto.self, from: json)

        XCTAssertEqual(episode.airDate, "December 2, 2013")
        XCTAssertEqual(episode.episode, "S01E01")
    }

    func testAFieldTheServerDropsFailsTheDecode() {
        let withoutDimension = """
        {"id": 1, "name": "Earth (C-137)", "type": "Planet", "residents": []}
        """
        let camelCase = """
        {"id": 1, "name": "Pilot", "airDate": "December 2, 2013", "episode": "S01E01", "characters": []}
        """

        XCTAssertThrowsError(try decode(LocationDto.self, from: withoutDimension))
        XCTAssertThrowsError(try decode(EpisodeDto.self, from: camelCase))
    }
}
