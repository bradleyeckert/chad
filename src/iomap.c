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

//#define VERBOSE

// Flash stream interpreter
// Start with a byte in SPIresult, FlashMemSPIformat is already set up.
// 0xxxxmbb = Load memory from flash, b+1 bytes/word, to code or data space
// 10xxssss = Set SCLK divisor
// 110xxx00 = Load dest[7:0] with 8-bit value
// 110xxx01 = Load dest with 16-bit value(big endian)
// 110xxx10 = Load length[7:0] with 8-bit value
// 110xxx11 = Load length with 16-bit value(big endian)
// 111rxxxx = End bootup and start processor

static uint8_t SPIresult;

static void FlashSPI(uint8_t c) {
    int r = FlashMemSPI8(c);
    if (r < 0) chadError(r);
    SPIresult = r;
}

static void FlashInterpret(void) {      // see spif.v, line 288
    uint8_t bytecount = 0;
    uint8_t bytes = 0;
    uint8_t b_mode = 0;
    uint32_t boot_data = 0;
    uint16_t b_dest = 0;
    uint16_t b_count = 0;
    while (1) {
        switch (b_mode >> 1) {
        case 0:                         // command mode
            switch (SPIresult & 0xC0) {
            case 0xC0:
                if (SPIresult & 0x20) { // 111xxxxx
                    FlashMemSPIformat(0);
                    return;
                }
                else {                  // 110xxxmm
                    b_mode = 4 + (SPIresult & 3); // 4 to 7
                }
            case 0x80: break;           // f_rate doesn't matter
            default:
                b_mode = 2 + ((SPIresult >> 2) & 1); // 2 to 3
                bytecount = bytes = (SPIresult & 3);
            } break;
        case 1:                         // data mode
            boot_data = (boot_data << 8) + SPIresult;
            if (bytecount)
                bytecount--;
            else {
                bytecount = bytes;
                if (b_mode & 1) {
#ifdef VERBOSE
                    printf("data[%Xh]=%Xh\n", b_dest, boot_data);
#endif
                    chadToData(b_dest++, boot_data);
                }
                else {
#ifdef VERBOSE
                    printf("code[%Xh]=%Xh\n", b_dest, boot_data);
#endif
                    chadToCode(b_dest++, boot_data);
                }
                boot_data = 0;
                if (b_count)  b_count--;
                else          b_mode = 0;
            } break;
        case 2:
            if (b_mode & 1) {
                b_dest = (b_dest & 0x00FF) | (SPIresult << 8);
                b_mode--;
            }
            else {
                b_dest = (b_dest & 0xFF00) | SPIresult;
                b_mode = 0;
            } break;
        default:
            if (b_mode & 1) {
                b_count = (b_count & 0x00FF) | (SPIresult << 8);
                b_mode--;
            }
            else {
                b_count = (b_count & 0xFF00) | SPIresult;
                b_mode = 0;
            } break;
        }
        FlashSPI(0);
    }
}

void FlashMemBoot(void) {
    FlashMemSPIformat(0);
    FlashMemSPIformat(2);
    FlashSPI(0x0B);
    FlashSPI(0);                // 3-byte address
    FlashSPI(0);
    FlashSPI(0);
    FlashSPI(0);                // dummy byte
    FlashSPI(0);                // read first byte
    FlashInterpret();
}

// ISP interpreter. In a real system, the UART can control the ISP.
// In a PC environment, stdin is not given this access.
// But, the processor can jam ISP bytes into a simulated ISP interpreter.
// JamISP keeps a little internal state.

// `00nnnnnn` set 12 - bit run length N(use two of these)
// `01xxxbpr` b = boot, p = ping, r = reset cpu
// `10xxxxff` Write N+1 bytes to flash using format f
// `11xxxxff` Read N+1 bytes from flash using format f

static void JamISP(uint8_t c) {
    static state = 0;
    static n = 0;
    int sel = c >> 6;
    switch (state) {
    case 0: // command
        switch (sel) {
        case 1: // ignore reset and ping flags
            if (c & 2) { printf("ISP: no ping\n"); }
            if (c & 4) { FlashMemBoot(); }
            break;
        case 2: state = sel;  break;
        case 3: state = sel;  break;
        default: n = (n << 6) + (c & 0x3F);
        } break;
    case 2: // write makes sense
        FlashSPI(c);
        if (n) n--; else { state = 0; }
        break;
    case 3: printf("ISP: read-to-UART not supported\n");
    default: state = 0; // weird state
    }
}


////////////////////////////////////////////////////////////////////////////////
// Host words start at I/O address 8000h.

// The `_IORD_` field in an ALU instruction strobes io_rd.
// In the J1, input devices sit on (mem_addr,io_din)

static uint32_t header_data;            // host API return data
static uint8_t nohostAPI;               // prohibit access to host API

static int termKey(void);
static int termQkey(void);

uint32_t readIOmap (uint32_t addr) {
    if ((addr & 0x8000) && (nohostAPI))
        chadError(BAD_HOSTAPI);
    switch (addr) {
    case 0: return termKey();           // Get the next incoming stream char
    case 1: return termQkey();
    case 2: return 0;                   // UART tx is never busy
    case 3: return SPIresult;           // SPI result
    case 4: return 0;                   // Jam status, not busy
    case 5: return 0;                   // DMA status, not busy
    case 6: return (uint32_t)chadCycles();
    case 0x8000: return header_data;
    default: chadError(BAD_IOADDR);
    }
    return 0;
}

// The `iow` field in an ALU instruction strobes io_wr.
// In the J1, output devices sit on (mem_addr,dout)

void writeIOmap (uint32_t addr, uint32_t x) {
    if ((addr & 0x8000) && (nohostAPI))
        chadError(BAD_HOSTAPI);
    switch (addr) {
    case 0:                             // emit
        putchar(x);
#ifdef __linux__
    fflush(stdout);
    usleep(1000);
#endif
        break;
    case 2: break;                      // set baud rate
    case 3: FlashInterpret();  break;
    case 4: JamISP(x);  break;          // Jam ISP byte
    case 7: nohostAPI = x;  break;
    case 12: TFTLCDwrite(x);  break;
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

