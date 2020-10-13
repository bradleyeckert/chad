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
#include "flash.h"

SI verbose = 0;
uint8_t sp, rp;                         // stack pointers
CELL t, pc, cy, lex, w;                 // registers
CELL Data[DataSize];                    // data memory
CELL Dstack[StackSize];                 // data stack
CELL Rstack[StackSize];                 // return stack
CELL Raddr;                             // data memory read address
SI error;                               // simulator and interpreter error code

// Shared variables
#define toin  0                         // pointer to next character
#define tibs  1                         // chars in input buffer
#define atib  2                         // address of input buffer
#define dp    3                         // define shared variables
#define base  4                         // use cells not bytes for compatibility
#define state 5                         // define cell addresses

SV Hex(void) { Data[base] = 16; }
SV Decimal(void) { Data[base] = 10; }
SV toImmediate(void) { Data[state] = 0; }
SV toCompile(void) { Data[state] = 1; }
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
    printf("%s ", itos(x, Data[base], 0, 0));
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

//##############################################################################
// CPU simulator

static uint16_t Code[CodeSize];         // code memory
static uint8_t spMax, rpMax;            // stack depth tracking
static uint32_t writeprotect = 0;       // highest writable code address
static uint64_t cycles = 0;             // cycle counter
static uint32_t latency = 0;            // maximum cycles between return

// The C host uses this (externally) to write to code and data spaces.
// Addr is a cell address in each case.

void chadToCode (uint32_t addr, uint32_t x) {
    if (addr >= CodeSize) {
        error = BAD_CODE_WRITE;  return;
    }
    if (addr < writeprotect) {
        error = BAD_ROMWRITE;  return;
    }
    Code[addr & (CodeSize-1)] = (uint16_t)x;
}

void chadToData(uint32_t addr, uint32_t x) {
    if (addr >= DataSize) {
        error = BAD_DATA_WRITE;  return;
    }
    Data[addr & (DataSize-1)] = (cell)x;
}

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
            case 0x0C: _t = readIOmap(t);                    break; /*  io[T] */
            case 0x0D: _t = Data[Raddr];
                if (verbose & VERBOSE_TRACE) {
                    printf("Reading %Xh from cell %Xh\n", _t, Raddr);
                } break;                                            /*    [T] */
            case 0x0E: _t = (t) ? 0 : -1;                    break; /*    T0= */
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

SV Cold(void) {                         // cold boot and run until error
    t = sp = rp = w = lex = cy = 0;
    Simulate(0);
}

//##############################################################################
// Compiler

CELL cp = 0;                            // dictionary pointer for code space
CELL latest = 0;                        // latest writable code word
SI notail = 0;                          // tail recursion inhibited for call

