//===============================================================================
// config.h
// Basic configuration and function prototype for chad.c
//===============================================================================
#ifndef __CONFIG_H__
#define __CONFIG_H__
#include <stdint.h>

#define CELLBITS        32      /* Width of a cell in bits, 16 to 32        */
// Sizes of memories in cells, should be an exact power of 2
#define CodeSize      2048      /* Code memory cells                        */
#define DataSize      1024      /* Data memory cells                        */
#define StackAwidth      5      /* log2(Stack cells)                        */
#define CodeFence     1024      /* Beginning of RAM-based Code space        */

#define EnableCPUchecks         /* Simulator has more instrumentation       */

#define LineBufferSize 256      /* Size of line buffer                      */
#define MaxKeywords   2000      /* Number of headers                        */
#define MaxNameSize     32      /* Number of chars in a name (less 1)       */
#define MaxFiles        20      /* Max depth of file nesting                */
#define MaxWordlists    20      /* Max number of wordlists                  */

#ifdef _MSC_VER                 /* Visual Studio wants "safe" functions.    */
#define MORESAFE                /* Compiler supports them (C11, C17, etc).  */
#endif

#define StackSize  (1 << StackAwidth)

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
