# Debugging options

- `verbosity` *( u -- )* Sets the tracing options
- `see` *( <name> -- )* Disassemble a word
- `dasm` *( addr len -- )* Disassembles a section of code
- `sstep` *( addr steps -- )* Single step starting at *addr*.
- `logsteps` *( steps -- )* Number of steps to log to "output.txt"

## verbosity

There are four bit flags in the verbosity setting that control what the
interpreter prints out.

- `1` enables line printing. Each line of input text is echoed.
- `2` enables printing of each blank delimited token and its stack effects.
- `4` enables machine level instruction trace in the simulator.
- `8` tracks the maximum stack depth
- `16` prints out the source remaining after >IN.

Options `1` and `2` (or both, 1|2 = `3`) show you what's going on in the
chad interpreter (known in Forth as the QUIT loop).

Option `4` is a machine level trace.
You get a detailed output log to the terminal.
If you use it, you are probably making your code too complex.
Maybe you should re-factor or try something different.
Stackrobatics usually means you need to re-think your approach.
But it does look cool and it's an easy way to see what your code is doing
in each instruction.

## see

`see <name>` looks up a definition and disassembles it.
When the instruction matches one of the predefined Forth primitives,
it displays that Forth word instead of the packed ALU instruction.
For example,

```
ok>see s>d
s>d
166 0011              dup
167 030c          0< exit
ok>
```

`dasm` can be used to disassemble a range of code.
To disassemble all code, you could do `0 there dasm`.

## sstep

`sstep` runs the simulator one step at a time for the number of steps
or until the return stack underflows, whichever comes first.
It does this by setting bit 2 in the verbosity setting during stepping.

`4 verbosity` does the same thing.
In that mode, invoking the simulator produces a log output listing. 
Make sure you use `0 verbosity` after getting the log because it's easy
to trigger a lot more data than you want.

## logsteps

`10000 logsteps cold` dumps the first 10000 simulation steps to "output.txt".
The Verilog model, `chad.v`, has a LOGGING option that saves the same thing
to "simlog.txt". Use a file comparison tool like WinMerge to see
differences in simulation. It's best to test code before doing I/O because
I/O is where the simulations start to differ. Real world peripherals
create delays. For example, `emit` spins while waiting for the UART.

# Machine level tracing

There are various triggers you can use to instrument the code without being
overwhelmed by data.
These triggers are custom user instructions that only execute in the simulator.
The instructions are:

- `debug+` *( -- )* Turns on instruction level tracing.
- `debug-` *( -- )* Turns off instruction level tracing.
- `regs?` *( -- )* Triggers a register dump.
- `/data` *( -- )* Clears data changes.
- `data?` *( -- )* Displays all data changes since the last `/data` or `data?`.
- `stacks?` *( -- )* Triggers a stack dump.

`/data` and `data?` are used to find where data is being clobbered.
Before the first use of `data?`, use `/data` to initialize it.
Every time `data?` executes, it will display a list of changes to data space
between address 0 and DP.
