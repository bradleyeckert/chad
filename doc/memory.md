# Memory Sizes

Each `chad` core uses two memories: code and data.
The memories should be small enough to encourage multi-core usage but
big enough to be useful.

As a rough rule of thumb, suppose a 6T RAM bit and a 4T NAND gate.
Since the packing of transistors in a memory is much more efficient than in logic,
each gate is roughly the size of two (single-port) RAM bits.

Stacks are bidirectional shift registers where each bit consists of a D-FF and four pass transistors.
A D-FF is 12T in CMOS, so let each stack bit be worth 4 gates of die area.
16x16 and 24x16 stacks total 2.5K gates.

The ARM 1 RISC processor (1985) was 25K transistors.
Assuming half of that was logic, that would be 3K gates. 
The original 8086 (1978) was 29K transistors, about the same complexity.
Suppose `chad` logic will cost 3K gates.
Allow 1.5K gates for user logic and 2.5K gates for stacks.
Let the memory have twice the die area of logic.
That would make the ideal total memory size in the 28Kb range:

- 1K x 16 code memory
- 512 x 24 data memory

To support a Forth interpreter, `chad` needs about 1.7K of code space.
It would be nice to support 1K of applet space and 1.3K of user code.
This brings the code space requirement to 4K. So, more sensible memory sizes are:

- 4K x 16 code memory
- 2K x 24 data memory

For reference, in 180nm memory density is about 160 Kb/mm<sup>2</sup>
so designing for the 180nm node would give one `chad` core a die area of 1 mm<sup>2</sup>.

A chip with 3 mm<sup>2</sup> of usable die area (1.73mm on a side) would have room for 
17 100um x 300um pad structures per side, which would give a 68-pad die with a size of
2.5mm on a side.
Supposedly, a mask set for 180nm is about $50K.
An 8" wafer could yield 4500 chips, which at a cost of $3K per wafer would be about $0.67/chip.

Reducing the active area area to 1 mm<sup>2</sup> has some impact.
A 44-pin chip with a pad ring of 11 on a side is 1.7mm x 1.7mm (1.8mm with dicing lanes)
so the cost would be $0.35/chip.
Compared to 68 pins, those 24 extra I/O pins cost a lot if you're pad-limited:
$0.57 at a penny a pin for packaging.
QFN packages are economical if you can use them. The biggest QFNs are around 80 pins.

For an ASIC with more than 60 pins, there is room for more memory at 180nm.
For the `chad` simulator, I propose defaulting to these memory sizes:

- 8K x 16 code memory
- 4K x 24 data memory

It's easy to forget the early days of computing, when RAM was separate from the CPU.
On-chip RAM is taken for granted these days.
Memory generators and their simulation toolchains are modern marvels that make such things possible.
Memories are usually supplied as GDSII and matching simulation code targeted to the particular fab and process node.
These size estimates should be taken with a grain of salt since RAM architectures vary wildly
depending on speed and power requirements and transistors per bit (there are 4T and 1T types).
For example, MoSys 1T SRAM is half the area of 6T SRAM. 4T is about 30% smaller than 6T.

## Memory DFT

Firmware can test memories because they are small.
The wafer probe card may contain SPI boot flash devices that each chip would load to run the test program.
Each die only needs 9 probe wires: VDD, VSS, 4-wire SPI, clock, reset, and pass/fail status.
This would enable cheap ATE and the testing of several chips at the same time.
The test program would screen dice using basic memory tests.
After packaging of good dice, ATE would perform I/O tests.

### Stacks

Firmware can test the stacks, so the stack FFs don't need to be part of the scan chain.

### Data Memory

Pattern testing is easy enough for data RAM due to read/write access.

### Code Memory

Code memory does not support random read.
I'm not sure it will support random write. That may be removed.
The trick here is to test it without providing a backdoor to attackers.

One possibility for testing is to put test patterns and commands into external SPI flash.
Instead of booting the CPU, commands would trigger a CRC scan of the memory
and check it against a 32-bit CRC. RAM is external to the `spif` module.
It has address and write ports, but `spif` will need a read port to get the read data
for the CRC test.

The test result would be stored in a register that's unaffected by reset.
Subsequent tests would run firmware to report pass/fail status on whatever I/O pin
is convenient.


