# Key Cutter

## Using a serial ports

`key.c` XORs a boot file with a pseudorandom keystream.
The stream cipher implements the `gecko` algorithm, which is similar to LIZARD.

### Usage

key in_filename out_filename keyhex keyID <options>

- in_filename, chad boot file in plaintext format
- out_filename, chad boot file in keystream format
- keyhex, 56-bit key in hex format
- keyID, 8-bit ID byte in hex format
- options: bit 0: save output in hex format instead of binary

The chad boot file is used by the isp utility to program the SPI flash.
The ISP utility will check the file's keyID to make sure it matches the hardware's key.
