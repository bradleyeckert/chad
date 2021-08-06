# Novix Stack Computer architecture, Chad style

The Chad ISA was inspired by the J1 architecture.
How did James Bowman come up with the J1?
Somehow the stars lined up and out popped the J1.
What a big architecture for the future of little computing.
Some small tweaks to the J1 facilitate double precision math, looping,
large address spaces, and room for user instructions.
The result is the Chad ISA.

J1-style CPUs handle branches very well. 
Even though the memories are synchronous-read, jumps and calls cost only one
clock cycle.
Returns often cost nothing since a "return" bit can trigger a return in parallel
with an ALU operation.

## Chad ISA summary

```
0xpppppR xwwwrrss = ALU instruction
    x = unused
    p = 5-bit ALU operation select
    R = return
    w = strobe select
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
    T = (lex<<11) | n
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
- x_0110: `T&N` T = N & T
- 0_0111: `><` T = swapped bytes: Even and Odd bytes swapped.
- 1_0111: `><16` T = swapped words: Even and Odd 16-bit words swapped.
- x_1000: `T+N` T = N + T
- x_1001: `N-T` T = N - T
- x_1010: `R` T = R
- x_1011: `R-1` T = R - 1
- x_1100: `io[T]` T = io_din
- x_1101: `[T]` T = mem_din
- x_1110: `T0=` T = -1 if T = 0 else 0
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
- 10: `r-2` RP = RP - 2 (do not use)
- 11: `r-1` RP = RP - 1

The `insn[1:0]` field of the ALU instruction is data stack control:

- 00: No change
- 01: `d+1` SP = SP + 1
- 10: `d-2` SP = SP - 2 (do not use)
- 11: `d-1` SP = SP - 1

### What's with the non-J1 ALU opcodes?

**Scratchpad Register** W is added to handle the kinds of state
that aren't stack-friendly.

- `W` T = W
- `CO` Write T to W

**Double precision math:**

- `C` T = 1 if carry else 0
- `cT2` T = T >> 1, MSB = carry
- `T2*c` T = (T << 1) + carry
- `CO` Latch the carry result of this instruction

You might think a carry-in add or subtract instructions would be nice to have.
It's easy enough to gate a carry into the adder. The problem with this is that
the instruction decoding that feeds in the carry adds significant delay,
which slows down the processor.

**Cache control for large apps**

Any `RET` that occurs with the LSB of R (top of the return stack) set causes
an exception (jump to 010h) instead of a return.

Some of code space is reserved for instruction cache.
This allows large applications to be paged into RAM as needed.
The code sections are called applets. A call to a word in an applet is compiled as:

- A literal containing a long address consisting as its code page in external memory
(such as SPI flash) packed with its offset into cache
- `call` to `(API)`, which loads the code into RAM and jumps to the word.

`(API)` also sets the LSB of R and pushes the current code page onto the return stack.
Return performs an exception if the LSB of the top of the return stack is set.
The exception loads the previous code back into cache before returning to it.

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

Literal instructions have 11 data bits, or 69% of a 16-bit instruction.
Tables of literals have an overhead of 31% to 50% depending on the data size.

**Long calls/jumps**

Software can access code past the 13-bit address range by putting a `litx`
before the jump or call. `chad` does not currently use this feature.

**Missing `T|N`**

Most code that uses `or` can use `+` instead.
If not, `or` is a cheap definition: `: or  invert swap invert and invert ;`.
Thanks to Chuck Moore for discovering this in his MISC work.

**\_MEMRD_**

The original J1 read from data memory all the time. Let's add a read strobe.
It's decoded from three `insn` bits, so it's plenty fast.
Simulation is set up to model a synchronous-read memory. 

**Missing N>>T and N<<T**

Barrel shifters are not cheap, especially in an FPGA.
Single-bit shifts are used instead.
To handle byte packing and unpacking,
`><` and `><16` are added to swap bytes and 16-bit halves.

**0000 is nop instead of jump**

The J1 ISA is set up so that execution of blank code space jumps to 0 which
does a cold boot. Kinda cool.
I noticed this rather late, but `nop` has the same effect.
The PC wraps back around to 0 when it walks off the end of code space.
I programmed my first computer using a pencil and paper for the assembler
and a DIP switch and a pushbutton to program a UV EPROM.
I could turn bad code into NOPs by overwriting it with zeros.
The idea stuck, so 0 is a `nop` although these days it doesn't matter.

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

The `coproc` coprocessor ports, excluding clock and reset, are:

- `sel`, 11-bit operation and/or register select
- `go`, trigger strobe ('1' when COP instruction)
- `y`, coprocessor output
- `a`, top of data stack
- `b`, 2nd item on data stack

The `C` simulation uses `coproc.h` and `coproc.c` to define the coprocessor
function `chad_coproc`. The "busy" status will always read 0.

### Hardware multiply and divide

There are many ways to implement a multiplier: iterative, pipelined, or full.
The software doesn't care. It just needs to test for completion.
Once an operation is triggered, reading `COP` gives a 0 when the coprocessor
is busy. Once finished, you can read the result from `COP`.
The lower 11 bits control reading and triggering:

- xxxxxxx0000 = Read status: 1 = busy, 0 = ready
- xxxxxxx0001 = Read options, bits\[2:0] = {shift, divide, multiply}
- xxxxxxx0010 = Read upper multiplication product
- xxxxxxx0011 = Read lower multiplication product
- xxxxxxx0100 = Read division quotient
- xxxxxxx0101 = Read division remainder
- xxxxxxx0110 = Read upper shift result
- xxxxxxx0111 = Read lower shift result
- SBBBBB1001x = Trigger multiplication of T and N; S=signed, B=bits-1
- xxxxxx1010x = Trigger division of T:N by W
- xxxxSL1011x = Trigger shift of T:N by W; S=signed, L=left

On a MAX10, a 24-bit processor needed about 300 LEs to add iterative hardware
multiply and divide. Since the FPGA's hard multipliers are not used,
the coprocessor won't slow down the processor if it's in an ASIC.

Fractional multiplication is great way to multiply small numbers or scale.
A fractional multiply is faster than a full iterative multiplication when
full precision isn't required. 

### SDRAM (TBD)

Coprocessor instructions could be used to page data between SDRAM and
data RAM. It seems you get a choice between high pin count and high cost
when choosing a SDRAM. 
For example, the Infineon/Cypress HyperRam has a reduced
pin count (5x5 BGA with 1mm ball pitch) but cost $3 to $4 for 64Mb (8MB).

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
That is low power computing.

The simulator models stacks with circular buffers. 
It reports overflow and underflow to avoid the difference in overflow and
underflow behavior that you would see when using a shift register stack.

Data and return stacks don't need to be deep.
A frame stack abstraction (`frame.f`) can
be used by library code to move excess stack contents to and from
the frame stack (in data memory) to prevent possible stack overflow.
A complex chunk of code would be preceded by `stack[` *( depth -- )* to
minimize stacks and `]stack` would restore the stacks.
For example, `2 stack[` would leave nothing but two items on the data
stack and an almost empty return stack. `d.r` uses `fstack`, for example.
The simulator word `stats` tells you how deep your code is
actually stacking.
With some stack management, 16-cell hardware stacks are sufficient.

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
out of its 200 or so lines of Verilog.

What Chuck Moore demonstrated with MISC was the utility of small stacks.
His Novix architecture from the 1980s had stacks made of 256-cell
memories. It turns out smaller is better.
GreenArrays adopted shift register stacks.
James Bowman's use of shift register stacks in the J1 was a great idea.
It seems that stack machines may have a future.
J1-style cores run as fast as you can keep them fed with instructions.

If you look at commercial ASIC processes, memory is slower than logic.
In an actual standard cell chip, the processor may have to wait
on memory. Adding a `cke` (clock enable) signal to the port list would
let the memories insert wait states.
With code memory, that wouldn't impact performance much.
If you use a wider data bus (such as 128-bit) on the ROM and mux it
down to 16-bit, most of the time you would only have the mux delay
because the 128-bit word is already settled.
So, a `chad` processor could be very fast in an ASIC.
