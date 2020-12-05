#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include "config.h"
#include "iomap.h"
#include "chad.h"
#include "flash.h"
#include "gecko.h"
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

uint64_t ChadBootKey = 0;               // global needed by chad.c

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
    GeckoLoad(ChadBootKey);
    while (1) {
        FlashSPI(0);
        uint8_t plain = SPIresult ^ GeckoByte();
        switch (b_mode >> 1) {
        case 0:                         // command mode
            switch (plain & 0xC0) {
            case 0xC0:
                if (plain & 0x20) { // 111xxxxx
                    FlashMemSPIformat(0);
                    return;
                }
                else {                  // 110xxxmm
                    b_mode = 18 + (plain & 3); // 18 to 21
                }
            case 0x80: break;           // f_rate doesn't matter
            default:
                b_mode = 2 + ((plain >> 2) & 15); // 2 to 17
                bytecount = bytes = (plain & 3);
            } break;
        case 1:                         // data mode
        case 2:                         // space for 16 sinks
        case 3:
        case 4:
        case 5:
        case 6:
        case 7:
        case 8:
            boot_data = (boot_data << 8) + plain;
            if (bytecount)
                bytecount--;
            else {
                bytecount = bytes;
                switch (b_mode) {
                case 2:
#ifdef VERBOSE
                    printf("code[%Xh]=%Xh\n", b_dest, boot_data);
#endif
                    chadToCode(b_dest++, boot_data);
                    break;
                case 3:
#ifdef VERBOSE
                    printf("data[%Xh]=%Xh\n", b_dest, boot_data);
#endif
                    chadToData(b_dest++, boot_data);
                    break;
                // room for 14 more memories or output streams here
                }
                boot_data = 0;
                if (b_count)  b_count--;
                else          b_mode = 0;
            } break;
        case 9:
            if (b_mode & 1) {
                b_dest = (b_dest & 0x00FF) | (plain << 8);
                b_mode--;
            }
            else {
                b_dest = (b_dest & 0xFF00) | plain;
                b_mode = 0;
            } break;
        case 10:
            if (b_mode & 1) {
                b_count = (b_count & 0x00FF) | (plain << 8);
                b_mode--;
            }
            else {
                b_count = (b_count & 0xFF00) | plain;
                b_mode = 0;
            } break;
        }
    }
}

void FlashMemBoot(void) {
    FlashMemSPIformat(0);
    FlashMemSPIformat(2);
    FlashSPI(0x0B);
    FlashSPI(FlashBaseBlock()); // 3-byte address
    FlashSPI(0);
    FlashSPI(0);
    FlashSPI(0);                // dummy byte
    FlashInterpret();
}

static uint64_t gkey = 0;
static uint8_t xorkey;

static int IOspiResult(void) {
    return SPIresult ^ xorkey;
}

// ISP interpreter. In a real system, the UART can control the ISP.
// In a PC environment, stdin is not given this access.
// But, the processor can jam ISP bytes into a simulated ISP interpreter.
// JamISP keeps a little internal state.

// `00nnnnnn` set 12 - bit run length N(use two of these)
// `01sxgbpr` s=SPI, x=unused, g = gecko, b = boot, p = ping, r = reset cpu
// `10xxxxff` Write N+1 bytes to flash using format f
// `11xxxxff` Read N+1 bytes from flash using format f

