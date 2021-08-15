#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#ifdef _MSC_VER
#include <conio.h>
#include <Windows.h>
static uint64_t GetMicroseconds() {
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    unsigned long long tt = ft.dwHighDateTime;
    tt <<= 32;
    tt |= ft.dwLowDateTime;
    tt /= 10;
    tt -= 11644473600000000ULL;
    return tt;
}
#else
#include <sys/time.h> // GCC library
static uint64_t GetMicroseconds() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * (uint64_t)1000000 + tv.tv_usec;
}
#endif

#include <string.h>
#include <inttypes.h>
#include <ctype.h>
#include <math.h>
#include "chaddefs.h"
#include "iomap.h"
#include "config.h"
#include "flash.h"
#include "gecko.h"

SI verbose = 0;
static uint8_t sp, rp;                  // stack pointers
CELL t, pc, cy, lex, w;                 // registers
CELL Data[DataSize];                    // data memory
CELL Dstack[StackSize];                 // data stack
CELL Rstack[StackSize];                 // return stack
CELL Raddr;                             // data memory read address
SI error;                               // simulator and interpreter error code

// Shared variables: The first three must be grouped together in this order.
#define toin    0                       // pointer to next character
#define tibs    (toin + 1)              // chars in input buffer
#define atib    (tibs + 1)              // address of input buffer
#define dp      (atib + 1)              // data space pointer
#define cp      (dp   + 1)              // code space pointer
#define base    (cp   + 1)              // use cells not bytes for compatibility
#define wids    (base + 1)              // table of target wids[8]
#define orders  (wids + 9)              // # of wids in the search order
#define order   (orders + 1)            // search order stack[8]
#define current (order + 9)             // wid of the current definition
#define state   (current + 1)           // compile if set else interpret
#define api     (state + 1)             // current API page
#define here    (api + 1)               // first free variable

#define TOIN    Data[toin]
#define TIBS    Data[tibs]
#define ATIB    Data[atib]
#define DP      Data[dp]
#define CP      Data[cp]
#define BASE    Data[base]
#define ORDERS  Data[orders]
#define ORDER(x) Data[order + (x)]
#define CURRENT Data[current]
#define CONTEXT ORDER(ORDERS - 1)
#define STATE   Data[state]
#define API     Data[api]

SV Hex(void) { BASE = 16; }
SV Decimal(void) { BASE = 10; }
SV toImmediate(void) { STATE = 0; }
SV toCompile(void) { STATE = 1; }
CELL DisassembleInsn(cell IR);

static char* itos(uint32_t x, uint8_t radix, int8_t digits, int isUnsigned) {
    static char buf[32];                // itoa replacement
    uint32_t sign = (x & (1 << (CELLBITS - 1)));
    if (isUnsigned) {
        sign = 0;
    }
    else {
        if (sign) x = (~x) + 1;
        x &= CELLMASK;
    }
    int i = 32;  buf[--i] = 0;
    do {
        char c = x % radix;
        if (c > 9) c += 7;
        buf[--i] = c + '0';
        x /= radix;
        digits--;
    } while ((x && (i >= 0)) || (digits > 0));
    if (sign) buf[--i] = '-';
    return &buf[i];
}

SV Cdot(cell x) {
    printf("%s ", itos(x, BASE, 0, 0));
}

SV PrintDataStack(void) {
    int depth = SDEPTH;
    for (int i = 0; i < depth; i++) {
        if (i == (depth - 1)) {
            Cdot(t);
        }
        else {
            Cdot(Dstack[(i + 2) & SPMASK]);
        }
    }
}

SV PrintReturnStack(void) {
    int depth = RDEPTH;
    if (depth == (RPMASK - 1)) depth = 0;
    for (int i = 0; i < depth; i++) {
        Cdot(Rstack[(i + 1) & RPMASK]);
    }
}

SV TraceLine(cell pc, uint16_t insn) {
    DisassembleInsn(insn);
    printf("%03Xh: %04Xh ( ", pc, insn);
    PrintDataStack();
    printf(")");
    if (RDEPTH) {
        printf(" (R: ");  PrintReturnStack();
        printf(")");
    }
    printf(" \\ w=%Xh, cy=%X\n", w & CELLMASK, cy);
}

SV NewMaxStack(uint8_t s, uint8_t r, int pc) {
    if (verbose & VERBOSE_STKMAX) {
        printf("SP=%d, RP=%d, PC=%Xh, R: ", s, r, pc);
        PrintReturnStack();
        printf("\n");
    }
}

//##############################################################################
// CPU simulator

static uint16_t Code[CodeSize];         // code memory
static uint8_t spMax, rpMax;            // stack depth tracking
static uint64_t cycles = 0;             // cycle counter
static uint32_t latency = 0;            // maximum cycles between return
static uint32_t irq = 0;                // interrupt requests

// The C host uses this (externally) to write to code and data spaces.
// Addr is a cell address in each case.

void chadToCode (uint32_t addr, uint32_t x) {
    if (addr >= CodeSize) {
        error = BAD_CODE_WRITE;  return;
    }
    Code[addr & (CodeSize-1)] = (uint16_t)x;
}

void chadToData(uint32_t addr, uint32_t x) {
    if (addr >= DataSize) {
        error = BAD_DATA_WRITE;  return;
    }
    Data[addr & (DataSize-1)] = (cell)x;
}

// Time-critical code starts here. Code is manually included to keep it
// all together for cache-friendliness (hopefully).

#include "_coproc.c"                    // include coprocessor code

SV Dpush(cell v)                        // push to on the data stack
{
    SP = SPMASK & (SP + 1);
    Dstack[SP] = t;
    t = v;
}

CELL Dpop(void)                         // pop from the data stack
{
    cell v = t;
    t = Dstack[SP];
    SP = SPMASK & (SP - 1);
    return v;
}

SV Rpush(cell v)                        // push to the return stack
{
    RP = RPMASK & (RP + 1);
    Rstack[RP] = v;
}

// Interrupts are handled by modifying the return instruction

static uint8_t Iack(void) {             // priority encoder
    uint8_t r = 0;
    uint32_t x = irq;
    if ((sp <= (MAXSP - IRQheadspace))  // only acknowledge if sufficient stack
        && (rp <= (MAXRP - IRQheadspace))) {
        while (x >>= 1) ++r;            // position of highest bit
        irq &= ~(1 << r);               // clear the request bit
    }
    return r;
}

#if (CELLBITS > 31)
#define sum_t uint64_t
#else
#define sum_t uint32_t
#endif

// The simulator used https://github.com/samawati/j1eforth as a template.
// single = 0: Run until the return stack empties, returns 2 if ok else error.
// single = -1: Run until error, returns error code.
// single = 1: Execute one instruction (single step) from Code[PC].
// single = 10000h + instruction: Execute instruction. Returns the instruction.
// MoreInstrumentation (config.h) slows down the code by 40%.

SI sign2b[4] = { 0, 1, -2, -1 };        /* 2-bit sign extension */

SI CPUsim(int single) {
    cell _t = t;                        // types are unsigned
    cell _pc;
    uint16_t insn;
#ifdef MoreInstrumentation
    uint16_t retMark = (uint16_t)cycles;
#endif
    uint8_t mark = RDEPTH;
    if (single == -1) {                 // run until error
        single = 0;
        mark = 0xFF;
    }
    if (single & 0x10000) {             // execute one instruction directly
        insn = single & 0xFFFF;
        goto once;
    }
    do {
        insn = Code[pc & (CodeSize - 1)];
    once:
#ifdef MoreInstrumentation
        if (verbose & VERBOSE_TRACE) {
            TraceLine(pc, insn);
        }
#endif
        _pc = pc + 1;
        uint8_t interruptVector = 0;
        uint8_t exception = 0;
        cell _lex = 0;
        cell s = Dstack[SP];
        cell temp;
        cell target;
        switch (insn >> 13) { // 4 to 7
        case 0:
        case 1:
            target = (lex << 13) | (insn & 0x1fff);
            if (insn & 0x100) {                                     /*  r->pc */
                interruptVector = Iack();
                exception = Rstack[RP] & 1;
                if (exception) _pc = ExceptionVector;
                else if (interruptVector) _pc = interruptVector;
                else {
                    _pc = Rstack[RP] >> 1;
                    if (RDEPTH == mark) single = 2;
                }
#ifdef MoreInstrumentation
                uint16_t time = (uint16_t)cycles - retMark;
                retMark = (uint16_t)cycles;
                if (time > latency)
                    latency = time;
#endif
            }
            cell _c = t & 1;
            sum_t sum;
            cell _w = (insn & 0x800) ? t : w;
            switch ((insn >> 9) & 0x1F) {
            case 0x00: _t = t;                               break; /*      T */
            case 0x10: _t = coprocRead();                    break; /*    COP */
            case 0x01: _t = (t & MSB) ? -1 : 0;              break; /*    T<0 */
            case 0x11: _t = cy;                              break; /*      C */
            case 0x02: temp = (t & MSB);
                _t = (t >> 1) | temp;                        break; /*    T2/ */
            case 0x12:
                _t = (t >> 1) | (cy << (CELLBITS - 1));      break; /*   cT2/ */
            case 0x03: _c = t >> (CELLBITS - 1);
                _t = t << 1;                                 break; /*    T2* */
            case 0x13: _c = t >> (CELLBITS - 1);
                _t = (t << 1) | cy;                          break; /*   T2*c */
            case 0x04: _t = s;                               break; /*      N */
            case 0x14: _t = w;                               break; /*      W */
            case 0x05: _t = s ^ t;                           break; /*    T^N */
            case 0x15: _t = ~t;                              break; /*     ~T */
            case 0x06: _t = s & t;                           break; /*    T&N */
            case 0x07: _t = ((t >> 8) & 0xFF00FF) | ((t & 0xFF00FF) << 8);
                break;                                              /*     >< */
            case 0x17: _t = ((t >> 16) & 0xFFFF) | ((t & 0xFFFF) << 16);
                break;                                              /*   ><16 */
            case 0x08: sum = (sum_t)s + (sum_t)t;
                _c = (sum >> CELLBITS) & 1;  _t = (cell)sum; break; /*    T+N */
            case 0x09: sum = (sum_t)s - (sum_t)t;
                _c = (sum >> CELLBITS) & 1;  _t = (cell)sum; break; /*    N-T */
            case 0x0A: _t = Rstack[RP];                      break; /*      R */
            case 0x0B: _t = Rstack[RP] - 1;                  break; /*    R-1 */
            case 0x0C: _t = readIOmap(CELL_ADDR(t));         break; /*  io[T] */
            case 0x0D: _t = Data[Raddr];
                if (verbose & VERBOSE_TRACE) {
                    printf("Reading %Xh from cell %Xh\n", _t, Raddr);
                } break;                                            /*    [T] */
            case 0x0E: _t = (t) ? 0 : -1;                    break; /*    T0= */
            case 0x0F: _t = (RDEPTH << 8) + SDEPTH;          break; /* status */
            default:   _t = t;  single = BAD_ALU_OP;
            }
            SP = SPMASK & (SP + sign2b[insn & 3]);                /* dstack+- */
            if ((interruptVector == 0) && (exception == 0))
                RP = RPMASK & (RP + sign2b[(insn >> 2) & 3]);     /* rstack+- */
            switch ((insn >> 4) & 7) {
            case  1: Dstack[SP] = t;                         break;   /* T->N */
            case  2: Rstack[RP] = t;                         break;   /* T->R */
            case  3: temp = CELL_ADDR(t);
                if (temp & ~(DataSize - 1)) { single = BAD_DATA_WRITE; }
                if (verbose & VERBOSE_TRACE) {
                    printf("Storing %Xh to cell %Xh\n", s, temp);
                } Data[temp & (DataSize - 1)] = s;           break; /* N->[T] */
            case  4: Raddr = CELL_ADDR(t);                         /* _MEMRD_ */
                if (Raddr & ~(DataSize - 1)) { single = BAD_DATA_READ; }  break;
            case  5: temp = writeIOmap(CELL_ADDR(t), s);          /* N->io[T] */
                if (temp) { single = temp; }   break;
                // 6 = IORD strobe
            case  7: cy = _c;  w = _w;                       break;   /*   co */
            default: break;
            }
            t = _t & CELLMASK;
            break;
        case 2:                                                /* literal */
            Dpush((lex << 12) | ((insn & 0x1e00) >> 1) | (insn & 0xff));
            if (insn & 0x100) {                                 /*  r->pc */
                interruptVector = Iack();
                exception = Rstack[RP & RPMASK] & 1;
                if (exception) _pc = ExceptionVector;
                else if (interruptVector) _pc = interruptVector;
                else {
                    _pc = Rstack[RP] >> 1;
                    if (RDEPTH == mark) single = 2;
                    RP = RPMASK & (RP - 1);
                }
#ifdef MoreInstrumentation
                uint16_t time = (uint16_t)cycles - retMark;
                retMark = (uint16_t)cycles;
                if (time > latency)
                    latency = time;
#endif
            } 
            break;
        case 3:                                                 /*   trap */
            Dpush((lex << 12) | ((insn & 0x1e00) >> 1) | (insn & 0xff));
            temp = ((insn >> 8) & 1);
            RP = RPMASK & (RP + 1);
            Rstack[RP & RPMASK] = _pc << 1;
            _pc = TrapVector + temp;
#ifdef MoreInstrumentation
            if (verbose & VERBOSE_TRACE) {
                printf("Trap to %Xh\n", _pc);
            }
#endif
            break;
        case 4:                                                 /*  zjump */
            if (!Dpop()) { 
                _pc = insn & 0x1fff; 
            }
            break;
        case 5:
            if (insn & 0x1000)                                  /* coproc */
                coprocGo(insn & 0x7FF,
                    t & CELLMASK, s & CELLMASK, w & CELLMASK);
            else {
                _lex = (lex << 12) | (insn & 0xFFF);            /*   litx */
            }
            break;
        case 6:                                                 /*   jump */
            _pc = insn & 0x1fff;  
            break;
        case 7:                                                 /*   call */
            RP = RPMASK & (RP + 1);
            Rstack[RP & RPMASK] = _pc << 1;
            _pc = insn & 0x1fff;
#ifdef MoreInstrumentation
                if (verbose & VERBOSE_TRACE) {
                    printf("Call to %Xh\n", _pc);
                }
#endif
            break;
        }
#ifdef MoreInstrumentation
        if (sp > spMax) {
            spMax = sp;
            NewMaxStack(sp, rpMax, _pc);
        }
        if (rp > rpMax) {
            rpMax = rp; 
            NewMaxStack(spMax, rp, _pc);
        }
        if (verbose & VERBOSE_TRACE) {
            if (exception)
                printf("Exception at %Xh, R/2=%Xh, page=%Xh\n",
                    pc, Rstack[RP] / 2, Rstack[(RP - 1) & RPMASK]);
            if (interruptVector)
                printf("Interrupt Level %d\n", _pc);
        }
#endif
        pc = _pc;  lex = _lex;
        cycles++;
        if ((cycles & CELLMASK) == 0) {  // raw counter overflow
            irq |= (1 << 1);            // lowest priority interrupt
        }
        if (pc & ~(CodeSize-1)) single = BAD_PC;
    } while (single == 0);
    return single;
}

