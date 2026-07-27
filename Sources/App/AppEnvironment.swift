//
//  AppEnvironment.swift
//  PantrixRortySwiftUI
//

import Foundation

/// App-wide configuration handed out through the DI container.
struct AppEnvironment {

    /// Base URL of the Rick & Morty REST API (`/character`, `/location`, `/episode`).
    let apiBaseURL: URL

    /// The Pantrix backend the SDK ships telemetry to.
    let pantrixBackendURL: URL

    /// The Pantrix URL is read from `BuildVariant` rather than restated here: the SDK is initialised
    /// from the variant too, and two independent copies of one URL is how one of them ends up
    /// pointing somewhere else after a change.
    static let live = AppEnvironment(
        apiBaseURL: URL(string: "https://rickandmortyapi.com/api")!,
        pantrixBackendURL: URL(string: BuildVariant.current.backendURL)!
    )
}
