# I/O map

The Chad CPU connects to an I/O space modeled in `iomap.c`.

The `_IORD_` field in an ALU instruction strobes `io_rd`.
In the J1, input devices sit on (`mem_addr`,`io_din`).
The `T->io[T]` field in an ALU instruction strobes `io_wr`.
Output devices sit on (`mem_addr`,`dout`).

See the `iomap.c` file for implementation details.

A Wishbone bus is implemented by `spif.v` to connect to user peripherals.

See the `spif` documentation for register details.
 