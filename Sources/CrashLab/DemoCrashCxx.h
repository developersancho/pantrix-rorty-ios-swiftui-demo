//
//  DemoCrashCxx.h
//  PantrixRortySwiftUI
//
//  Demo-only helper that raises an UNCAUGHT C++ exception, so the Crash Lab can exercise Pantrix's
//  C++ `std::terminate` catcher — the third of the three fatal-crash catchers (signal / NSException /
//  C++). Swift can't throw a C++ exception directly, so this thin ObjC++ shim does it.
//

#import <Foundation/Foundation.h>

@interface DemoCrashCxx : NSObject
+ (void)throwUncaughtCxxException;
@end
