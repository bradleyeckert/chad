# Novix Stack Computer architecture, Chad style

Data and return stacks don't need to be deep. A frame stack abstraction should
be used by library code to move excess stack contents to and from the frame
stack (in data memory) to prevent possible stack overflow.
A complex chunk of code would be preceded by `f[` *( depth -- )* to minimize
stacks and `]f` would restore the stacks.
For example, `2 f[` would leave nothing but two items on the data stack and
an empty return stack. `stats` tells you how deep your code is actually stacking.

The Chad ISA was inspired by the J1 architecture.
How did Bowman come up with the J1?
Somehow the stars lined up and out popped the J1.
What a great architecture for the future of computing.
Some small tweaks to the J1 facilitate double precision math, looping,
large address spaces, bit field operations, and room for user instructions.
The result is the Chad ISA.

## Chad ISA summary

```
0xpppppR wwwwrrss = ALU instruction
    x = unused
    p = 5-bit ALU operation select
    R = return
    w = strobe select {-, TN, TR, wr, iow, ior, co, TW, ...}
    r = return stack displacement
    s = data stack displacement
100nnnnn nnnnnnnn = jump
    PC = (lex<<13) | n
101nnnnn nnnnnnnn = conditional jump
110nnnnn nnnnnnnn = call, same as jump but pushes PC.
1110nnnn nnnnnnnn = literal extension
    lex = (lex<<12) | n;  Any other instruction clears lex.
1111nnnR nnnnnnnn = unsigned literal (imm)
    T = (lex<<13) | n
    R = return
```

### ALU detail

The `insn[12:8]` field of the ALU instruction is:

- x_0000: `T` T = T
- 0_0001: `T0<` T = -1 if T < 0 else 0
- 1_0001: `C` T = 1 if carry else 0
- 0_0010: `T2/` T = T / 2
- 1_0010: `cT2` T = T >> 1, MSB = carry
- 0_0011: `T2*` T = T << 1
- 1_0011: `T2*c` T = (T << 1) + carry
- 0_0100: `N` T = N
- 1_0100: `W` T = W
- 0_0101: `T^N` T = N ^ T
- 1_0101: `~T` T = ~T
- 0_0110: `T&N` T = N & T
- 1_0110: `T&W` T = W & T
- x_0111: `mask` if 16-bit cells: T = T >> 8; W = ~(-1<<T\[7:4]). 
Otherwise, T = T >> 10; W = ~(-1<<T\[9:5]). W is a bit mask.
- 0_1000: `T+N` T = N + T
- 1_1000: `T+Nc` T = N + T + carry
- 0_1001: `N-T` T = N - T
- 1_1001: `N-Tc` T = N - T - carry
- x_1010: `T0=` T = -1 if T = 0 else 0
- x_1011: `rshift` T = N >> T
- x_1100: `lshift` T = N << T
- 0_1101: `R` T = R
- 1_1101: `R-1` T = R - 1
- 0_1110: `[T]` T = mem_din
- 1_1110: `io[T]` T = io_din
- x_1111: `status` T = status: T\[9:5] = Rdepth; T\[4:0] = Depth, T\[15:10] = ID

The `insn[8]` bit of the ALU instruction is:

- 1: `RET` Return after this instruction. You should also use `r-1`.

The `insn[7:4]` field of the ALU instruction is:

- x000:
- x001: `T->N` Write T to N
- x010: `T->R` Write T to R
- x011: `N->[T]` Write T to mem\[A]
- x100: `N->io[T]` Write N to io\[T], waiting for its ACK signal
- x101: `_IORD_` Trigger read from the I/O port, wait if not ready
- x110: `CO` Write to carry: Adder or shifter carry out
- x111: `T->W` Write T to W

The `insn[3:2]` field of the ALU instruction is return stack control:

- 00: No change
- 01: `r+1` RP = RP + 1
- 10: `r-2` RP = RP - 2
- 11: `r-1` RP = RP - 1

The `insn[1:0]` field of the ALU instruction is data stack control:

- 00: No change
- 01: `d+1` SP = SP + 1
- 10: `d-2` SP = SP - 2
- 11: `d-1` SP = SP - 1

### What's with the non-J1 ALU opcodes?

**Scratchpad Register** W is added to handle the kinds of state
that aren't stack-friendly.

- `W` T = W
- `T&W` T = W & T
- `T->W` Write T to W

**Double precision math:**

- `C` T = 1 if carry else 0
- `cT2` T = T >> 1, MSB = carry
- `T2*c` T = (T << 1) + carry
- `T+Nc` T = N + T + carry
- `N-Tc` T = N - T - carry
- `CO` Latch the carry result of this instruction

**Loops** adds a decrement to the R -> T path:

- `R-1` T = R - 1
- `T0=` T = -1 if T = 0 else 0

`for` pushes the loop count to the return stack and starts a loop.
`next` compiles code and ends the loop:

```
     N    T->R  d-1  r+1
for: ...
     R-1  T->N  d+1
     T0=  T->R
     zjump for
                     r-1
```

**Literal extension instruction** `litx` extends literals and jump destinations.
A `RET` bit is allowed in a literal to handle lookup tables constructed with
executable code. Code space isn't necessarily randomly readable.
James Bowman used the J1 with dual-port RAM so that code and data spaces
overlapped. In an ASIC, memories would be single-port to save die area.
To handle read-only lookup tables, code can jump into a list of literals
that have their `RET` bits set.

**Missing `T|N`**

Most code that uses `or` can use `+` instead.
If not, `or` is a cheap definition: `: or  invert swap invert and invert ;`.
Thanks to Chuck Moore for discovering this in his MISC work
and for disabusing me of smudge bits.

### Memory Spaces

The code space contains ROM to function as a library.
ROM costs nearly nothing (in die area) compared to RAM.
Proposed memory space is organized as:

- Code ROM: 1024 x 16 (address 0x000 to 0x3FF)
- Code RAM: 1024 x 16 (address 0x400 to 0x7FF)
- Data RAM: 1024 x 18 (address 0x000 to 0x3FF)
- I/O space: address 0x000 to 0xFFF

The CPU boots from the ROM.
ROM contains the Forth kernel.
Code executing from ROM loads the application from the stream interface.