static void JamISP(uint8_t c) {
    static int state = 0;
    static int n = 0;
    int sel = c >> 6;
#ifdef VERBOSE
    printf("j[%d,%02X] ", state, c);
#endif
    switch (state) {
    case 0: // command
        switch (sel) {
        case 0: // 00nnnnnn
            n = (n << 6) + (c & 0x3F);
            break;
        case 1: // 01
            // (c & 1) ignore reset
            if (c & 2) { printf("ISP: no ping\n"); }
            if (c & 4) { FlashMemBoot(); }
            if (c & 8) {
#ifdef VERBOSE
                printf("Loading Key %X%08X\n", (uint32_t)(gkey >> 32), (uint32_t)gkey);
#endif
                GeckoLoad(gkey);
                gkey = 0;
                xorkey = GeckoByte();
            }
            if (c & 32) {
                FlashSPI(0);
                xorkey = GeckoByte();
#ifdef VERBOSE
                printf("SPI xfer, keystream=%02Xh, raw=%02X\n", xorkey, SPIresult);
#endif
            }
            break;
        case 2:
            FlashMemSPIformat(c & 7);
            if (c & 7) state = sel;
            break;
        case 3:
            FlashMemSPIformat(c & 7);
            state = sel;
            break;
        } break;
    case 2: // write makes sense
        FlashSPI(c);
        if (n) n--; else { state = 0; }
        break;
    case 3: printf("ISP: read-to-UART not supported\n");
    default: state = 0; // weird state
    }
}

/*
There are two ways to input from a keyboard: Cooked and Raw. Each has trade-offs.
KEY uses cooked input for compatibility with terminals.
If you use a terminal (like PuTTY) over a UART, it has to use cooked mode.
It buffers a line locally, allowing you to edit it, before sending it.
termKey will wait until a CR is received.
*/

static uint8_t buf[LineBufferSize];
static int toin = 0;
static int len = 0;

static int IOtermQkey(void) {
    if (toin < len) {
        return 1;                       // there are chars in the buffer
    }
    return KbHit();
}

static int IOtermKey(void) {              // Get the next byte in the input stream
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

////////////////////////////////////////////////////////////////////////////////
// Host words start at I/O address 8000h.

// The `_IORD_` field in an ALU instruction strobes io_rd.
// In the J1, input devices sit on (mem_addr,io_din)

static uint8_t nohostAPI;               // prohibit access to host API
static uint32_t WishboneUpperRx;
static uint32_t WishboneUpperTx;

uint32_t readIOmap (uint32_t addr) {
    if ((addr & 0x8000) && (nohostAPI))
        chadError(BAD_HOSTAPI);
    switch (addr) {
    case 0: return IOtermKey();         // Get the next incoming stream char
    case 1: return IOtermQkey();
    case 2: return 0;                   // UART tx is never busy
    case 3: return IOspiResult();       // SPI result
    case 4: return 0;                   // Jam status, not busy
    case 5: return 0;                   // DMA status, not busy
    case 6: return (uint32_t)chadCycles();
    case 7: return WishboneUpperRx;
    default: chadError(BAD_IOADDR);
    }
    return 0;
}

// The `iow` field in an ALU instruction strobes io_wr.
// In the J1, output devices sit on (mem_addr,dout)
// Result is error code

// 0 to 15 are reserved for SPIF registers, all else is Wishbone bus.
// See spif.v for mapping and Wishbone implementation.

int writeIOmap (uint32_t addr, uint32_t x) {
    static uint32_t codeAddr = 0;
    if ((addr & 0xFFFFC000) && (nohostAPI))
        chadError(BAD_HOSTAPI);
    switch (addr) {
    case 0x00:                          // emit
        putchar(x);
#ifdef __linux__
    fflush(stdout);
    usleep(1000);
#endif
        break;
    case 0x01: codeAddr = x;  break;
    case 0x02: chadToCode(codeAddr++, x);  break;
    case 0x03: FlashInterpret();  break;
    case 0x04: JamISP(x);  break;       // Jam ISP byte
    case 0x05: gkey = (gkey << CELLBITS) + x;
    case 0x06: break; // reserved (was stream output)
    case 0x07: WishboneUpperTx = x;  break;
    case 0x08: break; // reserved
#ifdef HAS_LCDMODULE
    case 0x10: TFTLCDwrite(x);  break;
#endif
#ifdef HAS_LEDSTRIP
    case 0x14: LEDstripWrite(x);  break;
#endif
    case 0x100: nohostAPI = x;  break;
    case 0x4000:                        // trigger an error
        chadError(x);  break;
    default: return BAD_IOADDR;
    }
    return 0;
}

void killHostIO(void) {
    nohostAPI = 1;
}

