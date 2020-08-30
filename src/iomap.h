//==============================================================================
// iomap.h
//==============================================================================
#ifndef __IOMAP_H__
#define __IOMAP_H__

uint32_t readIOmap (uint32_t addr);
void writeIOmap (uint32_t addr, uint32_t x);

#define BAD_IOADDR -70

#endif // __IOMAP_H__
