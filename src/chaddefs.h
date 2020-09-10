//===============================================================================
// chaddefs.h
// Local defines for chad.c.
// Define function prototypes (for export) separately in chad.h
//===============================================================================
#ifndef __CHADDEFS_H__
#define __CHADDEFS_H__

#include "config.h"

void ErrorMessage (int error, char *s); // defined in errors.c

#define ALL_ONES  ((unsigned)(~0))
#if (CELLBITS == 32)
#define cell     uint32_t
#define CELLSIZE 5  /* log2(CELLBITS) */
#define CELL_ADDR(x) (x >> 2)
#define BYTE_ADDR(x) (x << 2)
#elif (CELLBITS > 16)
#define cell     uint32_t
#define CELLSIZE 5  /* # of bits needed to address bits in a cell */
#define CELL_ADDR(x) (x >> 1) 
#define BYTE_ADDR(x) (x << 1)
#else
#define cell     uint16_t
#define CELLSIZE 4
#define CELL_ADDR(x) (x >> 1)
#define BYTE_ADDR(x) (x << 1)
#endif

#if (CELLBITS < 32)
#define CELLMASK (~(ALL_ONES<<CELLBITS))
#define MSB      (1 << (CELLBITS-1))
#else
#define CELLMASK 0xFFFFFFFF
#define MSB      0x80000000
#endif

#define CELLS    (BYTE_ADDR(1))
#define File FileStack[filedepth]
#define RPMASK   (StackSize-1)
#define RDEPTH   (rp & RPMASK)
#define SPMASK   (StackSize-1)
#define SDEPTH   (sp & SPMASK)
#define CELL_AMASK ((1 << CELLSIZE) - 1) /* 15 or 31 */
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
    char name[MaxNameSize];             // word name, local copy is needed
    VoidFn ExecFn;                      // C functions for compile/execute
    VoidFn CompFn;
    cell length;                        // size of definition in code space
    cell w;                             // optional data
    cell w2;
    cell target;                        // target address if used
    uint16_t references;
    uint16_t link;                      // enough for 64k headers
    cell *aux;                          // pointer to aux C data 
    uint8_t notail;                     // inhibit tail recursion
    uint8_t isALU;                      // is an ALU word
};

int chadSpinFunction(void);             // external function waiting for keyboard input

#define NOTANEQU -3412
#define MAGIC_DEFER 1000

// Assembler primitives for the ALU instruction
// Names are chosen to not conflict with Forth or C

#define alu    (0x00 << 9)
#define cop    (0x10 << 9)
#define less0  (0x01 << 9)
#define carry  (0x11 << 9)
#define shr1   (0x02 << 9)
#define shrx   (0x12 << 9)
#define shl1   (0x03 << 9)
#define shlx   (0x13 << 9)
#define NtoT   (0x04 << 9)
#define WtoT   (0x14 << 9)
#define eor    (0x05 << 9)
#define com    (0x15 << 9)
#define Tand   (0x06 << 9)
#define TandW  (0x16 << 9)
#define bmask  (0x07 << 9)
#define add    (0x08 << 9)
#define addc   (0x18 << 9)
#define sub    (0x09 << 9)
#define subc   (0x19 << 9)
#define zeq    (0x0A << 9)
#define shr    (0x0B << 9)
#define shl    (0x0C << 9)
#define RtoT   (0x0D << 9)
#define RM1toT (0x1D << 9)
#define read   (0x0E << 9)
#define input  (0x1E << 9)
#define who    (0x0F << 9)

// The insn[8] bit of the ALU enables return

#define ret    (1 << 8)

// The insn[7:4] field of the ALU instruction is:

#define TtoN   (1 << 4)
#define TtoR   (2 << 4)
#define write  (3 << 4)
#define memrd  (4 << 4)
#define iow    (5 << 4)
#define ior    (6 << 4)
#define co     (7 << 4)

// The insn[3:2] field of the ALU instruction is return stack control:

#define rup    (1 << 2)
#define rdn2   (2 << 2)
#define rdn    (3 << 2)

// The insn[1:0] field of the ALU instruction is data stack control:

#define sup    1
#define sdn2   2
#define sdn    3

// Other instruction types

#define jump   (4 << 13)
#define zjump  (5 << 13)
#define call   (6 << 13)
#define litx   (28 << 11)
#define copid  (29 << 11)
#define lit    (15 << 12)

#endif

// 0xpppppx Rwwwrrss = ALU op
//  x = unused
//  p = 5-bit ALU operation select
//  R = return
//  w = strobe select {-, TN, TR, wr, iow, ior, co, ?}
//  r = return stack displacement
//  s = data stack displacement
// 100nnnnn nnnnnnnn = jump
// 101nnnnn nnnnnnnn = conditional jump
// 110nnnnn nnnnnnnn = call
// 1110kkkk kkkkkkkk = literal extension
// 1111nnnn Rnnnnnnn = unsigned literal


// THROW Codes

#define BAD_STACKOVER    -3 // Stack overflow
#define BAD_STACKUNDER   -4 // Stack underflow
#define BAD_RSTACKOVER   -5 // Return stack overflow
#define BAD_RSTACKUNDER  -6 // Return stack underflow
#define DIV_BY_ZERO     -10 // Division by 0
#define UNRECOGNIZED    -13 // Unrecognized word
#define BAD_NOCOMPILE   -14 // Interpreting a compile-only word
#define BAD_ROMWRITE    -20 // Write to a read-only location
#define BAD_UNSUPPORTED -21 // Unsupported operation
#define BAD_CONTROL     -22 // Control structure mismatch
#define BAD_ALIGNMENT   -23 // Address alignment exception
#define BAD_BODY        -31 // >BODY used on non-CREATEd definition
#define BAD_ORDER_OVER  -49 // Search-order overflow
#define BAD_ORDER_UNDER -50 // Search-order underflow
#define BAD_EOF         -58 // unexpected EOF in [IF]
#define BAD_DATA_WRITE  -64 // Write to non-existent data memory
#define BAD_DATA_READ   -65 // Read from non-existent data memory
#define BAD_PC          -66 // PC is in non-existent code memory
#define BAD_CODE_WRITE  -67 // Write to non-existent code memory
#define BAD_ASSERT      -68 // Test failure
#define BAD_ALU_OP      -72 // Invalid ALU code
#define BAD_BITFIELD    -73 // Bitfield is too wide for a cell
#define BAD_IS          -74 // Trying to IS a non-DEFER
#define BAD_WID_OVER    -75 // Too many WORDLISTs
#define BAD_DOES        -77 // Invalid CREATE DOES> usage
#define BAD_INCLUDING   -99 // Nesting overflow during include
#define BAD_CREATEFILE -198
#define BAD_OPENFILE   -199 // Can't open file
#define BYE            -299

// verbose flags
#define VERBOSE_SOURCE  1
#define VERBOSE_TOKEN   2
#define VERBOSE_TRACE   4
#define VERBOSE_SRC     8
