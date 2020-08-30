# I/O map

The Chad CPU connects to an I/O space modeled in `iomap.c`.

The `_IORD_` field in an ALU instruction strobes `io_rd`.
In the J1, input devices sit on (`mem_addr`,`io_din`).
The `T->io[T]` field in an ALU instruction strobes `io_wr`.
Output devices sit on (`mem_addr`,`dout`).
The I/O devices supported are:

- UART
- Host source data
- Header data

## Input Registers

- 0: Read next byte from keyboard stream, -1 if empty. [^1]
- 1: Terminal type: 0=Window, 1=Linux. [^2]
- 2: UART transmit ready flag (always 1 on a PC)
- 4: Read flash SPI result. Bit 8 = `busy`.

### Host Only

- 8000h: Address of source, loaded after triggering a source read. [^4]
- 8001h: Length of source in cells. [^4]
- 8002h: Header data. [^5]

## Output Registers

- 0: UART transmit dout\[7:0]. [^6]
- 4: Start a flash SPI transfer. Bit 9 = starting CS, bit 8 = ending CS.

### Host Only

- 8000h: Load source into top of data memory using delimiter in io_din\[7:0]. [^7]
- 8001h: Load source into top of data memory using delimiter in io_din\[7:0]. [^8]

## Notes:

[^1]: Either waits for a character or reports empty.
[~2]: Terminal type might not apply to cooked input: Arrow keys don't apply.
[~3]: Wait until `busy` flag is 0 before starting another SPI operation.
[~4]: Write the delimiter to 0x8000 before reading these.
[~5]: Write a selector to 0x8001 before reading this.
[~6]: Wait for (io\[2] <> 0) before writing to io\[0].
[~7]: This is how Forth code reads the interpreter's input stream.
[~8]: This is how Forth code reads the interpreter's header data.
