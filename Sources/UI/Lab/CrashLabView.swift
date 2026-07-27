//
//  CrashLabView.swift
//  PantrixRortySwiftUI
//
//  Nine deliberate crashes, one per catcher family. PantrixCrash captures each and reports it on the
//  NEXT launch — so the flow is: tap, app dies, reopen, look in the dashboard.
//
//  No view model: every row's whole job is to terminate the process. There is no state to manage and
//  nothing to observe afterwards.
//

import Pantrix
import SwiftUI

struct CrashLabView: View {

    var body: some View {
        List {
            Section {
                Text("Each button crashes the app on purpose. PantrixCrash captures it and reports it on the next launch.")
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }

            Section("Signal catcher (SIGTRAP / SIGABRT)") {
                CrashRow("Force-unwrap nil") {
                    let dict: [String: Int] = [:]
                    _ = dict["missing"]!
                }
                CrashRow("Array out-of-bounds") {
                    let items = [1, 2, 3]
                    _ = items[9]
                }
                CrashRow("fatalError()") {
                    fatalError("Pantrix Rorty SwiftUI demo: fatalError()")
                }
                CrashRow("abort() → SIGABRT") {
                    abort()
                }
            }

            Section {
                CrashRow("Stack overflow → SIGBUS") { DemoCrashMach.overflowStack() }
                CrashRow("Write read-only page → SIGBUS") { DemoCrashMach.writeToReadOnlyPage() }
                CrashRow("Illegal instruction → SIGILL") { DemoCrashMach.raiseIllegalInstruction() }
            } header: {
                Text("Mach catcher (hardware faults)")
            } footer: {
                Text("These live in ObjC, not Swift: the compiler folds the self-recursion into a loop and deletes the dead store unless the source says otherwise. Stack overflow says SIGBUS, not SIGSEGV — the guard page is a protection failure — and arrives with ~6 frames, because there is no stack left to unwind.")
            }

            Section("NSException catcher") {
                CrashRow("Uncaught NSException") {
                    NSException(
                        name: .genericException,
                        reason: "Pantrix Rorty SwiftUI demo: uncaught NSException",
                        userInfo: nil
                    ).raise()
                }
            }

            Section {
                CrashRow("Uncaught C++ exception") { DemoCrashCxx.throwUncaughtCxxException() }
            } header: {
                Text("C++ terminate catcher")
            } footer: {
                Text("Compiled as ObjC++ (.mm) so it can `throw` — uncaught, it reaches `std::terminate`, which is where the SDK's handler sits.")
            }
        }
        .navigationTitle("Crash Lab")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CrashRow: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            // Recorded before the process dies. The crash itself is captured by PantrixCrash and
            // reported next launch; this custom event says which button was pressed, which is what
            // makes an unexpected crash distinguishable from a deliberate one.
            Pantrix.track("crash_lab_triggered", attributes: ["trigger": title])
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .frame(width: 24)
                    .foregroundStyle(Color.red)
                Text(title).foregroundStyle(Color.red)
            }
        }
    }
}
