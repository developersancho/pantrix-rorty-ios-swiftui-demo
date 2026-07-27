//
//  Episode.swift
//  PantrixRortySwiftUI
//

import Foundation

struct Episode: Identifiable, Hashable {
    let id: Int
    let name: String
    let airDate: String
    /// Season/episode code, e.g. `S01E01`.
    let code: String
    /// Ids of the characters appearing in this episode.
    let characterIds: [Int]
}
