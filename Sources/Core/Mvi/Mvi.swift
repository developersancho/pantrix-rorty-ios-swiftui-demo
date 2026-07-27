//
//  Mvi.swift
//  PantrixRortySwiftUI
//
//  The three MVI marker protocols. Deliberately a direct translation of the team's Kotlin/Compose
//  admin panel (`corekit/base/MviContract.kt`) so the two codebases read the same way.
//

import Foundation

/// One-shot events the UI dispatches. An intent describes *what the user wants*, never *how the
/// state changes* — the reducer decides that.
public protocol MviIntent {}

/// A single immutable snapshot of everything the view needs.
///
/// `Equatable` is required here (the Kotlin side gets it free from `data class`): SwiftUI diffs on
/// it, and `sendRequest` callers rely on `setState` being idempotent.
public protocol MviState: Equatable {}

/// One-shot side effects — navigate, toast, dialog — that must NOT live in state. Consumed once and
/// discarded; putting them in state makes them replay on every re-render.
public protocol MviEffect {}
