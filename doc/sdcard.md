#SD card

Currently on my to-do list:

The LCD module plugged into the Arty-A7 board has a Micro-SD socket with four signal lines.
Let's set up a 4-wire SPI interface.
The wires are labeled:

| Name   | uSD pin | Usage             |
|--------|---------|-------------------|
| sd_ss  | 2       | SPI chip select   |
| sd_di  | 3       | Data to SD card   |
| sd_do  | 7       | Data from SD card |
| sd_sck | 5       | SD card clock     |
| GND    | 6       |                   |
| 3.3V   | 4       |                   |

`sd_sck` will typically run at 10 to 25 MHz.

The predominant SD card operations are block read and block write of 512 bytes each.
The SPI should support 1-byte to 4-byte transfers using the Wishbone interface.
When the transfer is finished, an ISR can be triggered to request the next word or
software can just poll the status. The time to transfer 32 bits at 25 MHz is 1.3 usec
which is 130 cycles at 100 MHz. It's probably okay to just poll.

For a CPU with 24-bit cells, the ISR would write 3 bytes at a time, which doesn't
exactly divide into 512. It's 170 cells and two bytes. The last write/read is a little short.

##Formatting

Most SD cards are formatted with FAT16, FAT32, or exFAT by default.
You'll want some kind of formatting even if you don't use it so that other computers will
recognize the card when you plug it in.

SD cards use sector virtualization to avoid quick burn-out from repeated update of FAT tables
and other data at fixed sector numbers. In the physical NAND flash, the actual data could be anywhere.
That means the SD card is already internally mapped for bad sectors.
Formatting the SD card isn't going to find new bad sectors as they are already mapped out.
So, FAT's cluster map is kind of redundant.

A portion of the SD card can be left unallocated. The range of unallocated blocks can be obtained
from the MBR and FAT tables. Then you could use a portion of the SD card as a FAT file system
and the rest as a block system.

##Blocks

The advantage of a block system is that updates to FAT can be avoided. You control the data as blocks.
You can put log data at fixed blocks, edit blocks in-place as text, etc. Again, the SD card works around
bad sectors for you.

##FAT File Systems

I wrote a FAT File System once. It's not too complicated, but it's a bit involved. It's a lot of code
just for compatibility with other computers. Maybe I don't want to use up that much code space.

Read-only files would be easier to manage since there would be no need to change the FAT.
Supporting only 8.3 filenames and the root directory (no folders) simplifies things further.
