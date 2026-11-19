// Temporary: here only to see how the build reports analyzer and clang warnings. Not part of the repository.
#import <Foundation/Foundation.h>
#include <stdlib.h>

int TemporaryAnalyzerProbe(int flag) {
    int unused = 3;
    int *value = NULL;
    if (flag) {
        return *value;
    }
    char *leaked = malloc(16);
    leaked[0] = 'a';
    return 0;
}
