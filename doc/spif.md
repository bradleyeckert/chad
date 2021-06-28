# SPI flash interface

The `spif` SPI flash controller loads code and data memory at boot time.

The design intent here was:

- Ease of inclusion in ASICs
- Flexibility of interfaces
- Hardware support of ISP

Making an ASIC is expensive in terms of time and cost.
To de-risk, code memory should be RAM.
Another reason for RAM-based code space is speed. ROM is slower.
SPI flash is a very attractive option. You get lots of storage at low cost.
The flash chip can be put outside or inside your chip's package.
Either way, it can be probed.
So, we encrypt the flash contents and decrypt it on the fly. 

ISP of SPI flash over USB is possible using a cheap ($0.30) USB UART chip,
the CH330N, or any of a number of such parts.

## Parameters (aka generics)

- CODE_SIZE, log2 of # of 16-bit instruction words in code RAM
- WIDTH, Word size of data memory
- DATA_SIZE, log2 of # of cells in data RAM
- BASEBLOCK: Which 64KB sector to start user flash at.
Allows room for FPGA bitstream if used.
- PRODUCT_ID: Product ID for ISP, user defined.
- STWIDTH: Width of outgoing stream data.
- KEY_LENGTH: Length of boot key
- RAM_INIT: Initialize RAM by default, set to 0 for faster verification

## Ports

Let N be the cell size in bits, 16 to 32.
To keep the J1 naming conventions, the ports on the processor side are:

| Name     | Dir | Bits | Usage                           |
|----------|:---:|-----:|---------------------------------|
| io_rd    | in  | 1    | I/O read strobe: get io_din     |
| io_wr    | in  | 1    | I/O write strobe: register din  |
| mem_addr | in  | 16   | Data memory address             |
| mem_wr   | in  | 1    | Data memory write enable        |
| mem_rd   | in  | 1    | Data memory read enable         |
| din      | in  | N    | Data memory (and I/O) in        |
| io_dout  | out | N    | I/O data out                    |
| code_addr| in  | 16   | Code memory address             |
| p_hold   | out | 1    | Processor hold                  |
| p_reset  | out | 1    | Processor reset                 |

A streaming byte interface is intended to connect to a host PC. This is usually
a UART. The baud rate is not programmable so that software can't block access.
A simple protocol in hardware lets a PC:

- Hold the CPU in reset
- Control the SPI flash chip over UART
- Release the CPU's reset

UART ports are:

| Name     | Dir | Bits | Usage                           |
|----------|:---:|-----:|---------------------------------|
| u_ready  | in  | 1    | Ready for next byte to send     |
| u_wr     | out | 1    | UART transmit strobe            |
| u_dout   | out | 8    | UART transmit data              |
| u_full   | in  | 1    | UART has received a byte        |
| u_rd     | out | 1    | UART received strobe            |
| u_din    | in  | 8    | UART received data              |

Other kinds of byte streaming devices can be used with the UART port.
For example, registers in a JTAG chain or a FTDI FT232H in FSI mode.
The latter isn't cheap, but it only takes 4 pins to transfer data at
50 MBPS.

The SPI flash may be shared with a FPGA bitstream.
It may also be virtual, so low-level control is in a separate module.
The handshaking scheme for the flash is similar to that of the UART
except that receive is tied to transmit as is the case with a SPI transaction.
Flash ports are:

| Name     | Dir | Bits | Usage                           |
|----------|:---:|-----:|---------------------------------|
| f_ready  | in  | 1    | Ready for next byte to send     |
| f_wr     | out | 1    | Flash transmit strobe           |
| f_dout   | out | 8    | Flash transmit data             |
| f_format | out | 3    | Flash format                    |
| f_rate   | out | 4    | SPI frequency divider           |
| f_din    | in  | 8    | Flash received data             |

f_format is the bus format of the SPI:

