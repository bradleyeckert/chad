# ASIC considerations

The 130nm node is attractive for several reasons:

- The masks are more affordable: No need for multi-layer reticles.
- It's supported by 12" fabs, which is not the case with 180nm.
- 180nm is cheaper, but the capacity crunch is hitting 8" hard. 
- Due to the above, 130nm is best for new designs.
- eFabless has FOSS chip design tools for 130 nm.
- 130nm handles analog and mixed signal well too. 

Forth computers are tiny, even when used on a 130nm process like Sky130.
It's likely your chip will be pad-limited.

## I/O pads

I/O pads are blocks of hard IP with ESD diodes, drivers and receivers.
They offer slew rate control, pullup/pulldown, and various other features.
You can hard-wire them or control them through registers with sensible
default settings.

Sky130 pads have a specified maximum frequency of 30 MHz.

I/O pads are big. I couldn't find size information on Sky130 I/O pads, but
a MOSIS 0.35um Hi-ESD I/O pad has an outline of 0.3 x 0.09 mm.
44 of these (11 per side) would give a 1.6mm x 1.6mm chip with a 1mm x 1mm
user area. The four corners can be used for power pins, so a 48-pin package
could house the chip. Can a Chad-based ASIC fit in 1 mm<sup>2</sup>?
Let's see.

## Memory Sizes

Stacks are bidirectional shift registers where each bit consists of a D-FF
and four pass transistors.
A D-FF is 12T in CMOS, so let each stack bit be worth 4 gates of die area.
16x16 and 24x16 stacks total 2.5K gates.
Figure another 3K gates for the CPU etc. but it's a lousy estimate because
logic area depends on speed and power requirements.
It doesn't matter, SRAM is the biggest user of die area.

To support a Forth interpreter, `chad` needs about 1.2K of code space.
It would be nice to support 0.4K of applet space and 0.4K of user code.
This brings the minimum code space requirement to 2K (32 Kb).
Adding 1K of 24-bit data RAM adds 24 Kb for a total of 56 Kb of SRAM.
Twice that would be nice if you can get it: 112 Kb.

Free tools from eFabless work with the Sky130 process. There are RAM generators for
OpenRAM and DFFRAM, whose densities are roughly 75 and 25 Kb/mm<sup>2</sup> respectively.
The seemingly low density could have something to do with Sky130 having only 5 metal layers.
More metal layers would put the wiring for the RAM cells on top of the cells.
Said 56 Kb would be 0.75 mm<sup>2</sup>
of OpenRAM. A [test RAM](https://github.com/ShonTaware/SRAM_SKY130) had
an access time of less than 2.5ns using Google SkyWater SKY130 PDKs and
OpenRAM memory complier.

SRAM dominates the design, so 0.75 mm<sup>2</sup> of RAM should allow an ASIC in
a 48-pin package.

The preferred 112 Kb of SRAM would need more area, and let's add some margin
and say the design needs 2.5 mm<sup>2</sup>. A pad ring with 60 I/Os (15 on a side)
and 4 power pads would fit in a 64-pin package, have an active area of 2.8 mm<sup>2</sup>,
and have dicing lanes on a 2.37mm pitch.
About 5K dice at $3K per 8" wafer is a die cost of $0.60.

## Packages

A rule of thumb for IC packaging is a penny a pin, which means packaging dominates
chip cost up to about 64 pins.

A 64-pin package such as 64-LFQFP (10x10) or 64-QFN (9x9) seems like a good
target package for an ASIC. 

A staggered pad ring would make sense with higher pin counts than 100.
Such a dual pad ring would add 1.2mm to a core width of 1.8mm for a $1.00 die
that doesn't get pad-limited until 160 pads. 
The same sized die with a single pad ring would support 100 pads.

Higher pin counts like these usually use Flip Chip, which uses a grid of solder bumps
to mount the die to a substrate that breaks out into a FCBGA.

## ECC

Hamming(26,31) can correct single-bit errors on data words as wide as 26-bit.
Code memory can use 32-bit words with 6 parity bits to ECC code RAM.
A 2:1 multiplexer would split the corrected data into 16-bit halves.

## Multicore

Multicore computers can do things faster, but why? Custom hardware is much better.
The value proposition of multiple cores is safety-critical systems.
You would have a supervisor core and a user core.

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

## SPI flash power consumption

SPI flash should be run at 30 MHz due to I/O pad limitations.
The power dissipation of QSPI would be equivalent to three wires at 30 MHz.
Allowing 20pF per wire at 1.8V, this is about 6 mW of power dissipation.
The read current of a AT25XE041B is about 4 mW at 30 MHz.
