# Welcome to your new cult

Maybe it's time for something new.
Why not get real about what it means to be a computer programmer?
Like programming as a way of being, a creative download from the Universe.
Why isn't computer programming treated as a monastic calling?
Maybe that's where it all went wrong.
If you're up for it, you might consider...

- A monastic lifestyle, meaning:
- Celibacy, but including meditative practice.
- Living in a yoga center or other such conditioned space.
- You have to understand C well enough to see what `chad` does.

You are a blessing. A gift to God (or creation or universe or whathaveyou).
Each new day starts with you.
You create a feeling of gratitude and abundance.
It's like setting a pointer whose default setting is a kind of crappy
collective unconscious of the planet.
Nope, set that pointer every morning first thing after waking.
Take a long, deep breath, while thinking of how grateful you are to be alive
and how wonderful the possibilities of the new day are.
Upon exhaling, say "thank you". That's it.
Every morning, don't forget.
It affects your coding work greatly.
And your general attitude on life.

Perform a similar gratitude ritual upon sleeping so your brain can
do its best work while you sleep. Power naps can be great problem solvers.

If you're a coder, learn how to be a monk. Lots of resources on that.
Can't quite swing "living in a yoga center"?
You can consecrate your own space, but it will take some doing. 
The monastery guys (and gals) figured this out long ago.
Try the Isha foundation if you're secularly minded.

If you're looking for a cult leader, I'm probably not the guy.
I'm willing to learn from the legendary Charles H. Moore himself,
who didn't want to be one either. I only wrote `chad`.

If this is all just too much, stick with C.
You know, the language for writing operating systems.
Because computing had to pay the bills.
Because of that, libraries.
Because of that, it's not your code.
That's not a spiritual practice then, is it? It's business.

Which is fine, but why does everyone on the planet have an ARM processor
in their hands?
Because arms are offensive weapons.
How's everyone at each other's throats working for you?

How about waging peace?
How about we forget about ARM and its wannabes like RISC V?
They are all part of the same dying world.
It's rather poetic that Corona-virus could bring an empire built on C to its knees.
Sorry, C is not the language of peace.
It's the language of Commerce, which makes `C` such a fitting name.
If there's a mathematical function relating lines of code to body count,
the C language and its libraries wouldn't exactly come out clean.
Don't stop me, I'm on a roll.
An Admiral in the US Navy starting off this whole business had its time.
But here's the thing about planetary consciousness shifts.
You have to roll with the tide.
Stop coding for war machines.

If your code is so great, why shouldn't everyone on the planet be 
able to run it without it being hosted by
some military industrial complex derived CPU
accompanied by a ridiculously complex C tool-chain?
Building the silicon is a formality, the CPU can be simulated.
Which is fine. Did you build your code so sucky the time would matter?

No, let's get real. Let's get simple. Let's just build code.

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
Chad improves on the J1 to facilitate bigger apps.

`chad` protects your software investment by targeting a very simple but
very powerful (for its size) stack computer.
Modern desktop computers are fast enough to simulate the CPU on the order of at-speed.
Simulation speed on my desktop depends on the compiler:

- 145 MIPS on Code::Blocks 17.12 (GCC).
- 160 MIPS on Visual Studio 2019 Community Edition.

It's like having a real CPU running in an FPGA, but without an FPGA.
Forth should execute the code it compiles.
Cross compiling, such as targeting ARM with code running on x86,
adds a lot of complexity which is completely unnecessary with Chad.

You can add custom functions easily. Just edit `chad.c` and `chaddefs.h`.
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

To try it out, launch it with `chad include lib.fs`.
At the `ok>` prompt, type `0 here dasm` to disassemble everything.

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

## While we're at it, a documentation standard.

`chad` presents a documentation system for Forth systems.
It doesn't need the ANS Forth standard, it generates a standard from source.

Your project folder has a `html` folder that contains documentation.
`chad` generates hyperlinked HTML versions of each source file
so that you can click on any word to get an explanation of what it does
and if necessary, a link to the source code of that word.
That helps you navigate Forth source code even if you're new to Forth.
The documentation is re-built each time you build your app.

The 20th Century was great and all, with its books and PDF equivalents.
We have web browsers now.
