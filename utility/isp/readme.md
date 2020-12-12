# In System Programming

## Using a serial port

`isp.c` programs the target's SPI flash using a UART.
Serial communication uses a cross-platform library that has a GPL license. Thanks, Teunis!
The library numbers ports starting from 0, so `COM4` would be `3`.

`isp.c` works but isn't polished. It was tested with Code::Blocks on Windows.

NOTE: It should be broken by a change in the `ping` packet and translation of outgoing 
10h-13h chars. Needs to be fixed.

`term.c` is a terminal emulator. It redirects stdin and stdout to the COM port.
You're supposed to be able to use pipes for this, but Windows is funny about that.
Running `term` in ConEmu provides a decent terminal.

## Command Line of isp.c

isp filename port# \[baud]

- filename is a file path without embedded spaces.
- port# is the COM port number.
- baud is an optional baud rate. Default = 1MBPS.

The input file is the SPI flash data with a 16-byte preamble, created by chad's "save-flash".
Multi-byte numbers are little-endian.

- "chad", 4-byte file type identifier
- BASEBLOCK, 1-byte first 64KB sector of user flash
- KEY_ID, 1-byte keyID
- PRODUCT_ID, 2-byte product ID
- Length, 4-byte number of bytes (n) in the data
- CRC32, 4-byte CRC of the data
- Data, n-byte boot data to be placed at address (BASEBLOCK<<16) in SPI flash

### USB-UART chips

- CH330N or CH340, max baud rate = 2M
- MCP2200, max baud rate = 1M
- CY7C65213A, max baud rate = 3M
- CP2102N, max baud rate = 3M
- FT230X, max baud rate = 3M
- FT232H, max baud rate = 12M

## Command Line of term.c

term port# \[baud]

- port# is the COM port number. In Windows, subtract 1.
- baud is an optional baud rate. Default = 3MBPS.

`term` by itself lists the eligible port numbers.
To compile an executable, include `term.c`, `rs232.c`, and `rs232.h`.

