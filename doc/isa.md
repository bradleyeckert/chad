# Novix Stack Computer architecture, Chad style

The Chad ISA was inspired by the J1 architecture.
How did James Bowman come up with the J1?
Somehow the stars lined up and out popped the J1.
What a big architecture for the future of little computing.
Some small tweaks to the J1 facilitate double precision math, looping,
large address spaces, bit field operations, and room for user instructions.
The result is the Chad ISA.

## Chad ISA summary

```
0xpppppR xwwwrrss = ALU instruction
    x = unused
    p = 5-bit ALU operation select
    R = return
    w = strobe select {-, TN, TR, wr, iow, ior, co, TW}
    r = return stack displacement
    s = data stack displacement
100nnnnn nnnnnnnn = jump
    PC = (lex<<13) | n
101nnnnn nnnnnnnn = conditional jump
110nnnnn nnnnnnnn = call, same as jump but pushes PC.
11100nnn nnnnnnnn = literal extension
    lex = (lex<<11) | n;  Any other instruction clears lex.
11101nnn nnnnnnnn = reserved for user's coprocessor
1111nnnR nnnnnnnn = unsigned literal (imm)
    T = (lex<<13) | n
    R = return
```

### ALU detail

The `insn[12:8]` field of the ALU instruction is:

- 0_0000: `T` T = T
- 1_0000: `COP` T = coprocessor status (0 if none)
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

The `insn[6:4]` field of the ALU instruction is:

- 000:
- 001: `T->N` Write T to N
- 010: `T->R` Write T to R
- 011: `N->[T]` Write T to mem\[A]
- 100: `N->io[T]` Write N to io\[T], waiting for its ACK signal
- 101: `_MEMRD_` Trigger read from data memory
- 110: `_IORD_` Trigger read from the I/O port
- 111: `CO` Write to carry: Adder or shifter carry out; also save T to W

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
- `CO` Write T to W

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

**\_MEMRD_**

The original J1 read from data memory all the time. Let's add a read strobe.
It's decoded from three `insn` bits, so it's plenty fast.
Simulation is set up to model a synchronous-read memory. 

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
Code executing from ROM loads the application.

## Coprocessor Conventions

A coprocessor can take parameters from T, N, W, and carry.

The `COP` ALU field sets T=0 when there is no coprocessor.
Instruction 11101xxxxxxxxxxx is reserved for a coprocessor if you have one.
In simulation, it would trigger the chadCOPtrigger(T, N, W).
The simulator would perform `chadCOPstep` in each cycle. 
The `COP` field would set T = `chadCOPresult`.

To enable code to detect the coprocessor (if any), the `copid` instruction
is defined as `0xE800`.
After that executes, `COP` is ready at most two cycles later.
These are the proposed `copid` codes:

- 0: No coprocessor exists
- 1: Hardware multiply and divide

### Hardware multiply and divide (TBD)

There are many ways to implement a multiplier: iterative, pipelined, or full.
The software doesn't care. It just needs to test for completion.
Once an operation is triggered, reading `COP` gives a 0 when the coprocessor
is busy. Once finished, you can read result registers into `COP`.

- 0xE800 = Read ID = 1
- 0xE801 = Read upper multiplication product
- 0xE802 = Read lower multiplication product
- 0xE803 = Read division quotient
- 0xE804 = Read division remainder
- 0xE808 = Trigger multiplication of T and N
- 0xE809 = Trigger division of T:N by W

### SDRAM (TBD)

Coprocessor instructions could be used to page data between SDRAM and
data RAM. 
It seems you get a choice between high pin count and high cost when
choosing a SDRAM. For example, the Infineon/Cypress HyperRam has a reduced
pin count (5x5 BGA with 1mm ball pitch) but cost $3 to $4 for 64Mb.
64Mb is 8M bytes.

SDRAMs usually need an occasional `refresh` instruction, which could be
supplied by a periodic ISR. 
The ISR would also maintain a counter to keep track of time.

## Shift register stacks

It took me a while to come around to shift register stacks.
Not a circularly indexed register file, but actual bi-directional
shift registers for the stack.
One shift register for each bit in the cell.
Power dissipation is caused by wires.
In a shift register, the bits are right next to each other.
It should synthesize nicely, with the business end where you want it.

The simulator models stacks with circular buffers. 
It reports overflow and underflow to avoid the difference in overflow and
underflow behavior that you would see when using a shift register stack.

Data and return stacks don't need to be deep.
A frame stack abstraction should
be used by library code to move excess stack contents to and from the frame
stack (in data memory) to prevent possible stack overflow.
A complex chunk of code would be preceded by `f[` *( depth -- )* to minimize
stacks and `]f` would restore the stacks.
For example, `2 f[` would leave nothing but two items on the data stack and
an empty return stack. `d.r` uses `f[`, for example.
The simulator word `stats` tells you how deep your code is
actually stacking.

## chad vs MISC

The MISC architecture is based on 5-bit instructions
with four instructions packed into an 18-bit word.
With a 5:5:5:3 format, opcodes that need immediate data can take up to
13 bits of data from the remainder of the word. Same as `chad`.

MISC is designed to accept relatively slow code fetch in relation to the
speed of execution of the sequence of MISC instructions.
That's the allure of asynchronous computing.
When ported to the synchronous world of clock edges
(which is how we play well together),
the advantages of MISC evaporate.
The super simple opcodes spend most of their time waiting for
the next clock edge.

MISC is great if you can simulate it, but there's the rub.
Commercial chip design tools just aren't up to doing
that kind of simulation. If you can't simulate it, you can't build it.
GreenArrays built their own simulation tools.
Okay, but...

Any synthesis tool,
which you can get for free if you are targeting an FPGA,
or can get at all if you are targeting an ASIC,
will readily synthesize a `chad` processor
out of 200 or so lines of Verilog.

What Chuck Moore demonstrated with MISC was the utility of small stacks.
His Novix architecture from the 1980s had stacks made of 256-cell
memories. It turns out smaller is better.
James Bowman's use of shift register stacks in the J1 was a great idea.

If you look at commercial ASIC processes, ON Semi's 180nm process offers
RAM with a cycle time of 3.3 to 5 ns. That's slow compared to GreenArrays
1 ns instructions. In an actual standard cell chip, the processor may
have to wait on memory. Adding a `hold` signal to the port list would let
the memories hold off execution to insert wait states. With code memory,
that wouldn't impact performance much.
If you use a wider data bus (such as 64-bit) on the ROM and mux it down to
16-bit, most of the time you would only have the mux delay because the
64-bit word is already settled. So, a `chad` processor could be very fast
even in legacy (cheaper) fab processes.
