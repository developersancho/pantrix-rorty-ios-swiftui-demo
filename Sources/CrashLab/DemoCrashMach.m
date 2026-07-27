//
//  DemoCrashMach.m
//  PantrixRortySwiftUI
//
//  Plain ObjC (`.m`, not `.mm`) — none of this needs C++, and ObjC++ would additionally make the
//  string-literal cast below a `-Wwrite-strings` error.
//

#import "DemoCrashMach.h"

#include <stdint.h>

// disable_tail_calls is LOAD-BEARING: a self-recursion is tail-call-folded into an infinite loop that
// never faults. The unbounded recursion clang warns about here is the whole point — a base case would
// defeat the trigger — so the warning is silenced locally rather than answered.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winfinite-recursion"
__attribute__((noinline, disable_tail_calls))
static uint64_t pantrix_burn_stack(uint64_t depth) {
    volatile uint64_t pad[64];
    for (int i = 0; i < 64; i++) { pad[i] = depth + (uint64_t)i; }
    uint64_t next = pantrix_burn_stack(depth + 1);
    return next + pad[depth % 64];
}
#pragma clang diagnostic pop

// `volatile` is LOAD-BEARING: without it clang deletes the dead store and the button silently does
// nothing. With it: SIGBUS.
__attribute__((noinline))
static void pantrix_store_ro(volatile char *p) { *p = 'X'; }

@implementation DemoCrashMach
+ (void)overflowStack { (void)pantrix_burn_stack(0); }

+ (void)writeToReadOnlyPage {
    volatile char *literal = (volatile char *)"pantrix";   // __TEXT / __DATA_CONST — read-only page
    pantrix_store_ro(literal);
}

+ (void)raiseIllegalInstruction {
#if defined(__arm64__) || defined(__aarch64__)
    __asm__ volatile(".inst 0x00000000");   // UDF #0 → EXC_BAD_INSTRUCTION → SIGILL
#elif defined(__x86_64__)
    __asm__ volatile("ud2");                // also EXC_BAD_INSTRUCTION → SIGILL
#else
    __builtin_trap();
#endif
}
@end
