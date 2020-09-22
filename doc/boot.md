# Boot Loader Protocol

Some hardware assistance can be used to determine the baud rate of the UART
and start accepting characters.
The RXD line has a pulldown resistor so that when the cable is
disconnected, the UART sees a long BREAK.
Likewise, if a bus-powered USB-UART bridge will output a `0`
when unplugged.

When the UART is disconnected for more than 100 ms, the boot code will
launch the app. For example, 100 ms after power-up the app starts.

When a cable is plugged in, RXD goes to 1. 
The UART goes into training mode.
A <space> character trains the UART, then subsequent characters are
available to the `chad` processor.
Upon exiting training mode, the UART resets the processor.
Training mode may be re-activated by a long BREAK.

Upon entry, the bootloader emits `?`.
The boot loader runs entirely in ROM, which means a 1024 x 16 ROM
would be sufficient for kernel words and the bootloader app.
A 2048 x 16 ROM would be better. It could host most of a full Forth.
Boot code monitors RXD to determine whether to launch the app (RXD=`0`)
or stay in the bootloader (RXD=`1`). When in the bootloader, <space>
tries to launch the app. 

The app is in flash.
It must have correct boilerplate (TBD) in order to launch.
Otherwise, app launch attempts will be ignored.

## Booting from flash

The SPI flash contains application code that loads into code RAM,
the code space above the 2Kx16 ROM.
Practically all app data is in SPI flash.
If you don't want that data in plaintext format, there's CTEA.

CTEA is the XTEA-inspired crypto algorithm for `chad`.
It enciphers or deciphers 36-bit words using a 72-bit key.
CTEA (file `ctea.f`) fits in 76 instructions and executes in 2000 cycles.
About half the time of CTEA is spent in `CTshift`,
which would be a trivial hardware instruction if implemented.
Decipher of flash contents, with the helper instruction added,
would take 2.5 usec per byte at 100 MHz.

## UART commands

The bootloader is most practical in plaintext.
Bytes are represented by hex digits.
The bootloader commands are:

- `<space>` Launch the app (if possible)
- `!` Write N SPI bytes, expect 2N hex digits.
- `@` Read N SPI bytes, return 2N hex digits.
- `#` Set `N` parameter, expect 2 hex digits.
- `$` Stop SPI flash command, return `.` when flash is not busy.
- `%` Start a SPI flash command.
- `&` Boilerplate, return 2M hex digits where M is the length of the string.
- `'` Enable the bootloader, expect 4 hex digits.
- `other` Ignored.

### Launch the app

If the app is in SPI flash, it is checked for validity before being launched.
Usually, you want two copies of the app in flash: The one that's running and
the one that's the upgrade so that the app can upgrade itself.
At the next boot, the bootloader decides which one to use.
One 4K sector could be used as a header pointing to the active app.

The active app could begin with some 16-bit fields:
- 0: `cc0d` marks the beginning of `chad` application code.
- 1: Build number.
- 2: Length of the app.
- 3: Checksum of the app.

64KB sectors used for data would be marked by `cdat` instead of `cc0d`.
It would have the same build number, length, and checksum.
A checksum can be computed using the fast QSPI read (EBh) command at about
20M bytes/sec, so a 64KB sector can be checked in 3.3 msec.

### Write N SPI bytes

`!` receives 2N hex digits and sends them to the SPI.

### Read N SPI bytes

`@` sends back the most recent byte received from the SPI and does the following
`N` times: Send 0 to the SPI and send back the result as two hex digits. 

### Set byte N

`#` Set N from two hex digits.

### End SPI transfer

`$` raises CS#.
Polls the flash to wait until it's not busy erasing or writing.
Returns a `.` character.

### Start a SPI flash command

`%` lowers the CS# line of the SPI flash.

### Boilerplate

A table in ROM contains boilerplate data as an array of bytes.
Their meanings are:

- Byte 0 = A4h, `chad` identifier
- Byte 1 = bootloader protocol: 0 = simple plaintext
- Byte 2 = ROM revision level. You don't want many of these.
- Bytes 4, 5 = Product ID, little endian.

The host will poll the SPI flash chip directly to determine its type,
capacity, etc. 

### Enable

The enable `'` requires a 16-bit matching key to enable the bootloader.
Without the key, it won't work. All commands will be ignored.
This prevents power glitches from triggering commands that might
corrupt the flash.

## Programming time

Page programming occurs as follows:

- Program a 256-byte page sending 780 chars out the serial port.
- Wait for a `.` to be returned, normally 2.5ms after programming.
- The OS (Windows etc.) inserts another 1 ms (a USB frame) of delay.
- Read back 256 bytes (512 chars) for verification.

A baud rate of 2M BPS would give a program and verify time of 40ms per KB,
or 40 seconds per MB.
That can be supported by a USB-FS bridge chip like the $0.33 CH330N.
Raising the baud rate wouldn't speed up programming much due to the delays.

Production programming of flash (if you're using much of it) would be
better done by a motherboard flasher like the Dediprog SF100.

## Applications

Computers don't keep all apps in RAM, all the time. That would be dumb.
Applications could work the same way.
When you need a feature, load it from flash.
In Forth, applications usually start executing near the end and call backwards
to more primitive words. 
You would want to get a feature loaded into RAM before starting execution.
Handling one feature at a time is easy.
Compile the feature to a RAM-based code space and save it to flash.
Load it back when you need it.

For handling multiple features,
compilation from text source in flash is a better idea.
The Forth QUIT loop keeps its headers in flash so it can't start out with a
blank flash.
It should take about 30 clock cycles per header to traverse a wordlist.
With 300 headers, that would be about 90 us (100 MIPS) so the compilation
rate would be 11 tokens per ms. If a blank delimited token averages 6 chars,
that would make the compilation speed about 80KB/sec.

Should flash be arranged as blocks or text?
It's easy to refill a buffer until the next newline.
The only problem is editing in the flash.
Inserting a character expands the whole "file".
Since the flash block (in SPI NOR flash) is 4KB and we don't want to provide
such a large RAM buffer for it, 
it seems that editing on the target isn't such a great idea.
Text file format would be fine.
The host side of the bootloader can be used to manage the file(s).
