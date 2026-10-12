//
//  EntitiesTests.swift
//  PantrixRortySwiftUITests
//

import XCTest
@testable import PantrixRortySwiftUI

final class EntitiesTests: XCTestCase {
    func testEveryStatusHasTheValueTheAPIFiltersByAndAWordForPeople() {
        let values = CharacterStatus.allCases.map { "\($0.queryValue)=\($0.display)" }
        XCTAssertEqual(values, ["alive=Alive", "dead=Dead", "unknown=Unknown"])
    }

    func testEveryGenderHasAWordForPeople() {
        let genders: [CharacterGender] = [.female, .male, .genderless, .unknown]
        XCTAssertEqual(genders.map(\.display), ["Female", "Male", "Genderless", "Unknown"])
    }

    func testAnEmptyPageHasNoCursor() {
        let page = Page<Episode>.empty
        XCTAssertEqual(page.items, [])
        XCTAssertNil(page.nextURL)
        XCTAssertEqual(page.total, 0)
    }

    func testNoFilterIsNoNameAndNoStatus() {
        XCTAssertEqual(CharacterFilter.none, CharacterFilter(name: nil, status: nil))
        XCTAssertEqual(LocationFilter.none, LocationFilter(name: nil))
        XCTAssertEqual(EpisodeFilter.none, EpisodeFilter(name: nil))
    }
}
