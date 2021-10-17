# ISA of a Forth processor

The instruction set architecture depends on the match between logic speed and memory speed. High-speed SRAMs are roughly as fast as high-speed 32-bit adders. The slower ones have the delay of a ripple-carry adder and the faster ones more closely match a carry-lookahead adder. This seems to indicate that one instruction per clock matches one instruction per memory word, so a Novix-style stack machine makes sense.

The J1 CPU [Bowman, 2010] is an example of a Novix-style stack machine. A slight modification facilitates large applications in a code space as small as 2K 16-bit instructions. Application features can be paged into code RAM as needed.

16 bits seems to be the sweet spot for instruction size. Data should be 32-bit because the data structures of modern life are built from 8-bit, 16-bit, and 32-bit data. It’s 24 at the current time because headers got broken at 32-bit.

Paging time depends on the bandwidth of external memory. The number of code instructions in the cache region is up to 400, but let’s say 250 typical. Calling a word that executes in cache involves loading the new code from external memory, executing it, and restoring the old code upon return. The total amount of data transferred is 500 16-bit words, which would be an overhead of 5 μs with a 100 MHz SDRAM or 50 μs with a 50 MHz SPI flash in dual-rate mode.

Stacks are implemented as bi-directional shift registers, which provide high speed at low power due to the few long wires needed to implement a stack.

The Chad processor is like the J1 but with more roomy ALU instructions. For example, the J1 uses three bits for the return stack operation (2-bit displacement and 1-bit R). This can be done in two bits: The unused “-2” displacement is the R signal. Freeing up that bit allows for more strobes or more ALU opcodes. Returns often cost nothing since the "return" is in parallel with the ALU operation.

There is better support for multi-precision math via a carry bit. The adder uses only carry-out, not carry-in. Carry-in would put decode delay in the critical path.

Although it is not used, there is space in the ISA for MISC sequences. Those would be 3-instruction groups with 4-bit instructions. That would aid in compressing certain operations, but it would also complexify control flow.

## 16-bit instruction summary

<table>
  <tr>
   <td><strong><em>15</em></strong>
   </td>
   <td><strong><em>14</em></strong>
   </td>
   <td><strong><em>13</em></strong>
   </td>
   <td><strong><em>12</em></strong>
   </td>
   <td><strong><em>11</em></strong>
   </td>
   <td><strong><em>10</em></strong>
   </td>
   <td><strong><em>9</em></strong>
   </td>
   <td><strong><em>8</em></strong>
   </td>
   <td><strong><em>7</em></strong>
   </td>
   <td><strong><em>6</em></strong>
   </td>
   <td><strong><em>5</em></strong>
   </td>
   <td><strong><em>4</em></strong>
   </td>
   <td><strong><em>3</em></strong>
   </td>
   <td><strong><em>2</em></strong>
   </td>
   <td><strong><em>1</em></strong>
   </td>
   <td><strong><em>0</em></strong>
   </td>
   <td colspan="6" ><strong><em>Instruction type</em></strong>
   </td>
  </tr>
  <tr>
   <td colspan="3" >000
   </td>
   <td colspan="5" >opcode
   </td>
   <td colspan="4" >strobe
   </td>
   <td colspan="2" >rpinc
   </td>
   <td colspan="2" >spinc
   </td>
   <td colspan="6" >ALU
   </td>
  </tr>
  <tr>
   <td colspan="3" >001
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td colspan="6" >Reserved
   </td>
  </tr>
  <tr>
   <td colspan="3" >010
   </td>
   <td>S
   </td>
   <td colspan="12" >k
   </td>
   <td colspan="6" >Literal
   </td>
  </tr>
  <tr>
   <td colspan="3" >011
   </td>
   <td>T
   </td>
   <td colspan="12" >k
   </td>
   <td colspan="6" >Trap
   </td>
  </tr>
  <tr>
   <td colspan="3" >100
   </td>
   <td colspan="13" >k
   </td>
   <td colspan="6" >zJump
   </td>
  </tr>
  <tr>
   <td colspan="4" >1010
   </td>
   <td colspan="12" >k
   </td>
   <td colspan="6" >Litx
   </td>
  </tr>
  <tr>
   <td colspan="5" >10110
   </td>
   <td colspan="11" >k
   </td>
   <td colspan="6" >User coprocessor
   </td>
  </tr>
  <tr>
   <td colspan="5" >10111
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
   <td colspan="6" >Reserved
   </td>
  </tr>
  <tr>
   <td colspan="3" >110
   </td>
   <td colspan="13" >k
   </td>
   <td colspan="6" >Jump
   </td>
  </tr>
  <tr>
   <td colspan="3" >111
   </td>
   <td colspan="13" >k
   </td>
   <td colspan="6" >Call
   </td>
  </tr>
</table>



### ALU

