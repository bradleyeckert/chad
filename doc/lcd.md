# Driving an ILI9341

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
