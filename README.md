# chad

Welcome to deep embedded computing, where the best hardware is no hardware.
Well, minimal hardware. How does a processor in 200 lines of Verilog sound?
Pretty awful? Try pretty awesome.

It's so simple your computer will simulate it at 100 to 150 MIPS.
At that speed, it can host itself on your computer.
No need to turn the Verilog into hardware, just run the processor model
on your desktop or laptop.
That's the ideal environment for Forth, the programming language of
deep embedded computing.

Forth hardware's claim to fame is its lack of a compiler in the traditional sense.
It's both high-level and low-level, with both levels seamlessly integrated.
Forth computers execute the language directly by implementing Forth instructions
in hardware. If you disassemble code, it looks a lot like the source code.
No compiler means no compiler bugs.

Now you can build computing platforms almost without a processor.
If you have an FPGA or ASIC, there's your computer.
`chad` is the at-speed simulation model.

The C and Verilog models match as closely as possible so that the generated
flash memory image can run on either model. Although the project started as
a simple CPU, the SPI controller morphed into a central hub for handling
memory decryption, in-system-programming, and boot-from-flash. Chad is:

- Secure. Flash memory is encrypted.
- Fast. 100 MHz on a MAX10 FPGA. Single-cycle instructions.
- Efficient. Forth provides excellent semantic density.
- Low-power. In an ASIC, hardware stacks are power-efficient.
- Portable. Runs on small FPGAs but is easily ported to ASIC.
- Extensible. Really easy to customize.
- Inexpensive. $0 up-front license cost, $0 per chip, $0 maintenance fee.

The sample MCU uses an external SPI flash and external USB UART.
Green data is plaintext, red data is encrypted.

![MCU Image](doc/mcu.png)

## A self-hosting Forth for J1-style CPUs

