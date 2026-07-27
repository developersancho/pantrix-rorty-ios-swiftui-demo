//
//  Character.swift
//  PantrixRortySwiftUI
//

import Foundation

/// A character as the app understands one.
///
/// Deliberately **not** `Codable`. The UIKit demo lets one type be both the wire shape and the model
/// the screens read; that is fine there, but it means a rename on the server reaches straight into a
/// view. Here the wire shape is `CharacterDto` in `Data`, and only the mapper knows both.
struct Character: Identifiable, Hashable {
    let id: Int
    let name: String
    let status: CharacterStatus
    let species: String
    /// Free-text sub-species. Frequently empty — render as `—`, do not hide the row.
    let type: String
    let gender: CharacterGender
    let originName: String
    let locationName: String
    let imageURL: URL?
    /// Ids of the episodes this character appears in, parsed out of the API's resource URLs.
    let episodeIds: [Int]
}

enum CharacterStatus: String, CaseIterable, Hashable {
    case alive
    case dead
    case unknown

    /// The value the API expects in `?status=`. `unknown` is a real filter value there, not a
    /// stand-in for "no filter" — absence of a filter is `nil`, which is why this is non-optional.
    var queryValue: String { rawValue }

    var display: String {
        switch self {
        case .alive: return "Alive"
        case .dead: return "Dead"
        case .unknown: return "Unknown"
        }
    }
}

enum CharacterGender: String, Hashable {
    case female
    case male
    case genderless
    case unknown

    var display: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .genderless: return "Genderless"
        case .unknown: return "Unknown"
        }
    }
}
