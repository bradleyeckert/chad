#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>

#ifdef _MSC_VER

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
//  return PCcycleCount.QuadPart /= PCfrequency.QuadPart;
//  QueryPerformanceCounter(&PCcycleCount);
//  QueryPerformanceFrequency(&PCfrequency);
//  PCcycleCount.QuadPart *= 1000000;

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
#include "config.h"
#include "chaddefs.h"
#include "iomap.h"
#define NameOffset 0x20


////////////////////////////////////////////////////////////////////////////////
// CPU simulator

SI error;                               // simulator and interpreter error code
CELL Dstack[StackSize];                 // data stack
CELL Rstack[StackSize];                 // return stack
CELL Code[CodeSize];                    // code memory
CELL Data[DataSize];                    // data memory
int sp, rp;                             // stack pointers
int spMax, rpMax;                       // stack depth tracking
CELL t, pc, cy, lex, w;                 // registers
static uint32_t writeprotect = 0;       // highest writable code address
static uint64_t cycles = 0;

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

#if (CELLSIZE > 31)
#define sum_t uint64_t
#else
#define sum_t uint32_t
#endif

// The simulator used https://github.com/samawati/j1eforth as a template.
// We want to single step or run. To single step, use single = 1.
// Execution starts at the pc. It returns a code:
// 1 = finished with execution
// 2 = PC is not in code space
// other = stepped

SI dsx[4] = { 0, 1, -2, -1 };           /* 2-bit sign extension */
SI rsx[4] = { 0, 1, 0, -1 };

