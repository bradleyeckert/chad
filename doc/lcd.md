# Using TFT LCD displays

Small color graphic LCD modules for embedded projects range from 128x160
to 480x640. Popular sizes are 240x320 (QVGA), controlled by the ILI9341,
and 480x640 (VGA), controlled by the ILI9388.

`TFTsim.c` simulates a TFT controller chip by plotting pixels to a BMP data
structure. The same 24-bit BMP you see when you look at the binary of a BMP
file. In graphics programming, it's not much to plop a BMP up on the screen.
Once the app calls `TFTLCDsetup` to assign the BMP and module size,
Chad can write to the simulated LCD using `io!` to a single address.

## Driving an ILI9341 or ILI9388

The ILI9341 is the controller on most 240 x 320 TFT displays.
The data bus can be 8, 9, 16, or 18 bits.
A 9-bit bus would be nice, but the ones you can get off-the-shelf are 8-bit.

Suppose chad is connected to drive the ILI9341 directly from I/O.
The chip has a write cycle time of 66ns. 7 cycles at 100 MHz CPU clock.
One of my favorite primitives shifts out 1-bit pixels while translating each bit
into a foreground color and a background color for rendering text bitmaps.

A 16-bit color fits in a 16-bit cell. It takes two writes to send it the
ILI9321 when the DBI\[2:0] bits of 3Ah register are set to "101".
Code on a 16-bit machine would be:

```forth
variable bgcolor
variable fgcolor

: render  ( u bits -- )
    for   dup 1 and  cells bgcolor + @  ( u color )
        dup 8 rshift LCDport io!  \ io! takes 3 cycles
	    255 and  nop LCDport io!  \ including call and return
    next  drop
;
```

This looks like 24 cycles per pixel, which at 100 MIPS is 4.2M pixels/sec.
That would fill a 240 x 320 screen in 18 ms.

A VGA panel would be a little slower, at 72 ms. A 16-bit or 18-bit data
connection would speed things up.

```
: render  ( u bits -- )
    for   dup 1 and  cells bgcolor + @  LCDport _io! drop
    next  drop
;
```

This code takes 13 clocks per iteration (next takes 3) so a VGA could be filled
in 40 ms. Unrolling the loop would bring it down to 31 ms.

The theoretical minimum time is 20 ms, limited by the controller's 66ns write
cycle time. This is pushing the physical limits of the interface, which is why
you don't see panels larger than VGA controlled with this method.

## A graphics programming paradigm for color TFTs.

Graphic primitives are optimized for use with ILI9341 (etc.) commands.
Graphics are drawn by setting the limits for a rectangular drawing area and
pouring a raster of pixels into that area. The commands used are:

- Column Address Set (2Ah)
- Page Address Set (2Bh)
- Memory Write (2Ch)

To pop up a message window or draw a new region of text, you would start by
clearing the region with a rectangular fill command.
Then you would paint characters on that blank background.

## Text rendering

The primary use of the panel is text display from fonts stored in SPI flash.
One bit per pixel is pretty compact.
Run length encoding can save a little space, perhaps half,
but given the roominess of SPI flash it's not worth it.
When rendered, each bit selects either the foreground color or background
color.

Non-Latin glyphs (Kanji etc.) need a 16 x 16 field at a minimum.

Some character sets at various sizes are:

- 5 x 8 fixed font, 20h to 7Fh = 480 bytes
- 8 x 16 fixed font, 20h to 7Fh = 1.5K bytes
- 12 x 24 fixed font, 20h to 7Fh = 3.4K bytes

The cursor position is in units of pixels. 
When using a fixed font, the cursor steps to the right after each `emit`.
If it has reached the right edge, the cursor goes to the next text line
or stays on the current line if it's at the bottom of the screen.
Scrolling is not supported.

## Graphic primitives

- `gat` *( x y -- )* Sets the upper left corner of the next drawing feature.
- `gsize` *( w h -- )* Sets the size of the drawing area.
- `gat?` *( -- x y )* Reads the current cursor position.
- `gfill` *( color -- )* Rectangular fill with color.
- `>bgcolor` *( color -- )* Set the background color for text rendering.
- `>fgcolor` *( color -- )* Set the foreground color for text rendering.
- `gmono` *( addr -- )* Render bitmap from `addr` in flash memory.
- `gkerning` *( x y -- )* Sets the kerning values used by `gmono`.

The LSB of the first byte is the upper left pixel in the field of `gmono`.

After `gmono` renders a bitmap, it steps the cursor according to the
parameters set by `gsize` and `gkerning`.
Kerning is the amount of spacing between characters.

## Font compiler

A font compiler is used to create bitmaps.
It uses a list of all of the messages in the system to build data structure.
The data structure is expected to fit in a 64KB region.
It starts with a lookup table whose elements point to the character data.
It uses little-endian format and 8-bit bytes.

- 2-byte table size, N
- N x { 2-byte character value, 2-byte index to bitmap }
- N x { 1-byte width, 1-byte height, Bitmap data }

It takes about 10 branches to do a binary lookup.
Random read of flash, even in QSPI mode (command EBh),
requires 40 clock cycles to start the read and then 4 cycles per byte
assuming the SPI clock is half the processor clock.
Jumping around costs you.
It will take about 600 cycles to find the character.
Drawing the character will take 24 cycles per pixel as shown above.
An 8 x 16 field would paint in 2000 cycles, swamping the lookup time.






