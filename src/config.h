//===============================================================================
// config.h
// Basic configuration for chad.c
//===============================================================================
#ifndef __CONFIG_H__
#define __CONFIG_H__
#include <stdint.h>

#define CELLBITS        24      /* Width of a cell in bits, 16 to 32        */
// Sizes of memories in cells, should be an exact power of 2
#define CodeSize      4096      /* Code memory 16-bit words                 */
#define CodeCache      512      /* Size of cache region                     */
#define DataSize      2048      /* Data memory cells                        */
#define DataCache      256      /* Size of cache region                     */
#define StackAwidth      5      /* log2(Stack cells)                        */
#define CodeAlignment    1      /* Alignment for new definitions            */

#define MoreInstrumentation     /* Simulator has more instrumentation       */
//#define HASFLOATS             /* Dotted numbers are floating point        */

#define LineBufferSize 128      /* Size of line buffer                      */
#define MaxLineLength   80      /* Max TIB size                             */
#define MaxKeywords   2000      /* Number of headers                        */
#define MaxNameSize     32      /* Number of chars in a name (less 1)       */
#define MaxAnchorSize   40      /* Number of chars in an anchor string (-1) */
#define MaxFiles        16      /* Max open files                           */
#define MaxFilePaths    32      /* Max unique files                         */
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

#define COP_OPTIONS 15	/* Coprocessor options */

//Set these up in the project's build configuration
//#define HAS_LCDMODULE			/* Include LCD module in I/O map			*/
//#define HAS_LEDSTRIP			/* Include LED strip in I/O map				*/

#endif
