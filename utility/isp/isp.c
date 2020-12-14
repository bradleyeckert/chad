#include <stdio.h>
#include <stdint.h>
#ifdef _WIN32
#include <Windows.h>
#else
#include <unistd.h>
#endif
#include "rs232.h"

/*
Chad ISP utility, C99, tested on Windows. Should compile on Linux/Mac.

The spif interface allows hardware control through the UART stream.
A host PC can control 'spif' through a serial port to:
  - Reset the target CPU
  - Load the SPI flash with new data
  - Reboot the target

Command line parameters are:
<filename> <port#> [baud]
filename is a file path without embedded spaces.
port# is the COM port number.
baud is an optional baud rate.

Serial communication uses https://gitlab.com/Teuniz/RS-232/ for cross-platform
abstraction. Ports are numbered for this. Numbering starts at 0, so COM4 is 3.
*/

#define DEFAULTBAUD 3000000L
#define DEFAULTPORT 12
#define MemorySize  (1024*1024)
#define MAXPORTS 31
//#define VERBOSE

uint32_t crc32b(uint8_t* message, size_t length) {
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

void ms(int msec) {                     // time delay
#ifdef _WIN32
    Sleep(msec);
#else
    usleep(msec * 1000);
#endif
}

uint8_t mem[MemorySize];                // raw data to program
uint8_t response[1024];                 // place to put UART read data
int portnum = DEFAULTPORT;

uint8_t ISP_enable[] = { 4, 0x12, 0xA5, 0x5A, 0x42 };
uint8_t ISP_disable[] = { 2, 0x12, 0 };
uint8_t ISP_RJID[] =  { 7, 0, 0, 0x82, 0x9F, 2, 0xC2, 0x080 };
uint8_t ISP_RDSR[] =  { 6, 0, 0, 0x82, 0x05, 0xC2, 0x80};
uint8_t ISP_WREN[] =  { 5, 0, 0, 0x82, 6, 0x80 };

void Dump(uint8_t* p, int length) {
    for (int i=0; i<length; i++)
        printf("%02X ", *p++);
    printf("\n");
}

void ISP_TX(uint8_t* cstr) {            // send counted string
    #ifdef VERBOSE
    printf("ISP_TX ");  Dump(&cstr[1], cstr[0]);
    #endif
    RS232_SendBuf(portnum, &cstr[1], cstr[0]);
}

// SPIF replaces 10h-13h with {10h, 0-3}.
int GetResponse(int length) {           // get data from the RX buffer
    uint8_t *p = response;
    uint8_t c;
    int tally = 0;
    #ifdef VERBOSE
    printf("ISP_RX");
    #endif // VERBOSE
    for (int i = 0; i < length; i++) {
        int len = RS232_PollComport(portnum, &c, 1);
        if (len == 0) break;
        if (c == 0x10) {
            RS232_PollComport(portnum, &c, 1);
            c = 0x10 + (c & 3);
        }
        *p++ = c;
        tally ++;
        #ifdef VERBOSE
        printf(" %02X", c);
        #endif // VERBOSE
    }
    #ifdef VERBOSE
    printf("\n");
    #endif // VERBOSE
    return tally;
}

void PingOn(void) {
    ISP_TX(ISP_enable);
    ms(50); // Give RS232_PollComport time to receive the ping.
}
void GetRJID(void) {                    // get 3-byte RJID
    ISP_TX(ISP_RJID);
    ms(50);
    if (GetResponse(3) != 3) {
        memset(response, 0, 3);
    }
}

int TestWIP(void) {                     // read status register
    ISP_TX(ISP_RDSR);
    int retry = 100;
    while (retry--) {
        ms(2);
        if (GetResponse(1)) {
            return response[0];
        }
    }
    return -1;
}

void WaitWIP(void) {                    // wait for not busy
    int timer = 30;
    while (timer--) {
        if ((TestWIP() & 1) == 0) return;
    }
    printf("Status read error\n");
}

// Encode an outgoing message that re-maps the special characters (0x10-0x13).
// The sequence includes chip select assert/deassert.

uint8_t pagebuf[512];
uint8_t *pb;
int pagelen;
void AddToBuf(uint8_t c) {
    if ((c & 0xFC) == 0x10) {
        *pb++ = 0x10;
        *pb++ = c & 3;
        pagelen += 2;
    } else {
        *pb++ = c;
        pagelen += 1;
    }
}
void BeginSPI(void) {
    pagelen = 3;
    pb = &pagebuf[3];
    AddToBuf(0x82);
}
void EndSPI(int n) {
    AddToBuf(0x80);
    uint8_t* p = pagebuf;
    uint8_t hi = (n >> 6) & 0x3F;
    uint8_t lo = n & 0x3F;
    if ((lo & 0xFC) == 0x10) {
        *p++ = hi;
        *p++ = 0x10;
        *p++ = lo & 3;
    } else {
        *p++ = 0;
        *p++ = hi;
        *p++ = lo;
    }
    RS232_SendBuf(portnum, pagebuf, pagelen);
    #ifdef VERBOSE
    printf("EndSPI ");  Dump(pagebuf, pagelen);
    #endif
}

int baseblock;

// 00 00 03 82 20 ss s0 00 80
void Erase4K(int sector) {
    ISP_TX(ISP_WREN);
    BeginSPI();
    AddToBuf(0x20);
    AddToBuf(baseblock + (sector >> 4));
    AddToBuf(sector << 4);
    AddToBuf(0);
    EndSPI(3);
    ms(50);         // typical erase time is about 50 ms
    WaitWIP();      // it could be longer
}

// 00 uu uu 82 02 pp pp 00 xx xx xx xx ... 80
void ProgramPage(int page) {
    ISP_TX(ISP_WREN);
    BeginSPI();
    AddToBuf(0x02);
    AddToBuf(baseblock + (page >> 8));
    AddToBuf(page);
    AddToBuf(0);
    uint8_t* src = &mem[page << 8];
    for (int i = 0; i < 256; i++)
        AddToBuf(*src++);
    EndSPI(259);
    ms(5);
//    WaitWIP();
}

// 00 00 03 82 0B pp pp 00 03 3F C2 80
// return ior: 0 = okay, -1 = no response to read request, 1 = bad data
int ReadPage(int page) {
    BeginSPI();
    AddToBuf(0x0B);
    AddToBuf(baseblock + (page >> 8));
    AddToBuf(page);
    AddToBuf(0);
    AddToBuf(0);            // dummy byte
    AddToBuf(0x03);
    AddToBuf(0x3F);
    AddToBuf(0xC2);
    EndSPI(4);
    ms(20);
    int x = GetResponse(256);
    if (x == 256)
         return 1 & memcmp(&mem[page<<8], response, 256);
    return -1;
}

int main(int argc, char *argv[])
{
    int baudrate = DEFAULTBAUD;
    if (argc < 2) {
		printf("Usage: 'isp filename [port#] [baud]'\n");
		printf("Possible port#:");
		for (int i = 0; i < MAXPORTS; i++) {
            if (RS232_OpenComport(i, baudrate, "8N1", 0) == 0) {
                RS232_CloseComport(i);
                printf(" %d", i);
            }
		}
		return 1;
	}
	FILE* inf = fopen(argv[1], "rb");
	if (!inf) {
		printf("Input file <%s> not found\n", argv[1]);
		return 1;
	}
    if (argc > 3) {
        char* p = argv[3];
        baudrate = 0;
        char c;
        while ((c = *p++)) baudrate = baudrate * 10 + (c - '0');
    }
    if (argc > 2) {
        char* p = argv[2];
        portnum = 0;
        char c;
        while ((c = *p++)) portnum = portnum * 10 + (c - '0');
    }
    char str[4];
    fread(str, 1, 4, inf);
    if (memcmp(str, "chad", 4)) {
        printf("Not a firmware file\n");
        fclose(inf);
        return 2;
    }
    uint32_t pid, length, crc;

    fread(&pid, 1, 4, inf);
    fread(&length, 1, 4, inf);
    fread(&crc, 1, 4, inf);
    size_t oal = fread(mem, 1, MemorySize, inf);
    fclose(inf);
    if ((length != oal) || (crc != crc32b(mem, oal))) {
        printf("Corrupted file (bad CRC)\n");
        return 2;
    }

    if (RS232_OpenComport(portnum, baudrate, "8N1", 0)) {
        printf("Can't open com port %d\n", portnum);
        return 3;
    }

    printf("Opened port %d at %d BPS\n", portnum, baudrate);

/*
At this point, the file has been read-in and checked. The serial port is open.
Now we want to ping the target to make sure it's there and to match it up with
the pid number.
*/
    PingOn();
    int pingLength = GetResponse(7);
    if (pingLength != 7) {
        printf("No ping\n");
        return 4;
    }
/*
The PING byte of ISP_enable (0x42) sends 5 bytes out the UART:
BASEBLOCK    first 64KB sector of user flash
PRODUCT_ID   product ID, 16-bit little-endian
KEY_ID       key ID, 8-bit
SERIALNUM    16-bit serial number
SANITY       0xAA constant
*/
    if (response[6] != 0xAA) {
        printf("Ping failure\n");
        ISP_TX(ISP_disable);
        return 5;
    }
/*
Firmware has hardware dependencies requiring BASEBLOCK, PRODUCT_ID, and
KEY_ID to match up.
*/
    if (memcmp(&pid, response, 4)) {
        printf("Firmware does not match hardware\n");
        printf("You need firmware type %06X\n", (pid & 0xFFFFFF));
        ISP_TX(ISP_disable);
        return 5;
    }
/*
Yay! You're connected to the ISP, ready to access the SPI flash chip.
Program length/4096 sectors
*/
    GetRJID();
    printf("RJID = %d, %d, %d\n", response[0], response[1], response[2]);

    int sectors = (length + 4095) >> 12;
    int errors = 0;
    baseblock = (uint8_t)pid;

    printf("Programming %d 4KB sectors starting at addr %02X0000", sectors, baseblock);

    for (int i=0; i < sectors; i++) {
        printf("\nSector %d ", i);
        Erase4K(i);
        for (int j = 0; j < 16; j++) {
            int page = (i << 4) + j;
            ProgramPage(page);
            if (ReadPage(page))
                { printf("?"); errors++; }
            else
                { printf("."); }
        }
    }
    printf("\n%d errors", errors);

    ISP_TX(ISP_disable);

    ms(50);
    RS232_CloseComport(portnum);
}

