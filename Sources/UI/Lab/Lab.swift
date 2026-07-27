//
//  Lab.swift
//  PantrixRortySwiftUI
//
//  One row per SDK surface — each does the smallest real thing that produces an event, so "did it
//  arrive?" can be answered in the dashboard.
//
//  The HTTP section is where this demo differs from the UIKit one. That app uses Alamofire and its
//  `PantrixEventMonitor`; this one uses `Pantrix.instrumentedSession()`, and the three rows below
//  exist to make the trade-off between the two paths visible rather than described.
//

import Foundation
import Observation
import Pantrix
import PantrixSwiftUI
import Resolver
import SwiftUI

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

// MARK: - Contract

enum LabContract {
    struct State: MviState {
        var log: [String] = []
        var isBusy = false
        var showPrivacySheet = false
    }

    enum Intent: MviIntent {
        case trackEvent
        case trackInteraction
        case httpAuto
        case httpManualBody
        case httpFailing
        case handledException
        case showPrivacy
        case dismissPrivacy
        case clearLog
    }

    enum Effect: MviEffect {
        case navigate(Route)
    }
}

// MARK: - View model

@MainActor
final class LabViewModel: MviViewModel<LabContract.State, LabContract.Intent, LabContract.Effect> {

    @ObservationIgnored @Injected private var client: RickMortyClient
    @ObservationIgnored private var eventCounter = 0

    /// One session for the whole screen. `instrumentedSession()` builds a delegate-backed session and
    /// `URLSession` retains its delegate until invalidated — one per tap would leak one per tap.
    @ObservationIgnored private lazy var session = Pantrix.instrumentedSession()

    private static let probeURL = URL(string: "https://rickandmortyapi.com/api/character/1")!

    init() { super.init(initialState: .init()) }

