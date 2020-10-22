#include <stdio.h>
#include <stdint.h>
#include <windows.h>

/* 
Chad ISP utility

The 'spif' interface is set up to allow hardware control through the UART stream.
A host PC can control 'spif' through a serial port to:
  - Reset the target CPU
  - Load the SPI flash with new data
  - Reboot the target

Command line parameters are:
<filename> <portname> [baud]
filename is a file path without embedded spaces.
portname is the COM port name to test, such as "COM4".
baud is an optional baud rate.
*/

#define DEFAULTBAUD 1000000L
#define MemorySize  (1024*1024)

// Opens the specified serial port, configures its timeouts, and sets its
// baud rate.  Returns a handle on success, or INVALID_HANDLE_VALUE on failure.
HANDLE open_serial_port(const char* device, uint32_t baud_rate)
{
    HANDLE port = CreateFileA(device, GENERIC_READ | GENERIC_WRITE, 0, NULL,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (port == INVALID_HANDLE_VALUE)
    {
        return INVALID_HANDLE_VALUE;
    }

    // Flush away any bytes previously read or written.
    BOOL success = FlushFileBuffers(port);
    if (!success)
    {
        printf("Failed to flush serial port\n");
        CloseHandle(port);
        return INVALID_HANDLE_VALUE;
    }

    // Configure read and write operations to time out after 100 ms.
    COMMTIMEOUTS timeouts = { 0 };
    timeouts.ReadIntervalTimeout = 0;
    timeouts.ReadTotalTimeoutConstant = 100;
    timeouts.ReadTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 100;
    timeouts.WriteTotalTimeoutMultiplier = 0;

    success = SetCommTimeouts(port, &timeouts);
    if (!success)
    {
        printf("Failed to set serial timeouts\n");
        CloseHandle(port);
        return INVALID_HANDLE_VALUE;
    }

    DCB state;
    state.DCBlength = sizeof(DCB);
    success = GetCommState(port, &state);
    if (!success)
    {
        printf("Failed to get serial settings\n");
        CloseHandle(port);
        return INVALID_HANDLE_VALUE;
    }

    state.BaudRate = baud_rate;

    success = SetCommState(port, &state);
    if (!success)
    {
        printf("Failed to set serial settings\n");
        CloseHandle(port);
        return INVALID_HANDLE_VALUE;
    }

    return port;
}

// Writes bytes to the serial port, returning 0 on success and -1 on failure.
int write_port(HANDLE port, uint8_t* buffer, size_t size)
{
    DWORD written;
    BOOL success = WriteFile(port, buffer, size, &written, NULL);
    if (!success)
    {
        printf("Failed to write to port\n");
        return -1;
    }
    if (written != size)
    {
        printf("Failed to write all bytes to port\n");
        return -1;
    }
    return 0;
}

// Reads bytes from the serial port.
// Returns after all the desired bytes have been read, or if there is a
// timeout or other error.
// Returns the number of bytes successfully read into the buffer, or -1 if
// there was an error reading.
SSIZE_T read_port(HANDLE port, uint8_t* buffer, size_t size)
{
    DWORD received;
    BOOL success = ReadFile(port, buffer, size, &received, NULL);
    if (!success)
    {
        printf("Failed to read from port\n");
        return -1;
    }
    return received;
}

uint32_t crc32b(uint8_t* message, int length) {
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

HANDLE port;
uint8_t mem[MemorySize];


int main(int argc, char *argv[])
{
	int baudrate = DEFAULTBAUD;
	if (argc < 3) {
		printf("Usage: 'isp filename portname [baud]'\n\n");
		return 1;
	}
#pragma warning(suppress : 4996)
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
    int oal = fread(mem, 1, MemorySize, inf);
    fclose(inf);
    if ((length != oal) || (crc != crc32b(mem, oal))) {
        printf("Corrupted file (bad CRC)\n");
        return 2;
    }

    port = open_serial_port(argv[2], baudrate);
    if (port == INVALID_HANDLE_VALUE) {
        printf("Couldn't open serial port %s at %d baud\n", argv[2], baudrate);
        return 1;
    }

/* 
At this point, the file has been read-in and checked. The serial port is open.
Now we want to ping the target to make sure it's there and to match it up with
the pid number.

As you can see, this is on the to-do list.
*/

    printf("File=%s, port=%s, baud=%d\n", argv[1], argv[2], baudrate);
    CloseHandle(port);
}

