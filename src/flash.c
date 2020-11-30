#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "config.h"
#include "flash.h"
#include "chad.h"

/*
Flash Memory Simulator
The interface to flash memory is through a SPI interface.

Flash memory is a static array of bytes that C initializes to 0.
Read and write invert the data so that blank means 0xFF.
Chad can call LoadFlashMem to initialize it from a file.

The flash memory may be relocated by non-zero BASEBLOCK so that the
beginning of physical memory is reserved for a FPGA bitstream.
*/

//#define VERBOSE

static uint8_t mem[FlashMemorySize];
static uint8_t boilerplate[16];

#define BASEBLOCK boilerplate[4]		// 64K block of physical memory

void FlashMemStore(uint32_t addr, uint8_t c) {
	if (addr < FlashMemorySize)
		mem[addr] = ~c;
}

static void invertMem(uint8_t* m, uint32_t n) {
	while (n--) {
		uint8_t c = *m;
		*m++ = ~c;
	}
}

static uint32_t crc32b(uint8_t* message, uint32_t length) {
	uint32_t crc = 0xFFFFFFFF;			// compute CRC32
	while (length--) {
		crc = crc ^ (*message++);		// Get next byte.
		for (int j = 7; j >= 0; j--) {	// Do eight times.
			uint32_t mask = -(signed)(crc & 1);
			crc = (crc >> 1) ^ (0xEDB88320 & mask);
		}
	}
	return ~crc;
}

int FlashBaseBlock(void) {
	return BASEBLOCK;
}

// load binary image
// origin=0 is a special case: initialize flash and skip the boilerplate.
// otherwise, you can load raw data at an offset without clearing memory.

int LoadFlashMem(char* filename, uint32_t origin) { 
	if (origin == 0)
		memset(mem, 0, FlashMemorySize); // erase entire flash
	FILE* fp;
#ifdef MORESAFE
	errno_t err = fopen_s(&fp, filename, "rb");
#else
	fp = fopen(filename, "rb");
#endif
	if (fp == NULL) return BAD_OPENFILE;
	if (origin == 0)
		fread(boilerplate, 1, 16, fp);	// get boilerplate
	uint32_t length = fread(&mem[origin], 1, FlashMemorySize - origin, fp);
	invertMem(&mem[origin], length);
	fclose(fp);
	return 0;
}

// Save binary image
// A little extra is saved in case the last byte(s) are unintentional 0xFF
// caused by the PRNG xoring.
// the low byte of pid is the BASEBLOCK number, other bytes are product ID.
int SaveFlashMem(char* filename, uint32_t pid) {
	BASEBLOCK = (uint8_t)pid;
	uint32_t i = FlashMemorySize;
	while ((i) && (mem[--i] == 0)) {}   // trim
	i += 0x140;  
	if (i > FlashMemorySize) i = FlashMemorySize;
	i &= 0xFFFFFF00L;					// round to 256-byte page
	FILE* fp;
#ifdef MORESAFE
	errno_t err = fopen_s(&fp, filename, "wb");
#else
	fp = fopen(filename, "wb");
#endif
	if (fp == NULL) return BAD_CREATEFILE;
	fwrite("chad", 1, 4, fp);			// boilerplate: "chad"
	fwrite(&pid, 1, 4, fp);			    // product ID
	fwrite(&i, 1, 4, fp);			    // length
	invertMem(mem, i);
	uint32_t crc = crc32b(mem, i);
	fwrite(&crc, 1, 4, fp);			    // crc
	fwrite(mem, 1, i, fp);
	invertMem(mem, i);
	fclose(fp);
	return 0;
};

int SaveFlashMemHex(char* filename, int baseblock) {
	int i = FlashMemorySize;
	while ((i) && (mem[--i] == 0)) {}   // trim
	if (!i) return 0;                   // nothing to save
	i++;								// include both endpoints
	FILE* fp;
#ifdef MORESAFE
	errno_t err = fopen_s(&fp, filename, "w");
#else
	fp = fopen(filename, "w");
#endif
	if (fp == NULL) return BAD_CREATEFILE;
	invertMem(mem, i);
	fprintf(fp, "@%02X0000\n", baseblock);
	for (int n = 0; n < i; n++)
		fprintf(fp, "%02X\n", mem[n]);
	invertMem(mem, i);
	fclose(fp);
	return 0;
};

