# Opinions on Verilog

To be taken with a grain of salt.

My first exposure to discrete event simulation was in about 2000.
I used Forth, Win32forth at the time, to model a Forth CPU.
Then I took a couple of VHDL classes in 2002 at the local university,
beginning my long road to perdition. 

I stuck with VHDL for a good long time. Why would I switch to Verilog?
In 2020, I finally tried Verilog.
I decided I wasn't going to use a language developed by the
Department of Defense.
A language made by grunts for grunts has a certain roguish charm,
but my ideas about life changed.

Using Verilog is a lot like using VHDL, since I prefer RTL coding.
But how does it handle? As it turns out, nicer than expected.

## What I like about Verilog

- Registers and wires are declared as such, not inferred from signals.
- You can declare regs and wires near where you use them.
- The syntax is much more concise.
- Case sensitivity.
- File operations are much easier.

## What I like about VHDL

- Enumerated states. Okay, SV has that too. I like to see FSM state named in the simulation waveform.
- In simulation it's easier to not think about the differences between registers and wires. But that's a style thing.
- Stricter typing.

## My Verilog style 

It seems there are all kinds of ways people use Verilog.
You can't just copy from examples on the Internet because a lot of those
examples are garbage. Although my examples could also be garbage.

I like to declare the port list in a VHDL-ish style, including "wire" and "reg"
keywords to show up-front what kind of signals the ports are.
Declaring a signal "output reg" makes it clear that it's a registered output,
which is good design practice.

I usually declare regs and wires as far down in the file as possible,
near where they are first used. This makes them a lot easier to find.

I use 8-character tabs and 2-character indents.
