//
//  DemoBridging.h
//  PantrixRortySwiftUI
//
//  Objective-C bridging header for the Crash Lab.
//
//  The Mach-fault and C++-terminate triggers cannot be written in Swift — Swift has no `throw` that
//  reaches `std::terminate`, and the compiler folds or deletes the constructs that produce SIGSEGV /
//  SIGBUS / SIGILL.
//
//  The two file extensions are load-bearing and must not be "tidied":
//    · DemoCrashCxx.**mm** — ObjC++, so it can `throw` a C++ exception.
//    · DemoCrashMach.**m** — plain ObjC. As ObjC++ the string-literal cast in `writeToReadOnlyPage`
//      becomes a `-Wwrite-strings` error.
//

#import "DemoCrashCxx.h"
#import "DemoCrashMach.h"
