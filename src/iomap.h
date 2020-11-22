//==============================================================================
// iomap.h
//==============================================================================
#ifndef __IOMAP_H__
#define __IOMAP_H__

int writeIOmap (uint32_t addr, uint32_t x);
void killHostIO(void);
int IOtermKey(void);
int IOtermQkey(void);
int IOspiResult(void);

// Load memory spaces from the boot stream
void FlashMemBoot(void);

#define BAD_IOADDR  -70
#define BAD_HOSTAPI -76

extern uint64_t ChadBootKey;

#endif // __IOMAP_H__