SV Simulate(cell xt) {
    latency = 0;                        // reset latency measurement
    Rpush(0);  pc = xt;
    int result = CPUsim(0);             // run until last RET or error
    if (result < 0) error = result;
}

//##############################################################################
// Compiler

CELL latest = 0;                        // latest writable code word
SI notail = 0;                          // tail recursion inhibited for call

SV toCode (cell x) {                    // compile to code space
    chadToCode(CP++, x);
}
SV CompExit (void) {                    // compile an exit
    if (latest == CP) {                 // code run is empty
        goto plain;                     // nothing to optimize
    }
    int a = (CP-1) & (CodeSize-1);
    int old = Code[a];                  // previous instruction
    if (((old & 0xC000) == 0) && (!(old & rdn))) { // ALU doesn't change rp?
        Code[a] = rdn | old | ret;      // make the ALU instruction return
    } else if ((old & 0xF000) == lit) { // literal?
        Code[a] = old | ret;            // make the literal return
    } else if ((!notail) && ((old & 0xE000) == call)) {
        Code[a] = (old & 0x1FFF) | jump; // tail recursion (call -> jump)
    } else {
plain:  toCode(alu | ret | rdn);         // compile a stand-alone return
    }
}

// The LEX register is cleared whenever the instruction is not LITX.
// LITX shifts 12-bit data into LEX from the right.
// Full 16-bit and 32-bit data are supported with 2 or 3 inst.

SV extended_lit (int k) {
    toCode(litx | (k & 0xFFF));
}
SI lit_field(int x) {
    x &= 0xFFF;
    return (x & 0xff) | (x & 0xF00) << 1;
}
SV Literal (cell x) {
#if (CELLBITS > 24)
    if (x & 0xFF000000) {
        extended_lit(x >> 24);
        extended_lit(x >> 12);
    }
    else {
        if (x & 0x0FFF000)
            extended_lit(x >> 12);
    }
#else
    if (x & 0x0FFF000)
        extended_lit(x >> 12);
#endif
    toCode (lit | lit_field(x));
}

#ifdef HASFLOATS

// Floating point number representation uses double numbers, which can be 32
// to 64 bits. Usually it's somewhere in between. The MSB is the sign, the
// exponent has a programmable number of bits, and the mantissa is the rest.

static int FPexpbits = 8;

SV fdot(void) {                         // ( d -- )
    uint64_t d = (uint64_t)Dpop() << CELLBITS;   d += Dpop();
    int manbits = 2 * CELLBITS - 1 - FPexpbits;
    if (d & ((uint64_t)1 << (2 * CELLBITS - 1)))  printf("-");
    d &= ~((uint64_t)-1 << (2 * CELLBITS - 1));  // strip off sign
    if (d == 0) {                       // either +0 or -0
        printf("0. ");  return;
    }
    int64_t exp = (d >> manbits) - ((uint64_t)1 << (FPexpbits - 1));
    d &= ~((uint64_t)-1 << manbits);
    d += (uint64_t)1 << manbits;
    int digits = (int)(2.0 * logf((float)manbits) / logf(2.0));
    printf("%.*g ", digits, (double)d * pow(2.0, (double)(exp - manbits)));
}

uint64_t pack754_64(double f) {
    uint64_t* pfloatingToIntValue;
    pfloatingToIntValue = (uint64_t*)&f;
    return (*pfloatingToIntValue);
}

static uint64_t FPtoDouble(double x) {
    uint64_t r = 0;
    if (x == 0) return r;
    if (x < 0) r += ((uint64_t)1 << (2 * CELLBITS - 1));
    uint64_t i = pack754_64(fabs(x));
    int manbits = 2 * CELLBITS - 1 - FPexpbits;
    uint64_t exp = (i >> 52) + ((uint64_t)1 << (FPexpbits - 1)) - 1023;
    r += exp << manbits;
    return r + ((i & 0xFFFFFFFFFFFFF) >> (52 - manbits));
}

SV LiteralFP(double x) {
    uint64_t i = FPtoDouble(x);
    uint32_t hi = (i >> CELLBITS) & CELLMASK;
    Literal((uint32_t)i & CELLMASK);  Literal(hi);
}

SV DpushFP(double x) {
    uint64_t i = FPtoDouble(x);
    uint32_t hi = (i >> CELLBITS)& CELLMASK;
    Dpush((uint32_t)i & CELLMASK);  Dpush(hi);
}

SI isfloat(char* s) {
    if (BASE != 10) return 0;     // FP is only valid for base 10
    if (strchr(s, 'E')) return 1;       // must have exponent
    if (strchr(s, 'e')) return 1;
    return 0;
}
#endif

SV CompCall (cell xt) {
    if (xt & 0xFFE000)
        toCode(litx | (xt >> 13));      // accommodate 24-bit address space
    toCode (call | (xt & 0x1fff));
}

SI aligned(int n) {
    int32_t cellbytes = CELLS;
    return (n + (cellbytes - 1)) & (-cellbytes);
}

// Code space isn't randomly readable, so lookup tables are supported by jump
// into a list of literals with their return bits set.
// Use |bits| to set the size of your data. It's cellsize by default.
// Syntax is  : tjmp 2* r> + >r ;  : mytable tjmp [ 12 | 34 | 56 ] literal ;

CELL tablebits = CELLBITS;
SV SetTableBitWidth(void) { tablebits = Dpop(); }
SV TableEntry(void) {
    int bits = tablebits;
    cell x = Dpop();
#if (CELLBITS > 22)
    if (bits > 22) extended_lit(x >> 22);
#endif
    if (bits > 11) extended_lit(x >> 11);
    toCode(ret | lit | (x & 0xFF) | (x & 0x700) << 1);
}

// Compile Control Structures

CELL CtrlStack[256];                    // control stack
static uint8_t ConSP = 0;
SI lastAPI;

SV ControlSwap(void) {
    cell x = CtrlStack[ConSP];
    CtrlStack[ConSP] = CtrlStack[ConSP - 1];
    CtrlStack[ConSP - 1] = x;
}
SV sane(void) {
    if (ConSP)  error = BAD_CONTROL;
    ConSP = 0;
}

// Addressing beyond 1FFFh is not supported yet.

SV ResolveFwd(void) { Code[CtrlStack[ConSP--]] |= CP;  latest = CP;  lastAPI = 0; }
SV ResolveRev(int inst) { toCode(CtrlStack[ConSP--] | inst);  latest = CP;  lastAPI = 0; }
SV MarkFwd(void) { CtrlStack[++ConSP] = CP;  lastAPI = 0; }
SV doBegin(void) { MarkFwd(); }
SV doAgain(void) { ResolveRev(jump); }
SV doUntil(void) { ResolveRev(zjump); }
SV doIf(void) { MarkFwd();  toCode(zjump); }
SV doThen(void) { ResolveFwd(); }
SV doElse(void) { MarkFwd();  toCode(jump);  ControlSwap();  ResolveFwd(); }
SV doWhile(void) { doIf();  ControlSwap(); }
SV doRepeat(void) { doAgain();  doThen(); }
SV doFor(void) { toCode(alu | NtoT | TtoR | sdn | rup);  MarkFwd(); }
SV noCompile(void) { error = BAD_NOCOMPILE; }
SV noExecute(void) { error = BAD_NOEXECUTE; }

SV doNext(void) {
    toCode(alu | RM1toT | TtoN | sup);  /* (R-1)@ */
    toCode(alu | zeq | TtoR);  ResolveRev(zjump);
    toCode(alu | rdn);  latest = CP;    /* rdrop */
}

SV CoprocInst(void) {
    int sel = Dpop();
    if (sel > 0x3FF) error = BAD_COPROCESSOR;
    toCode(copop | sel);
}

// HTML output is a kind of log file of token handling. It's a browsable
// version of the source text with links to reference documents.

SI fileID = 0;                          // cumulative file ID
struct FileRec FileStack[MaxFiles];
struct FilePath FilePaths[MaxFilePaths];
SI filedepth = 0;                       // file stack
static uint32_t logcolor = 0;
static int leadingblanks = 0;

SV LogR(char* s) {                      // raw text to HTML file
    FILE* fp = File.hfp;
    if (fp) fprintf(fp, "%s", s);
}

SV FlushBlanks(void) {
    switch (leadingblanks) {
    case 0: break;
    case 1: LogR(" "); break;
    default:
        while (--leadingblanks)
            LogR(" ");
        LogR("&nbsp;");
    }
    leadingblanks = 0;
}

SV LogChar(char c) {
    FILE* fp = File.hfp;
    if (fp) {
        if (' ' != c)  FlushBlanks();
        switch (c) {
        case '"':  fprintf(fp, "&quot;");  break;
        case '\'': fprintf(fp, "&apos;");  break;
        case '<':  fprintf(fp, "&lt;");    break;
        case '>':  fprintf(fp, "&gt;");    break;
        case '&':  fprintf(fp, "&amp;");   break;
        case ' ':  leadingblanks++;        break;
        default:   fprintf(fp, "%c", c);
        }
    }
}

SV Log(char* s) {
    char c;
    while ((c = *s++)) LogChar(c);
}

SV LogBegin(char* title) {
    LogR("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n");
    LogR("<meta charset=\"utf-8\">\n<title>");
    LogR(title);
    LogR("</title>\n<link rel=\"stylesheet\" href=\"doc.css\">\n");
    LogR("</head>\n<body>\n<h1>");
    LogR(title);
    LogR("</h1>\n<pre class=\"forth\">\n<font color=black>\n");
    LogR("<hr>\n");
}

SV LogEnd(void) {
    LogR("\n</pre>\n</body>\n</html>\n");
}

// A strncpy that complies with C safety checks.

void strmove(char* dest, char* src, int maxlen) {
    for (int i = 0; i < maxlen; i++) {
        char c = *src++;  *dest++ = c;
        if (c == 0) return;             // up to and including the terminator
    }
    *--dest = 0;                        // max reached, add terminator
}

