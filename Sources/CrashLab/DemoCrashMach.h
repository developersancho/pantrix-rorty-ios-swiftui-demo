//
//  DemoCrashMach.h
//  PantrixRortySwiftUI
//
//  Demo-only helpers that raise the hardware faults the Mach exception catcher exists for, so the Crash
//  Lab can drive the PRIMARY catcher (EXC_BAD_ACCESS / EXC_BAD_INSTRUCTION) and not just the signal path.
//  None of the three can be written in Swift: `udf #0` needs inline asm (Swift has none), and a Swift
//  self-recursion is tail-call-folded into an infinite loop that spins forever instead of exhausting the
//  stack — see the attributes in the .m, which are load-bearing, not decoration.
//

#import <Foundation/Foundation.h>

@interface DemoCrashMach : NSObject
/// Unbounded recursion until the stack is exhausted.
///
/// Reports as **SIGBUS**, not SIGSEGV: hitting the guard page raises `KERN_PROTECTION_FAILURE` (the page
/// exists, it just isn't writable), not `KERN_INVALID_ADDRESS`. A standalone repro on macOS arm64
/// measures SIGSEGV — iOS answers differently, so only a device settles it. The record also arrives with
/// only ~6 frames, one address repeated, because there is no stack left to unwind.
+ (void)overflowStack;
/// Stores into a read-only page → KERN_PROTECTION_FAILURE → **SIGBUS**.
+ (void)writeToReadOnlyPage;
/// Executes `UDF #0` → EXC_BAD_INSTRUCTION → **SIGILL**.
+ (void)raiseIllegalInstruction;
@end
