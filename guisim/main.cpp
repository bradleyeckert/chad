
#include <stdio.h>
#include <stdint.h>
#include <ctype.h>
#include <string>
#include <thread>
extern "C" {
#include "gui.h"
#include "../src/config.h"
#include "../src/chad.h"
}

using namespace std;

static char command[LineBufferSize];    // a line buffer for Forth

int main(int argc, char** argv)
{
    std::thread thread1(GUIrun);        // run the GUI separately

// I was worried GLUT would interfere with keyboard input.
// Miraculously, chad gets cooked-mode stdin like it wants.

    command[0] = '\0';
    // concatenate everything on the command line to the line buffer
    for (int i = 1; i < argc; i++) {
#ifdef MORESAFE
        strncat_s(command, LineBufferSize, argv[i], LineBufferSize);
        if (i != (argc - 1))  strncat_s(command, LineBufferSize, " ", 2);
#else
        strncat(command, argv[i], LineBufferSize - strlen(command));
        if (i != (argc - 1))  strncat(command, " ", 2);
#endif
    }
    int ior = chad(command, LineBufferSize);
    exit(ior); // or tell glut to quit. How?
//  thread1.join(); // will hang until GUI quits

    return ior;
}

