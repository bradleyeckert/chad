#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "config.h"
#include "chad.h"

static char command[LineBufferSize]; // a line buffer for Forth

int main(int argc, char *argv[]) {
    command[0] = 0;
    // concatenate everything on the command line to the line buffer
    for (int i=1; i < argc; i++) {
#ifdef MORESAFE
        strncat_s(command, LineBufferSize, argv[i], LineBufferSize);
        if (i != (argc - 1))  strncat_s(command, LineBufferSize, " ", 2);
#else
        strncat(command, argv[i], LineBufferSize - strlen(command));
        if (i != (argc - 1))  strncat(command, " ", 2);
#endif
    }
    int ior = chad(command, LineBufferSize);
    return ior;
}

// If you poll for window messages, use this. Return true to quit chad. 
// Or, just comment it out so _kbhit is not needed.
// int chadSpinFunction(void) { 
//     return 0; 
// }
