//
//  Profile.swift
//  PantrixRortySwiftUI
//
//  The SDK's user-identity control panel — the whole identity surface in one screen, plus the theme
//  picker and a read-out of what the DI container resolved.
//

import Foundation
import Observation
import Pantrix
import PantrixSwiftUI
import Resolver
import SwiftUI

// MARK: - Contract

enum ProfileContract {
    struct State: MviState {
        /// Mirrors the SDK's user state for display. The SDK persists the user id internally but
        /// exposes no getter, so the screen keeps its own copy in `UserDefaults` to survive relaunch.
        /// `cdId` needs no mirror — `getCdId()` exists.
        var userId: String?
        var note: String?

        var statusLine: String {
            userId.map { "Signed in as \($0)" } ?? "Anonymous (no user set)"
        }
    }

    enum Intent: MviIntent {
        case appear
        case login
        case setProperty
        case setProperties
        case unsetProperty
        case logout
        case setCdId
        case readCdId
        /// Sign in as a typed id rather than the built-in demo one.
        case submitUserId(String)
        /// Set `favorite_show` to a typed value rather than the built-in one.
        case submitFavoriteShow(String)
    }

    enum Effect: MviEffect {}
}

// MARK: - View model

@MainActor
final class ProfileViewModel: MviViewModel<
    ProfileContract.State,
    ProfileContract.Intent,
    ProfileContract.Effect
> {
    @ObservationIgnored @Injected private var environment: AppEnvironment

    private static let userKey = "demo_user_id"
    private static let demoUserId = "demo-user-42"
    private static let demoCdId = "rorty-device-7"

    /// Exposed for the environment read-out — the DI smoke test.
    var apiBaseURL: String { environment.apiBaseURL.absoluteString }
    var pantrixBackendURL: String { environment.pantrixBackendURL.absoluteString }

    init() { super.init(initialState: .init()) }

    override func onHandleIntent(_ intent: ProfileContract.Intent) {
        switch intent {
        case .appear:
            setState { $0.userId = UserDefaults.standard.string(forKey: Self.userKey) }

        case .login:
            Pantrix.setUser(
                userId: Self.demoUserId,
                properties: ["plan": "pro", "role": "qa", "app": "rorty-swiftui"]
            )
            UserDefaults.standard.set(Self.demoUserId, forKey: Self.userKey)
            Pantrix.track("profile_login", attributes: ["userId": Self.demoUserId])
            setState {
                $0.userId = Self.demoUserId
                $0.note = "Logged in — subsequent events carry this user id."
            }

        case .setProperty:
            Pantrix.setUserProperty(key: "favorite_show", value: "Rick and Morty")
            Pantrix.track("profile_property_set", attributes: ["key": "favorite_show"])
            setState { $0.note = "Set favorite_show = Rick and Morty" }

        case .setProperties:
            Pantrix.setUserProperties(["region": "eu", "tier": "beta"])
            Pantrix.track("profile_properties_set", attributes: ["count": 2])
            setState { $0.note = "Set region = eu, tier = beta" }

        case .unsetProperty:
            Pantrix.removeUserProperty(key: "favorite_show")
            Pantrix.track("profile_property_removed", attributes: ["key": "favorite_show"])
            setState { $0.note = "Removed favorite_show" }

        case .logout:
            Pantrix.clearUser()
            UserDefaults.standard.removeObject(forKey: Self.userKey)
            Pantrix.track("profile_logout")
            // Deliberately does NOT clear the custom device id: it identifies the device, not the
            // person, and survives a log-out on both platforms.
            setState {
                $0.userId = nil
                $0.note = "Logged out — user cleared. The custom device id is untouched."
            }

        case .setCdId:
            Pantrix.setCdId(cdId: Self.demoCdId)
            Pantrix.track("profile_cd_id_set")
            setState { $0.note = "cdId set — later events carry it." }

        case .readCdId:
            setState { $0.note = "getCdId() → \(Pantrix.getCdId() ?? "nil")" }

        case let .submitUserId(raw):
            let userId = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !userId.isEmpty else {
                setState { $0.note = "Type an id first — an empty one would not identify anybody." }
                return
            }
            Pantrix.setUser(userId: userId, properties: ["source": "typed"])
            UserDefaults.standard.set(userId, forKey: Self.userKey)
            Pantrix.track("profile_login", attributes: ["userId": userId, "source": "typed"])
            setState {
                $0.userId = userId
                $0.note = "Signed in as the id you typed."
            }

        case let .submitFavoriteShow(raw):
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                setState { $0.note = "Type a value first — use Unset to remove the key instead." }
                return
            }
            Pantrix.setUserProperty(key: "favorite_show", value: value)
            Pantrix.track("profile_property_set", attributes: ["key": "favorite_show", "source": "typed"])
            setState { $0.note = "Set favorite_show = \(value)" }
        }
    }
}

