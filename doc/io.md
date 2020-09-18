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

See the `iomap.c` file for implementation details.

## I/O hardware
 
Since I/O (and memory) read/write sends a strobe, hardware can drop the
processor's `CKE` line (or gate off the clock) if it needs to wait,
as long as the strobe instruction is followed by a `nop`.
This would come in handy for waiting for I/O processors to finish.
 