//==============================================================================
// flash.h
//==============================================================================
#ifndef __FLASH_H__
#define __FLASH_H__

int LoadFlashMem (char *filename);
int SaveFlashMem (char *filename);

// Start a SPI transfer and return the result, negative result if error.
int FlashMemSPI(int n);

// Set the CSN pin state and the SPI format.
void FlashMemSPIformat(int n);

// Get the status of the SPI hardware, 1 when busy.
int FlashMemSPIbusy(void);

// Flash memory size in bytes
#define FlashMemorySize 0x200000

// The SPI flash clock is the system clock divided by this:
#define clockDivisor 2

#define SYSMHZ 100

// 4K erase delay in system clocks
#define ERASE_DELAY (45000 * SYSMHZ)
#define WRSR_DELAY  (5000 * SYSMHZ)
#define BYTE_DELAY  (3 * SYSMHZ)
#define BYTE0_DELAY (28 * SYSMHZ)

#define BAD_CREATEFILE -198
#define BAD_OPENFILE   -199
#define BAD_NOTBLANK   -60
#define BAD_PAGEFAULT  -69
#define BAD_NOTENABLED -71

#endif // __FLASH_H__
