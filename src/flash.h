//==============================================================================
// flash.h
//==============================================================================
#ifndef __FLASH_H__
#define __FLASH_H__

int LoadFlashMem (char *filename);
int SaveFlashMem (char *filename);
int FlashMemSPI8 (int n);

// Flash memory size in bytes
#define FlashMemorySize 0x200000

#define BAD_CREATEFILE -198 
#define BAD_OPENFILE   -199 
#define BAD_NOTBLANK   (-60 * 256)
#define BAD_PAGEFAULT  (-69 * 256)

#endif // __FLASH_H__