/*------------------------------------------------------------------------------
| Name   | Hex | Command                           |
|:-------|-----|----------------------------------:|
| QFR    | EBh | Read Data Bytes from Memory, QSPI |
| FR     | 0Bh | Read Data Bytes from Memory       |
| PP     | 02h | Page Program Data Bytes to Memory |
| SER    | 20h | Sector Erase 4KB                  |
| WREN   | 06h | Write Enable                      |
| WRDI   | 04h | Write Disable                     |
| RDSR   | 05h | Read Status Register              |
| RDJDID | 9Fh | Read 3-byte JEDEC ID              |
*/

enum states {
	idle, wait_, rdsr, rdsrh, wrsra, wrsrb, jid1, jid2, jid3,
	addr2, addr1, addr0, cmd, fastread, read, write
};

enum states state = idle;               // FSM state
static uint8_t format;                  // SPI format, 0 = 1-bit
static uint64_t mark;                   // Flash time-out

void FlashMemSPIformat(int n) {
	format = 7 & (n >> 1);				// basically ignored
	if (n == 0)
		state = idle;                   // CS line = inactive
#ifdef VERBOSE
	if (n)
		printf("[%d:", format);
	else
		printf("]\n");
#endif
}

static int FlashBusy(void) {
	return (chadCycles() < mark) ? 1 : 0;
}

// Simulate a byte connection to SPI flash: 8-bit in, 8-bit out.
// Return value is the SPI return or error code
// RDJDID (9F command) is custom: 0xAA, 0xHH, 0xFF number of 4K blocks

int FlashMemSPI8(uint8_t cin) {
	static uint8_t command = 0;         // current command
	static uint8_t wen = 0;             // write enable
	static uint8_t qe = 2;              // quad rate enable
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
		case 0x01: if (wen) { state = wrsra; }  break;
		case 0x06: state = wait_;  wen = 2;     break;
		case 0x04: state = wait_;  wen = 0;     break;
		case 0x35: state = rdsrh;               break;
		case 0x05: state = rdsr;                break;
		case 0xEB: // quad rate commands must have QE set
		case 0x32: if (qe == 0) { break; }
		case 0x0B: /* FR  opcd A2 A1 A0 xx -- data... */
		case 0x02: /* PP  opcd A2 A1 A0 d0 d1 d2 ... */
		case 0x20: /* SER4K */  state = addr2;  break;
		case 0x9F: /* RDJDID */ state = jid1;   break;
		} break;
	case wait_: break;				// wait for trailing CS
	case rdsr: cout = wen + FlashBusy();        break;
	case rdsrh: cout = qe;                      break;
	case jid1: cout = 0xAA;  state = jid2;      break;
	case jid2: cout = 0xFF & (FlashMemorySize >> 24);
		state = jid3;  break;
	case jid3: cout = 0xFF & (FlashMemorySize >> 16);
		state = wait_;  break;
	case addr2: addr = (cin - BASEBLOCK) << 16;
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
			case 0x20: // 4K erase
				if (wen) {
					wen = 0;
					memset(&mem[addr & (~0xFFF)], 0, 4096);
					mark = chadCycles() + (uint64_t)ERASE_DELAY;
				} break;
			case 0x03: // slow read
				state = read;  break;
			case 0xEB:  dummy = 2;
			case 0x0B: // fast read
				state = fastread;  break;
			case 0x32: // QDR page write
				if (qe == 0) { goto notenabled; }
			case 0x02: // page write
				if (wen) {
					mark = chadCycles() + (uint64_t)BYTE0_DELAY;
					state = write;  break;
				}
			notenabled:  wen = 0;
				return BAD_NOTENABLED;
			} break;
		} return BAD_FLASHADDR;
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

