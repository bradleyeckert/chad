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
#include "chaddefs.h"
#include "iomap.h"
#include "config.h"

SI verbose = 0;
uint8_t sp, rp;                         // stack pointers
CELL t, pc, cy, lex, w;                 // registers
CELL Data[DataSize];                    // data memory
CELL Dstack[StackSize];                 // data stack
CELL Rstack[StackSize];                 // return stack
CELL Raddr;                             // data memory read address
SI error;                               // simulator and interpreter error code

#define dpCell 0                        // define shared variables
#define baseByte (dpCell + CELLS)
#define stateByte (baseByte + 1)

static uint8_t fetchByte(int caddr) {   // fetch byte from data memory
    cell a = CELL_ADDR(caddr);
    if (a & ~(DataSize - 1)) {
        error = BAD_DATA_READ;  return 0;
    }
    int shift = (caddr & (CELLS - 1)) << 3;
    return (Data[a] >> shift) & 0xFF;
}

SV storeByte(uint8_t c, int caddr) {    // store byte to data memory
    cell a = CELL_ADDR(caddr);
    if (a & ~(DataSize - 1)) {
        error = BAD_DATA_WRITE;  return;
    }
    cell shift = 8 * (caddr & (CELLS - 1));
    cell old = Data[a] & ~(0xFF << shift);
    Data[a] = old + (c << shift);
}

static uint8_t baseFetch(void) { return fetchByte(baseByte); }
SV baseStore(uint8_t c) { storeByte(c, baseByte); }
static uint8_t stateFetch(void) { return fetchByte(stateByte); }
SV stateStore(uint8_t c) { storeByte(c, stateByte); }
CELL dpFetch(void) { return Data[CELL_ADDR(dpCell)]; }
SV dpStore(cell x) { Data[CELL_ADDR(dpCell)] = x; }
SV Hex(void) { baseStore(16); }
SV Decimal(void) { baseStore(10); }
SV toImmediate(void) { stateStore(0); }
SV toCompile(void) { stateStore(1); }
CELL DisassembleInsn(cell IR);

SV Cdot(cell x) {  // cuz no itoa
    int32_t n = x;
#if (CELLBITS < 32)
    if (x & (1 << (CELLBITS - 1))) n -= 1 << CELLBITS;
    x &= CELLMASK; // unsigned
#endif
    if (baseFetch() == 16) printf("%Xh ", x);
    else printf("%d ", n);
}

SV PrintStack(void) {                   // ( ... -- ... )
    int depth = SDEPTH;                 // primitive of .s
    for (int i = 0; i < depth; i++) {
        if (i == (depth - 1)) {
            Cdot(t);
        }
        else {
            Cdot(Dstack[(i + 2) & SPMASK]);
        }
    }
}

SV PrintRStack(void) { 
    int depth = RDEPTH;
    if (depth == (RPMASK - 1)) depth = 0;
    for (int i = 0; i < depth; i++) {
        Cdot(Rstack[(i + 1) & RPMASK]);
    }
}

SV TraceLine(cell pc, uint16_t insn) {
    DisassembleInsn(insn);
    printf("%03Xh: %04Xh ( ", pc, insn);
    PrintStack();
    printf(")");
    if (RDEPTH) {
        printf(" (R: ");  PrintRStack();
        printf(")");
    }
    printf(" \\ w=%Xh, cy=%X\n", w & CELLMASK, cy);
}

//##############################################################################
// CPU simulator

static uint16_t Code[CodeSize];         // code memory
uint8_t spMax, rpMax;                   // stack depth tracking
static uint32_t writeprotect = 0;       // highest writable code address
static uint64_t cycles = 0;             // cycle counter
static uint32_t latency = 0;            // maximum cycles between return

// The C host uses this to write to code space.
// Forth code can only write to code space using iomap.c.

void chadToCode (uint32_t addr, uint32_t x) {
    if (addr > CodeSize) {
        error = BAD_CODE_WRITE;  return;
    }
    if (addr < writeprotect) {
        error = BAD_ROMWRITE;  return;
    }
    Code[addr & (CodeSize-1)] = (cell)x;
}

SV Dpush(cell v) // push v on the data stack
{
    SP = SPMASK & (SP + 1);
    Dstack[SP] = t;
    t = v;
}

CELL Dpop(void) // pop value from the data stack and return it
{
    cell v = t;
    t = Dstack[SP];
    SP = SPMASK & (SP - 1);
    return v;
}

SV Rpush(cell v) // push v on the return stack
{
    RP = RPMASK & (RP + 1);
    Rstack[RP] = v;
}

#if (CELLBITS > 31)
#define sum_t uint64_t
#else
#define sum_t uint32_t
#endif

// The simulator used https://github.com/samawati/j1eforth as a template.
// single = 0: Run until the return stack empties, returns 2 if ok else error.
// single = 1: Execute one instruction (single step) from Code[PC].
// single = 10000h + instruction: Execute instruction. Returns the instruction.
// MoreInstrumentation slows down the code by 40%.

SI sign2b[4] = { 0, 1, -2, -1 };        /* 2-bit sign extension */