SI CPUsim(int single) {
    cell _t = t;                        // types are unsigned
    unsigned int _pc, _lex, insn;
    int mark = RDEPTH;
    if (single & 0x10000) {             // execute one instruction directly
        insn = single & 0xFFFF;
        goto once;
    }
    do {
        insn = Code[pc & (CodeSize-1)];
once:   _pc = pc + 1;
        _lex = 0;
        if (insn & 0x8000) {
            int target = insn & 0x1fff;
            switch (insn >> 13) { // 4 to 7
            case 4:                     /* jump */
                _pc = target;  break;
            case 5:                     /* zjump */
                if (!Dpop()) {_pc = target;}  break;
            case 6:                     /* call */
                RP = RPMASK & (RP + 1);
                Rstack[RP & RPMASK] = _pc;
                _pc = target;
                break;
            default:
                if (insn & 0x1000) {    /* imm */
                    Dpush((lex<<11) | ((insn&0xf00)>>1) | (insn&0x7f));
                    if (insn & 0x80) {  /* r->pc */
                        _pc = Rstack[RP];
                        if (RDEPTH == mark) single = 1;
                        RP = RPMASK & (RP - 1);
                    }
                } else {                /* lex */
                    _lex = (lex << 12) | (insn & 0xFFF);
                }
            }
        } else { // ALU
            if (insn & 0x80) {          /* r->pc */
                _pc = Rstack[RP];
                if (RDEPTH == mark) single = 1;
            }
            cell s = Dstack[SP];
            cell c = 0;
            cell temp;
            sum_t sum;
            switch ((insn >> 8) & 0x1F) {
            case 0x00: _t = t;                               break; /* T    */
            case 0x01: _t = (t&MSB) ? -1:0;                  break; /* T<0  */
            case 0x11: _t = cy;                              break; /* C    */
            case 0x02: c = t & 1;  temp = (t & MSB);
                _t = (t >> 1) | temp;                        break; /* T2/  */
            case 0x12: c = t & 1;
                _t = (t >> 1) | (cy << (CELLSIZE-1));        break; /* cT2/ */
            case 0x03: c = t >> (CELLSIZE-1);
                       _t = t << 1;                          break; /* T2*  */
            case 0x13: c = t >> (CELLSIZE-1);
                       _t = (t << 1) | cy;                   break; /* T2*c */
            case 0x04: _t = s;                               break; /* N    */
            case 0x14: _t = w;                               break; /* W    */
            case 0x05: _t = s ^ t;                           break; /* T^N  */
            case 0x15: _t = ~t;                              break; /* ~T   */
            case 0x06: _t = s & t;                           break; /* T&N  */
            case 0x16: _t = w & t;                           break; /* T&W  */
            case 0x07: _t = t >> 8;  w = ~((~0) << t);       break; /* T>>8 */
            case 0x17: _t = t << 8;                          break; /* T<<8 */

            case 0x08: sum = (sum_t)s + (sum_t)t;
                c = (sum >> CELLSIZE) & 1;  _t = sum;        break; /* T+N  */
            case 0x18: sum = (sum_t)s + (sum_t)t + cy;
                c = (sum >> CELLSIZE) & 1;  _t = sum;        break; /* T+Nc */
            case 0x09: sum = (sum_t)s - (sum_t)t;
                c = (sum >> CELLSIZE) & 1;  _t = sum;        break; /* N-T  */
            case 0x19: sum = ((sum_t)s - (sum_t)t) - cy;
                c = (sum >> CELLSIZE) & 1;  _t = sum;        break; /* N-Tc */
            case 0x0A: _t = (t) ? 0 : -1;                    break; /* T0=  */
            case 0x0B: _t = s >> t;                          break; /* N>>T */
            case 0x0C: _t = s << t;                          break; /* N<<T */

            case 0x0D: _t = Rstack[RP];                      break; /* R    */
            case 0x1D: _t = Rstack[RP] - 1;                  break; /* R-1  */
            case 0x0E: if (t & ~(DataSize-1)) { single = BAD_DATA_READ; }
                _t = Data[t & (DataSize-1)];                 break; /* [T]  */
            case 0x1E: _t = readIOmap(t);                    break; /* io[T] */
            case 0x0F: _t = (RDEPTH<<8) + SDEPTH;            break; /* status */
            default:   _t = t;                                      /* T    */
            }
            SP = SPMASK & (SP + dsx[insn & 3]);                 /* dstack+- */
            RP = RPMASK & (RP + rsx[(insn >> 2) & 3]);          /* rstack+- */
            switch ((insn >> 4) & 7) {
            case  1: Dstack[SP] = t;                         break; /* T->N */
            case  2: Rstack[RP] = t;                         break; /* T->R */
            case  3: if (t & ~(DataSize-1)) { single = BAD_DATA_WRITE; }
                Data[t & (DataSize-1)] = s;                  break; /* N->[T] */
            case  4: writeIOmap(t, s);                       break; /* N->io[T] */
            case  6: cy = c;                                 break; /* co   */
            case  7: w = t;                                  break; /* T->W */
            default: break;
            }
            t = _t & CELLMASK;
        }
        pc = _pc;  lex = _lex;
        cycles++;
        if (sp > spMax) spMax = sp;
        if (rp > rpMax) rpMax = rp;
        if (pc & ~(CodeSize-1)) single = BAD_PC;
    } while (single == 0);
    return single;
}
#define BAD_STACKOVER    -3 // Stack overflow
#define BAD_STACKUNDER   -4 // Stack underflow
#define BAD_RSTACKOVER   -5 // Return stack overflow
#define BAD_RSTACKUNDER  -6 // Return stack underflow

SV RegDump (void) {
    printf("PC=%x, SP=%x, RP=%x, ",pc, sp, rp);
    printf("N=%x, T=%x, R=%x, W=%x, c=%x\n",Dstack[SP],t,Rstack[RP],w,cy);
}
SV doSteps (void) {             // ( addr steps -- )
    uint8_t cnt = (uint8_t)Dpop();
    pc = Dpop();
    RegDump();
    for (int i=0; i<cnt; i++) {
        CPUsim(1);
        RegDump();
    }
}

SV doInstruction (void) {       // ( instruction -- )
    CPUsim(0x10000 | Dpop());
    RegDump();
}

CELL dp = 0;                    // dictionary pointer for data space
CELL fence = 0;                 // latest writable code word
SI notail = 0;                  // tail recursion inhibited for recent call

