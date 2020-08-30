#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "config.h"
#include "chad.h"

int main(int argc, char *argv[]) {
	char command[LineBufferSize];
	command[0] = 0;
	// concatenate everything on the command line to one long string
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