//##############################################################################
// Dictionary
// The dictionary uses a static array of data structures loaded at startup.
// Links are int indices into this array of Headers.

SI hp;                                  // # of keywords in the Header list
static struct Keyword Header[MaxKeywords];
CELL me;                                // index of found keyword
static char* foundWidName;              // name of wid the word was found in
static char ref[LineBufferSize];        // ReferenceString result buffer
static char* ReferenceStackPic;         // string remaining after first blank

static char* ReferenceString(int i) {   // extract reference string
    char* hs = Header[i].help;
    ReferenceStackPic = NULL;
    if (hs[0]) {
        strmove(ref, hs, LineBufferSize);
        if ((ReferenceStackPic = strchr(ref, ' ')) != NULL)
            *ReferenceStackPic++ = '\0';
        return ref;
    }
    return NULL;
}

// HTML output of the token being evaluated, with hyperlink to reference.
SV LogColor(uint32_t color, int ID, char* s) {
    FlushBlanks();
    if (logcolor != color) {
        logcolor = color;
        LogR("</font><font color=#");
        Log(itos(color, 16, 6, 1));
        LogR(">");
    }
    if (ID) {
        LogR("<a href = \"");
        LogR(foundWidName);
        LogR(".html#");
        LogR(ReferenceString(ID));
        LogR("\" style=\"text-decoration: none; color: #");
        Log(itos(color, 16, 6, 1));
        LogR("\">");
        LogR(s);
        LogR("</a>");
    }
    else
        LogR(s);
    LogR(" ");
}

// The search order is a list of wordlists with CONTEXT searched first
// order:   wid3 wid2 wid1
// context------------^      ^-----ORDERS
// A wid points to a linked list of headers.
// The head pointer of the list is created by WORDLIST.

static cell wordlist[MaxWordlists];     // head pointers to linked lists
static char wordlistname[MaxWordlists][16];// optional name string
SI wordlists;                           // number of defined wordlists
SI root_wid;                            // the basic wordlists
SI forth_wid;
SI asm_wid;
SI context(void) {
    if (ORDERS == 0) return 0;
    return CONTEXT;
}

SV printWID(int wid) {
    char* s = &wordlistname[wid][0];
    if (*s)
        printf("%s ", s);
    else
    	Cdot(wid);
}

SV Order(void) {
    printf(" Context : ");
    for (int i = ORDERS; i > 0; i--)  printWID(ORDER(i-1));
    printf("\n Current : ");  printWID(CURRENT);
}

SI findinWL(char* key, int wid) {       // find in wordlist
    uint16_t i = wordlist[wid];
    if (strlen(key) < MaxNameSize) {
        while (i) {
            if (strcmp(key, Header[i].name) == 0) {
                if (Header[i].smudge == 0) {
                    me = i;
                    return i;
                }
            }
            i = Header[i].link;
        }
    }
    return -1;                          // return index of word, -1 if not found
}

SI FindWord(char* key) {                // find in context
    for (cell i = ORDERS; i > 0; i--) {
        int wid = ORDER(i - 1);
        int id = findinWL(key, wid);
        if (id >= 0) {
            Header[me].references += 1; // bump reference counter
            foundWidName = &wordlistname[i][0];
            return id;
        }
    }
    return -1;
}

SI Ctick(char* name) {
    if (FindWord(name) < 0) {
        error = UNRECOGNIZED;
        // printf("<%s> ", name);
        return 0;
    }
    return Header[me].target;           // W field of found word
}

/* Wordlists are on the host. A copy of header space is made by MakeHeaders for
use by the target's interpreter. ANS Forth's WORDLIST is not useful because it
can't be used in Forth definitions. We don't get the luxury of temporary
wordlists but "wordlists--;" can be used by C to delete the last wordlist.
*/

SI AddWordlist(char *name) {
    wordlist[++wordlists] = 0;          // start with empty wordlist
    strmove(&wordlistname[wordlists][0], name, 16);
    if (wordlists == (MaxWordlists - 1)) error = BAD_WID_OVER;
    return wordlists;
}

SV OrderPush(uint8_t n) {
    ORDER(15 & ORDERS++) = n;
    if (ORDERS == 9) error = BAD_ORDER_OVER;
}

SI OrderPop(void) {
    uint8_t r = (ORDER(15 & --ORDERS));
    if (ORDERS & 0x10) error = BAD_ORDER_UNDER;
    return r;
}

SV Only       (void) { ORDERS = 0; OrderPush(root_wid); OrderPush(forth_wid); }
SV ForthLex   (void) { CONTEXT = forth_wid; }
SV AsmLex     (void) { CONTEXT = asm_wid; }
SV Definitions(void) { CURRENT = context(); }
SV PlusOrder  (void) { OrderPush(Dpop()); }
SV Previous   (void) { OrderPop(); }
SV Also       (void) { int v = OrderPop();  OrderPush(v);  OrderPush(v); }
SV SetCurrent (void) { CURRENT = Dpop(); }
SV GetCurrent (void) { Dpush(CURRENT); }

SV GetOrder(void) { // widn .. wid1 --> ORDER[widn .. wid1]
    for (cell i = 0; i < ORDERS; i++)
        Dpush(ORDER(i));
    Dpush(ORDERS);
}

SV SetOrder(void) {
    int8_t len = Dpop();
    if (len < 0)
        Only();
    else {
        ORDERS = len;
        for (int i = len; i > 0; i--)
            ORDER(i - 1) = Dpop();
    }
}

SI EvalToken (char *key) {              // do a command, return 0 if found
    int i = FindWord(key);
    if (i < 0)
        return -1;                      // not found
    LogColor(Header[i].color, i, key);
    if (STATE)
        Header[i].CompFn();
    else
        Header[i].ExecFn();
    return 0;
}

static uint32_t my (void) {return Header[me].w;}
SV doLITERAL  (void) { Literal(Dpop()); }
SV Equ_Comp   (void) { Literal(my()); }
SV Equ_Exec   (void) { Dpush(my()); }
SV Prim_Comp  (void) { toCode(my()); }
SV Prim_Exec  (void) { CPUsim(0x10000 + my()); } // single step
SV doInstMod  (void) { int x = Dpop(); Dpush(my() | x); }
SV doLitOp    (void) { toCode(Dpop() | my());  Dpush(0); }

// Referencing a word outside of an API

SV Def_Comp   (void) {
    notail = Header[me].notail;
    CompCall(my()); 
}

SV Def_Exec   (void) {
    if (verbose & VERBOSE_TOKEN) {
        printf(" <exec:%Xh>", my());
    }
    Simulate(my());
}

// Literal and word: push and execute or literal and [compile]

SV LitnExec(char* name, cell value) {
    Dpush(value);
    int x = me;
    Simulate(Ctick(name));
    me = x;
}

SV LitnComp(char* name, cell value) {
    int x = me;
    int xt = Ctick(name);
    notail = Header[me].notail;
    Literal(value);
    CompCall(xt);
    me = x;
}
SI AppletSync(void) {
    int page = Header[me].applet;
    if (page)
        LitnExec("spifload", page);
    return page;
}

SI AddHead (char* name, char* anchor) { // add a header to the list
    int r = 1;
    hp++;
    if (hp < MaxKeywords) {
        strmove(Header[hp].name, name, MaxNameSize);
        strmove(Header[hp].help, anchor, MaxAnchorSize);
        Header[hp].length = 0;          // set defaults to 0
        Header[hp].notail = 0;
        Header[hp].target = 0;
        Header[hp].notail = 0;
        Header[hp].smudge = 0;
        Header[hp].isALU = 0;
        Header[hp].srcFile = File.FID;
        Header[hp].srcLine = File.LineNumber;
        Header[hp].link = wordlist[CURRENT];
        Header[hp].references = 0;
        Header[hp].w2 = 0;
        Header[hp].applet = 0;
        wordlist[CURRENT] = hp;
    } else {
        printf("Please increase MaxKeywords and rebuild.\n");
        r = 0;  error = BYE;
    }
    return r;
}

SV SetFns (cell value, void (*exec)(), void (*comp)()) {
    Header[hp].w = value;
    Header[hp].ExecFn = exec;
    Header[hp].CompFn = comp;
}

SV AddKeyword (char* name, char* help, void (*xte)(), void (*xtc)()) {
    if (AddHead(name, help)) {
        SetFns(NOTANEQU, xte, xtc);
        Header[hp].color = COLOR_ROOT;
    }
}

SV AddALUinst(char* name, char* help, cell value) {
    if (AddHead(name, help)) {
        SetFns(value, Prim_Exec, Prim_Comp);
        Header[hp].isALU = 1;
        Header[hp].color = COLOR_ALU;
    }
}

int DefMark, DefMarkID;

SV AddEquate(char* name, char* help, cell value) {
    if (AddHead(name, help)) {
        SetFns(value, Equ_Exec, Equ_Comp);
        Header[hp].color = COLOR_EQU;
        DefMarkID = hp; // was for DOES> but can't do it here
    }
}

// Modify the ALU instruction being constructed
SV AddModifier (char *name, char* help, cell value) {
    if (AddHead(name, help)) {
        SetFns(value, doInstMod, noCompile);
        Header[hp].color = COLOR_ASM;
    }
}

// Literal operations literal data from the stack and toCode the instruction.
SV AddLitOp (char *name, char* help, cell value) {
    if (AddHead(name, help)) {
        SetFns(value, doLitOp, noCompile);
        Header[hp].w2 = MAGIC_OPCODE;
        Header[hp].color = COLOR_ASM;
    }
}

//##############################################################################
// Facilities for viewing, debugging, etc.

// Disassembler

static char* TargetName (cell addr, int page) {
    if (!addr) return NULL;
    int i = hp + 1;
    while (--i) {
        if (Header[i].target == addr) {
            if ((!page) | (page == Header[i].applet))
            return Header[i].name;
        }
    }
    return NULL;
}

char DAbuf[256];                        // disassembling to a buffer

SV appendDA(char* s) {                  // append string to DA buffer
    size_t i = strlen(DAbuf);
    size_t len = strlen(s);
    strmove(&DAbuf[i], s, len + 1);
    i += len;
    DAbuf[i++] = ' ';                   // trailing space
    DAbuf[i++] = '\0';
}

SV HexToDA(cell x) {                    // append hex number to DA buffer
    appendDA(itos(x, 16, 2, 0));
}

SV diss (int id, char *str) {
    while (id--) { while (*str++); }
    if (str[0]) appendDA(str);
}

SI ALUlabel(uint16_t insn) {            // try to match to a predefined ALUinst
    for (int i = 1; i < hp; i++) {
        if (insn & ret) {               // strip RET and rdn
            if ((insn & rdn) == rdn)
                insn &= ~(ret | rdn);
        }
        if ((Header[i].isALU) && (Header[i].w == insn)) {
            appendDA(Header[i].name);
            return 1;
        }
    }
    return 0;
}

CELL DisassembleInsn(cell IR) {         // see chad.h for instruction set summary
    static cell lex;
    cell _lex = 0;
    char* name;
    DAbuf[0] = '\0';
    int target;
    switch ((IR>>13) & 7) {
    case 0:
    case 1:
        if (ALUlabel(IR)) {
            if (IR & ret) appendDA("exit");
        }
        else {
            int id = (IR >> 9) & 7;
            switch ((IR >> 12) & 3) {
            case 0: diss(id, "T\0T0<\0T2/\0T2*\0N\0T^N\0T&N\0mask"); break;
            case 1: diss(id, "T+N\0N-T\0T0=\0N>>T\0N<<T\0R\0[T]\0status"); break;
            case 2: diss(id, "COP\0C\0cT2/\0T2*c\0W\0~T\0T&W\0---"); break;
            default: diss(id, "T+Nc\0N-Tc\0---\0---\0---\0R-1\0io[T]\0---");
            }
            diss((IR >> 4) & 7, "\0T->N\0T->R\0N->[T]\0_MEMRD_\0N->io[T]\0_IORD_\0CO");
            diss(IR & 3, "\0d+1\0d-2\0d-1");
            diss((IR >> 2) & 3, "\0r+1\0r-2\0r-1");
            if (IR & ret) appendDA("RET");
            appendDA("alu");
        }
        break;
    case 2:
        target = (IR & 0xFF) | (IR & 0x1E00) >> 1;
        appendDA(itos((lex << 12) + target, BASE, 0, 0));
        appendDA("imm");
        if (IR & ret) { appendDA("exit"); }
        break;
    case 3:
        target = (lex << 12) | (IR & 0xFF) | (IR & 0x1E00) >> 1;
        int trapnum = (IR & ret) ? 1 : 0;
        if (trapnum) {
            name = TargetName((target & 0x3FF) + (CodeSize - CodeCache), target >> 10);
            if (name == NULL) HexToDA(target);
            appendDA("xcall");
            if (name != NULL) appendDA(name);
        }
        else {
            appendDA(itos(target, BASE, 0, 0));
            appendDA(itos(trapnum, BASE, 0, 0));
            appendDA("trap");
        }
        break;
    case 5:
        target = IR & 0xFFF;  HexToDA(target);
        if (IR & 0x1000) {
            appendDA("cop");
        }
        else {
            _lex = (lex << 12) + target;
            appendDA("litx");
        }
        break;
    case 4:
    case 6:
    case 7:
        target = IR & 0x1FFF;
        name = TargetName(target, 0);
        if (name == NULL) HexToDA(target);
        diss((IR>>13)&3,"zjump\0?\0jump\0call");
        if (name != NULL) appendDA(name);
    }
    lex = _lex;
    printf("%16s", DAbuf);
    return 0;
}