    override func onHandleIntent(_ intent: LabContract.Intent) {
        switch intent {
        case .trackEvent:
            eventCounter += 1
            Pantrix.track("lab_custom_event", attributes: ["source": "lab", "n": eventCounter])
            log("custom event sent (n=\(eventCounter))")

        case .trackInteraction:
            Pantrix.trackInteraction(.longClick, attributes: ["target": "lab_interaction_row"])
            log("interaction sent")

        case .httpAuto:
            run { [session] in
                let (data, response) = try await session.data(from: Self.probeURL)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                return "auto: \(status), \(data.count) bytes — SDK recorded everything EXCEPT the body"
            }

        case .httpManualBody:
            run { [session] in
                // Same request, but this time the response body is attached by hand. Apple never
                // hands the body to a data delegate for async/completion-handler tasks, so this is
                // the only way to get one — and doing it here is what makes the gap visible in the
                // data rather than only in the docs.
                let start = Pantrix.getCurrentTime()
                let (data, response) = try await session.data(from: Self.probeURL)
                let http = response as? HTTPURLResponse
                Pantrix.trackHttp(
                    url: Self.probeURL.absoluteString,
                    method: "GET",
                    client: "urlsession-manual",
                    statusCode: http?.statusCode,
                    startTime: start,
                    endTime: Pantrix.getCurrentTime(),
                    responseBody: String(decoding: data, as: UTF8.self),
                    responseContentType: http?.value(forHTTPHeaderField: "Content-Type")
                )
                return "manual: body attached (\(data.count) bytes) via trackHttp"
            }

        case .httpFailing:
            run { [client] in
                do {
                    let _: PageDto<CharacterDto> = try await client.page(
                        absolute: "https://rickandmortyapi.invalid/api/character"
                    )
                    return "failing UNEXPECTEDLY succeeded"
                } catch {
                    // Expected. The point is that the SDK recorded it at all — the Alamofire monitor
                    // needs a response to build an event, so it drops failures entirely.
                    return "failing: recorded with failureReason — Alamofire would have dropped it"
                }
            }

        case .handledException:
            // A real decode failure, not a fabricated error.
            do {
                _ = try JSONDecoder().decode(CharacterDto.self, from: Data(#"{"not":"a character"}"#.utf8))
                log("handled exception UNEXPECTEDLY decoded")
            } catch {
                Pantrix.trackException(error, attributes: ["source": "lab_handled_demo"])
                log("handled exception tracked — the app keeps running")
            }

        case .showPrivacy:
            setState { $0.showPrivacySheet = true }

        case .dismissPrivacy:
            setState { $0.showPrivacySheet = false }

        case .clearLog:
            setState { $0.log = [] }
        }
    }

    private func run(_ work: @escaping () async throws -> String) {
        sendRequest(
            onLoading: { [weak self] busy in self?.setState { $0.isBusy = busy } },
            onError: { [weak self] error in self?.log("failed — \(error.localizedDescription)") },
            request: work,
            onSuccess: { [weak self] line in self?.log(line) }
        )
    }

    private func log(_ line: String) {
        setState {
            $0.log.insert(line, at: 0)
            if $0.log.count > 10 { $0.log.removeLast() }
        }
    }
}

// MARK: - View

struct LabView: View {

    @State private var vm = LabViewModel()
    @Binding var path: [Route]

    var body: some View {
        List {
            Section("Events") {
                LabRow("Track a custom event", "Pantrix.track(\"lab_custom_event\", …)", "sparkles", element: "lab_track_event") {
                    vm.onIntent(.trackEvent)
                }
                LabRow("Track an interaction", "trackInteraction(.longClick, …)", "hand.tap.fill", element: "lab_track_interaction") {
                    vm.onIntent(.trackInteraction)
                }
            }

            Section {
                LabRow("instrumentedSession fetch", "automatic — method, status, timings, headers", "network", element: "lab_http_auto") {
                    vm.onIntent(.httpAuto)
                }
                LabRow("…the same, plus a response body", "trackHttp(responseBody:) — the only way on async", "square.and.pencil", element: "lab_http_manual_body") {
                    vm.onIntent(.httpManualBody)
                }
                LabRow("A request that fails", "captured here; the Alamofire path drops failures", "wifi.exclamationmark", element: "lab_http_failing") {
                    vm.onIntent(.httpFailing)
                }
            } header: {
                Text("HTTP — the URLSession path")
            } footer: {
                Text("This app has no Alamofire. `instrumentedSession()` observes without re-issuing, so it also records failures, `protocol` and `dnsAddress` — but Apple never delivers a response body to a data delegate for async tasks, so that one field needs `trackHttp`.")
            }

            Section("Diagnostics") {
                LabRow("Trigger a handled exception", "catch → trackException (not a crash)", "exclamationmark.triangle.fill", element: "lab_handled_exception") {
                    vm.onIntent(.handledException)
                }
                LabRow("Privacy & config", "how this demo configures the SDK", "lock.shield.fill", element: "lab_privacy_sheet") {
                    vm.onIntent(.showPrivacy)
                }
            }

            Section("Debug tools") {
                LabRow("Crash Lab", "trigger real crashes, captured on the next launch", "ladybug.fill", element: "lab_crash_lab", destructive: true) {
                    path.append(.crashLab)
                }
                LabRow("Send Feedback", "PantrixFeedback.show(from:)", "envelope.fill", element: "lab_send_feedback") {
                    PantrixFeedback.show(from: topViewController())
                }
                LabRow("Open Inspector", "PantrixInspector.present(from:) · or shake", "magnifyingglass", element: "lab_open_inspector") {
                    PantrixInspector.present(from: topViewController())
                }
            }

            Section {
                if vm.state.log.isEmpty {
                    Text("Tap an action above — results appear here.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                } else {
                    ForEach(Array(vm.state.log.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.caption, design: .monospaced))
                    }
                }
            } header: {
                HStack {
                    Text("Activity")
                    if vm.state.isBusy { ProgressView().controlSize(.mini) }
                    Spacer()
                    if !vm.state.log.isEmpty {
                        Button("Clear") { vm.onIntent(.clearLog) }.font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Lab")
        .trackScreen("Lab")
        .sheet(isPresented: privacyBinding) { PrivacySheet() }
    }

    private var privacyBinding: Binding<Bool> {
        Binding(
            get: { vm.state.showPrivacySheet },
            set: { if !$0 { vm.onIntent(.dismissPrivacy) } }
        )
    }

    /// The Inspector and Feedback tools present from a `UIViewController`. A pure-SwiftUI app has one
    /// to give — the hosting controller behind the scene — it just has to be reached for.
    private func topViewController() -> UIViewController {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController ?? UIViewController()
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

private struct LabRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    /// The analytics name, given explicitly rather than derived from `title`: a label is copy and gets
    /// reworded, and a derived key would silently rename the metric when it does.
    let element: String
    var destructive = false
    let action: () -> Void

    init(
        _ title: String,
        _ subtitle: String,
        _ systemImage: String,
        element: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.element = element
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        // `trackedTap`, not `.trackTap` — this row IS a Button, and the modifier would install a
        // second tap handler on top of the one the Button already owns. `trackedTap` wraps the
        // action instead: record, then run.
        Button(action: trackedTap(element, perform: action)) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(destructive ? Color.red : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    // Concrete colours — a Button tints its label, so the hierarchical `.primary` /
                    // `.secondary` would resolve to the accent colour instead.
                    Text(title).foregroundStyle(destructive ? Color.red : Color.primary)
                    Text(subtitle).font(.caption).foregroundStyle(Color.secondary)
                }
            }
        }
    }
}

private struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("trackHttpHeaders · trackHttpBody")
                    Text("retentionDays 0 · maxStoredEvents 0 (unlimited, dev only)")
                    Text("keepSentEvents true — so the Inspector still lists exported events")
                } header: {
                    Text("Requested by this app")
                } footer: {
                    Text("Requested, not decided: `enableRemoteConfig` is on, and remote config is a full override. A project with no SDK Config row gets the backend baseline — `trackHttpBody false`, `keepSentEvents false` — which silently wins over everything above.")
                }
                Section("Available but NOT set in this demo") {
                    Text("screenBlocklist · httpUrlBlocklist · httpHeadersBlocklist")
                    Text("redactionKeys · storageEncryption · collectDeviceId")
                }
            }
            .navigationTitle("Privacy & config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
