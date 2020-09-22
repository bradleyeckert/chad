#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "config.h"
#include "flash.h"
#include "chad.h"

/*
Flash Memory Simulator
The interface to flash memory is through a SPI interface.
A 16-bit word size is sufficient for the SPI.

Flash memory is a static array of bytes that C initializes to 0.
Read and write invert the data so that blank means 0xFF.
Chad can call LoadFlashMem to initialize it from a file.
*/

//#define VERBOSE

static uint8_t mem[FlashMemorySize];

int LoadFlashMem(char* filename) {      // load binary image
	memset(mem, 0, FlashMemorySize);    // erase flash
	FILE* fp;
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

int SaveFlashMem(char* filename) { // save binary image
	int p = FlashMemorySize;
	while ((p) && (mem[--p])) {}        // find the unblank size
	if (!p) return 0;                   // nothing to save
	FILE* fp;
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

enum states {
	idle, wait_, rdsr, wrsra, wrsrb, jid1, jid2, jid3,
	addr2, addr1, addr0, cmd, fastread, read, write
};

enum states state = idle;               // FSM state
static uint8_t format;                  // SPI format, 0 = 1-bit
static uint64_t mark;                   // Flash time-out

void FlashMemSPIformat(int n) {
	format = 7 & (n >> 1);
	if ((n & 1) == 0)
		state = idle;                   // CS line low = inactive
#ifdef VERBOSE
	if (n & 1)
		printf("[");
	else
		printf("]\n");
#endif
}

// Formats are:
// 00 = 8-bit old school SPI
// 01 = 8-bit QSPI mode transmit
// 10 = 8-bit QSPI mode receive
// 11 = 16-bit QSPI mode receive

static int FlashBusy(void) {
	return (chadCycles() < mark) ? 1 : 0;
}

// Return value is the SPI return or error code
// RDJDID (9F command) is custom: 0xAA, 0xHH, 0xFF number of 4K blocks

static int FlashMemSPI8(uint8_t cin) {
	static uint8_t command = 0;         // current command
	static uint8_t wen = 0;             // write enable
	static uint8_t qe = 0;              // quad rate enable
	static uint32_t addr;
	static uint32_t dummy;
	uint16_t cout = 0x00FF;
#ifdef VERBOSE
	if (state != idle)
	printf("{%X}", cin);
#endif
	switch (state) {
	case idle:
		command = cin;
#ifdef VERBOSE
		printf("#%02X ", cin);
#endif
		switch (command) {
		case 0x01: /* WRSR   opcd n -- */
			if (wen) { 
				state = wrsra;
			}  break;
		case 0x05: /* RDSR   opcd -- n1 */
			state = rdsr;                break;
		case 0xEB:
		case 0x32: if (qe == 0) { break; }
		case 0x0B: /* FR     opcd A2 A1 A0 xx -- data... */
		case 0x02: /* PP     opcd A2 A1 A0 d0 d1 d2 ... */
		case 0x20: /* SER4K  opcd A2 A1 A0 */
			state = addr2;               break;
		case 0x06: /* WREN   opcd */
			state = wait_;  wen = 2;      break;
		case 0x04: /* WRDI   opcd */
			state = wait_;  wen = 0;      break;
		case 0x9F: /* RDJDID opcd -- n1 n2 n3 */
			state = jid1;                break;
		} break;
	case wait_: break;				// wait for trailing CS
	case rdsr: cout = wen + FlashBusy();
		state = wait_;  break;
	case jid1: cout = 0xAA;
		state = jid2;  break;		// 3-byte RDJDID
	case jid2: cout = 0xFF & (FlashMemorySize >> 24);
		state = jid3;  break;
	case jid3: cout = 0xFF & (FlashMemorySize >> 16);
		state = wait_;  break;
	case addr2: addr = cin << 16;
		state = addr1;  break;
	case addr1: addr += cin << 8;
		state = addr0;  break;
	case addr0: addr += cin;
#ifdef VERBOSE
		printf("%02X[%06X] ", command, addr);
#endif
		state = wait_;
		if (addr < FlashMemorySize) {
			switch (command) {
			case 0x20:				// 4K erase
				if (wen) {
					wen = 0;
					memset(&mem[addr & (~0xFFF)], 0, 4096);
					mark = chadCycles() + (uint64_t)ERASE_DELAY;
				} break;
			case 0x03:
				state = read;  break;
			case 0xEB:  dummy = 2;
			case 0x0B:
				state = fastread;  break;
			case 0x32:
				if (qe == 0) { goto notenabled; }
			case 0x02:
				if (wen) { 
					mark = chadCycles() + (uint64_t)BYTE0_DELAY;
					state = write;  break; 
				}
			notenabled:  wen = 0;
				return BAD_NOTENABLED;
			} break;
		}
	case fastread: 
		if (dummy) dummy--; else { state = read; }
		break;
	case read:						// read as long as you want
		cout = 0xFF & ~mem[addr++];
		break;
	case write:						// write byte to flash
		if (mem[addr]) {			// 0 = blank
			wen = 0;  state = wait_;
			return BAD_NOTBLANK;
		}
		mem[addr++] = ~cin;
		mark += (uint64_t)BYTE_DELAY;
		if ((addr & 0xFF) == 0) {	// reached end of write page
			wen = 0;  state = wait_;
		}
		break;
	case wrsra:
		state++;  break;
	case wrsrb:
		qe = cin & 2;				// bit 9 of status write
		mark = chadCycles() + (uint64_t)WRSR_DELAY;
		state = idle;  break;
	default:
		state = idle;
	}
	return cout;
}

// format supports different modes

int32_t FlashMemSPI(uint16_t x) {
	int first = FlashMemSPI8((uint8_t)x);
	if (((format & 1) == 0) || (first & 0x8000))
		return first;
	int second = FlashMemSPI8((uint8_t)x);
	if (second & 0x8000)
		return second;
	return second<<8 | first;		// little endian 16-bit
}

// 000 = 8 - bit SPI
// 001 = 16 - bit SPI
// 100 = 8 - bit QSPI mode receive
// 101 = 16 - bit QSPI mode receive
// 110 = 8 - bit QSPI mode transmit
// 111 = 16 - bit QSPI mode transmit