James Bowman's seminal paper on the 
[J1 CPU](https://excamera.com/sphinx/fpga-j1.html "J1 CPU")
was presented in 2010.
At under 200 lines of Verilog, the J1 was a real breakthrough in simplicity.
It also happens to be a very powerful Forth processor.

The Chad CPU, like the J1, has excellent semantic density.
The application of the J1 was a UDP stack in a Xilinx FPGA.
The code was 70% smaller than the equivalent C on a MicroBlaze.
The code just wouldn't fit in memory, so the J1 was used instead.
Admittedly, MicroBlaze is a hog. However J1 has a lot going for it.
Calls and jumps take only a single cycle.
Often a return is combined with an ALU instruction to cause a return in
zero instructions.
It's a little freaky to watch in simulation if you're used to control flow
changes having to deal with pipelines.

Chad improves on the J1 to facilitate bigger apps.
`chad` protects your software investment by targeting a very simple but
very powerful (for its size) stack computer.
Modern desktop computers are fast enough to simulate the CPU on the order of at-speed.
It's like having a real CPU running in an FPGA, but without an FPGA.
Forth should execute the code it compiles.
Cross compiling, such as targeting ARM with code running on x86,
adds a lot of complexity which is completely unnecessary with Chad.

You can add custom functions easily. Just edit `chad.c`, `coproc.c`, and `chaddefs.h`.
Recompile and your simulated computer and its language have the new features.
Chad comes as C source. Once you compile it, you have a Forth that can extend
itself in such a way that the binaries can be output for inclusion in a SOC.
You can add code to Chad's simulation to mimic your SOC so that the PC is
the development environment.

More importantly, you aren't dependent on other people for long-term support.
The system can be understood and maintained by one person due to simplicity.

Since Chad's simulation of the CPU is its specification, which is under 200
lines of C, the processor is also called Chad.
You can specify the cell size as any width between 16 and 32 bits
(in the `config.h` file) and recompile Chad with any C compiler.

Chad's way of working isn't fully ANS compatible, which is fine.
The great thing about hosting the Forth in C is that there's not much confusion
about what the Forth does. You can look at the C source.

The main source files are:

- `main.c` Inputs the command line
- `chad.c` Simulates the CPU and implements a text interpreter
- `iomap.c` Simulates the I/O of the CPU

To try it out, compile `chad` and put it in the `forth` folder.
`cd` to the `myapp` directory and launch it with `../chad include myapp.fs`.
At the `ok>` prompt, `0 here dasm` to disassemble everything.

- `stats` lists the cycle count and maximum stack depths.
- `words` lists words.
- `see` disassembles a word.

For example:
```
ok>include forth.fs
370 instructions used
ok>25 fib .
121393 ok>stats
2792024 cycles, MaxSP=27, MaxRP=26, 155 MHz
ok>
```

The instruction rate is much less when doing I/O, so running an interpreter in
the simulator (by loading myapp.f and entering "cold") shows the cycle counter
incrementing at a much lower rate. When code is doing useful work, this isn't
a problem. The thread stays in cache.

## It's also a documentation standard.

`chad` provides a documentation system for Forth systems.
It doesn't need the ANS Forth standard, it generates a standard from source.

Your project folder has a `html` folder that contains documentation.
`chad` generates hyperlinked HTML versions of each source file
so that you can click on any word to get an explanation of what it does
and if necessary, a link to the source code of that word.
That helps you navigate Forth source code even if you're new to Forth.
The documentation is re-built each time you build your app.

The 20th Century was great and all, with its books and PDF equivalents.
We have web browsers now.

## Some interesting features of Chad

It's built for security. The ISA doesn't support random read of code memory,
which makes reverse engineering and hacking the code an exercise in chip
probing if it can even be done.
The MCU boots from SPI flash, which is encrypted using a stream cipher.
The weak spot then becomes key management: How secure are keys,
how hard can you make it to probe memory busses on the ASIC die, etc.

In-system programming (ISP) is handled by hardware state machines, not firmware.
The SPI flash controller integrates a UART and processor memories so that the
RAMs can be loaded from flash at boot time. The UART can also be used to
program flash by any host computer with a serial port.
It can also reset the processor.

The sample MCU has a Wishbone Bus Master so that you can add peripherals from
sites like OpenCores.

The interrupt system uses a style that's conducive to small stacks and Forth.
It trades a little extra interrupt latency (which you can control) for simpler
and less error-prone interrupt handling that's similar in concept to Forth's PAUSE.

## Consequences of the architecture

That arise from:

- Stacks in hardware that have limited depths
- Limited on-chip RAM
- Unlimited off-chip Flash memory

Means that it deviates from the ANS Forth model when necessary.
But it's close enough to make ANS Forth usable as a testbench.
Some of the RAM is used as a frame stack, which is used to:

- Protect the hardware stacks from overflow
- Provide local variables

The "unlimited flash" means SPI flash is very cheap, so data is kept there
whenever possible. That includes:

- Headers
- Text
- Boot code
- Paged application code (applets)

Applets remove restrictions on application size, at least where code is concerned.
Large apps may reside in flash yet still be supported by a small (and fast) code RAM
and a CPU with a limited (8K) address range.
Human-speed Forth tools are good candidates for applets so as to free up code RAM.

## Status

The "myapp" demo boots and runs in both `chad` and a Verilog simulator.
An ISP utility loads the boot file into an FPGA with SPI flash chip attached.
The FPGA boots and runs. You might call that "silicon proven".

`chad` boots and runs an app from simulated flash memory. 
A minimal SoC (MCU) in Verilog demonstrates synthesis results and
performs the following:

- `spif` clears the code and data RAMs
- `spif` loads RAMs from SPI flash (S25FL064L) using FMF model
- `chad` starts running the "myapp" demo after bootup
- The demo runs a Forth interpreter (ok> prompt) via the UART.

It's silicon-proven on Digilent's Arty A7-35T board: 100 MHz, 10% of the chip.
Here's what text rendering looks like on a TFT LCD module:

![ArtyA7 Image](doc/artyLCD.jpg)

## To-do

Applets need better cache handling. Use exceptions, which are supported in the
simulator but not used by applets yet.

The ISP utility should have the terminal code merged in.
Although it's written in C, it should be translated to Forth and 8th.

SPI should default to dual data rate mode. 
Dual rate takes 5 SPI clocks or 10 system clocks per byte.
This matches the 9 cycles per byte overhead of decryption.
QSPI doesn't add anything.
You lose the WP pin and it costs you 2 extra I/O pins.

Catch and Throw should use the features of `frame.f` to set up `catch` frames.
Maybe leave more stack space for the frame stack in data RAM.

A cooperative multitasker can likewise use `frame.f` words to move hardware
stacks to and from task buffers. This makes a context switch more unwieldy, but still
in the microsecond range.