Opcode = 6-bit ALU operation select (source of T). See table 1.

Strobe = 4-bit strobe select (not all are used). See table 2.

RPinc = Return stack pointer displacement { `0, R+, RET, R-` }. 

SPinc = Data stack pointer displacement { `0, S+, x, S-` }.


### Literal

Push (lex&lt;<12) | k to the data stack. S is the sign bit, value of the upper bits. If set, push (-1&lt;<12) | k to the data stack.


### Trap

Push (lex&lt;<12) | k to the data stack. Call to address (trap + T) where trap is 16 and T is a 1-bit trap selector.


### zJump

Drop the top of the data stack. If it was 0, jump to address k (PC = (lex&lt;<13) + k).


### Litx

Shift k into the lex register from the right. If the next instruction is not Litx, lex is cleared.


### Jump

Jump to address k. PC = (lex&lt;<13) + k.


### Call

Call to address k. Push (PC&lt;<1) to the return stack, PC = (lex&lt;<13) + k.


## ALU detail


### Table 1. ALU opcode (T source)

4-bit op[3:0] plus 1-bit modifier bit op[4]. If op[4] is used, ‘0’ case is shown on top.


<table>
  <tr>
   <td><strong><em>op[3:0]</em></strong>
   </td>
   <td><strong><em>Name</em></strong>
   </td>
   <td><strong><em>Meaning</em></strong>
   </td>
  </tr>
  <tr>
   <td rowspan="2" >0000
   </td>
   <td><strong><code>T</code></strong>
   </td>
   <td>nop
   </td>
  </tr>
  <tr>
   <td><strong><code>COP</code></strong>
   </td>
   <td>Coprocessor status
   </td>
  </tr>
  <tr>
   <td rowspan="2" >0001
   </td>
   <td><strong><code>T0&lt;</code></strong>
   </td>
   <td>-1 if T &lt; 0 else 0
   </td>
  </tr>
  <tr>
   <td><strong><code>C</code></strong>
   </td>
   <td>1 if carry else 0
   </td>
  </tr>
  <tr>
   <td rowspan="2" >0010
   </td>
   <td><strong><code>T2/</code></strong>
   </td>
   <td>T / 2
   </td>
  </tr>
  <tr>
   <td><strong><code>cT2/</code></strong>
   </td>
   <td>T >> 1, MSB = carry
   </td>
  </tr>
  <tr>
   <td rowspan="2" >0011
   </td>
   <td><strong><code>T2*</code></strong>
   </td>
   <td>T &lt;< 1
   </td>
  </tr>
  <tr>
   <td><strong><code>T2*c</code></strong>
   </td>
   <td>(T &lt;< 1) + carry
   </td>
  </tr>
  <tr>
   <td>0100
   </td>
   <td><strong><code>T+N</code></strong>
   </td>
   <td>T + N
   </td>
  </tr>
  <tr>
   <td rowspan="2" >0101
   </td>
   <td><strong><code>T&N</code></strong>
   </td>
   <td>T & N
   </td>
  </tr>
  <tr>
   <td>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td rowspan="2" >0110
   </td>
   <td><strong><code>T^N</code></strong>
   </td>
   <td>T ^ N
   </td>
  </tr>
  <tr>
   <td><strong><code>~T</code></strong>
   </td>
   <td>Complement of T
   </td>
  </tr>
  <tr>
   <td>0111
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td rowspan="2" >1000
   </td>
   <td><strong><code>>&lt;</code></strong>
   </td>
   <td>Swapped bytes: Even and Odd bytes swapped.
   </td>
  </tr>
  <tr>
   <td><strong><code>>&lt;16</code></strong>
   </td>
   <td>Swapped words: Even and Odd 16-bit words swapped.
   </td>
  </tr>
  <tr>
   <td rowspan="2" >1001
   </td>
   <td><strong><code>N</code></strong>
   </td>
   <td>N
   </td>
  </tr>
  <tr>
   <td><strong><code>A</code></strong>
   </td>
   <td>A register
   </td>
  </tr>
  <tr>
   <td rowspan="2" >1010
   </td>
   <td><strong><code>R</code></strong>
   </td>
   <td>R
   </td>
  </tr>
  <tr>
   <td>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td>1011
   </td>
   <td><strong><code>R-1</code></strong>
   </td>
   <td>R - 1
   </td>
  </tr>
  <tr>
   <td>1100
   </td>
   <td><strong><code>io</code></strong>
   </td>
   <td>io_din, from IOspace[T]
   </td>
  </tr>
  <tr>
   <td>1101
   </td>
   <td><strong><code>M</code></strong>
   </td>
   <td>mem_din, from data memory[T]
   </td>
  </tr>
  <tr>
   <td>1110
   </td>
   <td><strong><code>T0=</code></strong>
   </td>
   <td>-1 if T = 0 else 0
   </td>
  </tr>
  <tr>
   <td rowspan="2" >1111
   </td>
   <td><strong><code>status</code></strong>
   </td>
   <td>(Rdepth&lt;<8) | Sdepth
   </td>
  </tr>
  <tr>
   <td>
   </td>
   <td>
   </td>
  </tr>
