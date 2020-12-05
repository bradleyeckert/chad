# Sample Application

This sample Forth app loads Forth code including a text interpreter (`quit` loop).

It saves the output in several formats:

- `.bin` is a binary image of the SPI flash with 16-byte boilerplate
- `.txt` is the same image (sans boilerplate) in hex format for simulation
- HTML documentation folder

`chad` can boot and run the `.bin` file.
If you program the data into a SPI flash, the synthesized MCU will boot and run it.

If you look at the `.bin` file, you'll see several sections:

- The 16-byte boilerplate: base sector, length, CRC32, and product ID
- Boot code that initializes code and data memories
- Dictionary headers
- Text strings
- Font bitmap data (in plaintext)