SV Dasm (void) { // ( addr len -- )
    int length = Dpop() & 0x0FFF;
    int addr = Dpop();
    char* name;
    for (int i=0; i<length; i++) {
        int a = addr++ & (CodeSize-1);
        int x = Code[a];
        name = TargetName(a, 0);
        if (name != NULL) printf("%s\n", name);
        printf("%03x %04x  ", a, x);
        DisassembleInsn(x);
        printf("\n");
    }
}

SV Steps(void) {                      // ( addr steps -- )
    uint16_t cnt = (uint16_t)Dpop();    // single step debugger gives a listing
    pc = Dpop();
    verbose |= VERBOSE_TRACE;
    for (uint16_t i = 0; i < cnt; i++) {
        CPUsim(1);
        if (rp == (StackSize - 1)) break;
    }
    verbose &= ~VERBOSE_TRACE;
}

SV Assert(void) {                     // for test code
    int expected = Dpop();
    int actual = Dpop();
    if (expected != actual) {
        printf("Expected = "); Cdot(expected);
        printf("actual = "); Cdot(actual);
        printf("\n");
        error = BAD_ASSERT;
    }
}

uint64_t elapsed_us;
uint64_t elapsed_cycles;

SV Stats(void) {
    printf("%" PRId64 " cycles, MaxSP=%d, MaxRP=%d, latency=%d",
        elapsed_cycles, spMax, rpMax, latency);
    if (elapsed_us > 99) {
        printf(", %" PRId64 " MIPS", elapsed_cycles / elapsed_us);
    }
    printf("\n");
    spMax = sp;  rpMax = rp;
}

SV dotESS (void) {                      // ( ... -- ... )
    PrintDataStack();                   // .s
    printf("<-Top\n");
}

SV dot(void) {                          // ( n -- )
    Cdot(Dpop());                       // .
}

//##############################################################################
// Forth interpreter
// When a file is included, the rest of the TIB is discarded.
// A new file is pushed onto the file stack.
// Every time a file is opened, the fileID is bumped.

static char* buf;                       // line buffer
SI maxlen;                              // maximum buffer length
static char BOMmarker[4] = {0xEF, 0xBB, 0xBF, 0x00};

static char* Title(char* filename) {    // strip down filename
    char* p = &filename[strlen(filename)];
    int running = 1;  int dot = 0;
    do {
        switch (*--p) {
        case '\\':                      // trim leading file path
        case '/': running = 0;  p++;  break;
        case '.':                       // trim file extension
            if (dot == 0) { dot = 1;  *p = '\0'; }
        }
    } while ((p > filename) && (running));
    return p;
}

static char* RefPath(char* filename) {  // convert filename format
    static char buf[LineBufferSize];
    strmove(buf, "./html/", LineBufferSize);
    strmove(&buf[strlen(buf)], Title(filename), LineBufferSize);
    strmove(&buf[strlen(buf)], ".html", LineBufferSize);
    buf[strlen(buf)] = '\0';
    return buf;
}

// Industry consensus is that utf-8 files should not need a BOM, which is a
// Microsoft hack. Try to use an editor that treats files as utf-8 by default.
// Maybe SwallowBOM should be removed to punish users for putting a BOM in their
// files, but I'm not going to be the BOM police.

SV SwallowBOM(FILE *fp) {               // swallow leading UTF8 BOM marker
    char BOM[4];                        // to support utf-8 files on Windows
    (void)(fgets(BOM, 4, fp) != NULL);
    if (strcmp(BOM, BOMmarker)) {
        rewind(fp);                     // keep beginning of file if no BOM
    }
}

static FILE* fopenx(char* filename, char* fmt) {
#ifdef MORESAFE
    FILE* fp;
    errno_t err = fopen_s(&fp, filename, fmt);
    return fp;
#else
    return fopen(filename, fmt);
#endif
}

SI OpenNewFile(char *name) {            // Push a new file onto the file stack
    filedepth++;  fileID++;
    File.fp = fopenx(name, "r");
    File.LineNumber = 0;
    File.Line[0] = 0;
    File.FID = fileID;
    if (File.fp == NULL) {
        filedepth--;
        return BAD_OPENFILE;
    } else {
        if ((filedepth >= MaxFiles) || (fileID >= MaxFilePaths))
            return BAD_INCLUDING;
        else {
            SwallowBOM(File.fp);
            strmove(FilePaths[fileID].filepath, name, LineBufferSize);
            File.hfp = fopenx(RefPath(name), "w");
            LogBegin(Title(name));
        }
    }
    return 0;
}

static char tok[LineBufferSize+1];      // blank-delimited token

// the quick brown fox jumped
// >in before -----^   ^--- after, tok = fox\0

SI parseword(char delimiter) {
    while (buf[TOIN] == delimiter) {    // skip leading delimiters
        LogChar(delimiter);
        TOIN++;
    }
    int length = 0;
    while (1) {
        char c = buf[TOIN];
        if (c == 0) break;              // hit EOL
        TOIN++;
        if (c == delimiter)  break;
        tok[length++] = c;
    }
    tok[length] = 0;                    // tok is zero-delimited
    return length;
}

SV ParseFilename(void) {
    while (buf[TOIN] == ' ') TOIN++;
    if (buf[TOIN] == '"') {
        parseword('"');                 // allow filename in quotes
    }
    else {
        parseword(' ');                 // or a filename with no spaces
    }
    LogColor(COLOR_NONE, 0, tok);
}

SV Include(void) {                      // Nest into a source file
    ParseFilename();
    error = OpenNewFile(tok);
}

SV LoadFlash(void) {                    // ( dest -- )
    ParseFilename();
    error = LoadFlashMem(tok, Dpop());
}

// d_pid is a double cell PID16:KEYID8

SV SaveFlash(void) {                    // ( format d_pid baseblock -- )
    ParseFilename();
    int baseblock = Dpop();
    uint64_t d = (uint64_t)Dpop() << CELLBITS;   d += Dpop();
    int format = Dpop();                //  v--- 1st byte of 32-bit pid
    d = (d << 8) + baseblock;           // {BASEBLOCK, PIDlo, PIDhi, KeyID}
    error = SaveFlashMem(tok, (uint32_t)d, format);
}

// API calls are compiled as a literal xxt and a call to xexec

SI isAPI;                               // compiler is in API mode

SI xxt(void) {                          // convert xt to xxt
    int offset = my() - (CodeSize - CodeCache);
    return (Header[me].applet << 10) + offset;
}
SV DefA_Exec(void) {
    LitnExec("xexec", xxt());
}
SV DefA_Comp(void) {
    int id = Header[me].applet;
    if (lastAPI != id) {                // changed from last reference
        lastAPI = id;
        int ext = xxt();
        extended_lit(ext >> 12);
        toCode(trap | ret | lit_field(ext));
    }
    else 
        Def_Comp();
}

// Start a new definition at the code boundary specified by CodeAlignment.
// Use CodeAlignment > 1 for Code memory (ROM) that's slow.
// For example, a ROM with a 64-bit prefetch buffer would have
// CodeAlignment = 4 and use a 4:1 mux to fetch the instruction.

SV Colon(void) {
    parseword(' ');
    if (AddHead(tok, "")) {             // start a definition
        CP = (CP + (CodeAlignment - 1)) & (cell)(-CodeAlignment);
        LogColor(COLOR_DEF, 0, tok);
        if (isAPI) {
            Header[hp].applet = isAPI;
            SetFns(CP, DefA_Exec, DefA_Comp);
        }
        else {
            SetFns(CP, Def_Exec, Def_Comp);
        } 
        lastAPI = isAPI;
        Header[hp].target = CP;
        Header[hp].color = COLOR_WORD;
        Header[hp].smudge = 1;
        DefMarkID = hp;                 // save for later reference
        DefMark = CP;
        latest = CP;                    // code starts here
        ConSP = 0;
        toCompile();
    }
}

SV NoName(void) {
    Dpush(CP);  DefMarkID = 0;          // no length
    toCompile();
    latest = CP;
    ConSP = 0;
}

SV Constant(void) {
    parseword(' ');
    AddEquate(tok, "", Dpop());
    LogColor(COLOR_EQU, 0, tok);
}

SV Lexicon(void) {                      // named wordlist
    parseword(' ');
    AddEquate(tok, "", AddWordlist(tok));
    LogColor(COLOR_DEF, 0, tok);
}

SV BrackDefined(void) {
    parseword(' ');
    int r = (FindWord(tok) < 0) ? 0 : 1;
    if (r) {
        if (Header[me].target == 0) r = 0;
        LogColor(COLOR_NONE, me, tok);
    }
    else
        LogColor(COLOR_WORD, me, tok);
    Dpush(r);
}

SV EndDefinition(void) {                   // resolve length of definition
    if (DefMarkID) {
        Header[DefMarkID].length = CP - DefMark;
        Header[DefMarkID].smudge = 0;
    }
}

SV CompMacro(void) {
    int len = Header[me].length;
    int addr = my();
    for (int i=0; i<len; i++) {
        int inst = Code[addr++];
        if ((i == (len - 1)) && (inst & ret)) { // last inst has a return?
            inst &= ~(ret | rdn);       // strip trailing return
        }
        toCode(inst);
    }
}

SV Macro(void) {
    Header[DefMarkID].CompFn = CompMacro;
}

SV Immediate(void) {
    Header[DefMarkID].CompFn = Header[DefMarkID].ExecFn;
}

SV NoTailRecursion (void) {
    Header[DefMarkID].notail = 1;
}

SV SaveMarker(cell* dest) {
    dest[0] = hp;    dest[1] = CP;  dest[4] = fileID;
    dest[2] = wordlists;  dest[3] = DP;
    memcpy(&dest[5], wordlist, sizeof(cell) * MaxWordlists);
}

SV LoadMarker(cell* src) {
    hp = src[0];     CP = src[1];   fileID = src[4];
    wordlists = src[2];  DP = src[3];
    memcpy(wordlist, &src[5], sizeof(cell) * MaxWordlists);
}

SV Marker_Exec(void) {                  // execution semantics of a marker
    cell* pad = Header[me].aux;
    LoadMarker(pad);
    free(pad);
}

SV Marker (void) {
    parseword(' ');
    if (AddHead(tok, "")) {
        SetFns(CP, Marker_Exec, noCompile);
        Header[hp].color = COLOR_ROOT;
        cell* pad = malloc(sizeof(cell) * (MaxWordlists + 8));
        Header[hp].aux = pad;
        SaveMarker(pad);
        LogColor(COLOR_DEF, 0, tok);
    }
}

SV ListWords(int wid) {                 // in a given wordlist
    uint16_t i = wordlist[wid];
    while (i) {
        size_t len = strlen(tok);       // filter by substring
        char* s = strstr(Header[i].name, tok);
        if ((s != NULL) || (len == 0))
            printf("%s ", Header[i].name);
        i = Header[i].link;             // traverse from oldest
    }
}
SV Words(void) {
    parseword(' ');                     // tok is the search key (none=ALL)
    ListWords(context());               // top of wordlist
    printf("\n");
}

SI tick (void) {                        // get the w field of the word
    parseword(' ');
    int xt = Ctick(tok);
    LogColor(COLOR_WORD, me, tok);
    return xt;
}

SI isImmediate(void) {                  // ticked word is immediate?
    return (Header[me].CompFn == Header[me].ExecFn);
}

