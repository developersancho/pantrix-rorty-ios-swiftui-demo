//
//  Dtos.swift
//  PantrixRortySwiftUI
//
//  The wire shapes. These mirror the API exactly — including the parts the app does not use — so a
//  server change shows up here as a decode failure rather than as a wrong value on a screen.
//

import Foundation

struct PageDto<T: Decodable>: Decodable {
    let info: InfoDto
    let results: [T]
}

struct InfoDto: Decodable {
    let count: Int
    let pages: Int
    /// Absolute URL of the next page, or nil on the last one.
    let next: String?
    let prev: String?
}

/// `{ "name": …, "url": … }` — the API's inline reference to another resource.
struct ResourceRefDto: Decodable {
    let name: String
    let url: String
}

struct CharacterDto: Decodable {
    let id: Int
    let name: String
    let status: String
    let species: String
    let type: String
    let gender: String
    let origin: ResourceRefDto
    let location: ResourceRefDto
    let image: String
    /// Resource URLs, not ids — `["https://…/episode/1", …]`.
    let episode: [String]
}

struct LocationDto: Decodable {
    let id: Int
    let name: String
    let type: String
    let dimension: String
    let residents: [String]
}

struct EpisodeDto: Decodable {
    let id: Int
    let name: String
    let airDate: String
    let episode: String
    let characters: [String]

    private enum CodingKeys: String, CodingKey {
        case id, name, episode, characters
        case airDate = "air_date"
    }
}
