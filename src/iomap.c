#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include "config.h"
#include "iomap.h"
#include "chad.h"
#include "flash.h"
#include "TFTsim.h"
#ifdef __linux__
#include <unistd.h>
/**
 Linux (POSIX) implementation of _kbhit().
 Morgan McGuire, morgan@cs.brown.edu
 */
#include <stdio.h>
#include <sys/select.h>
#include <termios.h>
#include <stropts.h>

int KbHit(void) { // _kbhit in Linux
    static const int STDIN = 0;
    static bool initialized = false;

    if (!initialized) {
        // Use termios to turn off line buffering
        termios term;
        tcgetattr(STDIN, &term);
        term.c_lflag &= ~ICANON;
        tcsetattr(STDIN, TCSANOW, &term);
        setbuf(stdin, NULL);
        initialized = true;
    }

    int bytesWaiting;
    ioctl(STDIN, FIONREAD, &bytesWaiting);
    return bytesWaiting;
}
#else
#include <conio.h>
int KbHit(void) {
    return _kbhit();
}
#endif

// Host words start at I/O address 8000h.

// The `_IORD_` field in an ALU instruction strobes io_rd.
// In the J1, input devices sit on (mem_addr,io_din)

static uint32_t header_data;            // host API return data
static uint16_t SPIresult;
static uint8_t nohostAPI;               // prohibit access to host API

static int termKey(void);
static int termQkey(void);

uint32_t readIOmap (uint32_t addr) {
    int32_t r, temp;
    if ((addr & 0x8000) && (nohostAPI))
        chadError(BAD_HOSTAPI);
    switch (addr) {
// ===== 0 to 3 = UART read
    case 0: return termKey();           // Get the next incoming stream char
    case 1: return termQkey();
    case 2: // terminal type (control and function keys differ)
#ifdef __linux__
        return 1;
#else
        return 0;
#endif
    case 3: return 0;                   // UART tx is never busy
// ===== 4 to 7 = SPI read
    case 4:
        temp = SPIresult;               // get result and start another transfer
        r = FlashMemSPI(0);
        SPIresult = (uint16_t)r;
        if (r < 0) { chadError(r); }
        return temp;
    case 5: 
        return SPIresult;               // get result
    case 0x8000: return header_data;
    default: chadError(BAD_IOADDR);
    }
    return 0;
}

// The `iow` field in an ALU instruction strobes io_wr.
// In the J1, output devices sit on (mem_addr,dout)

// Code space is writable through this interface.
void writeIOmap (uint32_t addr, uint32_t x) {
    static codeaddr = 0;
    int r;
    if ((addr & 0x8000) && (nohostAPI))
        chadError(BAD_HOSTAPI);
    switch (addr) {
// ===== 0 to 3 = UART write
    case 0:
        putchar((char)x);
#ifdef __linux__
    fflush(stdout);
    usleep(1000);
#endif
        break;
    case 3:
        nohostAPI = x;  break;
// ===== 4 to 7 = SPI write
    case 4:
        r = FlashMemSPI((int)x);
        SPIresult = (uint16_t)r;
        if (r < 0) {chadError(r);}
        break;
    case 5:
        FlashMemSPIformat(x);  break;
    case 8:                             // Start code writes here
        codeaddr = x;  break;           // addressing 16-bit instructions
    case 9:                             // write next code word
        chadToCode(codeaddr++, x);  break;
    case 12:
        TFTLCDwrite(x);
    case 0x8000:                        // trigger an error
        chadError(x);  break;
    case 0x8001:                        // trigger a header data read 
        header_data = chadGetHeader(x);  break;
    default: chadError(BAD_IOADDR);
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

static uint8_t buf[LineBufferSize];
static int toin = 0;
static int len = 0;

static int termQkey(void) {
    if (toin < len) {
        return 1;                       // there are chars in the buffer
    }
    return KbHit();
}

static int termKey(void) {              // Get the next byte in the input stream
    if (toin < len) {
        return buf[toin++];
    }
    toin = 0;
    len = 0;
    if (fgets((char*)buf, LineBufferSize, stdin) != NULL) {
        len = strlen((char*)buf);
    }
    if (len) {                          // the string ends in newline
        return buf[toin++];
    }
    return -1;                          // so this shouldn't happen ever
}

void killHostIO(void) {
    nohostAPI = 1;
}

