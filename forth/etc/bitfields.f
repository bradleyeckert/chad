\ : bvar ( <name> -- )
\ : b! ( u bf -- ) Stores *u* to a bit field.
\ : b@ ( u bf -- ) Fetches *u* from a bit field.
\ : bit+ ( bf1 -- bf2 ) Skips to the next field in an array of bit fields.
\ : bits ( bf1 n -- bf2 ) Addresses the nth field in an array of bit fields.
\ : balign ( -- ) Align the next bit field on a cell boundary.

[defined] -bf [if] -bf [else] marker -bf [then]

\ Bitfield proof of concept

\ This version of bit fields uses a single cell to specify a bit field.
\ It packs address, width, and shift count into one cell.
\ On one hand, the address range is somewhat restricted.
\ On the other hand, they work a lot like variables.

: width_of_cell ( -- n )
    -1 0 begin
    over  while 1+ swap 1 rshift swap
    repeat   nip
;

width_of_cell                        constant cellbits   \ usually 32
cellbits 16 > [if] 5 [else] 4 [then] constant specwidth  \ bits/field
-1 specwidth lshift invert           constant specmask   \ 01Fh etc.
1 specwidth 2* lshift                constant specabump  \ 400h etc.

\ Since ANS Forth variables can be rather large, you can't use them
\ directly with bit addressing. Use them within a bitspace instead.
\ A THROW code is added: -73 = "Bitfield is 0 or too wide for a cell"

1024 cells buffer: bitspace
-73 constant BAD_BITFIELD

variable bp

: bhere    ( -- bf )       bp @ ;
: borg     ( bf -- )       bp ! ;
: baligned ( bf1 -- bf2 )  specmask invert and  specabump + ;
: balign   ( -- )          bhere baligned borg ;
: bf.addr  ( bf -- addr )  specwidth 2* rshift  cells bitspace + ;
: bf.width ( bf -- width ) specwidth rshift  1+  specmask and ;
: bf.pos   ( bf -- position ) specmask and ;
: bf.mask  ( bf -- mask )  bf.width  -1 swap lshift invert ;

\ Skip to the next bitfield in an array of bitfields of width bf1.width
: bit+     ( bf1 -- bf2 )           
    dup >r   
    [ specmask invert ] literal and \ ( bf0 | bf1 ) bf with position = 0
    r@ bf.width  r> bf.pos      
    over >r +  dup r> +  cellbits >  if 
        drop specabump  			\ doesn't fit ( bf0 pos' ) 
    then  +
;

\ Declare a bit field variable that returns a bf token.
: bvar     ( width <name> -- )
    dup cellbits >  over 0= or  BAD_BITFIELD and throw  
    dup  1- specwidth lshift >r     \ width | <width>
    bhere dup >r  bf.pos            \ width pos | <width> bf
    2dup + cellbits > if            \ doesn't fit in current cell
        drop specabump              \ pos=0, bump address   
    else
        tuck + swap 
    then                            \ pos' pos | <width> bf
    r> [ specabump 1- invert ] literal and + \ pos' adr:0:pos
    r> +                            \ pos' adr:width:pos
    tuck [ specmask invert ] literal and + \ adr:w:pos adr:w:pos'
    borg  create , does> @
;

\ Fetch from a bit field
: b@  ( bf -- u )
    dup >r  bf.addr @
    r@ specmask and  rshift
    r> bf.mask and
;

\ Store to a bit field
: b!  ( u bf -- )
    dup >r  bf.addr  swap   		\ a u | bf
    r@ bf.mask  tuck and    		\ a mask u | bf
    r> specmask and dup >r  		\ a mask u shift | shift
    lshift  swap r> lshift  		\ a new mask'
    invert  rot  dup @      		\ new mask' a old
    swap >r  and  + r> !
;

: bf.  ( bf -- )                	\ unpack and print the bit field
    dup bf.addr   ." addr=" .
    dup bf.width  ." width=" .  
	    bf.pos    ." pos=" .
;

6 bvar foo      10 foo b!
1 bvar bar       0 bar b!
7 bvar percent  33 percent b!    	\ for numbers 0 to 100
8 bvar mybyte   47 mybyte b!     	\ an actual byte
16 bvar classic 12345 classic b! 	\ old school 16-bit value

13 bvar y0   11 y0 b!
13 bvar y1   12 y1 b!
13 bvar y2   13 y2 b!
13 bvar y3   14 y3 b!
13 bvar y4   15 y4 b!
13 bvar y5   16 y5 b!
13 bvar y6   17 y6 b!
13 bvar y7   18 y7 b!

: test  y0  8 0 do  dup b@ .  bit+  loop drop ;