- 00x = inactive (CS# = '1')
- 01x = single data rate send and receive
- 100 = dual data rate send
- 101 = dual data rate receive
- 110 = quad data rate send
- 111 = quad data rate receive

## UART ISP protocol

The power-up default is for UART characters to be mapped to I/O space.
An escape sequence activates the ISP protocol, which intercepts UART
data until the ISP exits.

The character 0x12 (^R, DC2) is reserved for the ISP protocol.
The UART presents it to `u_din` and raises `u_full` regardless of whatever
is already buffered. It may discard that. The controller will see `0x12`
and take control of the UART.

Hardware flow control, if it's used, presents a complication here.
Without a RTS to tell the sender it's okay to send the next character,
the `0x12` never shows up. The UART side is responsible for handling
that case by buffering one byte and interpreting it accordingly.

Of the 256 bytes in an 8-bit character, we avoid using XON and XOFF
(0x11 and 0x13) to allow for soft flow control in the future and
0x12 to avoid the special case.

0x10 fills in the hole left in the character set so that all 256 codes can be
received by `spif`. `0x10 n` is interpreted as:

- 0x10 0x00 = 0x10 
- 0x10 0x01 = 0x11 
- 0x10 0x02 = 0x12 
- 0x10 0x03 = 0x13

Outgoing bytes use the same scheme. Although a UART can send all 256 codes,
you might want to replace the UART with a SPI Bob or a JTAG register.
In that case, you'll need a `sync` character, which can be `12h` meaning
no data. That would be implemented in the module that replaces the UART.

ISP command bytes:

- `00nnnnnn` set 12-bit run length N (use two of these)
- `01sfgbpr` s=SPI, f=flashrate, g=gecko, b=boot, p=ping, r=reset
- `10xxxfff` Write N+1 bytes to flash using format fff
- `11xxxfff` Read N+1 bytes from flash using format fff

`01sfgbpr` detail:

- s = SPI cycle: write byte again, reading the result.
- g = Load the cypher with the new key.
- f = set flash bus rate from N. 0 is fastest.
- b = Reboot from flash.
- p = Trigger a ping. It will send boilerplate out the UART.
- r = Reset the processor.

The ISP commands are enough to erase and program the SPI flash.
When an erase or programming operation is in progress, the chip's WIP
status bit is set. The host PC polls this bit with ISP commands.

Some example ISP sequences are:

- `12 A5 5A` unlocks the ISP, enabling the ISP commands
- `12 00` locks the ISP, disabling the ISP commands
- `41 40` issues a hard reset pulse to the processor
- `42` returns 3 bytes of boilerplate data
- `00 04 81 0B 00 00 00 00 31 C1 80` reads 50 bytes from flash to the UART

### Programming time

Page programming occurs as follows:

- Program a 256-byte page sending 260 chars out the serial port.
- Poll the WIP flag via the UART, falls normally 2.5ms after programming.
- The OS (Windows etc.) inserts another 0 or 1 ms (a USB frame) of delay.
- Read back 256 bytes (260 chars) for verification.

Suppose a 256-byte program-verify sequence has 5.2ms of data transfer time
and 3.0ms of turnaround delay at 1M BPS.
That can be supported by a USB-FS bridge chip like the $0.33 CH330N.
Raising the baud rate wouldn't speed up programming much due to the delays.
Production programming of flash (if you're using much of it) would be
better done by a motherboard flasher like the Dediprog SF100.

Since serial ports are typically USB-UART interface chips, buffer sizes come
into play when the baud rate is somewhat high.
For example, a USB-FS chip like FT2232D (on the Lattice Brevia 2 board) has
a 384-byte output buffer and 256-byte input buffer.
The host PC reads from the input buffer every 1 ms, so continuous input data
is limited to a baud rate of 2.56 MBPS. The Brevia2 demo operates at 1M BPS.

The CH330N has a RTS pin that the UART interface could monitor to hold off
transmission. In the case of ISP, the occasional USB glitch can be tolerated
since pages can be re-programmed in case of bad verification.

### Ping data

A 'ping' command (0x42) sends 7 bytes out the UART:

- BASEBLOCK, first 64KB sector of user flash
- Product ID\[7:0]
- Product ID\[15:8]
- SerialNumber\[7:0] or key ID
- SerialNumber\[15:8]
- SerialNumber\[23:16]
- 0xAA, indicates a valid ping format

The SerialNumber is 0 if there is no serialization.
If you make it (and the decryption key) programmable,
it can be associated with the key through the use of a KDF so that the key
can be deduced from the serial number.

The "Product ID" (or `pid`) and BASEBLOCK are used to manage ISP.
If you build products with `chad`, you can pick your own `pid` bytes.
I charge you nothing, unlike rent-seeking bodies like USB-IF and IEEE.
Yup, numbers as free as air.
If you want to reserve your PRODUCT_ID to avoid collision with other adopters
of `chad`, add it to this list and do a pull request:

### Reserved PRODUCT ID values

- 0, Demonstration models for `chad`
- 1 to 99, Reserved for Brad Eckert's commercial projects

### Rollback attacks

The ISP is designed to be un-brickable. The programming utility checks the first
four bytes of the PING to make sure you are programming the expected device.
Encryption is built into the flash image, but today's regulatory standards often
require protection against rollback attacks.

The ISP enable command starts with `12 A5 5A` by default (see `spif.v`).
You can change the `A5 5A` to anything, so that your device only works with your
programming utility. A 16-bit key is kind of useless since it takes maybe
20 us to check a key with decent hardware.
A 45-bit key would stretch that out to 20 years.
`spif.v` should be modified for a 48-bit programming-enable key.
The `ispActive` bit should only be resolved after the whole key is received.
This is a to-do item.

To prevent rollbacks, the ISP utility would check the version number held at a fixed
address in the flash.
The ISP utility would, of course, have a hidden key.
Executables are lousy places to hide keys. An encrypted executable is possible.
The ISP utility could be written in 8th, which would then support many platforms.
8th executables support strong encryption, which would hide the key as well as whatever else.

## Boot Loader

At power-up, the controller loads code and data memories from flash
before releasing the processor's reset line.

The stream of bytes is interpreted to get start addresses, lengths,
memory types, etc. The stream starts at address 0 (or BASEBLOCK<<16)
using the "fast read" (0Bh) flash command. Boot loader command bytes are:

- `0xxxmmbb` = Load memory from flash, b+1 bytes/word, to code or data space
- `10xxssss` = Set SCLK divisor
- `110xxx00` = Load dest\[7:0] with 8-bit value
- `110xxx01` = Load dest with 16-bit value (big endian)
- `110xxx10` = Load length\[7:0] with 8-bit value
- `110xxx11` = Load length with 16-bit value (big endian)
- `111rxxxx` = End bootup and start processor, r = reset (FF keeps in reset)

The memory type is `0` for code and `1` for data when loading memories from
flash. The protocol has room for a 5-bit memory selection field, so it could
load the memories on 16 different CPU cores or various other devices.
Memory type `2` is for a user output stream.

The SCLK frequency starts out at sysclk / 16 to be conservative.
At some point early on, you should include a command byte to raise the
frequency to more closely match the capability of the flash chip.
For example, `80` sets the maximum SCLK.

## User output stream

Flash memory can be streamed to a user device without CPU intervention.
Parameter STWIDTH is the number of bits in `st_o`. It may be anything up to
the cell size. 
A `st_stb` strobe is produced when a new word is output.
Writing to register 6 also produces a stream word.

A typical use case for the stream is a TFT LCD module.
A stream of bytes or words in SPI flash can be written to the module without
processor intervention. This could be used to load bitmaps onto the screen.

## I/O space

The 4-bit address: Below 10h = registers, else Wishbone Bus.

Read:

- 0: UART received byte, reading clears the `full` flag.
- 1: UART receive status: 1 = full: there is data
- 2: UART transmit status: 1 = ready: you may write to io\[0]
- 3: SPI flash result byte
- 4: Jam status: 1 = busy
- 5: Boot transfer status: 1 = loading memory from flash
- 6: Raw clock cycle count
- 7: Upper bits of a 32-bit Wishbone Bus read if cells are less than 32-bit 
- A: Get flash read-word result, upper cell if a cell is less than 32 bits
- B: Get flash read-word result, lower cell

Write:

- 0: UART transmit
- 1: Set the address for code write
- 2: Write 16-bit instruction to code RAM and bump the address
- 3: Trigger the flash boot interpreter starting at address (n<<12) using format n\[14:12]
- 4: Jam an ISP byte (see UART ISP protocol)
- 5: Write key: key = key<<cellbits + n
- 6: Set the lower address to n\[11:0] and data size for flash read to n\[13:12]+1 bytes
- 7: Set the upper bits of the next 32-bit Wishbone Bus write
- A: Trigger flash read of next word
- B: Trigger flash read starting at address (n<<12) using format n\[14:12]

### Jamming ISP bytes

Bytes can be fed into the ISP interpreter by writing them to io\[4].
This way of using the ISP lets software control the SPI flash directly to
execute flash commands. You can set up the DMA registers, start the command,
and trigger a DMA memory load.

Make sure to poll io\[4] to wait until the jammed command has been processed.

### Wishbone Bus Alice

Since the terms *master* and *slave* are being phased out of the tech lexicon
because of wokeness run amok,
I took the liberty of replacing them with *Alice* and *Bob* respectively.
*Bob* attaches to *Alice* and then *Alice* tells *Bob* what to do, so it's easy to remember.
In SPI terminology, *mosi* and *miso* become *aobi* and *aibo*.

The I/O space starting at address 16 (byte address 32 or 64) is mapped to a
Wishbone Alice.
To handle 32-bit data when the processor cell size is less than that,
a couple of registers handle the extra bits.

There are no byte lanes in the bus, so `sel_o` is assumed high. 
Since `cyc_o` is always the same as `stb_o`, it is not duplicated.

## Sample MCU

The MCU in the `verilog` folder connects to SPI flash and a USB UART such as CH330N.
If software somehow manages to disable the ISP, a shorting block or pushbutton can
keep CS# high so the MCU bootloader sees a blank flash so that it doesn't try to
boot up. The UART then has free reign over the SPI flash for programming it.

Any synthesis tool will infer the RAMs, although some will
warn you about possible simulation mismatch. Such problems occur if you try to
read back a word that was written to the same address in the previous cycle.
That won't happen in this architecture, the way `chad` is set up.

![MCU Image](doc/mcu.png)

### Encryption

The easiest method of encryption is to use a stream cypher to
decrypt the boot stream inside of `spif` as SPI flash data is loaded.
I went ahead and put this in, adding 200 LEs to the size. Not bad.
There are some very compact stream ciphers. LIZARD is one of the smallest.
This use case didn't need the sophisticated key initialization sequence of
LIZARD, so I simplified it and named the module `gecko`.

Along with the fact that random read of code space isn't supported by hardware,
making the plaintext unavailable, attacks will likely have to be brute-force.
A large network of FPGAs could crack it if it's used as-is.
The hardware easily supports up to 120-bit keys.

A fixed key has its downsides, which
should be addressed if the design moves to ASIC.
The key could be fuse-programmable, for example.
Then the security burden moves to programming hardware, which you control.
The typical strategy for key generation is to tie the key to the product serial
number, also programmed, through a KDF (key derivation function) based on an
irreversible and compute-intensive hash.

You have the option of not using a key (setting it to 0), which makes the 
keystream also 0 so that it doesn't decrypt anything.
Just keep the SPI flash contents in plaintext.

### Synthesis results

A demo MCU with UART, SPI flash interface, 16-deep stacks, and the
`chad` processor with 24-bit cells and hardware multiplication and division
comes to about 3.5K LUT4s and 80 to 100 MHz on low-end FPGAs.
`chad` itself is pretty small. The rest of the MCU, needed to make a useful
system, uses most of those LUTs. I think they are worth it.