SV comma (cell x) {             // compile to code space
    chadToCode(dp++, x);
}
SV compExit (void) {            // compile an exit
    if (fence == dp) {          // code run is empty
        goto plain;
    }
    int a = (dp-1) & (CodeSize-1);
    int old = Code[a];
    if (((old & 0x8000) == 0) && (!(old & rdn))) { // ALU that doesn't change rp
        Code[a] = rdn | old | ret;   // make the last instruction returnable
    } else if ((old & lit) == lit) { // literal
        Code[a] = old | ret;
    } else if ((!notail) && ((old & 0xE000) == call)) {
        Code[a] = (old & 0x1FFF) | jump; // tail recursion
    } else {
plain:  comma(alu | ret | rdn); // compile a stand-alone return
    }
}

// Literal extension clears the 12-bit LEX register whenever
// the instruction is not LITX.
// Otherwise it shifts 12-bit data into LEX from the right.
// Full 16-bit and 32-bit data are supported with 2 or 3 inst.

SV extended_lit (int k12) {
    comma(litx | (k12 & 0xFFF));
}
SV Literal (cell x) {
#if (CELLSIZE > 23)
    if (x & 0xFF800000) {
        extended_lit(x >> 23);
        extended_lit(x >> 11);
    }
#else
    if (x & 0x007FF800)
        extended_lit(x>>11);
#endif
    x &= 0x7FF;
    comma (lit | (x & 0x7F) | (x & 0x780) << 1);
}

SV Simulate (cell xt) {
    Rpush(0);  pc = xt;
    int result = CPUsim(0);
    if (result < 0) error = result;
}

SV CompCall (cell xt) {
    comma (call | xt);
}

// EXIT should test Code[dp-1] to see if it's a call. If so, convert to jump.
// But the CALL needs to be able to inhibit that with a call-only flag
// Add that to the data structure before adding this optimization.

CELL base = 10;
CELL state = 0;

// Dictionary
// The dictionary is a simple linear list that uses a bit mask for context.

SI hp;                          // # of hp added at startup
SI emptiness;                               // EMPTY sets hp to this
static struct Keyword Header[MaxKeywords];
CELL me;                                // index of keyword being executed
CELL context = 15;
CELL current = 1;

SI findname (char *key) {               // return index of word, -1 if not fount
    if (strlen(key) < MaxNameSize) {
        int i = hp;
        while (--i >= 0) {              // scan the list backwards
            if (Header[i].context & context) {
                if (strcmp(key, Header[i].name) == 0) {
                    me = i;
                    return i;
                }
            }
        }
    }
    return -1;
}

SI NotKeyword (char *key) {             // do a command, return 0 if found
    int i = findname(key);
    if (i < 0)
        return -1;                      // not found
    if (state)
        Header[i].CompFn();
    else
        Header[i].ExecFn();
    return 0;
}

CELL CtrlStack[256];
uint8_t ConSP = 0;

SV ControlSwap(void) {
    cell x = CtrlStack[ConSP];
    CtrlStack[ConSP] = CtrlStack[ConSP-1];
    CtrlStack[ConSP-1] = x;
}
SV sane (void) {
    if (ConSP)  error = BAD_CONTROL;
    ConSP = 0;
}

