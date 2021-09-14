# iCESugar-Pro

The [iCESugar-Pro] (https://github.com/wuxx/icesugar-pro) is by
[Muse Lab] (https://muselab-tech.aliexpress.com/).
It's a SODIMM module with on-board Lattice FPGA
(LFE5U-25), SDRAM, SPI flash, uSD slot, and iCELink USB interface.
The USB-C is set up to drag-and-drop bitstreams.
It also supports a UART.
On-board 25 MHz oscillator, RGB LED, and voltage regulators round out the board.
It's a nice way to prototype FPGA-based systems.
`chad` can be controlled through the on-module USB CDC UART.

The module itself costs $47 on Alibaba.
An extra $13 buys a breakout board with SODIMM-200 socket and a couple of connectors.
These connectors are:

- Six 2x15 0.1" headers, not populated.
- USB-C with iCELink and pogo pins.
- HDMI connector.

The breakout board does not have a part number or manufacturer ID on it,
but it's from the [Colorlight i5]
(https://github.com/wuxx/Colorlight-FPGA-Projects#ext-board) project.

This project only needs the iCESugar-Pro v1.3 module.
Once it's programmed, you can access Forth through a terminal.

The flash is a Winbond W25Q256JV. It comes with the QE bit set by default.
It's way oversized: 256 Mb is 32 MB, or a 25-bit address.
The FPGA bitstream only needs 5.5 Mb for a bitstream, or 11 Mb for dual-boot.
To accommodate dual-boot and software write protect of the bitstreams,
BOOTBLOCK is 32 (address 200000h).
A smaller, 32Mb (4 MB) flash could be substituted.

The W25Q256JVEIM has a DigiKey price of $2.40 on a 4K reel.
SPI NOR flash price scales with capacity at this size.
1Gb costs four times as much.
The $2.40 price point brings 4-byte addressing into the real world,
so flash controller code should account for it.

The demo uses P2 on the Ext Board, whose schematic uses funky pin numbering
for the dual row headers and has ball numbers that don't match the iCESugar-Pro.

On P2, 5 input switches are on odd pins (5,7,9,11,13) and 5 outputs are on even pins
(6,8,10,12,14). These pins correspond to SODIMM pins and FPGA balls as follows:

| P2 pin | ExtNet  | SODOMM pin | ProNet | FPGA pin |
|--------|---------|------------|--------|----------|
| 5      | PR20D   | 49         | PT35B  | B8       |
| 7      | PR44D   | 57         | PT27B  | B7       |
| 9      | PR35D   | 61         | PT22B  | B6       |
| 11     | PR32B   | 65         | PT15B  | B5       |
| 13     | PR47A   | 69         | PT11B  | B4       |
| 6      | PR47C   | 41         | PT29B  | A8       |
| 8      | PR2A    | 51         | PT29A  | A7       |
| 10     | PR44B   | 59         | PT18B  | A6       |
| 12     | PR32D   | 63         | PT18A  | A5       |
| 14     | PR47D   | 67         | PT6B   | A4       |

The Lattice Diamond project uses the files in the `verilog/rtl` folder and this folder.
Use Synplicity Pro for the synthesis engine.
The `.bit` file (already built) can be programmed into the board by drag-and-drop.
You can see that it's programmed by opening a serial terminal at 1MBPS and
pressing the reset button. A `[` will appear.

At this point, the application flash is blank and needs to be loaded with Forth.
Use the ISP utility in `/bin`.

# USB-C

The on-module USB-C is very convenient. It makes it very easy to load a bitstream.
The UART emulation is a little slow. Even at 1 MBPS, sometimes iCELink can't keep up.
You can get a buffer overflow with `words` or `dump`.
It spits out an error message but it recovers okay.

As a module for a real product, it's a little hobbled.
Without the USB-C, JTAG is only accessible through a row of pads.
You would want a better USB-UART bridge, but that new USB would need pogo pins if
JTAG access is needed.
That might be a feature. The on-board USB-C could be limited to loading bitstreams
and not for user access.

