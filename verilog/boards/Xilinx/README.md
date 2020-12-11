# Chad on the Digilent Arty A7 board

This project runs Forth on the A7-35T board, available for $129.00 from Digilent.
You also need a Micro USB cable and a 12V (2.1mm/5.5mm barrel plug) power supply.

Xilinx makes it easy to add user data to the input file. 
The `myapp` project generates `myappraw.bin`, which is the boot code and dictionary.
The board's flash part is `s25fl128sxxxxxx0-spi-x1_x2_x4`.
With the implementation open, the bitstream properties has additional options you can set
such as the SCLK speed, SPI width, etc.

Set your serial terminal to 3M baud, echo locally.