static uint32_t my (void) {return Header[me].w;}
SV doLITERAL  (void) { Literal(Dpop()); }
SV Equ_Comp   (void) { Literal(my()); }
SV Equ_Exec   (void) { Dpush(my()); }
SV Def_Exec   (void) { Simulate(my()); }
SV Def_Comp   (void) { CompCall(my()); notail = Header[me].notail; }
SV doInstMod  (void) { int x = Dpop(); Dpush(my() | x); }
SV doLitOp    (void) { comma(Dpop() | my());  Dpush(0); }
SV noCompile  (void) { error = BAD_NOCOMPILE; }
SV noExecute  (void) { error = BAD_UNSUPPORTED; }
SV ResolveFwd (void) { Code[CtrlStack[ConSP--]] |= dp; fence = dp; }
SV ResolveRev (int inst) { comma(CtrlStack[ConSP--] | inst); fence = dp; }
SV MarkFwd    (void) { CtrlStack[++ConSP] = dp; }
SV doBegin    (void) { MarkFwd(); }
SV doAgain    (void) { ResolveRev(jump); }
SV doUntil    (void) { ResolveRev(zjump); }
SV doIf       (void) { MarkFwd();  comma(zjump); }
SV doThen     (void) { ResolveFwd(); }
SV doElse     (void) { MarkFwd();  comma(jump);  ControlSwap();  ResolveFwd(); }
SV doWhile    (void) { MarkFwd();  ControlSwap(); }
SV doRepeat   (void) { doElse();  doAgain();  doThen(); }
SV doFor      (void) { comma(alu | NtoT | TtoR | sdn | rup);  MarkFwd(); }

SV doNext     (void) { comma(alu | RM1toT | TtoN | sup );     /* (R-1)@ */
                       comma(alu | zeq    | TtoR);  ResolveRev(zjump);
                       comma(alu |           rdn);  fence = dp;} /* rdrop */

// A strncpy that complies with C safety checks.

void strmove (char *dest, char *src, int maxlength) {
    for (int i=0; i<maxlength; i++) {
        char c = *src++;  *dest++ = c;
        if (!c) return;
    }   *--dest = 0;
}

