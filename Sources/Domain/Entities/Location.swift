//
//  Location.swift
//  PantrixRortySwiftUI
//

import Foundation

struct Location: Identifiable, Hashable {
    let id: Int
    let name: String
    /// Often empty on this API — render as `—`.
    let type: String
    let dimension: String
    /// Ids of the characters last seen here.
    let residentIds: [Int]
}
