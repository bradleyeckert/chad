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

For reference, in 130nm memory density is about 400 Kb/mm<sup>2</sup>
(according to ChipEstimate)
so designing for the 130nm node would give one `chad` core a die area of 0.4 mm<sup>2</sup>.
The 130nm node is attractive for several reasons:

- The masks are more affordable: No need for multi-layer reticles.
- It's supported by 12" fabs, which is not the case with 180nm.
- 180nm is cheaper, but the capacity crunch is hitting 8" hard. 
- Due to the above, 130nm is best for new designs.
- 130nm handles analog and mixed signal well too. 

It's easy to forget the early days of computing, when RAM was separate from the CPU.
On-chip RAM is taken for granted these days.
Memory generators and their simulation toolchains are modern marvels that make such things possible.
Memories are usually supplied as GDSII and matching simulation code targeted to the particular fab and process node.
These size estimates should be taken with a grain of salt since RAM architectures vary wildly
depending on speed and power requirements and transistors per bit (there are 4T and 1T types).
For example, MoSys 1T SRAM is half the area of 6T SRAM. 4T is about 30% smaller than 6T.

Free tools from eFabless work with the Sky130 process. There are RAM generators for
OpenRAM and DFFRAM, whose densities are roughly 75 and 25 Kb/mm<sup>2</sup> respectively.
20% the density of commercial memory IP is still usable for Forth chips.
The above mentioned 80 Kb (4Kx16 + 2Kx24) would be a little over 1 mm<sup>2</sup>
of OpenRAM. A [test RAM](https://github.com/ShonTaware/SRAM_SKY130) had
an access time of less than 2.5ns using Google SkyWater SKY130 PDKs and
OpenRAM memory complier.

Since OpenRAM is a little less mature, DFFRAM is a more reliable option.
The same RAM would be 3 mm<sup>2</sup>.

Google and eFabless are working with more chip fabs besides Skywater to set up open-source
PDKs. Now that a suitable way of protecting fab IP has been proven, the years of 2022 onward
should yield more free tools and more open-source IP as more fabs seek to have such IP target
their processes.

## ECC

Hamming(26,31) can correct single-bit errors on data words as wide as 26-bit.
Code memory can use 32-bit words with 6 parity bits to ECC code RAM.
A 2:1 multiplexer would split the corrected data into 16-bit halves.

## Lockstep operation

Evolving standards such as ISO 26262 (ASIL D functional safety) for automotive applications
and other standards such as those for household appliances and medical devices are moving
toward enhanced fault detection. One of these methods is dual-core lockstep,
which could be applied to `chad` without significant software changes. This doubles the die area.
The cores should be able to run independently or in lockstep mode depending on safety requirements.
Dual-core lockstep is all the rage among automotive MCU manufacturers these days.

A mismatch in state is detected within nanoseconds, but then what? I would suggest:

- Trigger an interrupt to request a graceful shutdown.
- The ISR is expected to trigger a hard reset.
- Hardware synchronizes the resets or does a reset-all if the reset triggers are not received.

The application should be structured so as to return to it's last mode of operation after reset.
It should take a few milliseconds to boot and run the application code, which could make the
system restoration transparent as long as no user input is required.

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