SV toCode (cell x) {                    // compile to code space
    chadToCode(cp++, x);
}
SV CompExit (void) {                    // compile an exit
    if (latest == cp) {                 // code run is empty
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

SV ResolveFwd(void) { Code[CtrlStack[ConSP--]] |= cp;  latest = cp; }
SV ResolveRev(int inst) { toCode(CtrlStack[ConSP--] | inst);  latest = cp; }
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
SV noExecute(void) { error = BAD_NOEXECUTE; }

SV doNext(void) {
    toCode(alu | RM1toT | TtoN | sup);  /* (R-1)@ */
    toCode(alu | zeq | TtoR);  ResolveRev(zjump);
    toCode(alu | rdn);  latest = cp;    /* rdrop */
}

// HTML output is a kind of log file of token handling. It's a browsable
// version of the source text with links to reference documents.

SI fileID = 0;                          // cumulative file ID
struct FileRec FileStack[MaxFiles];
struct FilePath FilePaths[MaxFilePaths];
SI filedepth = 0;                       // file stack
static int logcolor = 0;
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

SV Log(char* s) {
    FILE* fp = File.hfp;
    if (fp) {
        char c;
        while ((c = *s++)) {
            if (' ' != c)
                FlushBlanks();
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

// The search order is a lists of contexts with order[orders] searched first
// order:   wid3 wid2 wid1
// context------------^ ^-----orders
// A wid points to a linked list of headers.
// The head pointer of the list is created by WORDLIST.

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

SV Order(void) {
    printf(" Context : ");
    for (int i = 1; i <= orders; i++)  printWID(order[i]);
    printf("\n Current : ");  printWID(current);
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
    for (int i = orders; i > 0; i--) {
        int id = findinWL(key, i);
        if (id >= 0) {
            Header[me].references += 1; // bump reference counter
            foundWidName = &wordlistname[i][0];
            return id;
        }
    }
    return -1;
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
SV Words(void) {
    ListWords(context());               // top of wordlist
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

SV Only       (void) { orders = 0; OrderPush(root_wid); OrderPush(forth_wid); }
SV ForthLex   (void) { order[orders] = forth_wid; }
SV AsmLex     (void) { order[orders] = asm_wid; }
SV Definitions(void) { current = context(); }
SV PlusOrder  (void) { OrderPush(Dpop()); }
SV Previous   (void) { OrderPop(); }
SV Also       (void) { int v = OrderPop();  OrderPush(v);  OrderPush(v); }
SV SetCurrent (void) { current = Dpop(); }
SV GetCurrent (void) { Dpush(current); }

SV GetOrder(void) {
    for (int i = 0; i < orders; i++)
        Dpush(order[i]);
    Dpush(orders);
}

SV SetOrder(void) {
    int8_t len = Dpop();
    orders = 0;
    if (len < 0)
        Only();
    else
        for (int i = 0; i < len; i++)
            OrderPush(Dpop());
}

SI NotKeyword (char *key) {             // do a command, return 0 if found
    int i = FindWord(key);
    if (i < 0)
        return -1;                      // not found
    LogColor(Header[i].color, i, key);
    if (Data[state])
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

static char* TargetName (cell addr) {
    if (!addr) return NULL;
    int i = hp + 1;
    while (--i) {
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
    if (IR & 0x8000) {
        int target = IR & 0x1FFF;
        switch ((IR>>12) & 7) {
        case 6: 
            target = IR & 0x7FF;
            HexToDA(target);  _lex = (lex << 11) + target;
            appendDA("litx");  break;
        case 7:
            target = (IR & 0xFF) | (IR & 0xE00) >> 1;
            appendDA(itos((lex << 11) + target, Data[base], 0, 0));
            appendDA("imm");
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
        name = TargetName(a);
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
    PrintDataStack();                       // .s
    printf("<-Top\n");
}

SV dot (void) {                         // ( n -- )
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
    fgets(BOM, 4, fp);
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

SI parseword(char delimiter) {
    while (buf[Data[toin]] == delimiter) {
        Log(" ");
        Data[toin]++;
    }
    int length = 0;  char c;
    while ((c = buf[Data[toin]++]) != delimiter) {
        if (!c) {                       // hit EOL
            Data[toin]--;  break;       // step back to terminator
        }
        tok[length++] = c;
    }
    tok[length] = 0;                    // tok is zero-delimited
    return length;
}

SV ParseFilename(void) {
    while (buf[Data[toin]] == ' ') Data[toin]++;
    if (buf[Data[toin]] == '"') {
        Data[toin]++;  parseword('"');  // allow filename in quotes
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

SV LoadFlash(void) {
    ParseFilename();
    error = LoadFlashMem(tok);
}

SV SaveFlash(void) {
    ParseFilename();
    error = SaveFlashMem(tok);
}

SV SaveFlashHex(void) {
    ParseFilename();
    error = SaveFlashMemHex(tok);
}

// Start a new definition at the code boundary specified by CodeAlignment.
// Use CodeAlignment > 1 for Code memory (ROM) that's slow.
// For example, a ROM with a 64-bit prefetch buffer would have
// CodeAlignment = 4 and use a 4:1 mux to fetch the instruction.

SV Colon(void) {
    parseword(' ');
    if (AddHead(tok, "")) {             // start a definition
        cp = (cp + (CodeAlignment - 1)) & (cell)(-CodeAlignment);
        LogColor(COLOR_DEF, 0, tok);
        SetFns(cp, Def_Exec, Def_Comp);
        Header[hp].target = cp;
        Header[hp].color = COLOR_WORD;
        Header[hp].smudge = 1;
        DefMarkID = hp;                 // save for later reference
        DefMark = cp;
        latest = cp;                    // code starts here
        ConSP = 0;
        toCompile();
    }
}

SV NoName(void) {
    Dpush(cp);  DefMarkID = 0;          // no length
    toCompile();
    latest = cp;
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
        Header[DefMarkID].length = cp - DefMark;
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
    dest[0] = hp;    dest[1] = cp;  dest[4] = fileID;
    dest[2] = wordlists;  dest[3] = Data[dp];
    memcpy(&dest[5], wordlist, sizeof(cell) * MaxWordlists);
}

SV LoadMarker(cell* src) {
    hp = src[0];     cp = src[1];   fileID = src[4];
    wordlists = src[2];  Data[dp] = src[3];
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
        SetFns(cp, Marker_Exec, noCompile);
        Header[hp].color = COLOR_ROOT;
        cell* pad = malloc(sizeof(cell) * (MaxWordlists + 8));
        Header[hp].aux = pad;
        SaveMarker(pad);
        LogColor(COLOR_DEF, 0, tok);
    }
}

SI tick (void) {                        // get the w field of the word
    parseword(' ');
    if (FindWord(tok) < 0) {
        error = UNRECOGNIZED;
        return 0;
    }
    LogColor(COLOR_WORD, me, tok);
    return Header[me].target;           // W field of found word
}

SV See (void) {                         // ( <name> -- )
    int addr;
    if ((addr = tick())) {
        Dpush(addr);  Dpush(Header[me].length);  Dasm();
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
    parseword(')');  LogColor(COLOR_COM, 0, tok);  Log(")");  Data[toin]++;
}
SV Nothing   (void) { }
SV BeginCode (void) { Colon();  toImmediate();  OrderPush(asm_wid);  Dpush(0);}
SV EndCode   (void) { EndDefinition();  OrderPop();  Dpop();  sane();}
SV Recurse   (void) { CompCall(Header[DefMarkID].target); }
SV Bye       (void) { error = BYE; }
SV EchoToPar (void) { SkipToPar();  printf("%s", tok); }
SV Cr        (void) { printf("\n"); }
SV Tick      (void) { Dpush(tick()); }
SV BrackTick (void) { Literal(tick()); }
SV There     (void) { Dpush(cp); }
SV Torg      (void) { cp = Dpop(); }
SV WrProtect (void) { writeprotect = CodeFence;  killHostIO(); }
SV SemiComp  (void) { CompExit();  EndDefinition();  toImmediate();  sane();}
SV Semicolon (void) { EndDefinition();  sane(); }
SV Verbosity (void) { verbose = Dpop(); }
SV Aligned   (void) { Dpush(aligned(Dpop())); }
SV BrackUndefined(void) { BrackDefined();  Dpush(~Dpop()); }

SV SkipToEOL(void) {                    // and look for x.xxxx format number
    char* src = &buf[Data[toin]];
    char* p = src;
    char* dest = Header[DefMarkID].help;
    LogColor(COLOR_COM, 0, src);
    int digits = 0;  int decimals = 0;
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
    Data[toin] = (int)strlen(buf);
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
ask: Data[toin] = 0;
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
            if (command != '#')
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

SI flashPtr;
SV flashC8(uint8_t c)       { FlashMemStore(flashPtr++, c); }
SV flashC16(uint16_t w)     { flashC8(w >> 8);  flashC8((uint8_t)w); }
SV flashAN(uint16_t w) { flashC16(0xC100); flashC16(0xC3); flashC16(w - 1); }

// Write boot data to `flash.c`
SV MakeBootList(void) {
    flashPtr = 0;
    flashC8(0x80);                      // speed up SCLK
    flashAN(cp);
    flashC8(1);                         // 16-bit code write
    for (uint16_t i = 0; i < cp; i++) {
        flashC16(Code[i]);
    }
    uint16_t count = Data[dp];
    uint8_t bytes = (CELLBITS + 7) >> 3;
    flashAN(count);
    flashC8(3 + bytes);                 // 16-bit data write
    for (uint16_t i = 0; i < count; i++) {
        cell x = Data[i];
        uint8_t j = bytes;
        while (j)
            flashC8((uint8_t)(x >> (8 * --j)));
    }
    flashC8(0xE0);                      // end bootup
}

SV Boot(void) {
    LoadFlash();                        // file --> "SPI flash"
    FlashMemBoot();                     // boot from flash
    SkipToEOL();                        // don't trust >in anymore
    Cold();                             // run CPU
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

SV allot     (int n) { Data[dp] = n + Data[dp]; }
SV buffer    (int n) { Dpush(Data[dp]);  Constant();  allot(n); }
SV Buffer     (void) { buffer(Dpop()); }
SV Cvariable  (void) { buffer(1); }
SV Align      (void) { Data[dp] = aligned(Data[dp]); }
SV Variable   (void) { Align();  buffer(CELLS); }
SV Twovariable(void) { Variable();  allot(CELLS); }
SV Char       (void) { parseword(' ');  Dpush(getUTF8()); }
SV BrackChar  (void) { parseword(' ');  Literal(getUTF8()); }

// Initialize the dictionary at startup

SV LoadKeywords(void) {
    hp = 0; // start empty
    wordlists = 0;
    // Forth definitions
    root_wid = AddWordlist("root");
    forth_wid = AddWordlist("forth");
    Only(); // order = root _forth
    current = root_wid;
    AddEquate("root",         "1.0000 -- wid",        root_wid);
    AddEquate("forth-wordlist", "1.0010 -- wid",      forth_wid);
    AddEquate("cm-writable",  "1.0020 -- addr",       CodeFence);
    AddEquate("cm-size",      "1.0030 -- n",          CodeSize);
    AddEquate("dm-size",      "1.0040 -- n",          BYTE_ADDR(DataSize));
    AddEquate("cellbits",     "1.0050 -- n",          CELLBITS);
    AddEquate("cell",         "1.0060 -- n",          CELLS);
    AddEquate(">in",          "1.0070 -- addr",       BYTE_ADDR(toin));
    AddEquate("#tib",         "1.0071 -- addr",       BYTE_ADDR(tibs));
    AddEquate("'tib",         "1.0072 -- addr",       BYTE_ADDR(atib));
    AddEquate("dp",           "1.0073 -- addr",       BYTE_ADDR(dp));
    AddEquate("base",         "1.0074 -- addr",       BYTE_ADDR(base));
    AddEquate("state",        "1.0075 -- addr",       BYTE_ADDR(state));
    AddKeyword("stats",       "1.0080 --",            Stats,         noCompile);
    AddKeyword("locate",      "1.0085 <name> --",     Locate,        noCompile);
    AddKeyword("verbosity",   "1.0090 flags --",      Verbosity,     noCompile);
    AddKeyword("load-flash",  "1.0135 <filename> --", LoadFlash,     noCompile);
    AddKeyword("save-flash-h","1.0136 <filename> --", SaveFlashHex,  noCompile);
    AddKeyword("save-flash",  "1.0136 <filename> --", SaveFlash,     noCompile);
    AddKeyword("make-boot",   "1.0137 --",            MakeBootList,  noCompile);
    AddKeyword("boot",        "1.0138 <filename> --", Boot,          noCompile);
    AddKeyword("equ",         "1.0140 x <name> --",   Constant,      noCompile);
    AddKeyword("assert",      "1.0150 n1 n2 --",      Assert,        noCompile);
    AddKeyword(".s",          "1.0200 ? -- ?",        dotESS,        noCompile);
    AddKeyword("see",         "1.0210 <name> --",     See,           noCompile);
    AddKeyword("dasm",        "1.0220 xt len --",     Dasm,          noCompile);
    AddKeyword("sstep",       "1.0230 xt len --",     Steps,         noCompile);
    AddKeyword("cold",        "1.0235 --",            Cold,          noCompile);
    AddKeyword("words",       "1.0240 --",            Words,         noCompile);
    AddKeyword("bye",         "1.0250 --",            Bye,           noCompile);
    AddKeyword("[if]",        "1.0260 flag --",       BrackIf,       noCompile);
    AddKeyword("[then]",      "1.0270 --",            Nothing,       noCompile);
    AddKeyword("[else]",      "1.0280 --",            BrackElse,     noCompile);
    AddKeyword("[undefined]", "1.0290 <name> -- flag", BrackUndefined, noCompile);
    AddKeyword("[defined]",   "1.0300 <name> -- flag", BrackDefined, noCompile);
    AddKeyword(".",           "1.0400 n --",          dot,           noCompile);
    AddKeyword("forth",       "1.0420 --",            ForthLex,      noCompile);
    AddKeyword("assembler",   "1.0430 --",            AsmLex,        noCompile);
    AddKeyword("definitions", "1.0440 --",            Definitions,   noCompile);
    AddKeyword("get-current", "1.0450 -- wid",        GetCurrent,    noCompile);
    AddKeyword("set-current", "1.0460 wid --",        SetCurrent,    noCompile);
    AddKeyword("get-order",   "1.0470 -- widN..wid1 N", GetOrder,    noCompile);
    AddKeyword("set-order",   "1.0480 widN..wid1 N --", SetOrder,    noCompile);
    AddKeyword("only",        "1.0490 --",            Only,          noCompile);
    AddKeyword("previous",    "1.0500 --",            Previous,      noCompile);
    AddKeyword("also",        "1.0510 --",            Also,          noCompile);
    AddKeyword("order",       "1.0520 --",            Order,         noCompile);
    AddKeyword("+order",      "1.0530 wid --",        PlusOrder,     noCompile);
    AddKeyword("lexicon",     "1.0540 <name> --",     Lexicon,       noCompile);
    AddKeyword("include",     "1.1000 <filename> --", Include,       noCompile);
    AddKeyword("(",           "1.1010 ccc<paren> --", SkipToPar,     SkipToPar);
    AddKeyword("\\",          "1.1020 ccc<EOL> --",   SkipToEOL,     SkipToEOL);
    AddKeyword(".(",          "1.1030 ccc) --",       EchoToPar,     noCompile);
    AddKeyword("constant",    "1.1040 x <name> --",   Constant,      noCompile);
    AddKeyword("aligned",     "1.1050 addr -- a-addr", Aligned,      noCompile);
    AddKeyword("align",       "1.1060 --",            Align,         noCompile);
    AddKeyword("char",        "1.1070 <c> -- n",      Char,          noCompile);
    AddKeyword("chars",       "1.1080 n1 -- n2",      Nothing,         Nothing);
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
    AddKeyword("there",       "1.1290 -- taddr",      There,         noCompile);
    AddKeyword("torg",        "1.1300 taddr --",      Torg,          noCompile);
    AddKeyword("later",       "1.1310 <name> --",     Later,         noCompile);
    AddKeyword("resolves",    "1.1320 xt <name> --",  Resolves,      noCompile);
    AddKeyword("macro",       "1.1330 --",            Macro,         noCompile);
    AddKeyword("write-protect", "1.1340 --",          WrProtect,     noCompile);
    AddKeyword("no-tail-recursion", "1.1350 --",    NoTailRecursion, noCompile);
    AddKeyword("|bits|",      "1.1360 n --",       SetTableBitWidth, noCompile);
    AddKeyword("|",           "1.1370 x --",          TableEntry,    noCompile);
    AddKeyword("gendoc",      "1.1390 --",            GenerateDoc,   noCompile);
    // primitives can compile and execute
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
    current = asm_wid;
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
    current = forth_wid;
}

SV CopyBuffer(void) {                   // copy buf to tib region in Data
    char* src = buf;
    cell bytes = Data[tibs];
    cell words = (bytes + CELLS - 1) / CELLS;
    cell addr = DataSize - CELL_ADDR(MaxLineLength);
    Data[atib] = BYTE_ADDR(addr);
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
            Data[toin] = 0;
            Data[tibs] = strlen(buf);
            if (Data[tibs] >= MaxLineLength)
                error = BAD_INPUT_LINE;
            else
                CopyBuffer();
            uint64_t time0 = GetMicroseconds();
            uint64_t cycles0 = cycles;
            while (parseword(' ')) {
                if (verbose & 2) {
                    printf("  %s", tok);
                }
                if (NotKeyword(tok)) {  // try to convert to number
                    LogColor(COLOR_NUM, 0, tok);
                    int i = 0;   int radix = Data[base];   char c = 0;
                    if (radix == 0)
                        error = DIV_BY_ZERO;
                    int64_t x = 0;  int cp = -1;  int neg = 0;
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
                        if (cp < 0) {
                            x &= CELLMASK;
                            if (Data[state]) {
                                Literal((cell)x);
                            }
                            else {
                                Dpush((cell)(x));
                            }
                        }
                        else {
                            i = (x >> CELLBITS) & CELLMASK;
                            x &= CELLMASK;
                            if (Data[state]) {
                                Literal((cell)x);
                                Literal((cell)i);
                            } else {
                                Dpush((cell)(x));
                                Dpush((cell)(i));
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
                    printf(") (%s", &buf[Data[toin]]);
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
// These are called by iomap.c so that Forth code can access host data.
// Executable Forth may exercise the SPI bus to compile to SPI flash.
// This is beyond the scope of the C side of Chad.
// chadGetHeader would be used when building a header structure in flash.

uint32_t chadGetHeader (uint32_t select) {
    int ID = select >> 7;
    select &= 0x7F;
    int field = select >> 5; // 0 to 3
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
    case 8: return Header[ID].isALU;
    case 9: return Header[ID].srcFile;
    case 10: return Header[ID].srcLine;
    case 11: return Header[ID].color;
    case 16: return cp;
    case 17: return hp;
    case 18: return wordlists;
    case 19: return wordlist[ID];
    case 20: return wordlistname[ID / 16][ID % 16];
    case 21: return fileID;
    case 22: return LineBufferSize;
    default:
        select = ID & 0x1F;
        switch (field) {
        case 1:  return Header[ID].name[select];
        case 2:  return Header[ID].help[select];
        case 3:  return FilePaths[ID].filepath[select];
        default: return 0;
        }
    }
    return 0;
}

void chadError (int32_t n) {
    if (n & MSB) n |= ~CELLMASK;        // sign extend errorcode
    error = n;
}

uint64_t chadCycles(void) {
    return cycles;
}

uint16_t chadReadCode(uint32_t addr) {
    uint16_t r = Code[addr & (CodeSize - 1)];
    if (addr < CodeFence) r = 0;        // ROM is unreadable
    return r;
}

