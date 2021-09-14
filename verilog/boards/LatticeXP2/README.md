# Test Results

This project is for a Brevia 2 board, with LFXP2-5 FPGA.

## Lattice XP2: OK

No problems synthesizing the project and programming it into the FPGA's internal
flash. It's much easier than with RAM-based FPGAs.

It's clocked at 50 MHz, could be 75 MHz if the PLL is used.

## Gowin GW1N-4: Nope

The Gowin LittleBee starter kit boards also have a 50 MHz oscillator.
Same code should run on a DK-START-GW1N4 board.
This board has a FT2232HL for JTAG. It doesn't connect the second port to the FPGA.
Pins 38 and 39 can be soldered since U5 is TQFP.
J9 pins 3 and 4 can be TX and RX pins for the UART.

To avoid having to solder such tiny wires, a FTDI cable (TTL-232RG-VSW3V3-WE)
can be plugged onto J9 header pins:

| J9pin | PCB net | Wire Name | Wire Color | Pin |
|-------|---------|-----------|------------|-----|
| 1     | 3.3V    | VCC       | red        |     |
| 2     | GND     | GND       | black      |     |
| 3     | H_B_IO1 | RXD       | orange     | 130 |
| 4     | H_B_IO2 | TXD       | yellow     | 129 |

The UART is dead on arrival. Don't know why.