SV See (void) {                         // ( <name> -- )
    int addr;
    if ((addr = tick())) {
        int page = AppletSync();
        if (page)
            printf("API:%Xh ", page);
        if (isImmediate()) printf("immediate ");
        Dpush(addr);  Dpush(Header[me].length);  Dasm();
    }
}

SV Cold(void) {                         // cold boot and run forever
    pc = t = sp = rp = w = lex = cy = 0;
    while (1) {
        Dpush(CPUsim(-1));
        pc = Ctick("throw");
    }
}

SV Locate(void) {
    if (tick()) {
        uint8_t i = Header[me].srcFile;
        char* filename = FilePaths[i].filepath;
        int line = Header[me].srcLine;
        printf("%s", filename);
        FILE* fp = fopenx(filename, "r");
        if (fp == NULL) {
            printf(", Line# %d\n", line);
        }
        else {
            printf("\n");
            char b[LineBufferSize];
            for (int i = 1 - line; i < 10; i++) {
                if (fgets(b, LineBufferSize, fp) == NULL) break;
                if (i >= 0)
                    printf("%4d: %s", line++, b);
            }
            fclose(fp);
        }
    }
}

SV Later(void) {
    Colon();  toImmediate();  toCode(jump);
    Header[hp].w2 = MAGIC_LATER;
    EndDefinition();
}

SV Resolves(void) {                     // ( xt <name> -- )
    int addr = tick();
    if (Header[me].w2 != MAGIC_LATER) error = BAD_IS;
    cell insn = jump | (Dpop() & 0x1fff);
    chadToCode(addr, insn);
}

SV SkipToPar(void) {
    parseword(')');  LogColor(COLOR_COM, 0, tok);  Log(")");
}
SV irqStore  (void) { irq = Dpop(); }
SV Nothing   (void) { }
SV BeginCode (void) { Colon();  toImmediate();  OrderPush(asm_wid);  Dpush(0);}
SV EndCode   (void) { EndDefinition();  OrderPop();  Dpop();  sane();}
SV Recurse   (void) { CompCall(Header[DefMarkID].target); }
SV Bye       (void) { error = BYE; }
SV EchoToPar (void) { SkipToPar();  printf("%s", tok); }
SV Cr        (void) { printf("\n"); }
SV Tick      (void) { Dpush(tick()); }
SV BrackTick (void) { Literal(tick()); }
SV There     (void) { Dpush(CP); }
SV WrProtect (void) { killHostIO(); }
SV SemiComp  (void) { CompExit();  EndDefinition();  toImmediate();  sane();}
SV Semicolon (void) { EndDefinition();  sane(); }
SV Verbosity (void) { verbose = Dpop(); }
SV Aligned   (void) { Dpush(aligned(Dpop())); }
SV BrackUndefined(void) { BrackDefined();  Dpush(~Dpop()); }
#ifdef HASFLOATS
SV SetFPexpbits(void) { FPexpbits = Dpop(); }
#endif

SV Postpone(void) {                     // postpone of applet words not supported
    cell xte = tick();
    if (isImmediate())
        CompCall(xte);
    else {
        Literal(xte);
        CompCall(Ctick("compile,"));
    }
    if (Header[me].applet)
        error = BAD_POSTPONE;
}

SI localWID;                            // compilation wordlist for locals

SV BeginLocals(void) {
    localWID = AddWordlist("locals");
    OrderPush(localWID);  Definitions();
}

SV Exportable(void) {
    CURRENT = ORDER(ORDERS - 2);
}

SV EndLocals(void) { OrderPop();  Definitions();  wordlists--; }
SV LocalExec(void) { LitnExec("(local)", my()); }
SV LocalComp(void) { LitnComp("(local)", my()); }

SV Local(void) {
    int temp = CURRENT;  CURRENT = localWID;
    parseword(' ');
    if (AddHead(tok, "1.1430 -- a")) {
        SetFns(Dpop() + BYTE_ADDR(2), LocalExec, LocalComp);
    }
    CURRENT = temp;
}

SV SkipToEOL(void) {                    // and look for x.xxxx format number
    char* src = &buf[TOIN];
    char* p = src;
    char* dest = Header[DefMarkID].help;
    LogColor(COLOR_COM, 0, src);
    int digits = 0;
    int decimals = 0;
    for (int i = 0; i < 6; i++) {
        char c = *p++;
        if (isdigit(c))
            digits++;
        else if (c == '.')
            decimals++;
    }
    if ((dest[0] == '\0') && (digits == 5) && (decimals)) {
        // valid reference string recognized
        if ((p = strchr(src, '\\')) != NULL) *p = '\0';
        strmove(dest, src, MaxAnchorSize);
    }
    TOIN = (int)strlen(buf);
}


SV trimCR(char* buf) {                  // clean up the buffer returned by fgets
    char* p;                            // remove trailing newline
    if ((p = strchr(buf, '\n')) != NULL) *p = '\0';
    size_t len = strlen(buf);
    for (size_t i = 0; i < len; i++) {
        if (buf[i] == '\t')             // replace tabs with blanks
            buf[i] = ' ';
        if (buf[i] == '\r')             // trim CR if present
            buf[i] = '\0';
    }
}

SI refill(void) {
    int result = -1;
ask: TOIN = 0;
    int lineno = File.LineNumber++;
    if (File.fp == stdin) {
        printf("ok>");
        lineno = 0;
#ifdef chadSpinFunction
        if (_kbhit() == 0) {
            if (chadSpinFunction()) {
                buf[0] = '\0';
                error = BYE;
                return -1;
            }
        }
#endif
    }
    if (fgets(buf, maxlen, File.fp) == NULL) {
        result = 0;
        if (filedepth) {
            fclose(File.fp);
            LogEnd();
            fclose(File.hfp);
            filedepth--;
            goto ask;
        }
    }
    else
        trimCR(buf);
    strmove(File.Line, buf, LineBufferSize);
    logcolor = 0;
    Log("\n");
    if (verbose & VERBOSE_SOURCE)
        printf("%d: %s\n", lineno, buf);
    return result;
}

// [IF ] [ELSE] [THEN]

static void BrackElse(void) {
    int level = 1;
    while (level) {
        parseword(' ');
        int length = (int)strlen(tok);
        if (length) {
            if (!strcmp(tok, "[if]")) {
                level++;
            }
            if (!strcmp(tok, "[then]")) {
                level--;
            }
            if (!strcmp(tok, "[else]") && (level == 1)) {
                level--;
            }
            LogColor(COLOR_NONE, 0, tok);
        }
        else {                          // EOL
            if (!refill()) {
                error = BAD_EOF;
                return;
            }
        }
    }
}
static void BrackIf(void) {
    int flag = Dpop();
    if (!flag) {
        BrackElse();
    }
}

//##############################################################################
// HTML reference document generator

SV htmlOut(char* s, FILE* fp) {         // text -> HTML
    char c;
    int italic = 0;
    while ((c = *s++))
        switch (c) {
        case '"':  fprintf(fp, "&quot;");  break;
        case '\'': fprintf(fp, "&apos;");  break;
        case '<':  fprintf(fp, "&lt;");    break;
        case '>':  fprintf(fp, "&gt;");    break;
        case '&':  fprintf(fp, "&amp;");   break;
        case '`':
            if (italic)
                fprintf(fp, "</tok>");
            else
                fprintf(fp, "<tok>");
            italic = (italic == 0);
            break;
        default:   fprintf(fp, "%c", c);
        }
}

SV GenerateDoc(void) {
    ParseFilename();
    FILE* fpr = fopenx(tok, "r");
    if (fpr == NULL) {
        error = BAD_OPENFILE;  return;
    }
    ParseFilename();
    FILE* fpw = fopenx(tok, "w");
    if (fpw == NULL) {
        error = BAD_CREATEFILE;
        fclose(fpr);   return;
    }
    static char wikiline[LineBufferSize];
    long int org = 0;
    if (fpr) { // pull in the header
        while (1) {
            if (fgets(wikiline, LineBufferSize, fpr) == NULL) break;
            trimCR(wikiline);
            int command = wikiline[0];
            if (command == '\\') {      // end of header
                org = ftell(fpr);       // origin of wiki
                break;
            }
            if (command != '#')         // copy non-comment to new HTML
                fprintf(fpw, "%s\n", wikiline);
        }
    } else
        fprintf(fpw, "<body>\n<h1>Chad Reference</h1>\n");
    uint16_t i = wordlist[context()];
    while (i) {
        char* na = Header[i].name;
        uint8_t fid = Header[i].srcFile;
        if (Header[i].help[0]) {
            fprintf(fpw, "<a name=\"%s\"></a>\n", ReferenceString(i));
            fprintf(fpw, "<h3><ref>%s:</ref> ", ref);
            if (fid) {
                fprintf(fpw, "<a href=\"../%s\">",
                    FilePaths[fid].filepath);
                htmlOut(na, fpw);
                fprintf(fpw, "</a>");
            }
            else {
                fprintf(fpw, "<chad>");
                htmlOut(na, fpw);
                fprintf(fpw, "</chad>");
            }
            if (ReferenceStackPic) {
                fprintf(fpw, " <com><i>( ");  htmlOut(ReferenceStackPic, fpw);
                fprintf(fpw, " )</i></com>");
            }
            fprintf(fpw, "</h3>\n");
            if (fpr) {                  // -> wiki
                fseek(fpr, org, SEEK_SET);
                int found = 0;
                int processing = 1;
                do {
                    if (fgets(wikiline, LineBufferSize, fpr) == NULL)
                        processing = 0;
                    trimCR(wikiline);
                    int command = wikiline[0];
                    char* txt = &wikiline[1];
                    if (found) {
                        switch (command) {
                        case '=': processing = 0;
                        case '#': goto endparagraph;
                        case 'H': fprintf(fpw, "%s\n", txt);  break;
                        case '_': fprintf(fpw, "<hr>");       break;
                        case '-':
                            fprintf(fpw, "<li>");
                            htmlOut(txt, fpw);
                            fprintf(fpw, "</li>");
                            break;
                        case ' ':
                            if (found == 1)
                                fprintf(fpw, "\n<p>");
                            found = 2;
                            htmlOut(txt, fpw);
                            fprintf(fpw, "\n");
                            break;
                        default:
endparagraph:               if (found > 1)
                                fprintf(fpw, "</p>\n");
                            found = 1;
                        }
                    }
                    else {              // look for reference "ref:comment"
                        if (command == '=') {
                            char* p = txt;
                            if ((p = strchr(txt, ':')) != NULL) *p++ = '\0';
                            found = (strcmp(txt, ref) == 0);
                        }
                    }
                } while (processing);
            }
        }
        else {
            fprintf(fpw, "<!-- No reference for %s -->\n", na);
        }
        i = Header[i].link;             // traverse from oldest
    }
    fprintf(fpw, "</body>\n</html>\n");
    fclose(fpw);
    if (fpr) fclose(fpr);
}

//##############################################################################
// Compile to SPI flash memory image

// The gecko key must be set up before calling GeckoByte.
// MakeBootList uses all the same key, to be the key's reset value on the target.
// Output to flash is via flashC8.

static uint32_t signature, flashPtr;

SV flashC8(uint8_t c) {
    signature = crcbyte(c, signature);
    FlashMemStore(flashPtr++, c ^ GeckoByte());
}

SV AddBootKey(void)     { ChadBootKey = (ChadBootKey << CELLBITS) + Dpop(); }
SV forg(void)           { flashPtr = Dpop(); }
SV fhere(void)          { Dpush(flashPtr); }
SV flashC16(uint16_t w) { flashC8(w >> 8);  flashC8((uint8_t)w); }

SV flashAN(uint16_t addr, uint16_t len) { 
    flashC8(0xC1); flashC16(addr);
    flashC8(0xC3); flashC16(len - 1);
}

SV flashCC(uint32_t w) {                // append big endian cell with bytes
    if (CELLBITS == 16)                 // 2 bytes
        flashC16(w);
    else if (CELLBITS > 24) {           // 4 bytes
        flashC16(w >> 16);  flashC16(w);
    }
    else {                              // 3 bytes
        flashC16(w >> 8);  flashC8(w);
    }
}

SV fcByte(void) { flashC8(Dpop()); }    // ( c8 -- )
SV fcHalf(void) { flashC16(Dpop()); }   // ( n16 -- )
SV fcCell(void) { flashCC(Dpop()); }    // ( n -- )

SV fc32(void) {                         // ( d -- )
    uint32_t w = Dpop() << CELLBITS;
    w |= Dpop();
    flashC16(w >> 16);  flashC16(w);
}

