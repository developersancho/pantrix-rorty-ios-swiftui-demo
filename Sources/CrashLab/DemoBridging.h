//
//  DemoBridging.h
//  PantrixRortySwiftUI
//
//  Objective-C bridging header for the Crash Lab.
//
//  The Mach-fault and C++-terminate triggers cannot be written in Swift — Swift has no `throw` that
//  reaches `std::terminate`, and the compiler folds or deletes the constructs that produce SIGSEGV /
//  SIGBUS / SIGILL. They arrive in Faz 5 as an ObjC (.m) and an ObjC++ (.mm) pair, imported here.
//
//  The `SWIFT_OBJC_BRIDGING_HEADER` build setting points at this file from Faz 0 so the setting
//  never has to move later.
//

// #import "DemoCrashCxx.h"   // Faz 5
// #import "DemoCrashMach.h"  // Faz 5
