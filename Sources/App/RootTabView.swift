//
//  RootTabView.swift
//  PantrixRortySwiftUI
//

import PantrixSwiftUI
import SwiftUI

/// The five tabs, each owning its own navigation stack.
///
/// Per-tab `[Route]` paths rather than one shared path: that is the platform convention (switching
/// tabs preserves each stack), and it is also what the SDK can read — `trackNavigation(path:)`
/// requires a typed array, so one array per stack is the natural unit.
struct RootTabView: View {

    /// Tinting once at the root is the whole theme propagation. The UIKit demo had to set
    /// `window.tintColor` and then rebuild already-built rows by hand, because buttons baked the
    /// colour in at construction; here every descendant re-reads it and recolours on its own.
    private var theme = ThemeManager.shared

    @State private var charactersPath: [Route] = []
    @State private var locationsPath: [Route] = []
    @State private var episodesPath: [Route] = []
    @State private var profilePath: [Route] = []
    @State private var labPath: [Route] = []

    var body: some View {
        TabView {
            stack(path: $charactersPath) {
                CharactersView(path: $charactersPath)
            }
            .tabItem { Label("Characters", systemImage: "person.3.fill") }

            stack(path: $locationsPath) {
                LocationsView(path: $locationsPath)
            }
            .tabItem { Label("Locations", systemImage: "map.fill") }

            stack(path: $episodesPath) {
                EpisodesView(path: $episodesPath)
            }
            .tabItem { Label("Episodes", systemImage: "tv.fill") }

            stack(path: $profilePath) {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }

            stack(path: $labPath) {
                Faz1ProbeView()
            }
            .tabItem { Label("Lab", systemImage: "wrench.and.screwdriver.fill") }
        }
        .tint(theme.current.accent)
    }

    /// One navigation stack, its destination table, and its Pantrix reporting — in one place so the
    /// five tabs cannot drift apart.
    ///
    /// `trackNavigation` reports each pushed destination as a `screen_view`. The root screen is NOT
    /// covered by it (a stack with an empty path has no destination), which is why every root view
    /// carries its own `.trackScreen(_:)` — and why pushed screens must NOT, or each push would be
    /// reported twice.
    @ViewBuilder
    private func stack<Root: View>(
        path: Binding<[Route]>,
        @ViewBuilder root: () -> Root
    ) -> some View {
        NavigationStack(path: path) {
            root()
                .navigationDestination(for: Route.self) { destination($0, path: path) }
        }
        .trackNavigation(path: path.wrappedValue)
    }

    @ViewBuilder
    private func destination(_ route: Route, path: Binding<[Route]>) -> some View {
        switch route {
        case let .characterDetail(character):
            CharacterDetailView(character: character, path: path)
        case let .locationDetail(location):
            LocationDetailView(location: location, path: path)
        case let .episodeDetail(episode):
            EpisodeDetailView(episode: episode, path: path)
        case let .charactersByIds(ids, title):
            CharactersByIdsView(ids: ids, title: title, path: path)
        case let .episodesByIds(ids, title):
            EpisodesByIdsView(ids: ids, title: title, path: path)
        case .crashLab:
            PlaceholderScreen(name: "Crash Lab", systemImage: "ladybug.fill")
        }
    }
}

/// Faz 0 scaffolding — replaced screen by screen from Faz 2 on.
struct PlaceholderScreen: View {
    let name: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text(name).font(.title2.bold())
            Text("Faz 0 — bu ekran henüz kurulmadı.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(name)
        .trackScreen(name)
    }
}
