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
It uses a stream cipher that's a derivative of LIZARD. I call it `gecko`.
It takes 48 clock cycles to initialize and then provides a new pseudorandom
byte every 8 clocks.
So, with a 200 MHz clock, an on-chip (or QSPI) flash would be read at 25 MBPS.

The encryption hardware is limited to SPI flash decryption. It's not set up to
encrypt messages, so it's not hardened for that use case. It also allows
a `0` key, which sets the keystream to all zeros.
That makes it effectively useless for encryption of user data,
which means it is not under 5A002.a of US export control regulations.
Key length doesn't matter.
Gecko can take a key length of up to 15 bytes.

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
at bootup. The stream cipher key's reset value is `bkey`. 
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
a string or header record is read from flash. The actual cipher key concatenates
`tkey` and the address of the text. `tkey` *( -- ud )* is a word that behaves as a
double constant. `/text` synchronizes the keystream by loading it and the address
into the cipher for a total key length of 3 cells or 56 bits whichever is smaller.

`+tkey` *( n -- )* shifts one cell into `tkey` from the right.

`tkey` is a software feature. Hardware instantiation doesn't involve it.

## FPGA-based systems

Over-building is a concern with RAM-based FPGAs. Most modern RAM-based FPGAs have
fuses to encrypt the bitstream. You could compile a reduced feature set version
of your application to be used for board manufacturing.
Then, the CM (or SPI flash vendor) can leak it into the wild without serious consequences.
It works with blank-key FPGAs enough to test the board.
Then, at your site, you program the crypto fuses in the FPGAs and load the full app into flash.

Suppose you don't trust fuses. Maybe planned obsolescence is a solution to that.
At some point you stop supporting old hardware, so there's no incentive to clone it.
Some FPGAs store keys in battery-backed RAM, for the truly paranoid.

The other option is to use Flash-based FPGAs. Is flash readback protection more secure than fuses?
Who knows?

## Boot security standards compliance

Boot image cryptographic signing is starting to be mandated by standards.
The `spif` bootloader executes commands (streamed from SPI flash) to load data into on-chip RAM
while decrypting it. To enhance security, on-chip code RAM is not randomly readable.

Stream ciphers, where plaintext bits are XORed with a cipher bit stream, can be
very secure if used properly:

- Keys must never be used twice
- Valid decryption should never be relied on to indicate authenticity

This means that keys should be programmable (in an ASIC) or changed often (in an FPGA)
by changing the bitstream between PCB lots.

Cryptographic signing is handled by a CRC of plaintext. The signature is itself encrypted
using the boot key. If the boot code is to be hacked, a brute force search for the CRC will be
needed to make the hacked code boot. This search is restricted by the boot time, which is on the
order of milliseconds. The impracticality of messing with the code isn't worth the effort it
would take to target just a few PCBs at the most.

UART-based ISP is a replacement for JTAG. Since UART connectivity via cable is a usual feature,
the ISP feature should be able to be turned off by setting the `ISPenable` wire on `spif.v` low.
This lowers cybersecurity risk and puts it in a less onerous compliance category.
Firmware should warn of inadvertent ISP enable.

Firmware revision rollback is tricky to detect with a SPI flash that is easily cloned
by clip-on probe, desoldering, etc. That is beyond the scope of `spif`.
Compliance with that part of a cybersecurity standard is more of a system problem that depends
on what kinds of secure non-volatile memory are available.
Startup code should ensure proper revision level before running the app.
