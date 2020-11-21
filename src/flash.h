//==============================================================================
// flash.h
//==============================================================================
#ifndef __FLASH_H__
#define __FLASH_H__

int LoadFlashMem(char *filename);
int SaveFlashMem(char* filename, uint32_t pid);
int SaveFlashMemHex(char* filename, int baseblock);

// Write byte to flash directly, used to build boot list
void FlashMemStore(uint32_t addr, uint8_t c);

// Set the CSN pin state and the SPI format.
void FlashMemSPIformat(int n);

// 8-bit transfer via SPI: Send byte to SPI flash and receive the result byte.
int FlashMemSPI8(uint8_t cin);

// Flash memory size in bytes
#define FlashMemorySize 0x200000

// The SPI flash clock is the system clock divided by this:
#define clockDivisor 2

#define SYSMHZ 150

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
#define BAD_FLASHADDR  -83

#endif // __FLASH_H__
