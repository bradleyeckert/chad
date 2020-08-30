#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "config.h"
#include "flash.h"

/*
Flash Memory Simulator
The interface to flash memory is through a SPI interface.
A 16-bit word size is sufficient for the SPI.

Flash memory is a static array of bytes that C initializes to 0.
Read and write invert the data so that blank means 0xFF.
Chad can call LoadFlashMem to initialize it from a file.
*/

static uint8_t mem[FlashMemorySize];

int LoadFlashMem (char *filename) {     // load binary image
    memset(mem, 0, FlashMemorySize);    // erase flash
    FILE *fp;
#ifdef MORESAFE
    errno_t err = fopen_s(&fp, filename, "rb");
#else
    fp = fopen(filename, "rb");
#endif
    if (fp == NULL) return BAD_OPENFILE;
    fread(mem, FlashMemorySize, 1, fp);
    fclose(fp);
    return 0;
}

int SaveFlashMem (char *filename) { // save binary image
    int p = FlashMemorySize;
    while ((p) && (mem[--p])) {}        // find the unblank size
    if (!p) return 0;                   // nothing to save
    FILE *fp;
#ifdef MORESAFE
    errno_t err = fopen_s(&fp, filename, "wb");
#else
    fp = fopen(filename, "wb");
#endif
    if (fp == NULL) return BAD_CREATEFILE;
    fwrite(mem, p, 1, fp);
    fclose(fp);
    return 0;
};

/*------------------------------------------------------------------------------
| Name   | Hex | Command                           |
|:-------|-----|----------------------------------:|
| FR     | 0Bh | Read Data Bytes from Memory       |
| PP     | 02h | Page Program Data Bytes to Memory |
| SER    | 20h | Sector Erase 4KB                  |
| WREN   | 06h | Write Enable                      |
| WRDI   | 04h | Write Disable                     |
| RDSR   | 05h | Read Status Register              |
| RDJDID | 9Fh | Read 3-byte JEDEC ID              |
*/

static uint8_t state = 0;               // FSM state
static uint8_t command = 0;             // current command
static uint8_t wen;                     // write enable
static uint32_t addr;

// n bits: 11:10 = bus width (ignored, assumed 0)
// 9 = falling starts a command if it's not yet started
// 8 = finishes a command if it's not yet finished
// 7:0 = SPI data to transmit
// Return value is the SPI return byte combined with error code

// RDJDID (9F command) is custom: 0xAA, 0xHH, 0xFF number of 4K blocks

int FlashMemSPI8 (int n) {
    uint8_t cin = (uint8_t)(n & 0xFF);
    uint8_t cout = 0xFF;
    if (n & 0x200) {                                    // set /CS before transfer
        state = 0;                                      // inactive bus floats hi
        return cout;
    } else {
        if (state) {                                    // continue previous command
            switch (state) {
                case 1: break;                          // wait for trailing CS
                case 2: cout = wen;   state=1;  break;  // status = WEN, never busy
                case 3: cout = 0xAA;  state++;  break;  // 3-byte RDJDID
                case 4: cout = 0xFF & (FlashMemorySize>>24); state++;  break;
                case 5: cout = 0xFF & (FlashMemorySize>>16); state=1;  break;
                case 6: addr = cin<<16;                      state++;  break;
                case 7: addr += cin<<8;                      state++;  break;
                case 8: addr += cin;
                    if (addr < FlashMemorySize) {
                        switch (command) {
                            case 0x20:
                                if (wen) {
                                    memset(&mem[addr>>12], 0, 4096);
                                }   wen=0;  state=1;  /* 4K erase */   break;
                            case 0x0B: /* fast read */       state++;  break;
                            case 0x02: if (wen) {state=11; break;}
                                state=0;  return BAD_NOTENABLED;
                            default:                         state = 0;
                        } break;
                    } else {                            // invalid address, ignore
                        state = 0;
                    }
                case 9: state++;  break;                // dummy byte before read
                case 10: cout = ~mem[addr++];  break;   // read as long as you want
                case 11:                                // write byte to flash
                    if (mem[addr]) {
                        state=0;
                        return BAD_NOTBLANK;
                    }
                    mem[addr++] = ~cin;
                    if (((addr & 0xFF) == 0) && ((n & 0x100) == 0)) {
                        state=0;
                        return BAD_PAGEFAULT;
                    }
                    break;
                default: state = 0;
            }
        } else {                                        // start new command
            command = cin;
            switch (command) {
                case 0x05: /* RDSR   opcd -- n1 */                  state=2;  break;
                case 0x0B: /* FR     opcd A2 A1 A0 xx -- data... */
                case 0x02: /* PP     opcd A2 A1 A0 d0 d1 d2 ... */
                case 0x20: /* SER4K  opcd A2 A1 A0 */               state=6;  break;
                case 0x06: /* WREN   opcd */                        state=1;  wen=2;  break;
                case 0x04: /* WRDI   opcd */                        state=1;  wen=0;  break;
                case 0x9F: /* RDJDID opcd -- n1 n2 n3 */            state=3;  break;
                default: break;
            }
        }
    }
    if (n & 0x100) {                                    // set /CS after transfer
        state = 0;
    }
    return cout;
}
