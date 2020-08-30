# Chad's rendition of the J1 CPU architecture

All addressing is in cells. Bytes are not supported in hardware because you
should not be thinking bytes. Bytes are so 1970s.
Bytes are bit fields with a width of 8.
Why are applications declaring variables in bytes?
They should be using bit fields. RAM on a small processor isn't cheap.

Data and return stacks don't need to be deep. A frame stack abstraction should
be used by library code to move excess stack contents to and from the frame
stack (in data memory) to prevent possible stack overflow.
A complex chunk of code would be preceded by `f[` *( depth -- )* to minimize
stacks and `]f` would restore the stacks.
For example, `2 f[` would leave nothing but two items on the data stack and
an empty return stack.

Bit fields should be used instead of variables when raw speed is not needed.
They can use `b@` and `b!` as operators.
The bit address consists of packed address, shift, and width fields.
A 16-bit cell would address a bit field within a 256-cell block of RAM.

Support of double precision math was lacking in the J1. Chad supports carry.
Arbitrary width literals are supported in hardware.
The same trick allows jumps and calls into an arbitrarily large
(but physically limited to *2^cellsize* words) of code space.
Requiring fewer bits in the `imm` instruction freed up two extra bits
(currently unused) in the ALU instruction.

The J1 is a little unwieldy for loops.
A small tweak allows a 3-instruction `for` `next` loop.

Separate stacks are smaller, faster, and easier to use.
Your application should be able to manage stacks to avoid overflow.
The ISA is modified to expedite that, to keep stacks small.

## Chad ISA summary

```
0xxppppp Rwwwrrss = ALU instruction
    x = unused
    p = 5-bit ALU operation select
    R = return
    w = strobe select {-, TN, TR, wr, iow, ior, co, w}
    r = return stack displacement
    s = data stack displacement
100nnnnn nnnnnnnn = jump
    PC = (lex<<13) | n
101nnnnn nnnnnnnn = conditional jump
110nnnnn nnnnnnnn = call, same as jump but pushes PC.
1110nnnn nnnnnnnn = literal extension
    lex = (lex<<12) | n;  Any other instruction clears lex.
1111nnnn Rnnnnnnn = unsigned literal (imm)
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
- 1_0101: `W` T = W
- 0_0101: `T^N` T = N ^ T
- 1_0101: `~T` T = ~T
- 0_0110: `T&N` T = N & T
- 1_0110: `T&W` T = W & T
- 0_0111: `T>>8` T = T >> 8; W = ~(-1<<T\[7:4])
- 1_0111: `T<<8` T = T << 8;
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

The `insn[7]` bit of the ALU instruction is:

- 1: `RET` Return after this instruction. You should also use `r-1`.

The `insn[6:4]` field of the ALU instruction is:

- 000:
- 001: `T->N` Write T to N
- 010: `T->R` Write T to R
- 011: `N->[T]` Write T to mem\[A]
- 100: `N->io[T]` Write N to io\[T], waiting for its ACK signal
- 101: `_IORD_` Trigger read from the I/O port, wait if not ready
- 110: `CO` Write to carry: Adder or shifter carry out
- 111: `T->W` Write T to W

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

**Bytes and bit fields** need shifters:

- `mask` T = ~(-1 << MASK) & T
- `T>>8` T = T >> 8; MASK = T\[7:4]
- `T<<8` T = T << 8;
- `rshift` T = N >> T
- `lshift` T = N << T

Bit field read is about 7 cycles:

```
     T>>8  T->N  d+1    ( count addr )
     T                  \ wait for read to settle
     [T]                \ read the cell
     "SWAP"             ( data count )
     N>>T        d-1    \ value
     T&W        RET     \ bitfield
```

This relies on `N>>T` ignoring the mask field of the bit address.
If the cell is wider than 16-bit, some extra work is required to mask it off.
Or, T>>8 could be changed to T>>10 and the mask be taken from T\[9:5].

Bit field write is about 20 cycles:
    
```
     "SWAP"
     ">R"
     T>>8  T->N  d+1    ( count addr | n ) W = mask
     T     T->R  r+1
     [T]                ( count data | n addr )
     "OVER"             ( count data count | n addr )
     W     T->N  d+1    ( count data count mask | n addr )
     "SWAP"
     N<<T               ( count data mask' | n addr )
     ~T
     T&N         d-1    ( count data' | n addr )
     "SWAP"             ( data' count | n addr )
     "R>"               ( data' count n | addr )
     T&W                ( data' count n | addr )
     "SWAP"             ( data' n count | addr )
     N<<T        d-1    ( data' n' | addr )
     T+N         d-1    ( data' | addr )
     "R>"               ( data' addr )
     T    N->[T] d-1
     N    RET    d-1
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
Many thanks to Chuck Moore for discovering this in his MISC work.

### Memory Spaces

The code space contains ROM to function as a library.
ROM costs nearly nothing (in die area) compared to RAM.
Proposed memory space is organized as:

- Code ROM: 512 x 18 (address 0x000 to 0x1FF)
- Code RAM: 512 x 18 (address 0x400 to 0x5FF)
- Data RAM: 512 x 18 (address 0x000 to 0x1FF)
- I/O space: address 0x000 to 0xFFF

The CPU boots from the ROM.
ROM contains the Forth kernel.
Code executing from ROM loads the application from the stream interface.

