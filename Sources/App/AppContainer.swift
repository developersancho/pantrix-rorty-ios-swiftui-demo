//
//  AppContainer.swift
//  PantrixRortySwiftUI
//

import Resolver

/// Dependency-injection registrations. `registerAllServices()` is Resolver's well-known bootstrap
/// entry point; the `App` initialiser calls it once, before the SDK starts.
///
/// This is the ONLY place that knows the `Data` layer exists. `UI` talks to `Domain` protocols and
/// use cases; it cannot reach a `URLSession` or a DTO even by accident, because the dependency only
/// points one way.
///
/// Views use `@Injected` inside their view models, never `@InjectedObject` — that wrapper requires
/// `ObservableObject`, and these view models are `@Observable` (iOS 17).
// `@retroactive`: we knowingly conform an imported type (Resolver) to an imported protocol
// (ResolverRegistering) — the intended, documented Resolver bootstrap pattern.
extension Resolver: @retroactive ResolverRegistering {
    public static func registerAllServices() {
        // Application-scoped: one instance for the whole process lifetime.
        register { AppEnvironment.live }.scope(.application)

        // Data-layer registrations land here in Faz 1.
    }
}
