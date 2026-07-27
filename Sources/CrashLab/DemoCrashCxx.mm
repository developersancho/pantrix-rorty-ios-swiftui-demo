//
//  DemoCrashCxx.mm
//  PantrixRortySwiftUI
//
//  ObjC++ implementation — compiled as C++, so it can `throw`. Left uncaught on purpose.
//

#import "DemoCrashCxx.h"

#include <stdexcept>

@implementation DemoCrashCxx
+ (void)throwUncaughtCxxException {
    // Uncaught → std::terminate → Pantrix's set_terminate handler records the crash, then aborts.
    throw std::runtime_error("Pantrix Rorty SwiftUI demo: uncaught C++ exception");
}
@end
