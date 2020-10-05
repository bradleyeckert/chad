# SPI flash interface

The `spif` SPI flash controller loads code and data memory at boot time.
The controller contains inferred single-port RAM for code and data spaces.
Generics specify the sizes of memory.
It also has an I/O space.
These memory and I/O spaces connect to the ports of a J1 (etc.) CPU.

The design intent here was:

- Ease of inclusion in ASICs
- Flexibility of interfaces
- Hardware support of ISP

Making an ASIC is expensive in terms of time and cost.
To de-risk, code memory should be RAM.
Another reason for RAM-based code space is speed. ROM is slower.
4K bytes of code RAM would be 0.2 mm2 in a 180nm process,
or 0.8mm2 in a 350nm process. Either way the chip is probably pad-limited.

ISP is possible using a cheap ($0.30) USB UART chip, the CH330N.

FPGAs that boot from SPI flash are usually programmed by using another 
controller connected to the SPI flash.
Lattice and Efinix use a FTDI chip on their evaluation boards to program
the flash. A little extra logic (like a 74VHC4051AFT 2:1 mux) could switch
the FT232H between the SPI flash and a 4-wire "FSI UART".
This would supply a nice ISP/debug/streaming port at a cost of maybe $4 above
the super cheap CH330N solution. That might justify using a more expensive
flash-based FPGA such as an Intel MAX10 or a Gowin GW1N.

## Parameters (aka generics)

- CODE_SIZE, log2 of # of 16-bit instruction words in code RAM
- DWIDTH, Word size of data memory
- DATA_SIZE, log2 of # of cells in data RAM
- BASEBLOCK: Which 64KB sector to start user flash at.
Allows room for FPGA bitstream if used.
- PRODUCT_ID0: First product ID byte, user defined.
- PRODUCT_ID1: Second product ID byte, user defined.
- UART_RATE_POR: Default baud rate divisor for UART, Baud = Fclk / this.

## Ports

To keep the J1 naming conventions, the ports on the J1 side are:

| Name     | Dir | Bits | Usage                           |
|----------|:---:|-----:|---------------------------------|
| io_rd    | in  | 1    | I/O read strobe: get io_din     |
| io_wr    | in  | 1    | I/O write strobe: register din  |
| mem_addr | in  | 16   | Data memory address             |
| mem_wr   | in  | 1    | Data memory write enable        |
| mem_rd   | in  | 1    | Data memory read enable         |
| din      | in  | 18   | Data memory (and I/O) in        |
| mem_dout | out | 18   | Data memory out                 |
| io_dout  | out | 18   | I/O data out                    |
| code_addr| in  | 16   | Code memory address             |
| insn     | out | 16   | Code memory data                |
| p_hold   | out | 1    | Processor hold                  |
| p_reset  | out | 1    | Processor reset                 |

A streaming byte interface is intended to connect to a host PC. This is usually
a UART. A simple protocol is used to act as a system master from the PC to:

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
| u_rate   | in  | 16   | UART baud rate                  |

Other kinds of byte streaming devices can be used with the UART port.
For example, registers in a JTAG chain or a FTDI FT232H in FSI mode.
The latter isn't cheap, but it only takes 4 pins to transfer data at
50 MBPS.

The SPI flash may be shared with a FPGA bitstream.
It may also be virtual, so low-level control is in a separate module.
The handshaking scheme for the flash is similar to that of the UART
except that receive is tied to transmit as is the case with a SPI master.
Flash ports are:

| Name     | Dir | Bits | Usage                           |
|----------|:---:|-----:|---------------------------------|
| f_ready  | in  | 1    | Ready for next byte to send     |
| f_wr     | out | 1    | Flash transmit strobe           |
| f_who    | out | 1    | Who's asking? 0=sys, 1=UART     |
| f_dout   | out | 8    | Flash transmit data             |
| f_format | out | 3    | Flash format                    |
| f_rate   | out | 4    | SPI frequency divider           |
| f_din    | in  | 8    | Flash received data             |

