//===============================================================================
// chaddefs.h
// Local defines for chad.c.
// Define function prototypes (for export) separately in chad.h
//===============================================================================
#ifndef __CHADDEFS_H__
#define __CHADDEFS_H__

#include "config.h"

void ErrorMessage (int error, char *s); // defined in errors.c

#if (CELLSIZE > 16)
    #define cell     uint32_t
    #define CELLS         1                 /* log2(bytes per cell) */
#elif (CELLSIZE == 32)
    #define cell     uint32_t
    #define CELLS         2
#else
    #define cell     uint16_t
    #define CELLS         1
#endif

#define File FileStack[filedepth]
#if (CELLSIZE < 32)
#define CELLMASK (~((~0)<<CELLSIZE))
#define MSB      (1 << (CELLSIZE-1))
#else
#define CELLMASK 0xFFFFFFFF
#define MSB      0x80000000
#endif
#define RPMASK   (StackSize-1)
#define RDEPTH   (rp & RPMASK)
#define SPMASK   (StackSize-1)
#define SDEPTH   (sp & SPMASK)
#define SV static void
#define SI static int
#define CELL static cell

#define SP sp
#define RP rp

struct FileRec {
    char Line[LineBufferSize];          // the current input line
    char FilePath[LineBufferSize];      // filename
    FILE *fp;                           // file pointer
    uint32_t LineNumber;                // line number
    int FID;                            // file ID for LOCATE
};

typedef void (*VoidFn)();

struct Keyword {
    char  name[MaxNameSize];            // a name and
    VoidFn ExecFn;                      // C functions for compile/execute
    VoidFn CompFn;
    cell length;                        // size of definition in code space
    cell w;                             // optional data
    cell w2;
    cell notail;                        // inhibit tail recursion
    cell context;                       // 1=Forth, 2=assembler
    cell target;                        // target address if used
};

#define BYE -299
#define NOTANEQU -3412

// Assembler primitives for the ALU instruction
// Names are chosen to not conflict with Forth or C

#define alu    0x0000
#define less0  0x0100
#define carry  0x1100
#define shr1   0x0200
#define shrx   0x1200
#define shl1   0x0300
#define shlx   0x1300
#define NtoT   0x0400
#define eor    0x0500
#define com    0x1500
#define Tand   0x0600
#define mask   0x1600
#define shr8   0x0700
#define shl8   0x1700
#define add    0x0800
#define addc   0x1800
#define sub    0x0900
#define subc   0x1900
#define zeq    0x0A00
#define shr    0x0B00
#define shl    0x0C00
#define RtoT   0x0D00
#define RM1toT 0x1D00
#define read   0x0E00
#define input  0x1E00
#define who    0x0F00

// The insn[7] bit of the ALU enables return

#define ret    0x0080

// The insn[6:4] field of the ALU instruction is:

#define TtoN   0x0010
#define TtoR   0x0020
#define write  0x0030
#define iow    0x0040
#define ior    0x0050
#define co     0x0060

// The insn[3:2] field of the ALU instruction is return stack control:

#define rup    0x0004
#define rdn2   0x0008
#define rdn    0x000C

// The insn[1:0] field of the ALU instruction is data stack control:

#define sup    0x0001
#define sdn2   0x0002
#define sdn    0x0003

// Other instruction types

#define jump   0x8000
#define zjump  0xA000
#define call   0xC000
#define litx   0xE000
#define lit    0xF000

#endif

// 0uvppppp Rwwwrrss = ALU op
// 	x = unused
// 	u = use tail pointer instead of head pointer for return stack
// 	v = use tail pointer instead of head pointer for data stack
// 	p = 5-bit ALU operation select
// 	R = return
// 	w = strobe select {-, TN, TR, wr, iow, ior, co, ?}
// 	r = return stack displacement
// 	s = data stack displacement
// 100nnnnn nnnnnnnn = jump
// 101nnnnn nnnnnnnn = conditional jump
// 110nnnnn nnnnnnnn = call
// 1110kkkk kkkkkkkk = literal extension
// 1111nnnn Rnnnnnnn = unsigned literal


// THROW Codes

#define BAD_DATA_WRITE  -64 // Write to non-existent data memory
#define BAD_DATA_READ   -65 // Read from non-existent data memory
#define BAD_PC          -66 // PC is in non-existent code memory
#define BAD_ROMWRITE    -20 // Write to a read-only location
#define BAD_CODE_WRITE  -67 // Write to non-existent code memory
#define BAD_CONTROL     -22 // Control structure mismatch
#define BAD_NOCOMPILE   -14 // Interpreting a compile-only word
#define BAD_UNSUPPORTED -21 // Unsupported operation
#define BAD_OPENFILE   -199 // Can't open file
#define BAD_INCLUDING   -99 // Nesting overflow during include
#define UNRECOGNIZED    -13 // Unrecognized word
#define BAD_ASSERT      -68 // Test failure

