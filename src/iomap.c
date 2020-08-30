#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "config.h"
#include "iomap.h"
#include "chad.h"

// Unlike operations on data memory, I/O can insert wait states.

// The I/O controller is allowed to HOLD the CPU (clock enable off).
// This causes the Code memory to get ahead of itself so I/O
// should be followed by a NOP.

// The `ior` field in an ALU instruction strobes io_rd.
// In the J1, input devices sit on (mem_addr,io_din)

static uint32_t source_addr;
static uint32_t source_length;
static int termKey(void);

uint32_t readIOmap (uint32_t addr) {
	printf("Reading from iomap[%x]\n", addr);
    switch (addr) {
    case 0x000: return termKey();       // Get the next incoming stream char
    case 0x001: // terminal type (control and function keys differ)
#ifdef __linux__
        return 1;
#else
        return 0;
#endif
    case 0x002: return 0;               // UART tx is never busy
    case 0x100: return source_addr;
    case 0x101: return source_length;
    default: break;
    }
	return 0;
}

// The `iow` field in an ALU instruction strobes io_wr.
// In the J1B, output devices sit on (mem_addr,dout)

// Code space is writable through this interface.

void writeIOmap (uint32_t addr, uint32_t x) {
    uint32_t y;
    switch (addr) {
    case 0x000:
        putchar((char)x);
#ifdef __linux__
    fflush(stdout);
    usleep(1000);
#endif
        break;
    case 0x100: // host-only: Hardware should flag this.
        y = chadGetSource ((char)x);
        source_addr = y >> 8;
        source_length = y & 0xFF;
        break;
    default:
        if (addr >= 0x200) { // write to code space
            chadToCode (addr, x);
        }
    }
}

/*
There are two ways to input from a keyboard: Cooked and Raw. Each has trade-offs.
KEY uses cooked input for compatibility with terminals.
If you use a terminal (like PuTTY) over a UART, it has to use cooked mode.
It buffers a line locally, allowing you to edit it, before sending it.
termKey will wait until a CR is received.
In an embedded system, KEY should return -1 if there's no key.
Code should invoke KEY in a loop to replace the functionality of ?KEY.
*/

static char buf[LineBufferSize];
static int toin = 0;
static int len = 0;

static int termKey(void) {			    // Get the next byte in the input stream
    if (toin < len) {
        return buf[toin++];
    }
    toin = 0;
    len = 0;
	if (fgets(buf, LineBufferSize, stdin) != NULL) {
		len = strlen(buf);
	}
	if (len) {                  // the string ends in newline
        return buf[toin++];
	}
	return -1;                  // so this shouldn't happen unless bad gets
}

