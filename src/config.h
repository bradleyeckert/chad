//===============================================================================
// config.h
// Basic configuration and function prototype for chad.c
//===============================================================================
#ifndef __CONFIG_H__
#define __CONFIG_H__
#include <stdint.h>

// Sizes of memories in cells, should be an exact power of 2
#define CodeSize  0x800                 /* Code ROM */
#define DataSize  0x400                 /* Data RAM */
#define AppSize  0x2000                 /* Application ROM */
#define StackSize  0x20                 /* Stacks */
#define CodeFence 0x400                 /* Beginning of RAM-based Code space */

#define CELLSIZE     16                 /* Width of a cell in bits */

#define LineBufferSize 256              /* Size of line buffer */
#define MaxKeywords 1024
#define MaxNameSize 16
#define MaxFiles    20

#ifdef _MSC_VER
#define MORESAFE						// Visual Studio wants "safe" functions.
#endif

#if ((CodeSize-1) & CodeSize)
#error CodeSize must be an exact power of 2
#endif
#if ((DataSize-1) & DataSize)
#error DataSize must be an exact power of 2
#endif
#if ((StackSize-1) & StackSize)
#error StackSize must be an exact power of 2
#endif

#endif
