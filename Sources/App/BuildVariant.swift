//
//  BuildVariant.swift
//  PantrixRortySwiftUI
//
//  Build-variant environment, resolved at COMPILE time from the active configuration's
//  `SWIFT_ACTIVE_COMPILATION_CONDITIONS` (Debug→DEBUG, QaTest→QATEST, Release→neither).
//
//  Each variant installs under its OWN bundle id and is its OWN Pantrix project. The ingest gate
//  compares the incoming `build.appId` against the project's recorded `app_id` with EXACT equality,
//  so a token from the wrong project does not half-work — the whole batch is rejected with
//  APP_ID_MISMATCH and nothing arrives:
//
//      variant   bundle id                                  Pantrix project
//      debug     com.pantrix.demo.rorty.swiftui.debug       Rorty SwiftUI Dev
//      qaTest    com.pantrix.demo.rorty.swiftui.qatest      Rorty SwiftUI Test
//      release   com.pantrix.demo.rorty.swiftui             Rorty SwiftUI
//
//  The ingest tokens below are committed on purpose: an SDK key ships inside the app and is
//  extractable from any build, so the backend treats it as public. The CI keys — which upload dSYMs
//  and must stay secret — live in the gitignored `.pantrixrc*` files and never appear in code.
//

import Foundation

enum BuildVariant {
    case debug
    case qaTest
    case release

    /// The variant this binary was built as.
    static var current: BuildVariant {
        #if DEBUG
        return .debug
        #elseif QATEST
        return .qaTest
        #else
        return .release
        #endif
    }

    var isRelease: Bool { self == .release }

    /// Backend base URL — the ORIGIN, not an API path: the SDK appends `/api/v1/sdk/events` and
    /// `/api/v1/sdk/config` itself.
    ///
    /// **Real-device override:** `localhost` only works on the Simulator (which shares the Mac's
    /// loopback). On a physical device set `PANTRIX_BACKEND_URL` to the Mac's LAN IP in the scheme's
    /// Run → Environment Variables. Scheme env is a *runtime* override, so it does not reach an
    /// `.xcarchive` — bake the URL for that.
    var backendURL: String {
        if let override = ProcessInfo.processInfo.environment["PANTRIX_BACKEND_URL"], !override.isEmpty {
            return override
        }
        if isRelease {
            return "https://api.pantrixapp.com"
        } else {
            return "http://localhost:8099"
        }
    }

    /// SDK ingest token for this variant's Pantrix project. Must match the variant's bundle id.
    var ingestToken: String {
        switch self {
        case .debug: return "px_tpvqhf3i6niecswvds8i5fpaxy9ykchqpw53"
        case .qaTest: return "px_6if8hdp5rua698akfoqzxjunnsoiyufaz64l"
        case .release: return "px_l2r2eu3kux8nwuq0i4gj0palf798d1t23f9x"
        }
    }

    /// Verbose SDK logging is for development only — in release it is noise the user pays for.
    var enableSdkLogging: Bool { !isRelease }

    /// `http://` needs the insecure-connection opt-in; a real production backend would be HTTPS.
    /// This is only half the job — the Info.plist ATS exception is the other half, and they fail in
    /// different places if you only do one.
    var allowInsecureConnection: Bool { backendURL.hasPrefix("http://") }

    var displayName: String {
        switch self {
        case .debug: return "DEBUG"
        case .qaTest: return "QA_TEST"
        case .release: return "RELEASE"
        }
    }
}