</table>



### Table 2. Strobe select


<table>
  <tr>
   <td><strong><em>strobe</em></strong>
   </td>
   <td><strong><em>Name</em></strong>
   </td>
   <td><strong><em>Meaning</em></strong>
   </td>
  </tr>
  <tr>
   <td>0000
   </td>
   <td>
   </td>
   <td>No strobe
   </td>
  </tr>
  <tr>
   <td>0001
   </td>
   <td><strong><code>T->N</code></strong>
   </td>
   <td>Write T to N
   </td>
  </tr>
  <tr>
   <td>0010
   </td>
   <td><strong><code>T->R</code></strong>
   </td>
   <td>Write T to R
   </td>
  </tr>
  <tr>
   <td>0011
   </td>
   <td><strong><code>N->io[T]</code></strong>
   </td>
   <td>Write N to io[T], waiting for its ACK signal
   </td>
  </tr>
  <tr>
   <td>0100
   </td>
   <td><strong><code>[T]->M</code></strong>
   </td>
   <td>Trigger a read from data memory[T]
   </td>
  </tr>
  <tr>
   <td>0101
   </td>
   <td><strong><code>N->[T]</code></strong>
   </td>
   <td>Write N to mem[T]
   </td>
  </tr>
  <tr>
   <td>0110
   </td>
   <td><strong><code>N->[T]B</code></strong>
   </td>
   <td>Write N to mem[T], one byte lane enabled
   </td>
  </tr>
  <tr>
   <td>0111
   </td>
   <td><strong><code>N->[T]S</code></strong>
   </td>
   <td>Write N to mem[T], two byte lanes enabled
   </td>
  </tr>
  <tr>
   <td>1000
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td>1001
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td>1010
   </td>
   <td><strong><code>CO</code></strong>
   </td>
   <td>Write to carry: Adder or shifter carry out
   </td>
  </tr>
  <tr>
   <td>1011
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td>1100
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td>1101
   </td>
   <td><strong><code>io[T]->io</code></strong>
   </td>
   <td>Trigger a read from io[T]
   </td>
  </tr>
  <tr>
   <td>1110
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td>1111
   </td>
   <td><strong><code>T->A</code></strong>
   </td>
   <td>Write T to A, a general-purpose register
   </td>
  </tr>
</table>

Byte lane enables do not align the data, but they simplify byte and short writes.

### ALU instruction encoding

<table>
  <tr>
   <td>15
   </td>
   <td>14
   </td>
   <td>13
   </td>
   <td>12
   </td>
   <td>11
   </td>
   <td>10
   </td>
   <td>9
   </td>
   <td>8
   </td>
   <td>7
   </td>
   <td>6
   </td>
   <td>5
   </td>
   <td>4
   </td>
   <td>3
   </td>
   <td>2
   </td>
   <td>1
   </td>
   <td>0
   </td>
  </tr>
  <tr>
   <td colspan="2" >00
   </td>
   <td colspan="5" >opcode
   </td>
   <td>0
   </td>
   <td colspan="4" >strobe
   </td>
   <td colspan="2" >rpinc
   </td>
   <td colspan="2" >spinc
   </td>
  </tr>
</table>


### rpinc

<table>
  <tr>
   <td>01
   </td>
   <td><strong><code>R+</code></strong>
   </td>
   <td>Duplicate top of return stack
   </td>
  </tr>
  <tr>
   <td>10
   </td>
   <td><strong><code>RET</code></strong>
   </td>
   <td>Pop PC from return stack
   </td>
  </tr>
  <tr>
   <td>11
   </td>
   <td><strong><code>R-</code></strong>
   </td>
   <td>Drop from return stack
   </td>
  </tr>
</table>


The RET causes PC to be popped from the return stack. If an exception is pending, the return is not taken. Instead, the PC is loaded with an interrupt vector. Typically the vector is supplied by a priority encoder that gives a 4-bit vector between 1 and 15 (0 means nothing is pending). If the LSB of R is set, that is the highest priority exception. The PC is loaded with 18.

The “odd return” exception is used by cache management software to signal that the cache needs to be loaded to its previous state.

Exceptions used as interrupts work well with highly factored applications where not much time passes before the next return.


### spinc

<table>
  <tr>
   <td>01
   </td>
   <td><strong><code>S+</code></strong>
   </td>
   <td>Duplicate top of data stack, use with optional write to N
   </td>
  </tr>
  <tr>
   <td>10
   </td>
   <td>
   </td>
   <td>Drop data stack to (whatever), not used. Not very useful.
   </td>
  </tr>
  <tr>
   <td>11
   </td>
   <td><strong><code>S-</code></strong>
   </td>
   <td>Drop from data stack, use with optional read from N
   </td>
  </tr>