SV flashStr(char* s, int escaped) {     // compile string to flash
    size_t length = strlen(s);
    char hex[4];
    int cnt = 0;
    for (size_t i = 0; i < length; i++) {
        char c = *s++;
        if (escaped) {                  // handle escape sequences
            if (c == '\\') {
                c = *s++;
                length--;
                switch (c) {
                case 'e': c = 27;  break;  // ESC
                case 'l': c = 10;  break;  // LF
                case 'n': c = 10;  break;  // newline
                case 'r': c = 13;  break;  // CR
                case 'x': hex[2] = 0;  	   // hex byte
                    hex[0] = *s++;
                    hex[1] = *s++;
                    c = (char)strtol(hex, (char**)NULL, 16); break;
                case '0': c = 0;   break;  // NUL
                case '"': c = '"'; break;  // double-quote
                default: break;
                }
            }
        }
        flashC8(c);
        cnt++;
    }
}

// Strings in flash use a text encryption key in combination with the
// flash address to set the key. f$type needs to load this key
// unless the string is plaintext, in which case no key is needed.

uint64_t ChadTextKey = 0;

SV NewTextKey(void) {
    if (ChadTextKey) {
        GeckoLoad((ChadTextKey << CELLBITS) | (flashPtr & CELLMASK));
        GeckoByte();
    }
    else
        GeckoLoad(0);
}

SV xfcQuote(int escaped) {
    NewTextKey();
    if (flashPtr > CELLMASK)            // string must be 1-cell addressable
        error = BAD_FSOVERFLOW;
    parseword('"');
    flashC8((uint8_t)strlen(tok));      // string length
    flashStr(tok, escaped);             // string
}
SV fcQuote(void) { xfcQuote(0); }
SV feQuote(void) { xfcQuote(1); }
SV CfcQuote(void) { Literal(flashPtr);  fcQuote(); }
SV CfeQuote(void) { Literal(flashPtr);  feQuote(); }
SV dotQuote(void) { Literal(flashPtr);  fcQuote();  CompCall(Ctick("f$type")); }
SV desQuote(void) { Literal(flashPtr);  feQuote();  CompCall(Ctick("f$type")); }

SV AddTextKey(void) {
    ChadTextKey = (ChadTextKey << CELLBITS) + Dpop();
}
SV ExecTextKey(void) {
    Dpush(ChadTextKey & CELLMASK);  Dpush((cell)(ChadTextKey >> CELLBITS));
}
SV CompTextKey(void) {
    Literal(ChadTextKey & CELLMASK);  Literal((cell)(ChadTextKey >> CELLBITS));
}

// Write boot data to flash memory image in `flash.c`
SV MakeAPIlist(uint16_t cp0, uint16_t dp0) {
    GeckoLoad(ChadBootKey);
    signature = 0xFFFFFFFF;
    flashC8(0x80);                      // speed up SCLK
    flashAN(cp0, CP - cp0);
    flashC8(1);                         // 16-bit code write
    for (uint16_t i = cp0; i < CP; i++) {
        flashC16(Code[i]);
    }
    uint16_t count = DP - dp0;
    if (count) {
        uint8_t bytes = (CELLBITS + 7) >> 3;
        flashAN(CELL_ADDR(dp0), count);
        flashC8(3 + bytes);             // 16-bit data write
        for (uint16_t i = 0; i < count; i++) {
            cell x = Data[i];
            uint8_t j = bytes;
            while (j)
                flashC8((uint8_t)(x >> (8 * --j)));
        }
    }
    uint16_t sig_hi = signature >> 16;
    uint16_t sig_lo = signature & 0xFFFF;
    flashC8(0xE0);                      // end bootup
    flashC16(sig_hi);                   // 32-bit signature
    flashC16(sig_lo);
}

SV MakeBootList(void) { 
    MakeAPIlist(0, 0);
}

SV BootNrun(void) {
    Dpush(0);
    LoadFlash();                        // file --> "SPI flash"
    FlashMemBoot(0);                    // boot from flash
    Cold();                             // run CPU
}

SV Boot(void) {
    Dpush(0);
    LoadFlash();                        // file --> "SPI flash"
    FlashMemBoot(0);                    // boot from flash
    SkipToEOL();
}

// Translate C function to its Forth word name
static char* FnTargetName(void (*fn)()) { // target: ( w -- )
    if (fn == Def_Exec)  return "execute";
    if (fn == Def_Comp)  return "compile,";
    if (fn == DefA_Exec) return "APIexecute";
    if (fn == DefA_Comp) return "APIcompile,";
    if (fn == CompMacro) return "compile,"; // ignore macro
    if (fn == Equ_Exec)  return "noop";
    if (fn == Equ_Comp)  return "lit,";
    if (fn == Prim_Exec) return "InstExec";
    if (fn == Prim_Comp) return ",c";
    if (fn == doInstMod) return "or";
    if (fn == doLitOp)   return "lit,";
    if (fn == noCompile) return "noCompile";
    return NULL;
}

// Build header data in flash memory image in `flash.c`
// Copying lists this way reverses the linked list: The newest definitions are
// at the bottom, taking the longest to reach through traversal. This is good.
// Common Forth primitives will be found sooner.

SV MakeHeaders(void) {
    for (uint8_t i = wordlists; i > 0; i--) {
        char* wname = &wordlistname[i][0];
        size_t len = strlen(wname);
        NewTextKey();
        flashC8((uint8_t)len);          // begin wordlist with its name
        for (size_t i = 0; i < len; i++)
            flashC8(*wname++);
        NewTextKey();
        flashC8((uint8_t)len);
        uint32_t link = 0;
        uint16_t p = wordlist[i];
        while (p) {
            char* exec = FnTargetName(Header[p].ExecFn);
            char* comp = FnTargetName(Header[p].CompFn);
            if ((exec) && (comp)) {
                NewTextKey();
                uint32_t nextlink = flashPtr;
                flashCC(link);
                link = nextlink;
                wname = Header[p].name;
                len = strlen(wname);
                flashC8((uint8_t)len);
                for (size_t i = 0; i < len; i++)
                    flashC8(*wname++);
                flashCC(Header[p].w);
                flashCC(Ctick(exec));   // target versions of host fns
                flashCC(Ctick(comp));
                flashCC(Header[p].applet);
                uint8_t flags = 0xFF;
                if (Header[p].smudge == 0) flags &= ~0x80;
                if (Header[p].notail)      flags &= ~0x01;
                flashC8(flags);
            }
            p = Header[p].link;
        }
        Data[wids + i - 1] = link;
    }
}

/*
To do:
Add locals, applets, and cache size stuff to the wiki pages
*/

SI appletCP, appletDP, appletPage;

SV BeginApplet(void) {  // ( addr -- )
    appletCP = CP; CP = CodeSize - CodeCache;
    appletDP = DP; DP = BYTE_ADDR(DataSize - DataCache);
    isAPI = (Dpop() + 0xFF) >> 8;
    appletPage = isAPI << 8;
}

SV EndApplet(void) {
    uint32_t fp = flashPtr;
    flashPtr = isAPI << 8;              // 256-byte pages
    MakeAPIlist(CodeSize - CodeCache, BYTE_ADDR(DataSize - DataCache));
    CP = appletCP;
    DP = appletDP;
    appletPage = flashPtr;
    flashPtr = fp;                      // restore fp tp point to text region
    isAPI = 0;
    // wipe cache so you can't execute it without loading from flash image
    for (int i = 0; i < CodeCache; i++) {
        chadToCode(i + CodeSize - CodeCache, 0);
    }
}

SV AppletPage(void)   { Dpush(appletPage);   }
SV ToAppletPage(void) { appletPage = Dpop(); }

// Dump internal state in text format for file comparison tools like WinMerge.

SV SaveChadState(void) {
    ParseFilename();
    FILE* fp = fopenx(tok, "w");
    if (fp == NULL)
        error = BAD_CREATEFILE;
    else {
        fprintf(fp, "Code Memory\n");
        for (int i = 0; i < CodeSize; i++) {
            if ((i & 15) == 0) fprintf(fp, "%03X: ", i);
            fprintf(fp, "%04X", Code[i]);
            if ((i & 15) == 15) fprintf(fp, "\n");
            else fprintf(fp, " ");
        }
        fprintf(fp, "Data Memory\n");
        for (int i = 0; i < DataSize; i++) {
            if ((i & 7) == 0) fprintf(fp, "%03X: ", i);
            fprintf(fp, "%s", itos(Data[i], 16, (CELLBITS + 3) / 4, 1));
            if ((i & 7) == 7) fprintf(fp, "\n");
            else fprintf(fp, " ");
        }
        fprintf(fp, "\n");
        fclose(fp);
    }
}

// char and [char] support utf-8:
// bytes  from       to          1st        2nd         3rd         4th
// 1	  U + 0000   U + 007F    0xxxxxxx
// 2	  U + 0080   U + 07FF    110xxxxx	10xxxxxx
// 3	  U + 0800   U + FFFF    1110xxxx	10xxxxxx	10xxxxxx
// 4	  U + 10000  U + 10FFFF  11110xxx	10xxxxxx	10xxxxxx	10xxxxxx

CELL getUTF8(void) {
    char* p = tok;  cell c = *p++;
    if ((c & 0x80) == 0x00) return c;                       // 1-char UTF-8
    uint32_t d = *p++ & 0x3F;
    if ((c & 0xE0) == 0xC0) return ((c & 0x1F) << 6) | d;   // 2-char UTF-8
    d = (d << 6) | (*p++ & 0x3F);
    if ((c & 0xF0) == 0xE0) return ((c & 0x0F) << 12) | d;  // 3-char UTF-8
    d = (d << 6) | (*p++ & 0x3F);
    return ((c & 7) << 18) | d;                             // 4-char UTF-8
}

// Data space compilation assigns `dp` to a fixed RAM address to make it
// shareable. You can build a language with these, but it will only be usable
// on the host.

SV allot     (int n) { DP = n + DP; }
SV buffer    (int n) { Dpush(DP);  Constant();  allot(n); }
SV Buffer     (void) { buffer(Dpop()); }
SV Cvariable  (void) { buffer(1); }
SV Align      (void) { DP = aligned(DP); }
SV Variable   (void) { Align();  buffer(CELLS); }
SV Twovariable(void) { Variable();  allot(CELLS); }
SV Char       (void) { parseword(' ');  Dpush(getUTF8()); }
SV BrackChar  (void) { parseword(' ');  Literal(getUTF8()); }

SV HWoptions(void) {
    int n = COP_OPTIONS;
#ifdef HAS_LCDMODULE
    n |= 0x100;
#endif
#ifdef HAS_LEDSTRIP
    n |= 0x200;
#endif
    Dpush(n);
}

// Initialize the dictionary at startup

