# Flash Memory

Flash memory is not fast.
Most CPUs have hardware that keeps the most-used data in cache.
Why not manage that in code?

The chad processor has code and data memories made from high speed RAM.
You don't want physically large memories.
The bigger a RAM is, the slower and more expensive.
No, keep them small and manage flash in a way that pulls in features
when they are needed.

SPI flash is cheap and plentiful. Those things are everywhere.
They come in an 8-pin package, transfer 4 bits per clock, and can be clocked
at over 100 MHz.

The fundamental unit of SPI flash is the 256-byte page.
It's a simple enough abstraction. On-chip flash could be adapted to it.
A 16-bit cell will address 16M bytes of flash.
You have to erase a 4K sector before writing it.
The basic primitives for writing to flash use a 256-byte page buffer:

- `fwall` *( sector magic -- )* Set the first writable 4K flash sector.
*magic* works like a PIN number.
- `fpage` *( -- u-addr )* Address of the current page number.
- `fidx` *( -- c-addr )* Address of an 8-bit index into the page buffer.
- `fnew` *( sector -- )* Set the flash page to sector*16, idx to 0,
and erase the 4K sector.
- `fc,` *( c -- )* Append a byte to the page buffer. If the page is full,
write the page to flash. If it's the first page in a sector, erase it first.
- `fw,` *( w -- )* Append a 16-bit word to the page buffer in little-endian order.
- `fflush` *( -- )* Write the page buffer even if it's not full.
- `fbuf` *( -- a-addr )* Returns the address of the page buffer.
- `page>` *( u a-addr -- ior )** 
Read flash page u into memory at *a-addr*.
If u is not an available page, *ior* is -79, else 0. 
- `>page` *( u a-addr -- ior )** 
Write flash page u from memory at *a-addr*.
If u is not an available page, *ior* is -79.
If u can't been written, *ior* is -78, else 0.
- `ferase` *( sector -- ior )** 
Erase a 4K sector if it's not write protected.

## Notes on primitives

\[1] `fwall` *( page magic -- )* is a write-protect feature. You don't want to
inadvertently change it, so it needs a *magic* parameter to enable it.
Some page numbers are unavailable. 
If *page* is out of range or *magic* is wrong, nothing changes.
The proposed value for *magic* is 27182.
Flash pages below the wall are write protected.

Write protected RAM would be a "nice-to-have". 
This should be in I/O space, protected by enable and disable registers.
The wall should use such a register.
That would also make it accessible to the flash controller.

\[2] `fnew` *( sector -- )* is how you start loading a new 4K sector with data.
`fc,` *( c -- )* will append bytes for as long as you want, automatically
handling page programming and sector erase. Afterwards, use `fflush` to
write whatever remains in the page buffer.

\[3] `fbuf` *( -- a-addr )* is the address of the page buffer. You can assign it to anywhere in RAM you want. For example:

```
$200 fbuf !		\ the page working buffer is now at 200h.
0 fidx c!		\ reset the page buffer
```

This would be useful when compiling code to run at a particular address,
in this case 200h.
Control structures need to be able to resolve jump addresses.
`if` and `then` would use `fbuf` and `fidx` to compile.
To run that code, you would read into code memory and then call it.

## Implementation

Flash transfer to and from memory can be done by either software or hardware.
To keep it simple, it's done with software in ROM. A SPI port is in the I/O space.
The simulator models a simple SPI flash.
For other kinds of flash, such as on-chip, change the flash simulator.

Having a Forth kernel in masked ROM is very area-efficient.
You can have a lot of code in little space.
Masked ROM is a little slow compared to RAM.
Maybe it takes 2 or 3 cycles to settle.
No problem, just use a very wide word and mux the output down to 16-bit.
If the very wide word changes address, assert the HOLD line on the CPU
to let it settle.

## Compiling code to flash

The CPU has access to code memory through the flash.
You can compile code to data space, write that data to flash,
load it back into code space, and run it.

The dictionary pointer used by the compiler starts at the beginning of target
code space. The compiler accounts for the difference between the target
address and the code address in data memory.
Once finished, you write that data to flash.

The trick is to encapsulate external code such that calling it loads it
into memory for you. These are just ideas. I haven't tried it in practice.

