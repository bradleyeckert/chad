# Test results

I bought a Xyloni board from Efinix, through Digikey.
It has a T8F81C2 chip on it, which is a chip scale package with very tiny balls.
The design synthesized to 36 MHz on that chip.
The Efinity tool uses XML as the description language for top level interconnect to
the HDL core design rather than inferring from HDL.

The Efinity (2020.2) programmer uses `libusb`, a cross-platform USB API, to control the board's
FTDI chip. I needed to change the driver using `zadig`, which got its underlying Python
to talk to the board. I programmed the bitstream into the board's SPI flash.

But, then the FTDI chip would not enumerate as a serial port.
I uninstalled the driver a couple of times and was able to get the COM ports back.
Naturally, it broke the programmer. You can't have one driver for UART and libusb.

The Efinity programmer doesn't have facility for adding user data to the programming file.
No problem, I didn't need it. If I were to use Efinix FPGAs in production, I would not use
their programmer. I would use a separate SPI flashing dongle such as FT232H cable or Dediprog SF600.

Anyway, back to the COM port. Now I can receive serial data from the Xyloni board but not
send to it. Or so it seems, since the same code works on other FPGA boards.
Maybe I did something wrong, but the pain level turned me off to troubleshooting.

So, the experiment didn't work. Efinix has come a very long way in a very short time.
They will undoubtedly improve their tools. When their 16nm parts hit the supply chain,
Efinix will be a serious player in the low end FPGA business.

## Plan B

The T20 eval board is okay if a separate FTDI cable (or other COM adapter) provides the UART.

The T13 and T20 in 0.8mm BGA (256-ball) are good low-cost FPGAs.
The SPI flash can be programmed using FTDI SPI so that the configuration flash can be
programmed without knowing anything about the FPGA.

The MCU runs much faster in a T13/C3 than in a T8/C2: 75 MHz on a T13F256C3.
The T13F256C4 can safely run at 80 MHz.
It has 195 GPIOs available.


