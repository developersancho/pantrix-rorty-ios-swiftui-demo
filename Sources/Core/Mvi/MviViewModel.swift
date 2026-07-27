//
//  MviViewModel.swift
//  PantrixRortySwiftUI
//
//  The Swift analogue of the admin panel's `MviViewModel<State, Intent, Effect>`
//  (`corekit/base/MviViewModel.kt` + `shared/base/BaseViewModel.kt`).
//

import Combine
import Foundation
import Observation

/// Base view model: one observable `state`, a one-shot `effect` channel, and intents in.
///
/// ## The rule that is not negotiable
///
/// **Every piece of UI state must live inside `S`.** A stored property added by a subclass is *not*
/// observed by SwiftUI — the `@Observable` macro instruments the properties of the class it is
/// attached to, and this base is that class. Measured, on this exact shape:
///
///     tabandaki state gozlemlendi: 1  |  alt sinif property'si gozlemlendi: 0
///
/// It compiles silently and the view simply never updates. MVI asks for one immutable snapshot
/// anyway, so the discipline and the language agree here — but the failure mode is invisible, hence
/// this note. A subclass may hold non-UI collaborators only, and they must be `@ObservationIgnored`.
///
/// ## Why the effect channel is a Combine subject
///
/// Kotlin uses `MutableSharedFlow(replay = 0)`: multi-subscriber, nothing replayed to a late
/// subscriber. `PassthroughSubject` is the faithful match. `AsyncStream` is single-consumer and
/// would silently drop events once a second view subscribed — wrong shape for SwiftUI, where views
/// are re-created freely and more than one host may listen.
///
/// Consume it with `.onReceive(vm.effect)`, which ties the subscription to the view's lifetime.
@Observable
@MainActor
class MviViewModel<S: MviState, I: MviIntent, E: MviEffect> {

    private(set) var state: S

    @ObservationIgnored private let effects = PassthroughSubject<E, Never>()

    /// In-flight work, cancelled on deinit so a superseded screen cannot write state after it is gone.
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    var effect: AnyPublisher<E, Never> { effects.eraseToAnyPublisher() }

    init(initialState: S) {
        self.state = initialState
    }

    deinit {
        // `tasks` is isolated to the main actor but deinit is not; the array is only ever mutated on
        // the main actor and deinit runs after the last reference is gone, so this read is safe.
        MainActor.assumeIsolated { tasks.forEach { $0.cancel() } }
    }

    // MARK: - Intents

    /// The UI's entry point. Subclasses implement `onHandleIntent`.
    func onIntent(_ intent: I) {
        onHandleIntent(intent)
    }

    /// Abstract — subclasses must override.
    ///
    /// Swift has no `abstract`, and making this a protocol requirement would forfeit the shared
    /// generic storage above, so this is the standard trade: a trap that fires on the first call in
    /// development rather than a compile error.
    func onHandleIntent(_ intent: I) {
        fatalError("\(type(of: self)) must override onHandleIntent(_:)")
    }

    // MARK: - Reducers

    /// `setState { $0.isLoading = true }` — the Swift spelling of Kotlin's `setState { copy(...) }`.
    func setState(_ mutate: (inout S) -> Void) {
        mutate(&state)
    }

    /// `setEffect { .showError(message) }`
    func setEffect(_ build: () -> E) {
        effects.send(build())
    }

    // MARK: - Async work

    /// Runs `request` with the standard loading + error handling, mirroring `BaseViewModel.sendRequest`.
    ///
    /// There is no `ResultOf` here on purpose: Kotlin needs it because it has no checked exceptions,
    /// while `async throws` is already Swift's idiom for exactly this. Importing the wrapper would
    /// add a layer that the language already provides.
    ///
    /// `onLoading` is guaranteed to be called with `false` on every path — success, failure and
    /// cancellation alike.
    func sendRequest<T>(
        onLoading: ((Bool) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        request: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void = { _ in }
    ) {
        let task = Task { @MainActor [weak self] in
            guard self != nil else { return }
            onLoading?(true)
            defer { onLoading?(false) }
            do {
                let value = try await request()
                guard !Task.isCancelled else { return }
                onSuccess(value)
            } catch is CancellationError {
                // A superseded load — not an error the user should see.
            } catch {
                guard !Task.isCancelled else { return }
                onError?(error)
            }
        }
        tasks.append(task)
    }
}
