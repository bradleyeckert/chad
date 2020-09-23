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

## Streams

The SPI flash is stream-oriented, so generic `open-stream` and `close-stream`
are used to manage it:

- `open-stream` *( addr_lo addr_hi mode -- *)
- `close-stream` *( -- )*

`addr_lo` the lower 16 bits of the byte address. `addr_hi` is the upper bits.
`mode` is the kind of stream to open. `mode` has several bitfields:

- mode\[0] = direction: `0` = read, `1` = write
- mode\[2:1] = size: `00` = 8-bit, `01` = 16-bit, other=reserved
- mode\[4:3] = device ID: `00` = SPI flash
- mode\[10:5] = device rate n: SCLK = sysclk / 2\*(n+1).

This is enough to support a SPI bus with up to 4 devices on it and multiple SCLK
frequencies.

What happens if you want to open a stream while in another stream?
The easiest option is to close the stream and open the other one.
The current status of the stream should be readable so it can be restored
if you need to pick up where you left off.

## Write protection

Write protection can be managed by programming non-volatile status register
bits. This can be done by an app running on a host computer along with a
minimal bootloader that provides low level SPI flash transfers.

The status register needn't be placed in OTP mode since complete bricking
isn't possible. If the bootloader can be talked to, the flash can be reloaded
from a USB UART (etc.).

If you're wondering how a malicious virus can brick a motherboard, one way is
to set the OTP bits in the status register after infecting the BIOS.
This is a good reason to make the bootloader hard to get into.

## Primitives

The proposed primitives for writing to and reading from flash are:

- `stream-handle` *( -- a-addr )* Pointer to a 3-cell handle for the stream.
- `open-stream` *( addr_lo addr_hi mode -- *) Open a stream.
- `close-stream` *( -- )* Close the stream.
- `resume-stream` *( -- )* Open the stream where it closed.
- `>s` *( x -- )* Write x to stream, size depends on mode.
- `s>` *( -- x )* Read x from stream, size depends on mode.
- `dm>s` *( addr u -- )* Write `u` 16-bit words from data memory to stream.
- `s>dm` *( addr u -- )* Read `u` 16-bit words from stream to data memory.
- `cm>s` *( addr u -- )* Write `u` 16-bit words from code memory to stream.
- `s>cm` *( addr u -- )* Read `u` 16-bit words from stream to code memory.

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
- `rate` sets the SPI clock rate `div` = T\[10:5].

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

The `rate` register sets the SPI clock rate `div` = T\[10:5] and
a chip select decoder T\[4:3]. 
It selects both the SCLK frequency and the CS line to use,
so you can have multiple SPI devices on the same SPI bus.
For example:

- SPI NOR flash
- SPI NAND flash
- SPI SRAM
- Output port expansion: 74HC595s, etc.
