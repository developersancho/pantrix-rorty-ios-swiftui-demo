//
//  Mappers.swift
//  PantrixRortySwiftUI
//
//  Wire → domain. The only place that knows both shapes.
//

import Foundation

extension String {
    /// The trailing id from a resource URL: `https://…/episode/28` → `28`.
    var resourceId: Int? { Int(split(separator: "/").last ?? "") }
}

extension Array where Element == String {
    /// Resource URLs → ids, silently dropping anything unparseable. A malformed entry costs one
    /// missing row in a cross-navigation list; failing the whole screen for it would be worse.
    var resourceIds: [Int] { compactMap(\.resourceId) }
}

extension CharacterDto {
    func toDomain() -> Character {
        Character(
            id: id,
            name: name,
            // The API is documented as three values but is a plain string on the wire; an
            // unrecognised one means "unknown" rather than a decode failure that loses the record.
            status: CharacterStatus(rawValue: status.lowercased()) ?? .unknown,
            species: species,
            type: type,
            gender: CharacterGender(rawValue: gender.lowercased()) ?? .unknown,
            originName: origin.name,
            locationName: location.name,
            imageURL: URL(string: image),
            episodeIds: episode.resourceIds
        )
    }
}

extension LocationDto {
    func toDomain() -> Location {
        Location(
            id: id,
            name: name,
            type: type,
            dimension: dimension,
            residentIds: residents.resourceIds
        )
    }
}

extension EpisodeDto {
    func toDomain() -> Episode {
        Episode(
            id: id,
            name: name,
            airDate: airDate,
            code: episode,
            characterIds: characters.resourceIds
        )
    }
}

extension PageDto {
    /// Maps a wire page into a domain page. `total` comes from `info.count` — the number of records
    /// matching the filter, not the number on this page.
    func toDomain<Item: Hashable>(_ transform: (T) -> Item) -> Page<Item> {
        Page(items: results.map(transform), nextURL: info.next, total: info.count)
    }
}

// TODO: Goes with the pull request.
/// A trial of Pantrix MQ on a pull request: the pull request is closed, not merged.
func episodeCount(_ value: Any) -> Int {
    value as! Int
}