SV LoadKeywords(void) {
    hp = 0; // start empty
    wordlists = 0;
    DP = BYTE_ADDR(here);
    // Forth definitions
    root_wid = AddWordlist("root");
    forth_wid = AddWordlist("forth");
    Only(); // order = root _forth
    CURRENT = root_wid;
    AddEquate("root",         "1.0000 -- wid",        root_wid);
    AddEquate("forth-wordlist", "1.0010 -- wid",      forth_wid);
    AddKeyword("save-dump",  "1.0020 <filename> -- ", SaveChadState, noCompile);
    AddEquate("cm-size",      "1.0030 -- n",          CodeSize - CodeCache);
    AddEquate("cm-cache",     "1.0030 -- n",          CodeCache);
    AddEquate("dm-size",      "1.0040 -- n",          BYTE_ADDR(DataSize - DataCache));
    AddEquate("dm-cache",     "1.0040 -- n",          BYTE_ADDR(DataCache));
    AddEquate("cellbits",     "1.0050 -- n",          CELLBITS);
    AddEquate("cell",         "1.0060 -- n",          CELLS);
    AddEquate("|tib|",        "1.0065 -- n",          MaxLineLength);
    AddEquate(">in",          "1.0070 -- addr",       BYTE_ADDR(toin));
    AddEquate("#tib",         "1.0071 -- addr",       BYTE_ADDR(tibs));
    AddEquate("'tib",         "1.0072 -- addr",       BYTE_ADDR(atib));
    AddEquate("dp",           "1.0073 -- addr",       BYTE_ADDR(dp));
    AddEquate("cp",           "1.0074 -- addr",       BYTE_ADDR(cp));
    AddEquate("base",         "1.0075 -- addr",       BYTE_ADDR(base));
    AddEquate("wids",         "1.0076 -- addr",       BYTE_ADDR(wids));
    AddEquate("#order",       "1.0077 -- addr",       BYTE_ADDR(orders));
    AddEquate("orders",       "1.0078 -- addr",       BYTE_ADDR(order));
    AddEquate("current",      "1.0079 -- addr",       BYTE_ADDR(current));
    AddEquate("state",        "1.0080 -- addr",       BYTE_ADDR(state));
    AddEquate("api",          "1.0081 -- addr",       BYTE_ADDR(api));
    AddKeyword("stats",       "1.0090 --",            Stats,         noCompile);
    AddKeyword("locate",      "1.0091 <name> --",     Locate,        noCompile);
    AddKeyword("verbosity",   "1.0092 flags --",      Verbosity,     noCompile);
    AddKeyword("+bkey",       "1.0093 u --",          AddBootKey,    noCompile);
    AddKeyword("+tkey",       "1.0094 u --",          AddTextKey,    noCompile);
    AddKeyword("tkey",        "1.0095 -- ud",         ExecTextKey, CompTextKey);
    AddKeyword("load-flash",  "1.0134 <filename> a --", LoadFlash,   noCompile);
    AddKeyword("save-flash", "1.0136  fmt d_pid bit <name> --", SaveFlash, noCompile);
    AddKeyword("boot",        "1.0138 <filename> --", BootNrun,      noCompile);
    AddKeyword("boot-test",   "1.0139 <filename> --", Boot,          noCompile);
    AddKeyword("make-heads",  "1.0140 --",            MakeHeaders,   noCompile);
    AddKeyword("make-boot",   "1.0141 --",            MakeBootList,  noCompile);
    AddKeyword("applet",      "1.0146 addr --",       BeginApplet,   noCompile);
    AddKeyword("end-applet",  "1.0147 --",            EndApplet,     noCompile);
    AddKeyword("paged",       "1.0148 -- addr",       AppletPage,    noCompile);
    AddKeyword("paged!",      "1.0149 addr --",       ToAppletPage,  noCompile);
    AddKeyword("equ",         "1.0150 x <name> --",   Constant,      noCompile);
    AddKeyword("assert",      "1.0160 n1 n2 --",      Assert,        noCompile);
    AddKeyword("hwoptions",   "1.0170 -- n",          HWoptions,     noCompile);
    AddKeyword(".s",          "1.0200 ? -- ?",        dotESS,        noCompile);
    AddKeyword("see",         "1.0210 <name> --",     See,           noCompile);
    AddKeyword("dasm",        "1.0220 xt len --",     Dasm,          noCompile);
    AddKeyword("sstep",       "1.0230 xt len --",     Steps,         noCompile);
    AddKeyword("cold",        "1.0235 --",            Cold,          noCompile);
    AddKeyword("words",       "1.0240 --",            Words,         noCompile);
    AddKeyword("Words",       "1.0241 --",            Words,         noCompile);
    AddKeyword("bye",         "1.0250 --",            Bye,           noCompile);
    AddKeyword("[if]",        "1.0260 flag --",       BrackIf,       noCompile);
    AddKeyword("[then]",      "1.0270 --",            Nothing,       noCompile);
    AddKeyword("[else]",      "1.0280 --",            BrackElse,     noCompile);
    AddKeyword("[undefined]", "1.0290 <name> -- flag", BrackUndefined, noCompile);
    AddKeyword("[defined]",   "1.0300 <name> -- flag", BrackDefined, noCompile);
    AddKeyword(".",           "1.0400 n --",          dot,           noCompile);
#ifdef HASFLOATS
    AddKeyword("f.",          "1.0410 d --",          fdot,          noCompile);
    AddKeyword("set-expbits", "1.0415 n --",          SetFPexpbits,  noCompile);
#endif
    AddKeyword("forth",       "1.0420 --",            ForthLex,      noCompile);
    AddKeyword("assembler",   "1.0430 --",            AsmLex,        noCompile);
    AddKeyword("definitions", "1.0440 --",            Definitions,   noCompile);
    AddKeyword("get-CURRENT", "1.0450 -- wid",        GetCurrent,    noCompile);
    AddKeyword("set-CURRENT", "1.0460 wid --",        SetCurrent,    noCompile);
    AddKeyword("get-order",   "1.0470 -- widN..wid1 N", GetOrder,    noCompile);
    AddKeyword("set-order",   "1.0480 widN..wid1 N --", SetOrder,    noCompile);
    AddKeyword("only",        "1.0490 --",            Only,          noCompile);
    AddKeyword("previous",    "1.0500 --",            Previous,      noCompile);
    AddKeyword("also",        "1.0510 --",            Also,          noCompile);
    AddKeyword("order",       "1.0520 --",            Order,         noCompile);
    AddKeyword("Order",       "1.0520 --",            Order,         noCompile);
    AddKeyword("+order",      "1.0530 wid --",        PlusOrder,     noCompile);
    AddKeyword("lexicon",     "1.0540 <name> --",     Lexicon,       noCompile);
    AddKeyword("include",     "1.1000 <filename> --", Include,       noCompile);
    AddKeyword("(",           "1.1010 ccc<paren> --", SkipToPar,     SkipToPar);
    AddKeyword("\\",          "1.1020 ccc<EOL> --",   SkipToEOL,     SkipToEOL);
    AddKeyword(".(",          "1.1030 ccc> --",       EchoToPar,     noCompile);
    AddKeyword(".\"",         "1.1035 ccc> --",       noExecute,     dotQuote);
    AddKeyword(",\"",         "1.1036 ccc> --",       fcQuote,       CfcQuote);
    AddKeyword(".\\\"",       "1.1037 ccc> --",       noExecute,     desQuote);
    AddKeyword(",\\\"",       "1.1038 ccc> --",       feQuote,       CfeQuote);
    AddKeyword("/,",          "1.1500 --",            NewTextKey,    noCompile);
    AddKeyword("8,",          "1.1501 c --",          fcByte,        noCompile);
    AddKeyword("16,",         "1.1502 n --",          fcHalf,        noCompile);
    AddKeyword("f,",          "1.1503 n --",          fcCell,        noCompile);
    AddKeyword("32,",         "1.1504 d --",          fc32,          noCompile);
    AddKeyword("constant",    "1.1040 x <name> --",   Constant,      noCompile);
    AddKeyword("aligned",     "1.1050 addr -- a-addr", Aligned,      noCompile);
    AddKeyword("align",       "1.1060 --",            Align,         noCompile);
    AddKeyword("char",        "1.1070 <c> -- n",      Char,          noCompile);
    AddKeyword("chars",       "1.1080 n1 -- n2",      Nothing,       Nothing);
    AddKeyword("cr",          "1.1090 --",            Cr,            noCompile);
    AddKeyword("decimal",     "1.1110 --",            Decimal,       noCompile);
    AddKeyword("hex",         "1.1120 --",            Hex,           noCompile);
    AddKeyword("variable",    "1.1130 <name> --",     Variable,      noCompile);
    AddKeyword("cvariable",   "1.1140 <name> --",     Cvariable,     noCompile);
    AddKeyword("2variable",   "1.1145 <name> --",     Twovariable,   noCompile);
    AddKeyword("buffer:",     "1.1150 n <name> --",   Buffer,        noCompile);
    AddKeyword("[char]",      "1.1160 <c> --",        noExecute,     BrackChar);
    AddKeyword("[",           "1.1170 --",            toImmediate, toImmediate);
    AddKeyword("]",           "1.1180 --",            toCompile,     toCompile);
    AddKeyword("'",           "1.1190 <name> -- xt",  Tick,          noCompile);
    AddKeyword("[']",         "1.1200 <name> --",     noExecute,     BrackTick);
    AddKeyword(":",           "1.1210 <name> --",     Colon,         noCompile);
    AddKeyword(":noname",     "1.1220 -- xt",         NoName,        noCompile);
    AddKeyword("exit",        "1.1230 --",            noExecute,     CompExit);
    AddKeyword(";",           "1.1240 --",            Semicolon,     SemiComp);
    AddKeyword("recurse",     "1.1245 --",            noExecute,     Recurse);
    AddKeyword("CODE",        "1.1250 <name> -- 0",   BeginCode,     noCompile);
    AddKeyword("literal",     "1.1260 x --",          noExecute,     doLITERAL);
    AddKeyword("immediate",   "1.1270 --",            Immediate,     noCompile);
    AddKeyword("marker",      "1.1280 <name> --",     Marker,        noCompile);
    AddKeyword("postpone",    "1.1285 <name> --",     Postpone,      Postpone);
    AddKeyword("there",       "1.1290 -- taddr",      There,         noCompile);
    AddKeyword("forg",        "1.1300 faddr --",      forg,          noCompile);
    AddKeyword("fhere",       "1.1305 -- faddr",      fhere,         noCompile);
    AddKeyword("later",       "1.1310 <name> --",     Later,         noCompile);
    AddKeyword("resolves",    "1.1320 xt <name> --",  Resolves,      noCompile);
    AddKeyword("macro",       "1.1330 --",            Macro,         noCompile);
    AddKeyword("write-protect", "1.1340 --",          WrProtect,     noCompile);
    AddKeyword("no-tail-recursion", "1.1350 --",    NoTailRecursion, noCompile);
    AddKeyword("|bits|",      "1.1360 n --",       SetTableBitWidth, noCompile);
    AddKeyword("|",           "1.1370 x --",          TableEntry,    noCompile);
    AddKeyword("irq!",        "1.1380 x --",          irqStore,      noCompile);
    AddKeyword("gendoc",      "1.1390 --",            GenerateDoc,   noCompile);
    AddKeyword("cotrig",      "1.1400 sel --",        CoprocInst,    noCompile);
    AddKeyword("module",      "1.1410 --",            BeginLocals,   noCompile);
    AddKeyword("end-module",  "1.1420 --",            EndLocals,     noCompile);
    AddKeyword("exportable",  "1.1430 --",            Exportable,    noCompile);
    AddKeyword("local",       "1.1440 -- a",          Local,         noCompile);
    // Primitives can compile and execute
    // They are basically 16-bit fixed codes
    AddALUinst("nop",     "1.2000 --",   0);
    AddALUinst("invert",  "1.2010 x -- ~x",           com);
    AddALUinst("2*",      "1.2020 n -- n*2",          shl1  | co);
    AddALUinst("2/",      "1.2030 n -- n/2",          shr1  | co);
    AddALUinst("2*c",     "1.2040 n -- n*2+c",        shlx  | co);
    AddALUinst("2/c",     "1.2050 n -- c+n/2",        shrx  | co);
    AddALUinst("xor",     "1.2060 n1 n2 -- n3",       eor   |        sdn);
    AddALUinst("and",     "1.2070 n1 n2 -- n3",       Tand  |        sdn);
    AddALUinst("+",       "1.2080 n1 n2 -- n3",       add   |        sdn);
    AddALUinst("-",       "1.2090 n1 n2 -- n3",       sub   |        sdn);
    AddALUinst("dup",     "1.2100 x -- x x",          TtoN  |        sup);
    AddALUinst("over",    "1.2110 x1 x2 -- x1 x2 x1", NtoT  | TtoN | sup);
    AddALUinst("swap",    "1.2120 x1 x2 -- x2 x1",    NtoT  | TtoN);
    AddALUinst("drop",    "1.2130 x --",              NtoT  |        sdn);
    AddALUinst("nip",     "1.2140 x1 x2 -- x2",                      sdn);
    AddALUinst("0=",      "1.2150 x -- flag",         zeq   );
    AddALUinst("0<",      "1.2160 n -- flag",         less0 );
    AddALUinst(">r",      "1.2170 x -- | -- x",       NtoT  | TtoR | sdn | rup);
    AddALUinst("r>",      "1.2180 -- x | x --",       RtoT  | TtoN | sup | rdn);
    AddALUinst("r@",      "1.2190 -- x | x -- x",     RtoT  | TtoN | sup);
//  AddALUinst("rshift",  "1.2200 x1 u -- x2",        shr          | sdn);
//  AddALUinst("lshift",  "1.2210 x1 u -- x2",        shl          | sdn);
    AddALUinst("carry",   "1.2500 -- n",              carry | TtoN | sup);
    AddALUinst("w",       "1.2510 -- x",              WtoT  | TtoN | sup);
    AddALUinst(">carry",  "1.2520 n --",              NtoT  | co   | sdn);
    AddALUinst("+c",      "1.2530 n1 n2 -- n3",       add   | co   | sdn);
    AddALUinst("-c",      "1.2531 n1 n2 -- n3",       sub   | co   | sdn);
    AddALUinst("_@",      "1.2540 addr -- addr",              memrd);  // start
    AddALUinst("_@_",     "1.2550 addr -- x",         read);        // end read
    AddALUinst("_!",      "1.2560 x addr -- x",              write | sdn);
    AddALUinst("_io!",    "1.2570 x addr -- x",               iow  | sdn);
    AddALUinst("_io@",    "1.2580 addr -- addr",              ior);    // start
    AddALUinst("_io@_",   "1.2590 addr -- x",         input);    // end io read
    AddALUinst("2dupand", "1.2600 u v -- u v u&v",    Tand  | TtoN | sup);
    AddALUinst("2dupxor", "1.2610 u v -- u v u^v",    eor   | TtoN | sup);
    AddALUinst("2dup+",   "1.2620 u v -- u v u+v",    add   | TtoN | sup);
    AddALUinst("2dup-",   "1.2630 u v -- u v u-v",    sub   | TtoN | sup);
    AddALUinst("swapb",   "1.2640 x -- y",            swapb);
    AddALUinst("swapw",   "1.2650 x -- y",            swapw);
    AddALUinst("overand", "1.2660 u v -- u u&v",      Tand);
    AddALUinst("overxor", "1.2670 u v -- u u^v",      eor);
    AddALUinst("over+",   "1.2680 u v -- u u+v",      add   | co);
    AddALUinst("over-",   "1.2690 u v -- u u-v",      sub   | co);
    AddALUinst("dup>r",   "1.2700 x -- x | -- x",     TtoR               | rup);
    AddALUinst("rdrop",   "1.2710 -- | x --",                              rdn);
    AddALUinst("_dup@",   "1.2730 addr -- addr x",    read  | TtoN | sup);
    AddALUinst("spstat",  "1.2740 -- rp<<8|sp",       who   | TtoN | sup);
    AddALUinst("(R-1)@",  "1.2750 -- x-1 | x -- x",  RM1toT | TtoN | sup);
    AddALUinst("_next_",  "1.2760 n -- flag | x -- n", zeq  | TtoR);
    AddALUinst("costat",  "1.2770 -- n",              cop   | TtoN | sup);
    // compile-only control words, can't be postponed
    AddKeyword("begin",   "1.2900 --",  noExecute, doBegin);
    AddKeyword("again",   "1.2910 --",  noExecute, doAgain);
    AddKeyword("until",   "1.2920 --",  noExecute, doUntil);
    AddKeyword("if",      "1.2930 --",  noExecute, doIf);
    AddKeyword("else",    "1.2940 --",  noExecute, doElse);
    AddKeyword("then",    "1.2950 --",  noExecute, doThen);
    AddKeyword("while",   "1.2960 --",  noExecute, doWhile);
    AddKeyword("repeat",  "1.2970 --",  noExecute, doRepeat);
    AddKeyword("for",     "1.2980 --",  noExecute, doFor);
    AddKeyword("next",    "1.2990 --",  noExecute, doNext);
    // assembler
    asm_wid = AddWordlist("asm");
    AddEquate("asm",        "1.5000 -- wid", asm_wid);
    CURRENT = asm_wid;
    AddKeyword("begin",     "1.5100 --",  doBegin,   noCompile);
    AddKeyword("again",     "1.5110 --",  doAgain,   noCompile);
    AddKeyword("until",     "1.5120 --",  doUntil,   noCompile);
    AddKeyword("if",        "1.5130 --",  doIf,      noCompile);
    AddKeyword("else",      "1.5140 --",  doElse,    noCompile);
    AddKeyword("then",      "1.5150 --",  doThen,    noCompile);
    AddKeyword("while",     "1.5160 --",  doWhile,   noCompile);
    AddKeyword("repeat",    "1.5170 --",  doRepeat,  noCompile);
    AddKeyword(";CODE",     "1.5010 0 --",  EndCode,  noCompile);
    AddModifier("RET",      "1.5020 n1 -- n2",  ret | rdn );  // return bit
    AddModifier("T",        "1.6000 n1 -- n2",  alu  );  // Instruction fields
    AddModifier("COP",      "1.6010 n1 -- n2",  cop  );
    AddModifier("T0<",      "1.6020 n1 -- n2",  less0);
    AddModifier("C",        "1.6030 n1 -- n2",  carry);
    AddModifier("T2/",      "1.6040 n1 -- n2",  shr1 );
    AddModifier("cT2/",     "1.6050 n1 -- n2",  shrx );
    AddModifier("T2*",      "1.6060 n1 -- n2",  shl1 );
    AddModifier("T2*c",     "1.6070 n1 -- n2",  shlx );
    AddModifier("N",        "1.6080 n1 -- n2",  NtoT );
    AddModifier("W",        "1.6090 n1 -- n2",  WtoT );
    AddModifier("T^N",      "1.6100 n1 -- n2",  eor  );
    AddModifier("~T",       "1.6110 n1 -- n2",  com  );
    AddModifier("T&N",      "1.6120 n1 -- n2",  Tand );
    AddModifier("><",       "1.6130 n1 -- n2",  swapb );
    AddModifier("><16",     "1.6140 n1 -- n2",  swapw );
    AddModifier("T+N",      "1.6150 n1 -- n2",  add  );
    AddModifier("N-T",      "1.6170 n1 -- n2",  sub  );
    AddModifier("T0=",      "1.6190 n1 -- n2",  zeq );
//  AddModifier("N>>T",     "1.6200 n1 -- n2",  shr  );
//  AddModifier("N<<T",     "1.6210 n1 -- n2",  shl  );
    AddModifier("R",        "1.6220 n1 -- n2",  RtoT );
    AddModifier("R-1",      "1.6230 n1 -- n2",  RM1toT );
    AddModifier("[T]",      "1.6240 n1 -- n2",  read );
    AddModifier("io[T]",    "1.6250 n1 -- n2",  input);
    AddModifier("status",   "1.6260 n1 -- n2",  who);
    AddModifier("T->N",     "1.7010 n1 -- n2",  TtoN );  // strobe field
    AddModifier("T->R",     "1.7020 n1 -- n2",  TtoR );
    AddModifier("N->[T]",   "1.7030 n1 -- n2",  write);
    AddModifier("N->io[T]", "1.7040 n1 -- n2",  iow  );
    AddModifier("_IORD_",   "1.7050 n1 -- n2",  ior);
    AddModifier("_MEMRD_",  "1.7060 n1 -- n2",  memrd);
    AddModifier("CO",       "1.7070 n1 -- n2",  co  );
    AddModifier("r+1",      "1.8010 n1 -- n2",  rup  );  // stack pointer field
    AddModifier("r-1",      "1.8020 n1 -- n2",  rdn  );
    AddModifier("d+1",      "1.8030 n1 -- n2",  sup  );
    AddModifier("d-1",      "1.8040 n1 -- n2",  sdn  );
    AddLitOp("alu",         "1.9010 n -- 0",  alu );
    AddLitOp("branch",      "1.9020 n -- 0",  jump );
    AddLitOp("0branch",     "1.9030 n -- 0",  zjump);
    AddLitOp("scall",       "1.9040 n -- 0",  call );
    AddLitOp("litx",        "1.9050 n -- 0",  litx );
    AddLitOp("cop",         "1.9060 n -- 0",  copop );
    AddLitOp("imm",         "1.9070 n -- 0",  lit  );
    CURRENT = forth_wid;
}

