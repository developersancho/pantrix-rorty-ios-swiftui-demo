//
//  PantrixRortySwiftUIApp.swift
//  PantrixRortySwiftUI
//
//  From-scratch SwiftUI demo for the published Pantrix iOS SDK, driven by the Rick & Morty REST API.
//  Sibling of the UIKit demo; deliberately different in the three ways that matter to the SDK —
//  100% SwiftUI, MVI + layered architecture, and URLSession instead of Alamofire.
//

import Pantrix
import PantrixCrash
import Resolver
import SwiftUI

// The two debug tools swap to their inert no-op twins on Release: PANTRIX_INSPECTOR /
// PANTRIX_FEEDBACK are defined only on Debug + QaTest (see project.yml), so a Release build compiles
// against PantrixInspectorNoop / PantrixFeedbackNoop. The call sites are identical against either.
#if PANTRIX_INSPECTOR
import PantrixInspector
#else
import PantrixInspectorNoop
#endif
#if PANTRIX_FEEDBACK
import PantrixFeedback
#else
import PantrixFeedbackNoop
#endif

@main
struct PantrixRortySwiftUIApp: App {

    init() {
        Resolver.registerAllServices()
        Self.startPantrix()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }

    private static func startPantrix() {
        let variant = BuildVariant.current

        // As early as possible: autoStart defaults to true, so collection begins immediately.
        //
        // Note what does NOT happen in a pure-SwiftUI app: the SDK's automatic screen tracking sees
        // only UIViewControllers, and the single `UIHostingController` behind this whole app is not
        // treated as a container — so left alone it would report one screen called
        // "UIHostingController<RootTabView>" for everything. Every screen here is therefore named
        // explicitly with `.trackScreen(_:)`, and pushes are reported by `.trackNavigation(path:)`.
        Pantrix.initialize(with: PantrixConfig(
            token: variant.ingestToken,
            url: variant.backendURL
        ) { config in
            config.enableLogging = variant.enableSdkLogging
            config.allowInsecureConnection = variant.allowInsecureConnection
            config.trackHttpHeaders = true
            config.trackHttpBody = true
            // 0 = unlimited on both. The dev variants keep everything so the Inspector has something
            // to show; release prunes.
            config.retentionDays = variant.isRelease ? 30 : 0
            config.maxStoredEvents = variant.isRelease ? 50_000 : 0
            // Off would delete events right after upload — and the Inspector reads that same store,
            // which is what makes events look like they are "disappearing" from it.
            config.keepSentEvents = !variant.isRelease
            // On — and that makes everything above a REQUEST, not a decision.
            //
            // Remote config is a **full override**: whatever `/api/v1/sdk/config` returns replaces
            // these values on the next launch. A project with no SDK Config row gets the backend's
            // baseline, which has `trackHttpBody = false` and `keepSentEvents = false` — so a brand
            // new project silently turns body capture off (the Lab's response-body row records
            // nothing) and deletes events after upload (the Inspector looks empty).
            //
            // Measured on this demo's own project: with this flag off the manual `trackHttp` carried
            // 2719 bytes; with it on, the field never arrived at all.
            //
            // Set it to `false` to make the local config authoritative. It is left on because it is a
            // real SDK feature, and switching it off to make the demo look better would hide how the
            // SDK actually behaves.
            config.enableRemoteConfig = true
        })

        PantrixCrash.enable()

        var inspectorConfig = InspectorConfiguration()
        inspectorConfig.enablesShakeToOpen = true
        PantrixInspector.enable(inspectorConfig)

        PantrixFeedback.enable()
    }
}
