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

- `flash-wp` *( sector magic -- )* Set the first writable 4K flash sector.
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
If `sector<<16+addr` is less than `flash-wp<<12`, WREN is not issued.

## Notes on primitives

\[1] `flash-wp` *( sector magic -- )* is a write-protect feature. 
You don't want to inadvertently change it,
so it needs a *magic* parameter to enable it.
Some sector numbers are unavailable. 
If *sector* is out of range or *magic* is wrong, nothing changes.
The proposed value for *magic* is 27182.
Flash pages below flash-wp are write protected.

Two variables are used for flash-wp.
One is the inverse of the other so if they get stomped it will be
detected.

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
| 4    | `retrig` | `spitx`  |
| 5    | `result` | `format` |
| 6    |          | `rate`   |

Hardware is assumed to freeze the CPU if the relevant read or write
occurs before the SPI transfer is finished.

- `result` is data read from the flash.
- `retrig` is data read from the flash, triggering another read.
- `format` sets chip select CSN to ~T\[0] and the format to T\[3:1].
- `spitx` write triggers a SPI transfer.
- `rate` sets the SPI clock rate `div` = T\[5:0].

The format determines the width and format of the transfer:

- 000 = 8-bit SPI
- 001 = 16-bit SPI
- 100 = 8-bit QSPI mode receive
- 101 = 16-bit QSPI mode receive
- 110 = 8-bit QSPI mode transmit
- 111 = 16-bit QSPI mode transmit

## Hardware

The clock could be gated to run the SPI at the `chad` processor
frequency, but to keep it simple assume the maximum SPI clock
is half the processor clock. 
The `rate` register sets the SPI clock frequency to `sysclk/2(n+1)`.

A 16-bit shift register is the basis for the SPI.
In QSPI mode, the four I/O lines are `data`. The formats are:

- 000: 1-wire mode, MISO shifts into bit 0 and MOSI shifts out of bit 7.
- 001: 1-wire mode, MISO shifts into bit 0 and MOSI shifts out of bit 15.
- 10x: 4-wire receive, `data` is shifted into the lower 4 bits.
- 110: 4-wire transmit, `data` is driven by SR\[7:4].
- 111: 4-wire transmit, `data` is driven by SR\[15:11].

Writing to `spitx` or reading from `retrig` will trigger a SPI transfer.

The `result` is muxed from SR depending on the LSB of format:

- 0: SR\[7:0].
- 1: SR\[7:0]:SR\[15:8].

The `rate` register sets the SPI clock rate `div` = T\[5:0] and
a chip select decoder T\[7:6]. 
It selects both the SCLK frequency and the CS line to use,
so you can have multiple SPI devices on the same SPI bus.
For example:

- SPI flash
- SPI SRAM
- Output port expansion: 74HC595s, etc.
