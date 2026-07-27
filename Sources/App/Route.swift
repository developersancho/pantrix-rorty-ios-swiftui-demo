//
//  Route.swift
//  PantrixRortySwiftUI
//

import Foundation
import PantrixSwiftUI

/// Every push destination in the app, as one closed set.
///
/// The path must be a **typed array** (`[Route]`), not `NavigationPath`: `trackNavigation(path:)`
/// can only read a collection whose elements it can see, and a type-erased `NavigationPath` exposes
/// nothing but its `count`.
/// Detail routes carry the whole entity rather than an id. The list already has it, so re-fetching
/// would be a request for data in hand — the UIKit demo passes the object for the same reason. The
/// by-ids routes carry ids because that IS the query.
enum Route: Hashable {
    case characterDetail(Character)
    case locationDetail(Location)
    case episodeDetail(Episode)
    case charactersByIds(ids: [Int], title: String)
    case episodesByIds(ids: [Int], title: String)
    case crashLab
}

/// Names each destination for the SDK.
///
/// **Never derive the name from an associated value.** The ids and titles carried above identify
/// real records; a screen name travels to the backend and is displayed, so leaking one would put a
/// record id into analytics. The SDK is explicit about this too — it never reflects over associated
/// values, which is exactly why this protocol exists.
extension Route: PantrixScreenNameProviding {
    var pantrixScreenName: String {
        switch self {
        case .characterDetail: return "CharacterDetail"
        case .locationDetail: return "LocationDetail"
        case .episodeDetail: return "EpisodeDetail"
        case .charactersByIds: return "CharactersByIds"
        case .episodesByIds: return "EpisodesByIds"
        case .crashLab: return "CrashLab"
        }
    }
}