SV CopyBuffer(void) {                   // copy buf to tib region in Data
    char* src = buf;
    cell bytes = TIBS;
    cell words = (bytes + CELLS - 1) / CELLS;
    cell addr = DataSize - CELL_ADDR(MaxLineLength);
    ATIB = BYTE_ADDR(addr);
    cell* dest = &Data[addr];
    for (cell i = 0; i < words; i++) {  // pack string into data memory
        uint32_t w = 0;                 // little-endian packing
        for (int j = 0; j < CELLS; j++) {
            w |= (uint8_t)*src++ << (j * 8);
        }
        *dest++ = w;
    }
}

//##############################################################################
// Text Interpreter
// Processes a line at a time from either stdin or a file.

int chad(char * line, int maxlength) {
    buf = line;  maxlen = maxlength;    // assign a working buffer
    LoadKeywords();
    filedepth = 0;
    fileID = 0;
    Decimal();
    while (1) {
        File.fp = stdin;                // keyboard input
        error = 0;                      // interpreter state
        toImmediate();
        cycles = spMax = rpMax = 0;     // CPU stats
        sp = rp = 0;                    // stacks
        while (!error) {
            TOIN = 0;
            TIBS = strlen(buf);
            if (TIBS > MaxLineLength)
                error = BAD_INPUT_LINE;
            else
                CopyBuffer();
            uint64_t time0 = GetMicroseconds();
            uint64_t cycles0 = cycles;
            while (parseword(' ')) {
                if (verbose & 2) {
                    printf("  %s", tok);
                }
                if (EvalToken(tok)) {   // try to convert to number
                    LogColor(COLOR_NUM, 0, tok);
                    int i = 0;   int radix = BASE;   char c = 0;
                    if (radix == 0)
                        error = DIV_BY_ZERO;
#ifdef HASFLOATS
                    if (isfloat(tok)) {
                        char* eptr;
                        double y = strtod(tok, &eptr);
                        if ((errno == ERANGE) || (errno == EINVAL))
                            goto bogus;
                        if (STATE)
                            LiteralFP(y);
                        else
                            DpushFP(y);
                    } else
#endif
                    {
                        int64_t x = 0;  int neg = 0;  int decimal = -1;
                        switch (tok[0]) {   // leading digit
                        case '-': i++;  neg = -1;    break;
                        case '+': i++;               break;
                        case '$': i++;  radix = 16;  break;
                        case '#': i++;  radix = 10;  break;
                        case '&': i++;  radix = 8;   break;
                        case '%': i++;  radix = 2;   break;
                        case '\0': { goto bogus; }
                        default: break;
                        }
                        while ((c = tok[i++])) {
                            switch (c) {
                            case '.':  decimal = i;  break;
                            default:
                                c = c - '0';
                                if (c & 0x80) goto bogus;
                                if (c > 9) {
                                    c -= 7;
                                    if (c < 10) goto bogus;
                                }
                                if (c > 41) c -= 32; // lower to upper
                                if (c >= radix)
                                    bogus:          error = UNRECOGNIZED;
                                x = x * radix + c;
                            }
                        }
                        if (neg) x = -x;
                        if (!error) {
                            if (decimal < 0) {
                                x &= CELLMASK;
                                if (STATE) {
                                    Literal((cell)x);
                                }
                                else {
                                    Dpush((cell)(x));
                                }
                            }
                            else {
                                if (STATE) {
                                    Literal((cell)(x & CELLMASK));
                                    Literal((cell)(x >> CELLBITS) & CELLMASK);
                                }
                                else {
                                    Dpush((cell)(x & CELLMASK));
                                    Dpush((cell)(x >> CELLBITS)& CELLMASK);
                                }
                            }
                        }
                    }
                }
                if (verbose & VERBOSE_TOKEN) {
                    printf(" ( ");
                    PrintDataStack();
                    printf(")\n");
                }
                if (verbose & VERBOSE_SRC) {
                    printf(") (%s", &buf[TOIN]);
                }
                if (sp == (StackSize - 1)) error = BAD_STACKUNDER;
                if (rp == (StackSize - 1)) error = BAD_RSTACKUNDER;
                if (error) {
                    switch (error) {
                    case BYE: return 0;
                    default: ErrorMessage (error, tok);
                    }
                    while (filedepth) {
                        printf("%s, Line %d: ",
                            FilePaths[File.FID].filepath, File.LineNumber);
                        printf("%s\n", File.Line);
                        fclose(File.fp);
                        LogEnd();
                        fclose(File.hfp);
                        filedepth--;
                    }
                    rp = sp = 0;
                    goto done;
                }
            }
done:       elapsed_us = GetMicroseconds() - time0;
            elapsed_cycles = cycles - cycles0;
            if (File.fp == stdin) {
                if (SDEPTH) {
                    printf("\\ ");
                    PrintDataStack();
                }
            }
            refill();
        }
    }
}

//##############################################################################
// Other exported functions

void chadError (int32_t n) {
    if (n & MSB) n |= ~CELLMASK;        // sign extend errorcode
    error = n;
}

uint64_t chadCycles(void) {
    return cycles;
}

uint16_t chadReadCode(uint32_t addr) {
    uint16_t r = Code[addr & (CodeSize - 1)];
    return r;
}

