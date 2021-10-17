//===============================================================================
// chaddefs.h
// Local defines for chad.c.
// Define function prototypes (for export) separately in chad.h
//===============================================================================
#ifndef __CHADDEFS_H__
#define __CHADDEFS_H__

#include "config.h"
//#include <stdlib.h>

void ErrorMessage (int error, char *s); // defined in errors.c

#define ALL_ONES  ((unsigned)(~0))
#if (CELLBITS == 32)
#define cell     uint32_t
#define CELLSIZE 5  /* log2(CELLBITS) */
#define CELL_ADDR(x) ((x) >> 2)
#define BYTE_ADDR(x) ((x) << 2)
#elif (CELLBITS > 16)
#define cell     uint32_t
#define CELLSIZE 5  /* # of bits needed to address bits in a cell */
#define CELL_ADDR(x) ((x) >> 1) 
#define BYTE_ADDR(x) ((x) << 1)
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
    FILE* fp;                           // input file pointer
    FILE* hfp;                          // html documentation file pointer
    uint32_t LineNumber;                // line number
    int FID;                            // file ID for LOCATE
};

struct FilePath {
    char filepath[LineBufferSize];      // filename
};

typedef void (*VoidFn)();

struct Keyword {
    char name[MaxNameSize];             // word name, local copy is needed
    char help[MaxAnchorSize];           // help anchor name
    VoidFn ExecFn;                      // C functions for compile/execute
    VoidFn CompFn;
    cell length;                        // size of definition in code space
    cell w;                             // optional data
    cell w2;
    cell target;                        // target address if used
    uint16_t references;                // how many times it has been referenced
    uint16_t link;                      // enough for 64k headers
    cell *aux;                          // pointer to aux C data 
    uint8_t notail;                     // inhibit tail recursion
    uint8_t smudge;                     // hide current definition
    uint8_t isALU;                      // is an ALU word
    uint8_t srcFile;                    // source file ID
    uint16_t srcLine;                   // source line number
    uint32_t color;                     // HTML color
    uint16_t applet;                    // applet ID
};

int chadSpinFunction(void);             // external function waiting for keyboard input

#define NOTANEQU -3412
#define MAGIC_LATER 1000
#define MAGIC_OPCODE 1001

#define COLOR_NONE (0x000000)
#define COLOR_NUM  (0xAA0000)
#define COLOR_ROOT (0x00AAAA)
#define COLOR_WORD (0x0000FF)
#define COLOR_ALU  (0xFF00FF) // ALU predefined instruction
#define COLOR_ASM  (0xCCCCCC) // Assembler sub-field
#define COLOR_DEF  (0xFF0000)
#define COLOR_EQU  (0xAA00AA)
#define COLOR_COM  (0x008800)

// Assembler primitives for the ALU instruction
// Names are chosen to not conflict with Forth or C

#define OPCODE(x) ((x) >> 8)
#define T      (0x00 << 8)
#define cop    (0x10 << 8)
#define less0  (0x01 << 8)
#define carry  (0x11 << 8)
#define shr1   (0x02 << 8)
#define shrx   (0x12 << 8)
#define shl1   (0x03 << 8)
#define shlx   (0x13 << 8)
#define add    (0x04 << 8)
#define Tand   (0x05 << 8)
#define eor    (0x06 << 8)
#define com    (0x16 << 8)

#define swapb  (0x08 << 8)
#define swapw  (0x18 << 8)
#define NtoT   (0x09 << 8)
#define AtoT   (0x19 << 8)
#define RtoT   (0x0A << 8)
#define RM1toT (0x0B << 8)
#define input  (0x0C << 8)
#define read   (0x0D << 8)
#define zeq    (0x0E << 8)
#define who    (0x0F << 8)

#define OPCDnames0 "T\0T0<\0T2/\0T2*\0T+N\0T^N\0T&N\0---"
#define OPCDnames1 "><\0N\0R\0R-1\0io\0M\0T0=\0status"
#define OPCDnames2 "COP\0C\0cT2/\0T2*c\0W\0~T\0T&W\0---"
#define OPCDnames3 "><16\0A\0---\0---\0---\0---\0---\0---"

// The insn[7:4] field of the ALU instruction:

#define STROBE(x) ((x) >> 4)
#define TtoN   (1 << 4)
#define TtoR   (2 << 4)
#define iow    (3 << 4)
#define memrd  (4 << 4)
#define memwr  (5 << 4)
#define memwrb (6 << 4)
#define memwrs (7 << 4)
#define co     (10 << 4)
#define ior    (13 << 4)
#define TtoA   (15 << 4)

#define STROBEnames0 "\0T->N\0T->R\0N->io[T]\0[T]->M\0N->[T]\0N->[T]B\0N->[T]S"
//                      1     2     3         4        5       6        7
#define STROBEnames1 "?\0?\0CO\0?\0?\0io[T]->io\0?\0T->A"
//                    8  9  A   B  C  D       E  F

// The insn[3:2] field of the ALU instruction is return stack control:

#define rup    (1 << 2)
#define ret    (2 << 2)
#define rdn    (3 << 2)

#define ISRET  ((inst & rdn) == ret)
// The insn[1:0] field of the ALU instruction is data stack control:

#define sup    1
#define sdn    3

// Other instruction types

#define INST(x) ((x) >> 13)
#define alu0   (0 << 13)
#define alu1   (1 << 13)
#define lit    (2 << 13)
#define trap   (3 << 13)
#define zjump  (4 << 13)
#define litx   (5 << 13)
#define copop  (0x16 << 11)  /* 1011000 */
#define userop (0x17 << 11)  /* 1011100 */
#define jump   (6 << 13)
#define call   (7 << 13)

#define trapID1 0x1000
#define litSign 0x1000

// userop operation types

#define trcreg  0
#define trcon   1
#define trcoff  2
#define trcclrd 3
#define trcdata 4
#define trcstax 5

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
#define BAD_NOEXECUTE   -14 // Interpreting a compile-only word
#define BAD_ROMWRITE    -20 // Write to a read-only location
#define BAD_UNSUPPORTED -21 // Unsupported operation
#define BAD_CONTROL     -22 // Control structure mismatch
#define BAD_ALIGNMENT   -23 // Address alignment exception
#define BAD_BODY        -31 // >BODY used on non-CREATEd definition
#define BAD_ORDER_OVER  -49 // Search-order overflow
#define BAD_ORDER_UNDER -50 // Search-order underflow
#define BAD_EOF         -58 // unexpected EOF in [IF]
#define BAD_INPUT_LINE  -62 // Input buffer overflow, line too long
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
#define BAD_INCLUDING   -78 // Nesting overflow during include
#define BAD_NOCOMPILE   -79 // Compiling an execute-only word
#define BAD_FSOVERFLOW  -82 // Flash string overflow
#define BAD_COPROCESSOR -84 // Invalid coprocessor field
#define BAD_POSTPONE    -85 // Unsupported postpone
#define BAD_CREATEFILE -198
#define BAD_OPENFILE   -199 // Can't open file
#define BYE            -299

// verbose flags
#define VERBOSE_SOURCE  1   // show the source file line
#define VERBOSE_TOKEN   2   // show the source token (blank-delimited string)
#define VERBOSE_TRACE   4   // simulation trace in human readable form
#define VERBOSE_STKMAX  8   // track and show the maximum stack depth
#define VERBOSE_SRC     16  // display the remaining source in the TIB
#define VERBOSE_DASM    32  // disassemble in long format
