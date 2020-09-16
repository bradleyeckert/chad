# Flash Memory

Flash memory is not fast.
Most CPUs have hardware that keeps the most-used data in cache.
Why not manage that in code?

The `chad` processor has code and data memories made from high speed RAM.
You don't want physically large memories.
The bigger a RAM is, the slower and more expensive.
No, keep them small and manage flash in a way that pulls in features
when they are needed.

SPI flash is cheap and plentiful. Those things are everywhere.
They come in an 8-pin package, transfer 4 bits per clock, and can be clocked
at over 100 MHz.

SPI flash is a simple enough abstraction.
On-chip flash could be adapted to it.
The basic primitives for writing to and reading from flash are:

- `fwall` *( sector magic -- )* Set the first writable 4K flash sector.
*magic* works like a PIN number.
- `sector` *( -- a-addr )* Variable for the current flash sector number.
- `fp` *( -- a-addr )* Variable for a 16-bit index into the 64 KB sector.
- `write[` *( addr -- )* Set `fp` = `addr`.
If `addr` is at a 4KB boundary , erase the sector.
Start a page write at address `sector<<16+addr`. 
- `>f` *( c -- )* Append a byte to flash and bump `fp`.
- `]write` *( -- )* End the page program command.
- `read[` *( addr -- )* Start reading flash at address `sector<<16+addr`.
- `f>` *( -- c )* Read the next byte from flash.
- `]read` *( -- )* End the read command.

The `>f` sequence is:
 
- if `fp[7:0]` is 0, end the page program command.
- if `fp[11:0]` is 0, erase the next 4KB sector.
- if `fp[7:0]` is 0, start a new page program command.
- if `fp[15:0]` is 0, clear `fp` and bump `sector`.

Flash write issues a WREN when starting and a WRDI when finished.
If `sector<<16+addr` is less than `fwall<<12`, WREN is not issued.

## Notes on primitives

\[1] `fwall` *( sector magic -- )* is a write-protect feature. 
You don't want to inadvertently change it,
so it needs a *magic* parameter to enable it.
Some page numbers are unavailable. 
If *sector* is out of range or *magic* is wrong, nothing changes.
The proposed value for *magic* is 27182.
Flash pages below the wall are write protected.

Write protected RAM for the wall would be a "nice-to-have". 
This should be in I/O space, protected by enable and disable registers.
The wall should use such a register.
That would also make it accessible to an external flash controller.

\[2] `write[` *( addr -- )* Can trigger a -81 error if the sector
is not writable, or just do nothing so the flash chip ignores the data.

## Implementation

Flash transfer to and from memory can be done by either software or hardware.
To keep it simple, it's done with software in ROM. A SPI port is in the I/O space.
The simulator models a simple SPI flash.
For other kinds of flash, such as on-chip,
change the flash simulator `flash.c`.

I/O space of SPI flash simulator:

| Addr | Read     | Write    |
| ---- | -------- | -------- |
| 4    | `busy`   | `format` |
| 5    | `result` | `spi`    |

- `busy` = `1` if the SPI is busy, `0` otherwise.
- `result` = `1` is the SPI data read from the flash.
- `format` sets chip select CSN to T\[0] and the format to T\[3:2].
- `spi` write triggers a SPI transfer.

The format determines the width and format of the transfer:

- 00 = 8-bit old school SPI
- 01 = 8-bit QSPI mode transmit
- 10 = 8-bit QSPI mode receive
- 11 = 16-bit QSPI mode receive

The simulator currently supports only format 00.