When the `who` signal is `1`, the flash may opt to return blank data.
This would prevent the reading of internal flash via UART ISP.
Although it's not very useful with a board-mounted SPI flash,
a flash subsystem on an ASIC could have lock bits added for security.
A locked flash could return the "Write In Progress" status as data. 

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
(0x11 and 0x13) to allow for soft flow control and 0x12 to avoid the
special case.

0x10 fills in the hole left in the character set so that all 256 codes can be
received by `spif`. `0x10 n` is interpreted as:

- 0x10 0x00 = 0x10 
- 0x10 0x01 = 0x11 
- 0x10 0x02 = 0x12 
- 0x10 0x03 = 0x13

ISP command bytes:

- `00nnnnnn` set 12-bit run length N (use two of these)
- `01xxxbpr` b=boot, p=ping, r=reset
- `10xxxxff` Write N bytes to flash using format f
- `11xxxxff` Read N bytes from flash using format f

The ISP commands are enough to erase and program the SPI flash.
When an erase or programming operation is in progress, the chip's WIP
status bit is set. The host PC polls this bit with ISP commands.

Some example ISP sequences are:

- `12 A5 5A` unlocks the ISP, enabling the ISP commands
- `12 00` locks the ISP, disabling the ISP commands
- `41 40` issues a hard reset pulse to the processor
- `42` returns 3 bytes of boilerplate data
- `00 04 81 0B 00 00 00 00 31 C1 80` reads 50 bytes from flash to the UART

## Boot Loader

At power-up, the controller loads code and data memories from flash
before releasing the processor's reset line.

The stream of bytes is interpreted to get start addresses, lengths,
memory types, etc. The stream starts at address 0 (or BASEBLOCK<<16)
using the "fast read" (0Bh) flash command. Boot loader command bytes are:

- `0xxxxmbb` = Load memory from flash, b+1 bytes/word, to code or data space
- `10rxssss` = r=reset, s=SCLK divisor
- `110xxx00` = Load dest\[7:0] with 8-bit value
- `110xxx01` = Load dest with 16-bit value (big endian)
- `110xxx10` = Load length\[7:0] with 8-bit value
- `110xxx11` = Load length with 16-bit value (big endian)
- `111xxxxx` = End bootup and start processor

The memory type is `0` for code and `1` for data when loading memories from
flash. The protocol has room for a 5-bit memory selection field, so it could
load the memories on 16 different CPU cores.

The SCLK frequency starts out at sysclk / 16 to be conservative.
At some point early on, you should include a command byte to raise the
frequency to more closely match the capability of the flash chip.
For example, `A0` sets the maximum SCLK.

## I/O space

The 3-bit address allows for 8 read and 8 write registers.

Read:

- 0: UART received byte, reading clears the `full` flag.
- 1: UART receive status: 1 = full: there is data
- 2: UART transmit status: 1 = ready: you may write to io\[0]
- 3: SPI flash result byte
- 4: Jam status: 1 = busy
- 5: Boot transfer status: 1 = loading memory from flash

Write:

- 0: UART transmit
- 2: Set UART baud rate = sysclk / N
- 3: Trigger the flash boot interpreter
- 4: Jam an ISP byte (see UART ISP protocol)

### Jamming ISP bytes

Bytes can be fed into the ISP interpreter by writing them to io\[4].
This way of using the ISP lets you control the SPI flash directly to
execute flash commands. You can set up the DMA registers, start the command,
and trigger a DMA memory load.

Make sure to poll io\[4] to wait until the jammed command has been processed.

## Synthesis results

A demo MCU with UART, SPI flash interface, 18-bit cells, 16-deep stacks
produced these synthesis results:

**Intel/Altera 10M08SCE144A7G**

- 1529 LEs (19% of chip)
- Slow 125C model: 111 MHz

**Lattice ICE5LP4K-SG48ITR**

- 1516 LUT4s (40% of chip)
- 53 MHz worst case

