# chad
A self-hosting Forth for J1-style CPUs

James Bowman's seminal paper on the J1 CPU was presented in 2010.
At under 200 lines of Verilog, the J1 was a real breakthrough in simplicity.
It also happens to be a very powerful Forth processor.
Chad tweaks the J1, but it's very similar.

Chad protects your software investment by targeting Verilog
(or its VHDL equivalent) directly.
Modern computers are fast enough to simulate the CPU on the order of at-speed.
Forth should execute the code it compiles.
Cross compiling, such as targeting ARM with code running on x86,
adds a lot of complexity which is completely unnecessary with Chad.

You can add your functions easily. Just edit `chad.c` and `chaddefs.h`.
Recompile and your simulated computer and its language have the new features.
Chad comes as C source. Once you compile it, you have a Forth that can extend
itself in such a way that the binaries can be output for inclusion in a SOC.
You can add code to Chad's simulation to mimic your SOC so that the PC is
the development environment.

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

To try it out, launch it with `chad include forth.f`.
At the `ok>` prompt type `0 here dasm` to disassemble everything.