SI header (char * s) {
    int r = 1;
    if (hp < MaxKeywords) {
        strmove(Header[hp].name, s, MaxNameSize);
        Header[hp].context = current;
        Header[hp].length = 0;
        Header[hp].notail = 0;
        Header[hp].target = 0;
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
    if (header(name)) {
        SetFns(NOTANEQU, xte, xtc);
        hp++;
    }
}

SV AddEquate (char *name, cell value) {
    if (header(name)) {
        SetFns(value, Equ_Exec, Equ_Comp);
        hp++;
    }
}

// Modify the ALU instruction being constructed
SV AddModifier (char *name, cell value) {
    if (header(name)) {
        SetFns(value, doInstMod, noCompile);
        hp++;
    }
}

// Literal operations literal data from the stack and comma the instruction.
SV AddLitOp (char *name, cell value) {
    if (header(name)) {
        SetFns(value, doLitOp, noCompile);
        hp++;
    }
}

SV doWORDS (void) {
    for (int i=0; i<hp; i++) {
        if (Header[i].context & context) {
            printf("%s ", Header[i].name);
        }
    }
    printf("\n");
}

// Disassembler

static char* TargetName (cell addr) {
    if (!addr) return NULL;
    for (int i=0; i<hp; i++) {
        if (Header[i].target == addr) {
            return Header[i].name;
        }
    }
    return NULL;
}

SV Cdot (cell x) {  // cuz no itoa
    int32_t n = x;
    #if (CELLSIZE < 32)
    if (x & (1<<(CELLSIZE-1))) n -= 1<<CELLSIZE;
    x &= CELLMASK; // unsigned
    #endif
    if (base == 16) printf("%x ", x);
    else printf("%d ", n);
}
SV diss (int id, char *str) {
    while (id--) { while (*str++); }
    if (str[0]) printf("%s ", str);
}

cell DisassembleInsn(cell IR) { // see chad.h for instruction set summary
    char* name;
    if (IR & 0x8000) {
        int target = IR & 0x1FFF;
        switch ((IR>>12) & 7) {
        case 6: printf("%x lex", IR & 0x7F);  break;
        case 7: if (IR & 0x80) {printf("RET ");}
            printf("%x imm", (IR & 0x7F) | (IR & 0xF00)>>1);  break;
        default:
            name = TargetName(target);
            if (name == NULL) printf("%x ", target);
            diss((IR>>13)&3,"jump\0zjump\0call");
            if (name != NULL) printf("%s ", name);
        }
    } else { // ALU
        int id = (IR>>8) & 7;
        switch ((IR>>11) & 3) {
        case 0: diss(id,"T\0T0<\0T2/\0T2*\0N\0T^N\0T&N\0T>>8"); break;
        case 1: diss(id,"T+N\0N-T\0T0=\0N>>T\0N<<T\0R\0mem[T]\0status"); break;
        case 2: diss(id,"---\0C\0cT2/\0T2*c\0---\0~T\0mask\0T<<8"); break;
        default: diss(id,"T+Nc\0N-Tc\0---\0---\0---\0R-1\0io[T]\0---");
        }
        diss((IR>>4)&7,"\0T->N\0T->R\0N->[T]\0N->io[T]\0_IORD_\0CO\0T->CNT");
        diss( IR&3,    "\0d+1\0d-2\0d-1");
        diss((IR>>2)&3,"\0r+1\0r-2\0r-1");
        if (IR & 0x80) printf("RET ");
        printf("alu");
    }
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

SV PrintStack (void) {                  // ( ... -- ... )
    int depth = SDEPTH;
    for (int i=0; i<depth; i++) {
        if (i == (depth-1)) {
            Cdot(t);
        } else {
            Cdot(Dstack[(i + 2) & SPMASK]);
        }
    }
}

SV dotESS (void) {                      // ( ... -- ... )
    PrintStack();
    printf("<-Top\n");
}

SV dot (void) {                         // ( n -- )
    Cdot(Dpop());
}

SV ddot (void) {                        // ( d -- )
    cell hi = Dpop();
    cell lo = Dpop();
    uint64_t x = ((uint64_t)hi << CELLSIZE) | lo;
    #if (CELLSIZE < 32) // sign extend
    if (x & (1ull<<(CELLSIZE*2-1)))
        x -= 1ull<<(CELLSIZE*2);
    #endif
    printf("%" PRId64 " ", x);
}

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

SI parseword (char delimiter) {
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

SV doINCLUDE (void) {                   // Nest into a source file
    while (buf[toin] == ' ') toin++;
    if (buf[toin] == '"') {
        toin++;  parseword('"');        // allow filename in quotes
    } else {
        parseword(' ');                 // or a filename with no spaces
    }
    OpenNewFile(tok);
}

int DefMark, DefMarkID;

SV doColon (void) {
    parseword(' ');
    if (header(tok)) {                  // define a word that simulates
        SetFns(dp, Def_Exec, Def_Comp);
        Header[hp].target = dp;
        DefMarkID = hp++;               // save for later reference
        DefMark = dp;  state = 1;
        fence = dp;                     // code starts here
        ConSP = 0;
    }
}

SV doEQU (void) {
    parseword(' ');
    AddEquate(tok, Dpop());
}

SV SaveLength (void) {                  // resolve length of definition
    Header[DefMarkID].length = dp - DefMark;
}

SV CompMacro (void) {
    int len = Header[me].length;
    int addr = my();
    for (int i=0; i<len; i++) {
        int inst = Code[addr++];
        if ((i == (len - 1)) && (inst & ret)) { // last inst has a return?
            inst &= ~(ret | 0xc);       // strip trailing return
        }
        comma(inst);
    }
}

SV doMACRO (void) {
    Header[DefMarkID].CompFn = CompMacro;
}

SV doIMMEDIATE (void) {
    Header[DefMarkID].CompFn = Header[DefMarkID].ExecFn;
}

SV doNoTail (void) {
    Header[DefMarkID].notail = 1;
}

SV Marker_Exec (void) {                 // execution semantics of a marker
    dp = my();
    hp = Header[me].w2;                 // also forgets the marker
}

SV doMARKER (void) {
    parseword(' ');
    if (header(tok)) {                  // define a word that simulates
        SetFns(dp, Marker_Exec, noCompile);
        Header[hp].w2 = hp;
        hp++;
    }
}

SI tick (void) {                        // get the w field of the word
    parseword(' ');
    if (findname(tok) < 0) {
        error = UNRECOGNIZED;
        return 0;
    }
    return my();                        // W field of found word
}

SV doSEE (void) {                       // ( <name> -- )
    int addr;
    if ((addr = tick())) {
        Dpush(addr);  Dpush(Header[me].length);  doDASM();
    }
}

SV doAssert  (void) {                   // for test code
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
CELL tablebits = CELLSIZE;

SV doStats   (void) {
    printf("%" PRId64 " cycles, MaxSP=%d, MaxRP=%d", elapsed_cycles, spMax, rpMax);
    if (elapsed_us > 99) {
        printf(", %" PRId64 " MIPS", elapsed_cycles/elapsed_us);
    }
    printf("\n");
    spMax = sp;  rpMax = rp;
}

SV doTableEntry (void) {
    int bits = tablebits;
    cell x = Dpop();
    if (bits > 23) extended_lit(x >> 23);
    if (bits > 11) extended_lit(x >> 11);
    comma (ret | lit | (x & 0x7F) | (x & 0x780) << 1);
}

SV doCODE    (void) { doColon(); state = 0; context |= 8;  Dpush(0);}
SV doENDCODE (void) { SaveLength();        context &= ~8;  Dpop();  sane();}
SV doEMPTY   (void) { hp = emptiness; }
SV doBYE     (void) { error = BYE; }
SV doHEX     (void) { base = 16; }
SV doDEC     (void) { base = 10; }
SV doComment (void) { toin = strlen(buf); }
SV doCmParen (void) { parseword(')'); }
SV doComEcho (void) { doCmParen();  printf("%s",tok); }
SV doCR      (void) { printf("\n"); }
SV doContext (void) { Dpush(context); }
SV doToContx (void) { context = Dpop(); }
SV doToCurrn (void) { current = Dpop(); }
SV doToExec  (void) { state = 0; }
SV doToComp  (void) { state = 1; }
SV doHere    (void) { Dpush(dp); }
SV doTick    (void) { Dpush(tick()); }
SV doOrg     (void) { dp = Dpop(); }
SV doDROP    (void) { Dpop(); }
SV doComma   (void) { comma(Dpop()); }
SV doWrProt  (void) { writeprotect = CodeFence; }
SV doSemi    (void) { compExit();  SaveLength();  state = 0;  sane();}
SV doSetBits (void) { tablebits = Dpop(); }

// Keywords are visible based on bits in context.
// Set the same bits in current while loading hp.
// Current is 1 for host words, 2 for compiler, 4 for definitions

SV LoadKeywords(void) {
    hp = 0; // start empty
    current = -1;   // visible everywhere
    AddKeyword (">context", doToContx, noCompile);  // ( n -- )
    AddKeyword ("assert", doAssert, noCompile);     // ( n1 n2 -- )
    current = 1;    // hosting tools
    AddKeyword ("empty", doEMPTY, noCompile);
    AddKeyword ("context>", doContext, noCompile);  // ( -- n )
    AddKeyword (">current", doToCurrn, noCompile);  // ( n -- )
    AddKeyword ("stats", doStats, doToComp);
    AddKeyword ("hex", doHEX, noCompile);
    AddKeyword ("decimal", doDEC, noCompile);
    AddKeyword ("drop", doDROP, noCompile);
    AddKeyword ("\\", doComment, doComment);
    AddKeyword ("(", doCmParen, doCmParen);
    AddKeyword (".(", doComEcho, noCompile);
    AddKeyword ("cr", doCR, noCompile);
    AddKeyword ("include", doINCLUDE, noCompile);
    AddKeyword ("bye", doBYE, noCompile);
    AddKeyword ("words", doWORDS, noCompile);
    AddKeyword (".s", dotESS, noCompile);
    AddKeyword (".", dot, noCompile);               // ( n -- )
    AddKeyword ("d.", ddot, noCompile);             // ( d -- )
    AddKeyword ("dasm", doDASM, noCompile);
    AddKeyword ("see", doSEE, noCompile);
    AddKeyword ("sstep", doSteps, noCompile);
    AddKeyword ("inst", doInstruction, noCompile);
    AddKeyword ("write-protect", doWrProt, noCompile);
    AddEquate  ("code-writable", CodeFence);
    AddEquate  ("code-size", CodeSize);
    AddEquate  ("data-size", DataSize);
    AddEquate  ("cellsize", CELLSIZE);
    current = 2;    // compiler
    AddKeyword ("[", doToExec, doToExec);
    AddKeyword ("]", doToComp, doToComp);
    AddKeyword ("'", doTick, noCompile);
    AddKeyword (",", doComma, noCompile);
    AddKeyword ("here", doHere, noCompile);
    AddKeyword ("org", doOrg, noCompile);
    AddKeyword ("marker", doMARKER, noCompile);
    AddKeyword ("equ", doEQU, noCompile);
    AddKeyword (":", doColon, noCompile);
    AddKeyword ("CODE", doCODE, noCompile);
    AddKeyword ("exit", noExecute, compExit);
    AddKeyword (";", noExecute, doSemi);
    AddKeyword ("literal", noExecute, doLITERAL);
    AddKeyword ("macro", doMACRO, noCompile);
    AddKeyword ("immediate", doIMMEDIATE, noCompile);
    AddKeyword ("notail", doNoTail, noCompile);
    AddKeyword ("|bits|", doSetBits, noCompile);
    AddKeyword ("|", doTableEntry, noCompile);
    AddKeyword ("begin", noExecute, doBegin);
    AddKeyword ("again", noExecute, doAgain);
    AddKeyword ("until", noExecute, doUntil);
    AddKeyword ("if",    noExecute, doIf);
    AddKeyword ("else",  noExecute, doElse);
    AddKeyword ("then",  noExecute, doThen);
    AddKeyword ("while",  noExecute, doWhile);
    AddKeyword ("repeat",  noExecute, doRepeat);
    AddKeyword ("for",  noExecute, doFor);
    AddKeyword ("next",  noExecute, doNext);
    current = 8;    // assembler
    AddKeyword ("END-CODE", doENDCODE, noCompile);
    AddModifier("T",    alu  );  // Instruction fields
    AddModifier("T0<",  less0);
    AddModifier("C",    carry);
    AddModifier("T2/",  shr1 );
    AddModifier("cT2/", shrx );
    AddModifier("T2*",  shl1 );
    AddModifier("T2*c", shlx );
    AddModifier("N",    NtoT );
    AddModifier("T^N",  eor  );
    AddModifier("~T",   com  );
    AddModifier("T&N",  Tand );
    AddModifier("mask", mask );
    AddModifier("T>>8", shr8 );
    AddModifier("T<<8", shl8 );
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
    AddModifier("_IORD_", ior  );
    AddModifier("CO", co  );
    AddModifier("r+1",  rup  );  // stack pointer field
    AddModifier("r-1",  rdn  );
    AddModifier("r-2", rdn2 );
    AddModifier("d+1", sup  );
    AddModifier("d-1", sdn  );
    AddModifier("d-2", sdn2 );
    AddLitOp   ("alu", alu );
    AddLitOp   ("branch", jump );
    AddLitOp   ("0branch", zjump);
    AddLitOp   ("scall", call );
    AddLitOp   ("lex", litx );
    AddLitOp   ("imm", lit  );
    AddKeyword ("begin", doBegin, noCompile);
    AddKeyword ("again", doAgain, noCompile);
    AddKeyword ("until", doUntil, noCompile);
    AddKeyword ("if",    doIf, noCompile);
    AddKeyword ("else",  doElse, noCompile);
    AddKeyword ("then",  doThen, noCompile);
    AddKeyword ("while",  doWhile, noCompile);
    AddKeyword ("repeat",  doRepeat, noCompile);
    current = 4;    // forth
    emptiness = hp;
}

/*
The QUIT loop processes a line at a time from either the keyboard or a file.
The file handle is 0 for keyboard, other for file.
*/

SV refill (void) {
ask: toin = 0;
    File.LineNumber++;
    if (File.fp == stdin) {
        printf("ok>");
    }
    if (fgets(buf, maxlen, File.fp) == NULL) {
        if (filedepth) {
            fclose(File.fp);
            filedepth--;
            goto ask;
        }
    } else {
        char* p;                        // remove trailing newline
        if ((p = strchr(buf, '\n')) != NULL) *p = '\0';
        int len = strlen(buf);
        for (int i=0; i<len; i++) {
            if (buf[i] == '\t')         // replace tabs with blanks
                buf[i] = ' ';
        }
    }
    // save the line for error reporting
    strmove (File.Line, buf, LineBufferSize);
}

int chad(char * line, int maxlength) {
    buf = line;  maxlen = maxlength;    // assign a working buffer
    LoadKeywords();
    filedepth = 0;
    while (1) {
        File.fp = stdin;                // keyboard input
        fileID = error = state = 0;     // interpreter state
        cycles = spMax = rpMax = 0;     // CPU stats
        sp = rp = 0;                    // stacks
        while (!error) {
            toin = 0;
            uint64_t time0 = GetMicroseconds();
            uint64_t cycles0 = cycles;
            while (parseword(' ')) {
                if (NotKeyword(tok)) {  // try to convert to number
                    int i = 0;   int radix = base;   char c = 0;
                    int64_t x = 0;  int dp = 0;  int neg = 0;
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
                            dp = i;  break;
                        default:
                            c = c - '0';
                            if (c & 0x80) {goto bogus;}
                            if (c > 9)    {c -= 7;}
                            if (c > radix) {
bogus:                          error = UNRECOGNIZED;
                            }
                            x = x * radix + c;
                        }
                    }
                    if (neg) x = -x;
                    if (!error) {
                        if (dp) {
                            i = (x >> CELLSIZE) & CELLMASK;
                            x &= CELLMASK;
                            if (state) {
                                Literal((cell)x);
                                Literal((cell)i);
                            } else {
                                Dpush((cell)(x));
                                Dpush((cell)(i));
                            }
                        } else {
                            x &= CELLMASK;
                            if (state) {
                                Literal((cell)x);
                            } else {
                                Dpush((cell)(x));
                            }
                        }
                    }
                }
                if (sp == (StackSize-1)) error = BAD_STACKUNDER;
                if (rp == (StackSize-1)) error = BAD_RSTACKUNDER;
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

#define BYTES_PER_WORD ((CELLSIZE + 7) / 8)

uint32_t chadGetSource (char delimiter) {
    int bytes;
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
    int words = (bytes + BYTES_PER_WORD - 1) / BYTES_PER_WORD;
    int addr = DataSize - words;
    cell *dest = &Data[addr];
    for (int i=0; i<words; i++) {       // pack string into data memory
        uint32_t w = 0;                 // little-endian packing
        for (int j=0; j<BYTES_PER_WORD; j++) {
            w |= (uint8_t)*src++ << (j*8);
        }
        *dest++ = w;
    }
    return (addr<<8) + words;
}

uint32_t chadGetHeader (uint32_t select) {
    int ID = select >> 6;
    select &= 0x3F;
    if (ID < hp) {                      // valid ID
        switch (select) {
        case 0: return (Header[ID].ExecFn == Def_Exec); // it's executable code
        case 1: return (Header[ID].ExecFn == Header[ID].CompFn); // immediate
        case 2: return Header[ID].target;
        case 3: return Header[ID].length;
        case 4: return Header[ID].w;
        case 5: return Header[ID].w2;
        case 6: return Header[ID].notail;
        case 7: return dp;
        default:
            if ((select < NameOffset) || (select >= (NameOffset + MaxNameSize)))
                {return 0;}
            return Header[ID].name[select - NameOffset];
        }
    } else {
        return hp;                      // next free Header structure
    }
}

void chadError (int errorcode) {
    error = errorcode;
}
