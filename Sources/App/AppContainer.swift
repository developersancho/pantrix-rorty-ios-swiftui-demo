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

        // ONE client, and therefore one instrumented URLSession, for the whole app. Application
        // scope is load-bearing here, not a preference: `Pantrix.instrumentedSession()` builds a
        // delegate-backed session, and URLSession retains its delegate until invalidated — a client
        // per screen would leak one session each.
        register {
            RickMortyClient(baseURL: resolve(AppEnvironment.self).apiBaseURL)
        }.scope(.application)

        // Repositories: the Domain protocol is what everything else asks for, so the implementation
        // (and with it URLSession, JSON and the DTOs) stays invisible above this line.
        register { CharacterRepositoryImpl(client: resolve()) as CharacterRepository }.scope(.application)
        register { LocationRepositoryImpl(client: resolve()) as LocationRepository }.scope(.application)
        register { EpisodeRepositoryImpl(client: resolve()) as EpisodeRepository }.scope(.application)

        // Use cases are value types with no state — a fresh one per resolve costs nothing.
        register { GetCharactersUseCase(repository: resolve()) }
        register { GetLocationsUseCase(repository: resolve()) }
        register { GetEpisodesUseCase(repository: resolve()) }
        register { GetCharactersByIdsUseCase(repository: resolve()) }
        register { GetEpisodesByIdsUseCase(repository: resolve()) }
    }
}