SI CPUsim(int single) {
    cell _t = t;                        // types are unsigned
    cell _pc;
    uint16_t insn;
#ifdef MoreInstrumentation
    uint16_t retMark = (uint16_t)cycles;
#endif
    uint8_t mark = RDEPTH;
    if (single & 0x10000) {             // execute one instruction directly
        insn = single & 0xFFFF;
        goto once;
    }
    do {
        insn = Code[pc & (CodeSize-1)];
    once:   
#ifdef MoreInstrumentation
        if (verbose & VERBOSE_TRACE) {
            TraceLine(pc, insn);
        }
#endif
        _pc = pc + 1;
        cell _lex = 0;
        if (insn & 0x8000) {
            int target = (lex << 13) | (insn & 0x1fff);
            switch (insn >> 13) { // 4 to 7
            case 4:                                                 /*   jump */
                _pc = target;  break;
            case 5:                                                 /*  zjump */
                if (!Dpop()) {_pc = target;}  break;
            case 6:                                                 /*   call */
                RP = RPMASK & (RP + 1);
                Rstack[RP & RPMASK] = _pc << 1;
                _pc = target;
#ifdef MoreInstrumentation
                if (verbose & VERBOSE_TRACE) {
                    printf("Call to %Xh\n", target); 
                } 
#endif
                break;
            default:
                if (insn & 0x1000) {                                /*    imm */
                    Dpush((lex<<11) | ((insn&0xe00)>>1) | (insn&0xff));
                    if (insn & 0x100) {                             /*  r->pc */
                        _pc = Rstack[RP] >> 1;
                        if (RDEPTH == mark) single = 2;
                        RP = RPMASK & (RP - 1);
#ifdef MoreInstrumentation
                        uint16_t time = (uint16_t)cycles - retMark;
                        retMark = (uint16_t)cycles;
                        if (time > latency)
                            latency = time;
#endif
                    }
                } else {
                    _lex = (lex << 11) | (insn & 0x7FF);            /*   litx */
                }
            }
        } else { // ALU
            if (insn & 0x100) {                                     /*  r->pc */
                _pc = Rstack[RP] >> 1;
                if (RDEPTH == mark) single = 2;
#ifdef MoreInstrumentation
                uint16_t time = (uint16_t)cycles - retMark;
                retMark = (uint16_t)cycles;
                if (time > latency)
                    latency = time;
#endif
            }
            cell s = Dstack[SP];
            cell _c = t & 1;
            cell temp;
            sum_t sum;
            switch ((insn >> 9) & 0x1F) {
            case 0x00: _t = t;                               break; /*      T */
            case 0x10: _t = 0;                               break; /*    COP */
            case 0x01: _t = (t & MSB) ? -1 : 0;              break; /*    T<0 */
            case 0x11: _t = cy;                              break; /*      C */
            case 0x02: _c = t & 1;  temp = (t & MSB);
                _t = (t >> 1) | temp;                        break; /*    T2/ */
            case 0x12: _c = t & 1;
                _t = (t >> 1) | (cy << (CELLBITS-1));        break; /*   cT2/ */
            case 0x03: _c = t >> (CELLBITS-1);
                       _t = t << 1;                          break; /*    T2* */
            case 0x13: _c = t >> (CELLBITS-1);
                       _t = (t << 1) | cy;                   break; /*   T2*c */
            case 0x04: _t = s;                               break; /*      N */
            case 0x14: _t = w;                               break; /*      W */
            case 0x05: _t = s ^ t;                           break; /*    T^N */
            case 0x15: _t = ~t;                              break; /*     ~T */
            case 0x06: _t = s & t;                           break; /*    T&N */
            case 0x16: _t = w & t;                           break; /*    T&W */
            case 0x07: _t = (t & (CELLS-1)) << 3; // {0,8,16,24}
                w = 0xFF;                                    break; /*   mask */
            case 0x08: sum = (sum_t)s + (sum_t)t;
                _c = (sum >> CELLBITS) & 1;  _t = (cell)sum; break; /*    T+N */
            case 0x18: sum = (sum_t)s + (sum_t)t + cy;
                _c = (sum >> CELLBITS) & 1;  _t = (cell)sum; break; /*   T+Nc */
            case 0x09: sum = (sum_t)s - (sum_t)t;
                _c = (sum >> CELLBITS) & 1;  _t = (cell)sum; break; /*    N-T */
            case 0x19: sum = ((sum_t)s - (sum_t)t) - cy;
                _c = (sum >> CELLBITS) & 1;  _t = (cell)sum; break; /*   N-Tc */
            case 0x0A: _t = (t) ? 0 : -1;                    break; /*    T0= */
            case 0x0B: _t = s >> (t & CELL_AMASK);           break; /*   N>>T */
            case 0x0C: _t = s << (t & CELL_AMASK);           break; /*   N<<T */

            case 0x0D: _t = Rstack[RP];                      break; /*      R */
            case 0x1D: _t = Rstack[RP] - 1;                  break; /*    R-1 */
            case 0x0E: _t = Data[Raddr];
                if (verbose & VERBOSE_TRACE) {
                    printf("Reading %Xh from cell %Xh\n", _t, Raddr); 
                } break;                                            /*    [T] */
            case 0x1E: _t = readIOmap(t);                    break; /*  io[T] */
            case 0x0F: _t = (RDEPTH<<8) + SDEPTH;            break; /* status */
            default:   _t = t;  single = BAD_ALU_OP;
            }
            SP = SPMASK & (SP + sign2b[insn & 3]);                /* dstack+- */
            RP = RPMASK & (RP + sign2b[(insn >> 2) & 3]);         /* rstack+- */
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
            case  5: writeIOmap(t, s);                     break; /* N->io[T] */
               // 6 = IORD strobe
            case  7: cy = _c;  w = t;                        break;   /*   co */
            default: break;
            }
            t = _t & CELLMASK;
        }
        pc = _pc;  lex = _lex;
        cycles++;
#ifdef MoreInstrumentation
        if (sp > spMax) spMax = sp;
        if (rp > rpMax) rpMax = rp;
#endif
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

CELL cp = 0;                            // dictionary pointer for code space
CELL fence = 0;                         // latest writable code word
SI notail = 0;                          // tail recursion inhibited for call

SV toCode (cell x) {                    // compile to code space
    chadToCode(cp++, x);
}
SV compExit (void) {                    // compile an exit
    if (fence == cp) {                  // code run is empty
        goto plain;                     // nothing to optimize
    }
    int a = (cp-1) & (CodeSize-1);
    int old = Code[a];                  // previous instruction
    if (((old & 0x8000) == 0) && (!(old & rdn))) { // ALU doesn't change rp?
        Code[a] = rdn | old | ret;      // make the ALU instruction return
    } else if ((old & lit) == lit) {    // literal?
        Code[a] = old | ret;            // make the literal return
    } else if ((!notail) && ((old & 0xE000) == call)) {
        Code[a] = (old & 0x1FFF) | jump; // tail recursion (call -> jump)
    } else {
plain:  toCode(alu | ret | rdn);         // compile a stand-alone return
    }
}

// The LEX register is cleared whenever the instruction is not LITX.
// LITX shifts 11-bit data into LEX from the right.
// Full 16-bit and 32-bit data are supported with 2 or 3 inst.

SV extended_lit (int k) {
    toCode(litx | (k & 0x7FF));
}
SV Literal (cell x) {
#if (CELLBITS > 22)
    if (x & 0xFFC00000) {
        extended_lit(x >> 22);
        extended_lit(x >> 11);
    }
    else {
        if (x & 0x003FF800)
            extended_lit(x >> 11);
    }
#else
    if (x & 0x003FF800)
        extended_lit(x >> 11);
#endif
    x &= 0x7FF;
    toCode (lit | (x & 0xff) | (x & 0x700) << 1);
}

SV CompCall (cell xt) {
    if (xt & 0x01FFE000)
        toCode(litx | (xt >> 13));       // accommodate 25-bit address space
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
SV doSetBits(void) { tablebits = Dpop(); }
SV doTableEntry(void) {
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
uint8_t ConSP = 0;

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

SV ResolveFwd(void) { Code[CtrlStack[ConSP--]] |= cp; fence = cp; }
SV ResolveRev(int inst) { toCode(CtrlStack[ConSP--] | inst); fence = cp; }
SV MarkFwd(void) { CtrlStack[++ConSP] = cp; }
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
SV noExecute(void) { error = BAD_UNSUPPORTED; }

SV doNext(void) {
    toCode(alu | RM1toT | TtoN | sup);   /* (R-1)@ */
    toCode(alu | zeq | TtoR);  ResolveRev(zjump);
    toCode(alu | rdn);  fence = cp;      /* rdrop */
}

//##############################################################################
// Dictionary
// The dictionary uses a static array of data structures loaded at startup.
// Links are int indices into this array of Headers.

SI hp;                                  // # of keywords in the Header list
static struct Keyword Header[MaxKeywords];
CELL me;                                // index of found keyword

// The search order is a lists of contexts with order[orders] searched first
// order:   wid3 wid2 wid1
// context------------^ ^-----orders
// A wid points to a linked list of headers.
// The head pointer of the list is created by WORDLIST.
// In Forth, it would just be a cell in the dictionary placed by comma.
// The paradigm here expects names for everything.

SI order[32];                           // search order list
SI orders;                              // items in the search order list
static cell wordlist[MaxWordlists];     // head pointers to linked lists
static char wordlistname[MaxWordlists][16];// optional name string
static cell wordlists;
SI root_wid;                            // the basic wordlists
SI forth_wid;
SI asm_wid;
SI current;                             // the current definition
SI context(void) { return order[orders]; } // top of context

SV printWID(int wid) {
    char* s = &wordlistname[wid][0];
    if (*s)
        printf("%s ", s);
    else
        printf("%d ", wid);
}

SV doORDER(void) {
    printf(" Context : ");
    for (int i = 1; i <= orders; i++)  printWID(order[i]);
    printf("\n Current : ");  printWID(current);
}

SI findinWL(char* key, int wid) {       // find in wordlist
    uint16_t i = wordlist[wid];
    if (strlen(key) < MaxNameSize) {
        while (i) {
            if (strcmp(key, Header[i].name) == 0) {
                me = i;
                return i;
            }
            i = Header[i].link;
        }
    }
    return -1;                          // return index of word, -1 if not found
}

SI FindWord(char* key) {                // find in context
    for (int i = orders; i > 0; i--) {
        int id = findinWL(key, i);
        if (id >= 0) {
            Header[me].references += 1; // bump reference counter
            return id;
        }
    }
    return -1;
}

// A strncpy that complies with C safety checks.

void strmove(char* dest, char* src, int maxlen) {
    for (int i = 0; i < maxlen; i++) {
        char c = *src++;  *dest++ = c;
        if (c == 0) return;             // up to and including the terminator
    }
    *--dest = 0;                        // max reached, add terminator
}

SI AddWordlist(char *name) {
    wordlist[++wordlists] = 0;          // start with empty wordlist
    strmove(&wordlistname[wordlists][0], name, 16);
    if (wordlists == (MaxWordlists - 1)) error = BAD_WID_OVER;
    return wordlists;
}

SV ListWords(int wid) {                 // in a given wordlist
    uint16_t i = wordlist[wid];
    while (i) {
        printf("%s ", Header[i].name);
        i = Header[i].link;             // traverse from oldest
    }
}
SV doWoords(void) {
    ListWords(context());           // top of wordlist
    printf("\n");
}

SV OrderPush(int n) {
    order[31 & ++orders] = n;
    if (orders == 16) error = BAD_ORDER_OVER;
}

SI OrderPop(void) {
    int r = (order[31 & orders--]);
    if (orders < 0) error = BAD_ORDER_UNDER;
    return r;
}

SV doONLY(void) { orders = 0; OrderPush(root_wid); OrderPush(forth_wid); }
SV doFORTH(void) { order[orders] = forth_wid; }
SV doASSEMBLER(void) { order[orders] = asm_wid; }
SV doDEFINITIONS(void) { current = context(); }
SV doPlusOrder(void) { OrderPush(Dpop()); }
SV doPrevious(void) { OrderPop(); }
SV doSetCurrent(void) { current = Dpop(); }
SV doGetCurrent(void) { Dpush(current); }

SV doGetOrder(void) {
    for (int i = 0; i < orders; i++)
        Dpush(order[i]);
    Dpush(orders);
}

SV doSetOrder(void) {
    uint8_t len = Dpop();
    orders = 0;
    for (int i = 0; i < len; i++)
        OrderPush(Dpop());
}

SI NotKeyword (char *key) {             // do a command, return 0 if found
    int i = FindWord(key);
    if (i < 0)
        return -1;                      // not found
    if (stateFetch())
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
SV Def_Comp   (void) { CompCall(my()); notail = Header[me].notail; }

SV Def_Exec   (void) {
    if (verbose & VERBOSE_TOKEN) {
        printf(" <exec:%Xh>", my());
    }
    Simulate(my());
}

SI AddHead (char * s) {                 // add a header to the list
    int r = 1;
    hp++;
    if (hp < MaxKeywords) {
        strmove(Header[hp].name, s, MaxNameSize);
        Header[hp].length = 0;          // set defaults to 0
        Header[hp].notail = 0;
        Header[hp].target = 0;
        Header[hp].notail = 0;
        Header[hp].isALU = 0;
        Header[hp].link = wordlist[current];
        Header[hp].references = 0;
        wordlist[current] = hp;
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

SV AddKeyword (char *name, void (*xte)(), void (*xtc)()) {
    if (AddHead(name)) {
        SetFns(NOTANEQU, xte, xtc);
    }
}

SV AddALUinst(char* name, cell value) {
    if (AddHead(name)) {
        SetFns(value, Prim_Exec, Prim_Comp);
        Header[hp].isALU = 1;
    }
}

SV AddEquate(char* name, cell value) {
    if (AddHead(name)) {
        SetFns(value, Equ_Exec, Equ_Comp);
    }
}

// Modify the ALU instruction being constructed
SV AddModifier (char *name, cell value) {
    if (AddHead(name)) {
        SetFns(value, doInstMod, noCompile);
    }
}

// Literal operations literal data from the stack and toCode the instruction.
SV AddLitOp (char *name, cell value) {
    if (AddHead(name)) {
        SetFns(value, doLitOp, noCompile);
    }
}

//##############################################################################
// Facilities for viewing, debugging, etc.

// Disassembler

static char* TargetName (cell addr) {
    if (!addr) return NULL;
    for (int i = 1; i <= hp; i++) {
        if (Header[i].target == addr) {
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
    char buf[16];
    int  i = 16;  buf[--i] = 0;
    do {
        char c = x & 15;
        x >>= 4;
        if (c > 9) c += 7;
        buf[--i] = c + '0';
    } while (x && (i >= 0));
    appendDA(&buf[i]);
}

SV diss (int id, char *str) {
    while (id--) { while (*str++); }
    if (str[0]) appendDA(str);
}

SI ALUlabel(uint16_t insn) {            // try to match to a predefined ALUinst 
    for (int i = 0; i < hp; i++) {
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
    char* name;
    DAbuf[0] = '\0'; 
    if (IR & 0x8000) {
        int target = IR & 0x1FFF;
        switch ((IR>>12) & 7) {
        case 6: HexToDA(IR & 0x7FF);  appendDA("litx");  break;
        case 7: 
            HexToDA((IR & 0x7F) | (IR & 0xF00)>>1);  appendDA("imm");
            if (IR & ret) { appendDA("exit"); }  break;
        default:
            name = TargetName(target);
            if (name == NULL) HexToDA(target);
            diss((IR>>13)&3,"jump\0zjump\0call");
            if (name != NULL) appendDA(name);
        }
    } else { // ALU
        if (ALUlabel(IR)) {
            if (IR & ret) appendDA("exit");
        }
        else {
            int id = (IR >> 9) & 7;
            switch ((IR >> 12) & 3) {
            case 0: diss(id, "T\0T0<\0T2/\0T2*\0N\0T^N\0T&N\0mask"); break;
            case 1: diss(id, "T+N\0N-T\0T0=\0N>>T\0N<<T\0R\0[T]\0status"); break;
            case 2: diss(id, "---\0C\0cT2/\0T2*c\0W\0~T\0T&W\0---"); break;
            default: diss(id, "T+Nc\0N-Tc\0---\0---\0---\0R-1\0io[T]\0---");
            }
            diss((IR >> 4) & 7, "\0T->N\0T->R\0N->[T]\0_MEMRD_\0N->io[T]\0_IORD_\0CO");
            diss(IR & 3, "\0d+1\0d-2\0d-1");
            diss((IR >> 2) & 3, "\0r+1\0r-2\0r-1");
            if (IR & ret) appendDA("RET");
            appendDA("alu");
        }
    }
    printf("%16s", DAbuf);
    return 0;
}

SV doDASM (void) { // ( addr len -- )
    int length = Dpop() & 0x0FFF;
    int addr = Dpop();
    char* name;
    for (int i=0; i<length; i++) {
        int a = addr++ & (CodeSize-1);
        int x = Code[a];
        name = TargetName(a);
        if (name != NULL) printf("%s\n", name);
        printf("%03x %04x  ", a, x);
        DisassembleInsn(x);
        printf("\n");
    }
}

SV doSteps(void) {                      // ( addr steps -- )
    uint16_t cnt = (uint16_t)Dpop();    // single step debugger gives a listing
    pc = Dpop();
    verbose |= VERBOSE_TRACE;
    for (uint16_t i = 0; i < cnt; i++) {
        CPUsim(1);
        if (rp == (StackSize - 1)) break;
    }
    verbose &= ~VERBOSE_TRACE;
}

SV doAssert(void) {                     // for test code
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

SV doStats(void) {
    printf("%" PRId64 " cycles, MaxSP=%d, MaxRP=%d, latency=%d",
        elapsed_cycles, spMax, rpMax, latency);
    if (elapsed_us > 99) {
        printf(", %" PRId64 " MIPS", elapsed_cycles / elapsed_us);
    }
    printf("\n");
    spMax = sp;  rpMax = rp;
}

SV dotESS (void) {                      // ( ... -- ... )
    PrintStack();                       // .s
    printf("<-Top\n");
}

SV dot (void) {                         // ( n -- )
    Cdot(Dpop());                       // .
}

SV ddot (void) {                        // ( d -- )
    cell hi = Dpop();                   // d.
    cell lo = Dpop();
    uint64_t x = ((uint64_t)hi << CELLBITS) | lo;
    #if (CELLBITS < 32) // sign extend
    if (x & (1ull<<(CELLBITS*2-1)))
        x -= 1ull<<(CELLBITS*2);
    #endif
    printf("%" PRId64 " ", x);
}

//##############################################################################
// Forth interpreter
// When a file is included, the rest of the TIB is discarded.
// A new file is pushed onto the file stack.
// Every time a file is opened, the fileID is bumped.

static char* buf;                       // line buffer
SI maxlen;                              // maximum buffer length
SI toin;                                // pointer to next character
struct FileRec FileStack[MaxFiles];
SI filedepth = 0;                       // file stack
SI fileID = 0;                          // cumulative file ID
static char BOMmarker[4] = {0xEF, 0xBB, 0xBF, 0x00};

SV SwallowBOM(FILE *fp) {               // swallow leading UTF8 BOM marker
    char BOM[4];                        // to support utf-8 files on Windows
    fgets(BOM, 4, fp);
    if (strcmp(BOM, BOMmarker)) {
        rewind(fp);                     // keep beginning of file if no BOM
    }
}

SV OpenNewFile(char *name) {            // Push a new file onto the file stack
    filedepth++;  fileID++;
    strmove (File.FilePath, name, LineBufferSize);
#ifdef MORESAFE
    errno_t err = fopen_s(&File.fp, name, "r");
#else
    File.fp = fopen(name, "r");
#endif
    File.LineNumber = 0;
    File.Line[0] = 0;
    File.FID = fileID;
    if (File.fp == NULL) {
        filedepth--;
        error = BAD_OPENFILE;
    } else {
        if (filedepth >= MaxFiles) error = BAD_INCLUDING;
        else SwallowBOM(File.fp);
    }
}

static char tok[LineBufferSize+1];      // blank-delimited token

SI parseword(char delimiter) {
    while (buf[toin] == delimiter) toin++;
    int length = 0;  char c;
    while ((c = buf[toin++]) != delimiter) {
        if (!c) {                       // assume trailing 0 is there
            toin--;  break;             // step back to terminator
        }
        tok[length++] = c;
    }
    tok[length] = 0;                    // tok is zero-delimited
    return length;
}

SV ParseFilename(void) {
    while (buf[toin] == ' ') toin++;
    if (buf[toin] == '"') {
        toin++;  parseword('"');        // allow filename in quotes
    }
    else {
        parseword(' ');                 // or a filename with no spaces
    }
}

SV doINCLUDE(void) {                    // Nest into a source file
    ParseFilename();
    OpenNewFile(tok);
}

int DefMark, DefMarkID;

SV doColon(void) {
    parseword(' ');
    if (AddHead(tok)) {                 // define a word that simulates
        SetFns(cp, Def_Exec, Def_Comp);
        Header[hp].target = cp;
        DefMarkID = hp;                 // save for later reference
        DefMark = cp;  toCompile();
        fence = cp;                     // code starts here
        ConSP = 0;
    }
}

SV doNoName(void) {
    Dpush(cp);  DefMarkID = 0;          // no length
    toCompile();
    fence = cp;
    ConSP = 0;
}

SV doEQU(void) {
    parseword(' ');
    AddEquate(tok, Dpop());
}

SV doLexicon(void) {                    // named wordlist
    parseword(' ');
    AddEquate(tok, AddWordlist(tok));
}

SV doDEFINED(void) {                    // [defined]
    parseword(' ');
    int r = (FindWord(tok) < 0) ? 0 : 1;
    if (r) {
        if (Header[me].target == 0) r = 0;
    }
    Dpush(r);
}

SV doUNDEFINED(void) {                  // [undefined]
    doDEFINED();
    Dpush(~Dpop());
}

SV SaveLength(void) {                   // resolve length of definition
    if (DefMarkID)
        Header[DefMarkID].length = cp - DefMark;
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

SV doMACRO(void) {
    Header[DefMarkID].CompFn = CompMacro;
}

SV doIMMEDIATE(void) {
    Header[DefMarkID].CompFn = Header[DefMarkID].ExecFn;
}

SV doNoTail (void) {
    Header[DefMarkID].notail = 1;
}

SV SaveMarker(cell* dest) {
    dest[0] = hp;    dest[1] = cp;
    dest[2] = wordlists;  dest[3] = dpFetch();
    memcpy(&dest[4], wordlist, sizeof(cell) * MaxWordlists);
}

SV LoadMarker(cell* src) {
    hp = src[0];     cp = src[1];
    wordlists = src[2];  dpStore(src[3]);
    memcpy(wordlist, &src[4], sizeof(cell) * MaxWordlists);
}

SV Marker_Exec(void) {                  // execution semantics of a marker
    cell* pad = Header[me].aux;
    LoadMarker(pad);
    free(pad);
}

SV doMARKER (void) {
    parseword(' ');
    if (AddHead(tok)) {
        SetFns(cp, Marker_Exec, noCompile);
        cell* pad = malloc(sizeof(cell) * (MaxWordlists + 4));
        Header[hp].aux = pad;
        SaveMarker(pad);
    }
}

SI tick (void) {                        // get the w field of the word
    parseword(' ');
    if (FindWord(tok) < 0) {
        error = UNRECOGNIZED;
        return 0;
    }
    return Header[me].target;           // W field of found word
}

SV doSEE (void) {                       // ( <name> -- )
    int addr;
    if ((addr = tick())) {
        Dpush(addr);  Dpush(Header[me].length);  doDASM();
    }
}

SV doDEFER(void) {
    doColon();  toImmediate();  toCode(jump);
    Header[hp].w2 = MAGIC_DEFER;
}

SV doIS(void) {                        // ( xt <name> -- )
    int addr = tick();
    if (Header[me].w2 != MAGIC_DEFER) error = BAD_IS;
    cell insn = jump | (Dpop() & 0x1fff);
    chadToCode(addr, insn);
}

SV doNothing (void) { }
SV doCODE    (void) { doColon();  toImmediate();  OrderPush(asm_wid);  Dpush(0);}
SV doENDCODE (void) { SaveLength();  OrderPop();  Dpop();  sane();}
SV doBYE     (void) { error = BYE; }
SV doComment (void) { toin = (int)strlen(buf); }
SV doCmParen (void) { parseword(')'); }
SV doComEcho (void) { doCmParen();  printf("%s",tok); }
SV doCR      (void) { printf("\n"); }
SV doTick    (void) { Dpush(tick()); }
SV doTickImm (void) { Literal(tick()); }
SV doThere   (void) { Dpush(cp); }
SV doTorg    (void) { cp = Dpop(); }
SV doDROP    (void) { Dpop(); }
SV doTcomma  (void) { toCode(Dpop()); }
SV doWrProt  (void) { writeprotect = CodeFence; }
SV doSemi    (void) { compExit();  SaveLength();  toImmediate();  sane();}
SV doSemiEX  (void) { SaveLength();  sane(); }
SV doVerbose (void) { verbose = Dpop(); }
SV doAligned (void) { Dpush(aligned(Dpop())); }

SI refill(void) {
    int result = -1;
ask: toin = 0;
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
            filedepth--;
            goto ask;
        }
    }
    else {
        char* p;                        // remove trailing newline
        if ((p = strchr(buf, '\n')) != NULL) *p = '\0';
        size_t len = strlen(buf);
        for (size_t i = 0; i < len; i++) {
            if (buf[i] == '\t')         // replace tabs with blanks
                buf[i] = ' ';
            if (buf[i] == '\r')         // trim CR if present
                buf[i] = '\0';
        }
    }
    // save the line for error reporting
    strmove(File.Line, buf, LineBufferSize);
    if (verbose & VERBOSE_SOURCE)
        printf("%d: %s\n", lineno, buf);
    return result;
}

// [IF ] [ELSE] [THEN]

static void do_ELSE(void) {
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
        }
        else {                        // EOL
            if (!refill()) {
                error = BAD_EOF;
                return;
            }
        }
    }
}
static void do_IF(void) {
    int flag = Dpop();
    if (!flag) {
        do_ELSE();
    }
}

// Save and Load binary memory images.
// They are not large, save the entire space.
// The result differs between little-endian and big-endian machines.

SV SaveMem(uint8_t* mem, int length) { // save binary to a file
    ParseFilename();
    FILE* fp;
#ifdef MORESAFE
    errno_t err = fopen_s(&fp, tok, "wb");
#else
    fp = fopen(filename, "wb");
#endif
    if (fp == NULL)
        error = BAD_CREATEFILE;
    else {
        fwrite(mem, length, 1, fp);
        fclose(fp);
    }
};

SV LoadMem(uint8_t* mem, int length) {  // load binary from a file
    ParseFilename();
    FILE* fp;
#ifdef MORESAFE
    errno_t err = fopen_s(&fp, tok, "rb");
#else
    fp = fopen(filename, "rb");
#endif
    if (fp == NULL)
        error = BAD_OPENFILE;
    else {
        fread(mem, length, 1, fp);
        fclose(fp);
    }
};

SV doLoadCodeBin(void) { LoadMem((uint8_t*)Code, CodeSize * sizeof(uint16_t)); }
SV doSaveCodeBin(void) { SaveMem((uint8_t*)Code, CodeSize * sizeof(uint16_t)); }
SV doLoadDataBin(void) { LoadMem((uint8_t*)Data, DataSize * sizeof(cell)); }
SV doSaveDataBin(void) { SaveMem((uint8_t*)Data, DataSize * sizeof(cell)); }

// Data space compilation assigns `dp` to a fixed RAM address.
// There's not much you can do without compiling on the chad CPU.
// For example CREATE here is not usable with DOES>.

SV allot(int n) { dpStore(n + dpFetch()); }
SV buffer(int n) { Dpush(dpFetch());  doEQU();  allot(n); }
SV doBUFFER(void) { buffer(Dpop()); }
SV doCVARIABLE(void) { buffer(1); }
SV doAlign(void) { dpStore(aligned(dpFetch())); }
SV doVARIABLE(void) { doAlign();  buffer(CELLS); }
SV doCREATE(void) { doAlign();  buffer(0); }
SV doCHAR(void) { parseword(' ');  Dpush(tok[0]); }
SV doCHARimm(void) { parseword(' ');  Literal(tok[0]); }

// Initialize the dictionary at startup

SV LoadKeywords(void) {
    hp = 0; // start empty
    wordlists = 0;
    // Forth definitions
    root_wid = AddWordlist("root");
    forth_wid = AddWordlist("forth");
    doONLY(); // order = root _forth
    current = root_wid;
    AddEquate("root", root_wid);
    AddEquate("_forth", forth_wid);
    AddEquate("cm-writable", BYTE_ADDR(CodeFence));
    AddEquate("cm-size", BYTE_ADDR(CodeSize));
    AddEquate("dm-size", BYTE_ADDR(DataSize));
    AddEquate("cellbits", CELLBITS);
    AddEquate("cell", CELLS);
    AddEquate("dp", dpCell);
    AddKeyword("assert", doAssert, noCompile);     // ( n1 n2 -- )
    AddKeyword("verbosity", doVerbose, noCompile);
    AddKeyword("load-code", doLoadCodeBin, noCompile);
    AddKeyword("save-code", doSaveCodeBin, noCompile);
    AddKeyword("load-data", doLoadDataBin, noCompile);
    AddKeyword("save-data", doSaveDataBin, noCompile);
    AddKeyword("equ", doEQU, noCompile);
    AddKeyword("constant", doEQU, noCompile);
    AddKeyword("[if]", do_IF, noCompile);
    AddKeyword("[then]", doNothing, noCompile);
    AddKeyword("[else]", do_ELSE, noCompile);
    AddKeyword("[undefined]", doUNDEFINED, noCompile);
    AddKeyword("[defined]", doDEFINED, noCompile);
    AddKeyword("forth", doFORTH, noCompile);
    AddKeyword("assembler", doASSEMBLER, noCompile);
    AddKeyword("lexicon", doLexicon, noCompile);
    AddKeyword("definitions", doDEFINITIONS, noCompile);
    AddKeyword("only", doONLY, noCompile);
    AddKeyword("+order", doPlusOrder, noCompile);
    AddKeyword("previous", doPrevious, noCompile);
    AddKeyword("previous", doPrevious, noCompile);
    AddKeyword("get-current", doGetCurrent, noCompile);
    AddKeyword("set-current", doSetCurrent, noCompile);
    AddKeyword("get-order", doGetOrder, noCompile);
    AddKeyword("set-order", doSetOrder, noCompile);
    AddKeyword("stats", doStats, toCompile);
    AddKeyword("hex", Hex, noCompile);
    AddKeyword("decimal", Decimal, noCompile);
    AddKeyword("drop", doDROP, noCompile);
    AddKeyword("\\", doComment, doComment);
    AddKeyword("(", doCmParen, doCmParen);
    AddKeyword(".(", doComEcho, noCompile);
    AddKeyword("order", doORDER, noCompile);
    AddKeyword("cr", doCR, noCompile);
    AddKeyword("include", doINCLUDE, noCompile);
    AddKeyword("bye", doBYE, noCompile);
    AddKeyword("words", doWoords, noCompile);
    AddKeyword(".s", dotESS, noCompile);
    AddKeyword(".", dot, noCompile);
    AddKeyword("d.", ddot, noCompile);
    AddKeyword("dasm", doDASM, noCompile);
    AddKeyword("see", doSEE, noCompile);
    AddKeyword("sstep", doSteps, noCompile);
    AddKeyword("write-protect", doWrProt, noCompile);
    AddKeyword("calign", doNothing, doNothing);
    AddKeyword("caligned", doNothing, doNothing);
    AddKeyword("chars", doNothing, doNothing);
    AddKeyword("t,", doTcomma, noCompile);
    AddKeyword("there", doThere, noCompile);
    AddKeyword("torg", doTorg, noCompile);
    AddKeyword("aligned", doAligned, noCompile);
    AddKeyword("align", doAlign, noCompile);
    AddKeyword("buffer:", doBUFFER, noCompile);
    AddKeyword("variable", doVARIABLE, noCompile);
    AddKeyword("cvariable", doCVARIABLE, noCompile);
    AddKeyword("create", doCREATE, noCompile);
    AddKeyword("char", doCHAR, noCompile);
    AddKeyword("[char]", noExecute, doCHARimm);
    AddKeyword("[", toImmediate, toImmediate);
    AddKeyword("]", toCompile, toCompile);
    AddKeyword("'", doTick, noCompile);
    AddKeyword("[']", noExecute, doTickImm);
    AddKeyword("marker", doMARKER, noCompile);
    AddKeyword(":", doColon, noCompile);
    AddKeyword(":noname", doNoName, noCompile);
    AddKeyword("defer", doDEFER, noCompile);
    AddKeyword("is", doIS, noCompile);
    AddKeyword("CODE", doCODE, noCompile);
    AddKeyword("exit", noExecute, compExit);
    AddKeyword(";", doSemiEX, doSemi);
    AddKeyword("literal", noExecute, doLITERAL);
    AddKeyword("macro", doMACRO, noCompile);
    AddKeyword("immediate", doIMMEDIATE, noCompile);
    AddKeyword("no-tail-recursion", doNoTail, noCompile);
    AddKeyword("|bits|", doSetBits, noCompile);
    AddKeyword("|", doTableEntry, noCompile);
    // primitives
    AddALUinst("nop", 0);
    AddALUinst("invert",  com);
    AddALUinst("2*",      shl1  | co);
    AddALUinst("2/",      shr1  | co);
    AddALUinst("2*c",     shlx  | co);
    AddALUinst("2/c",     shrx  | co);
    AddALUinst("xor",     eor   |        sdn);
    AddALUinst("and",     Tand  |        sdn);
    AddALUinst("_+",      add   | sdn);
    AddALUinst("+",       add   | co   | sdn);
    AddALUinst("-",       sub   | co   | sdn);
    AddALUinst("dup",             TtoN | sup);
    AddALUinst("over",    NtoT  | TtoN | sup);
    AddALUinst("swap",    NtoT  | TtoN);
    AddALUinst("drop",    NtoT  |        sdn);
    AddALUinst("nip",                    sdn);
    AddALUinst("0=",      zeq   );
    AddALUinst("0<",      less0 );
    AddALUinst(">r",      NtoT  | TtoR | sdn | rup);
    AddALUinst("r>",      RtoT  | TtoN | sup | rdn);
    AddALUinst("r@",      RtoT  | TtoN | sup);
    AddALUinst("carry",   carry | TtoN | sup);
    AddALUinst("w",       WtoT  | TtoN | sup);
    AddALUinst(">carry",  NtoT  | co   | sdn);
    AddALUinst("rshift",  shr          | sdn);
    AddALUinst("lshift",  shl          | sdn);
    AddALUinst("_@",              memrd);  // start read
    AddALUinst("_@_",     read);           // end read
    AddALUinst("_!",      write |        sdn); // = tuck!
    AddALUinst("_io!",    iow          | sdn);
    AddALUinst("_io@",            ior);    // start io read
    AddALUinst("_io@_",   input);          // end io read
    AddALUinst("2dupand", Tand  | TtoN | sup);
    AddALUinst("2dupxor", eor   | TtoN | sup);
    AddALUinst("2dup+",   add   | TtoN | sup);
    AddALUinst("2dup-",   sub   | TtoN | sup);
    AddALUinst("mask",    bmask);
    AddALUinst("wand",    TandW);
    AddALUinst("overand", Tand);
    AddALUinst("overxor", eor);
    AddALUinst("over+",   add   | co);
    AddALUinst("over-",   sub   | co);
    AddALUinst("dup>r",   TtoR               | rup);
    AddALUinst("rdrop",                        rdn);
    AddALUinst("+c",      addc  | co   | sdn);
    AddALUinst("dup@",    read  | TtoN | sup);
    AddALUinst("spstat",  who   | TtoN | sup);
    AddALUinst("(R-1)@", RM1toT | TtoN | sup);
    AddALUinst("_next_",  zeq   | TtoR);

//   toCode(alu | RM1toT | TtoN | sup);   /* (R-1)@ */
//   toCode(alu | zeq | TtoR);  ResolveRev(zjump);

    AddKeyword("begin", noExecute, doBegin);
    AddKeyword("again", noExecute, doAgain);
    AddKeyword("until", noExecute, doUntil);
    AddKeyword("if",    noExecute, doIf);
    AddKeyword("else",  noExecute, doElse);
    AddKeyword("then",  noExecute, doThen);
    AddKeyword("while",  noExecute, doWhile);
    AddKeyword("repeat",  noExecute, doRepeat);
    AddKeyword("for",  noExecute, doFor);
    AddKeyword("next",  noExecute, doNext);
    // assembler
    asm_wid = AddWordlist("asm");
    AddEquate("asm", asm_wid);
    current = asm_wid;
    AddKeyword("END-CODE", doENDCODE, noCompile);
    AddModifier("T",    alu  );  // Instruction fields
    AddModifier("COP",  cop  );
    AddModifier("T0<",  less0);
    AddModifier("C",    carry);
    AddModifier("T2/",  shr1 );
    AddModifier("cT2/", shrx );
    AddModifier("T2*",  shl1 );
    AddModifier("T2*c", shlx );
    AddModifier("N",    NtoT );
    AddModifier("W",    WtoT );
    AddModifier("T^N",  eor  );
    AddModifier("~T",   com  );
    AddModifier("T&N",  Tand );
    AddModifier("T&W",  TandW );
    AddModifier("mask", bmask );
    AddModifier("T+N",  add  );
    AddModifier("T+Nc", addc );
    AddModifier("N-T",  sub  );
    AddModifier("N-Tc", subc );
    AddModifier("T0=",  zeq );
    AddModifier("N>>T", shr  );
    AddModifier("N<<T", shl  );
    AddModifier("R",    RtoT );
    AddModifier("R-1",  RM1toT );
    AddModifier("[T]", read );
    AddModifier("io[T]", input);
    AddModifier("status", who);
    AddModifier("RET",  ret | rdn );  // return bit
    AddModifier("T->N", TtoN );  // strobe field
    AddModifier("T->R", TtoR );
    AddModifier("N->[T]", write);
    AddModifier("N->io[T]", iow  );
    AddModifier("_IORD_", ior);
    AddModifier("_MEMRD_", memrd);
    AddModifier("CO", co  );
    AddModifier("r+1",  rup  );  // stack pointer field
    AddModifier("r-1",  rdn  );
    AddModifier("r-2", rdn2 );
    AddModifier("d+1", sup  );
    AddModifier("d-1", sdn  );
    AddModifier("d-2", sdn2 );
    AddLitOp("alu", alu );
    AddLitOp("branch", jump );
    AddLitOp("0branch", zjump);
    AddLitOp("scall", call );
    AddLitOp("litx", litx );
    AddLitOp("copid", copid );
    AddLitOp("imm", lit  );
    AddKeyword("begin", doBegin, noCompile);
    AddKeyword("again", doAgain, noCompile);
    AddKeyword("until", doUntil, noCompile);
    AddKeyword("if",    doIf, noCompile);
    AddKeyword("else",  doElse, noCompile);
    AddKeyword("then",  doThen, noCompile);
    AddKeyword("while",  doWhile, noCompile);
    AddKeyword("repeat",  doRepeat, noCompile);
    current = forth_wid;
}


//##############################################################################
// Text Interpreter
// Processes a line at a time from either stdin or a file.

int chad(char * line, int maxlength) {
    buf = line;  maxlen = maxlength;    // assign a working buffer
    LoadKeywords();
    filedepth = 0;
    Decimal();
    while (1) {
        File.fp = stdin;                // keyboard input
        fileID = error = 0;             // interpreter state
        toImmediate();
        cycles = spMax = rpMax = 0;     // CPU stats
        sp = rp = 0;                    // stacks
        while (!error) {
            toin = 0;
            uint64_t time0 = GetMicroseconds();
            uint64_t cycles0 = cycles;
            while (parseword(' ')) {
                if (verbose & 2) {
                    printf("  %s", tok);
                }
                if (baseFetch() == 0) 
                    error = DIV_BY_ZERO;
                if (NotKeyword(tok)) {  // try to convert to number
                    int i = 0;   int radix = baseFetch();   char c = 0;
                    int64_t x = 0;  int cp = 0;  int neg = 0;
                    switch (tok[0]) {   // leading digit
                        case '-': i++;  neg = -1;    break;
                        case '+': i++;               break;
                        case '$': i++;  radix = 16;  break;
                        case '#': i++;  radix = 10;  break;
                        case '&': i++;  radix = 8;   break;
                        case '%': i++;  radix = 2;   break;
                        case '\0': {goto bogus;}
                        default: break;
                    }
                    while ((c = tok[i++])) {
                        switch (c) {
                        case '.':       // string position starts at 1
                            cp = i;  break;
                        default:
                            c = c - '0';
                            if (c & 0x80) goto bogus;
                            if (c > 9) {
                                c -= 7;
                                if (c < 10) goto bogus;
                            }
                            if (c > 41) c -= 32; // lower to upper
                            if (c >= radix) {
bogus:                          error = UNRECOGNIZED;
                            }
                            x = x * radix + c;
                        }
                    }
                    if (neg) x = -x;
                    if (!error) {
                        if (cp) {
                            i = (x >> CELLBITS) & CELLMASK;
                            x &= CELLMASK;
                            if (stateFetch()) {
                                Literal((cell)x);
                                Literal((cell)i);
                            } else {
                                Dpush((cell)(x));
                                Dpush((cell)(i));
                            }
                        } else {
                            x &= CELLMASK;
                            if (stateFetch()) {
                                Literal((cell)x);
                            } else {
                                Dpush((cell)(x));
                            }
                        }
                    }
                }
                if (verbose & VERBOSE_TOKEN) {
                    printf(" ( ");
                    PrintStack();
                    printf(")\n");
                }
                if (verbose & VERBOSE_SRC) {
                    printf(") (%s", &buf[toin]);
                }
                if (sp == (StackSize - 1)) error = BAD_STACKUNDER;
                if (rp == (StackSize - 1)) error = BAD_RSTACKUNDER;
                if (error) {
                    switch (error) {
                    case BYE: return 0;
                    default: ErrorMessage (error, tok);
                    }
                    while (filedepth) {
                        printf("%s, Line %d: ", File.FilePath, File.LineNumber);
                        printf("%s\n", File.Line);
                        fclose(File.fp);
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
                    PrintStack();
                }
            }
            refill();
        }
    }
}

//##############################################################################
// Other exported functions
// These are called by iomap.c so that Forth code can access host data.
// For example, chadGetSource packs a string into data memory.
// Executable Forth may exercise the SPI bus to compile it to SPI flash.
// This is beyond the scope of the C side of Chad.
// chadGetHeader would be used when building a header structure in flash.

#define BYTES_PER_WORD  CELLS

uint32_t chadGetSource (char delimiter) {
    size_t bytes;
    char *src;
    if (delimiter) {
        parseword(delimiter);
        src = tok;
        bytes = strlen(tok);
    } else {
        src = &buf[toin];               // use the rest of the line
        bytes = strlen(buf) - toin;
        doComment();
    }
    size_t words = (bytes + BYTES_PER_WORD - 1) / BYTES_PER_WORD;
    size_t addr = DataSize - words;
    cell* dest = &Data[addr];
    for (size_t i = 0; i < words; i++) {// pack string into data memory
        uint32_t w = 0;                 // little-endian packing
        for (int j = 0; j < BYTES_PER_WORD; j++) {
            w |= (uint8_t)*src++ << (j * 8);
        }
        *dest++ = w;
    }
    return (uint32_t)((addr << 8) + words);
}

uint32_t chadGetHeader (uint32_t select) {
    int ID = select >> 6;
    select &= 0x3F;
    if (ID > hp) return -1;
    switch (select) {
    case 0: return (Header[ID].ExecFn == Def_Exec); // it's executable code
    case 1: return (Header[ID].ExecFn == Header[ID].CompFn); // immediate
    case 2: return Header[ID].target;
    case 3: return Header[ID].length;
    case 4: return Header[ID].w;
    case 5: return Header[ID].w2;
    case 6: return Header[ID].notail;
    case 7: return Header[ID].link;
    case 8: return Header[ID].references;
    case 16: return cp;
    case 17: return hp;
    default:
        if ((select < 0x20) || (select >= (0x20 + MaxNameSize)))
            return 0;
        return Header[ID].name[select - 0x20];
    }
    return 0;
}

void chadError (uint32_t errorcode) {
    int n = errorcode;
    if (n & MSB) n |= ~CELLMASK;        // sign extend errorcode
    error = n;
}