// MARK: - View

struct ProfileView: View {

    @State private var vm = ProfileViewModel()
    // The theme is app-wide chrome, not this screen's state, so it stays out of the MVI contract and
    // the view talks to the manager directly.
    private var theme = ThemeManager.shared

    // Draft text, not state: what is half-typed in a field is the field's business until submitted.
    // Putting it in `State` would push a mutation through the reducer on every keystroke.
    @State private var userIdDraft = ""
    @State private var favoriteShowDraft = ""
    @FocusState private var favoriteShowFocused: Bool

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.state.statusLine).font(.headline)
                    if let note = vm.state.note {
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Identity") {
                row("Log in as demo user", "setUser(\"demo-user-42\", properties)", "person.fill.checkmark") {
                    vm.onIntent(.login)
                }
                row("Set a user property", "setUserProperty(\"favorite_show\", …)", "tag.fill") {
                    vm.onIntent(.setProperty)
                }
                row("Set several properties", "setUserProperties(…) — one call, many keys", "tag.circle.fill") {
                    vm.onIntent(.setProperties)
                }
                row("Unset a property", "removeUserProperty(key: \"favorite_show\")", "tag.slash.fill") {
                    vm.onIntent(.unsetProperty)
                }
                row("Log out", "clearUser()", "person.fill.xmark", destructive: true) {
                    vm.onIntent(.logout)
                }
            }

            Section {
                // `onEditingChanged:` is a `TextField` parameter, so the tracking wraps the handler
                // instead of the view — that is why this one is a plain function, not a modifier.
                // It is also the ONLY focus signal that reaches iOS 13, which is the package floor.
                TextField(
                    "Sign in as…",
                    text: $userIdDraft,
                    onEditingChanged: trackedEditingChanged("profile_user_id_field")
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { vm.onIntent(.submitUserId(userIdDraft)) }

                // The same signal by the other road: you already hold the focus flag, so hand it over.
                // Deliberately NOT combined with `trackedEditingChanged` on one field — both emit
                // `ui_focus` on the same edge, so a field carrying both would count every focus twice.
                TextField("favorite_show value…", text: $favoriteShowDraft)
                    .focused($favoriteShowFocused)
                    .trackFocus("profile_favorite_show_field", isFocused: favoriteShowFocused)
                    .onSubmit { vm.onIntent(.submitFavoriteShow(favoriteShowDraft)) }
            } header: {
                Text("Type it instead")
            } footer: {
                Text("Return to apply. The two fields report focus by different routes — `trackedEditingChanged` wraps the field's own callback (iOS 13+), `trackFocus` reads a `@FocusState` you already own (iOS 15+). Both emit `ui_focus`.")
            }

            Section {
                row("Set a custom device id", "setCdId(\"rorty-device-7\") — rides on every later event", "iphone.badge.play") {
                    vm.onIntent(.setCdId)
                }
                row("Read it back", "getCdId() — nil before anything set one", "arrow.down.doc") {
                    vm.onIntent(.readCdId)
                }
            } header: {
                Text("Custom device id")
            } footer: {
                Text("The host app's own device identity, stamped onto every event as `cdId`. Independent of the user — logging out leaves it in place.")
            }

            Section("Appearance — theme") {
                ForEach(RortyTheme.all) { item in
                    Button {
                        theme.select(item)
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(item.swatch).frame(width: 22, height: 22)
                            // `Color.primary`, not `.primary`: the hierarchical styles resolve
                            // against the *current foreground style*, and a Button tints its label —
                            // so `.primary` inside one comes out as the accent colour, not the label
                            // colour. Every row rendered green until this was concrete.
                            Text(item.name).foregroundStyle(Color.primary)
                            Spacer()
                            if item == theme.current {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API: \(vm.apiBaseURL)")
                    Text("Pantrix: \(vm.pantrixBackendURL)")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            } header: {
                Text("Environment (resolved via Resolver DI)")
            }
        }
        .navigationTitle("Profile")
        .task { vm.onIntent(.appear) }
        .trackScreen("Profile")
    }

    private func row(
        _ title: String,
        _ subtitle: String,
        _ systemImage: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(destructive ? Color.red : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(destructive ? Color.red : Color.primary)
                    // `Color.secondary`, not `.secondary` — see the theme rows below for why.
                    Text(subtitle).font(.caption).foregroundStyle(Color.secondary)
                }
            }
        }
    }
}
