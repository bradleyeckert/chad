//==============================================================================
// iomap.h
//==============================================================================
#ifndef __IOMAP_H__
#define __IOMAP_H__

uint32_t readIOmap (uint32_t addr);
void writeIOmap (uint32_t addr, uint32_t x);

extern char * LoadFlashFilename;

#endif // __IOMAP_H__
