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

Boot code monitors RXD to determine whether to launch the app (RXD=`0`)
or stay in the bootloader (RXD=`1`). When in the bootloader, <space>
tries to launch the app. Upon entry, the bootloader emits `?`.
The boot loader runs entirely in ROM, which means a 1024 x 16 ROM
should be sufficient for kernel words and the bootloader app.

The app is in flash.
It must have correct boilerplate (TBD) in order to launch.
Otherwise, app launch attempts will be ignored.

Bootloader commands:

- `<space>` Launch the app (if possible)
- `!` Write next SPI byte, expect 2 hex digits.
- `@` Read next SPI byte, return 2 hex digits.
- `#` Start a SPI flash command, expect 2 hex digits.
- `$` Stop SPI flash command, return `.` when flash is not busy.
- `%` ROM version, return 2 hex digits.
- `&` Bootloader format, return 2 hex digits.
- `'` nop
- `other` Ignored.

The bootloader can be exercised from the keyboard or from data piped in
from `stdin`.
In a target environment, an app would be used to set up the flash and
load the app into it. It would wait for `.` after sending the `$`.
Page programming occurs as follows:

- Program a 256-byte page sending 778 bytes out the serial port.
- Wait for a `.` to be returned, normally 2.5ms after programming.
- The OS (Windows etc.) inserts another 0.3ms or so of delay.
- Read back 256 bytes (512 chars) for verification.

Due to the delays, very high baud rates don't make programming much faster.
A rate of 2M BPS would have a program and verify time of 38ms per KB,
or 40 seconds per MB.
That can be supported by a USF-FS bridge chip like CH330.

Production programming of flash (if you're using much of it) would be
better done by a motherboard flasher like the Dediprog SF100.