</table>



## Literal

Push (lex&lt;<12) | k12 to the data stack. Literals are 12-bit. If a longer literal is needed, a Litx instruction is used right before it to supply the following literal with extra bits. The sign bit (S) sets the upper bits to 1 for negative numbers.


## Trap

Push (lex&lt;<12) | k12 to the data stack. Call to address (trap + T) where trap is 16 and T is a 1-bit trap selector. So, there are two Trap instructions that call to either 16 or 17. The call pushes (PC&lt;<1) + T to the return stack. When a return hits the odd address, it will trigger an exception that cleans up from the trap.

An important usage for a trap is the API call. An API call compiles as a trap with its page and offset packed into a literal. The trap pushes the current page number onto a page stack, loads the page(s) into cache, and executes the code at the offset in cache memory. The trap cleanup will load the cache with the previous page.


## zJump

The zJump instruction executes Forth’s 0bran primitive used in **if then**, **begin while repeat**, and **begin until** control structures.

The signal for zJump, (t=0) is used by both zJump and the ALU’s T0= instruction. This signal can be slow in an FPGA due to the several layers of logic needed to form an ultra-wide NOR gate.


## Coprocessor conventions

A coprocessor can take parameters from T, N, A, and carry.

The `COP` ALU field sets T=0 when there is no coprocessor. Instruction 10110xxxxxxxxxxx is reserved for a coprocessor if you have one. In simulation, it would trigger the chadCOPtrigger(T, N, areg). The simulator would perform `chadCOPstep` in each cycle. The `COP` field would set T = `chadCOPresult`.

To enable code to detect the coprocessor (if any), the `copid` instruction is defined as `0xB000`.

After that executes, `COP` is ready at most two cycles later. These are the proposed `copid` codes:

* 0: No coprocessor exists
* 1: Hardware multiply and divide

The `coproc` coprocessor ports, excluding clock and reset, are:

* `sel`, 11-bit operation and/or register select
* `go`, trigger strobe ('1' when COP instruction)
* `y`, coprocessor output
* `a`, top of data stack
* `b`, 2nd item on data stack

The `C` simulation uses `coproc.h` and `coproc.c` to define the coprocessor function `chad_coproc`. The "busy" status will always read 0.


### Hardware multiply and divide

There are many ways to implement a multiplier: iterative, pipelined, or full. The software doesn't care. It just needs to test (or wait) for completion. Once an operation is triggered, reading `COP` gives a 0 when the coprocessor is busy. Once finished, you can read the result from `COP`. The lower 11 bits control reading and triggering:

* xxxxxxx0000 = Read status: 1 = busy, 0 = ready
* xxxxxxx0001 = Read options, bits\[2:0] = {shift, divide, multiply}
* xxxxxxx0010 = Read upper multiplication product
* xxxxxxx0011 = Read lower multiplication product
* xxxxxxx0100 = Read division quotient
* xxxxxxx0101 = Read division remainder
* xxxxxxx0110 = Read upper shift result
* xxxxxxx0111 = Read lower shift result
* SBBBBB1001x = Trigger multiplication of T and N; S=signed, B=bits-1
* xxxxxx1010x = Trigger division of T:N by W
* xxxxSL1011x = Trigger shift of T:N by W; S=signed, L=left

On a MAX10, a 24-bit processor needed about 300 LEs to add iterative hardware multiply and divide. Since the FPGA's hard multipliers are not used, the coprocessor won't slow down the processor if it's in an ASIC.

Fractional multiplication is great way to multiply small numbers or scale. A fractional multiply is faster than a full iterative multiplication when full precision isn't required. 


### SDRAM (TBD)

Coprocessor instructions could be used to page data between SDRAM and data RAM. It seems you get a choice between high pin count and high cost when choosing a SDRAM. For example, the Infineon/Cypress HyperRam has a reduced pin count (5x5 BGA with 1mm ball pitch) but cost $3 to $4 for 64Mb (8MB).

SDRAMs usually need an occasional `refresh` instruction, which could be supplied by a periodic ISR. The ISR would also maintain a counter to keep track of time.


## Shift register stacks

The simulator models stacks with circular buffers. It reports overflow and underflow to avoid the difference in overflow and underflow behavior that you would see when using a shift register stack.

Data and return stacks don't need to be deep. A frame stack abstraction (`frame.f`) can

be used by library code to move excess stack contents to and from the frame stack (in data memory) to prevent possible stack overflow. A complex chunk of code would be preceded by `stack(` *( depth -- )* to minimize stacks and `)stack` would restore the stacks. With some stack management, 16-cell hardware stacks are sufficient.
