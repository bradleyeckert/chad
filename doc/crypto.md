# Flash Memory Encryption

An SPI flash is easily read out using a clip-on probe and programming adapter.
A flash die bonded out in an ASIC package can be probed with some extra effort.
Encrypting the application protects it from prying eyes.
Such paranoia is justified if you look at the speed with which smart cards,
games and PC apps are cracked.
Encrypting the SPI flash contents is useful, perhaps mandatory, because it
protects against tampering and reverse engineering.
It's an important part of any risk management plan.

Even on-chip flash isn't safe from microprobing.
Encrypting the flash memory simplifies security hardening of a chip design
since there are more regions that you don't care about being probed.
You don't care if the flash and its ATE support can be accessed via JTAG.

Chad uses compact hardware to decrypt data coming from the SPI flash.
It uses a stream cypher that's a derivative of LIZARD.
It takes 48 clock cycles to initialize and then provides a new pseudorandom
byte every 8 clocks.
So, with a 200 MHz clock, an on-chip (or QSPI) flash would be read at 25 MBPS.

The multi-cell keys are `bkey` for the boot record and `tkey` for text in flash.
If non-zero, `bkey` encrypts the boot record when it gets written to flash memory.
Hardware that instantiates `spif.v` must use the same key in its parameters.
Boot hardware uses this key to decrypt code and data stored at the beginning of
flash (or beginning of user space if an FPGA bitstream starts at 0) before
storing it to code RAM or data RAM.

The keys are 0 by default, which turns off encryption so that the flash memory
image is in plaintext.

## Boot Key

The boot record key, referred to as `bkey`, is 56 bits by default. It is used once,
at bootup. The stream cypher key's reset value is `bkey`. 
Although the key is somewhat diffused, it isn't thoroughly diffused because that 
would require more clock cycles than I want to spend.
So, don't use simple keys such as `1` in a real application.
Generate a 56-bit random number and use that.

`+bkey` *( n -- )* shifts one cell into `bkey` from the right:
bkey = (bkey << cellbits) + n. Use as many as you need to populate the key.
For example, to set a `bkey` of 0x12345687654321 using 16-bit cells you would use:

`$12 +bkey  $3456 +bkey  $8765 +bkey  $4321 +bkey`

## Text Key

The text key, referred to as `tkey`, is 56 bits by default. It is used every time
a string or header record is read from flash. The actual cypher key concatenates
`tkey` and the address of the text. `tkey` *( -- ud )* is a word that behaves as a
double constant. `/text` synchronizes the keystream by loading it and the address
into the cypher for a total key length of 3 cells or 56 bits whichever is smaller.

`+tkey` *( n -- )* shifts one cell into `tkey` from the right.

`tkey` is a software feature. Hardware instantiation doesn't involve it.
