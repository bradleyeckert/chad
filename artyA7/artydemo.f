\ Application example for Arty A7 board with 320 x 480 LCD.     12/15/20

\ To load: With your working directory here, type:
\ ..\bin\gui include artydemo.f  (in Windows), or
\ ../bin/gui include artydemo.f  (in Linux)
\ If SPI flash is encrypted, for example, with `1 +bkey`, launch with:
\ ..\bin\gui 1 +bkey boot artydemo.bin


\ Put text high enough in flash memory that it won't get clobbered by
\ boot code and headers. Should be a multiple of 4096.

$6000 forg                              \ strings in flash start here
$8000 equ fontDB                        \ font database location

1 +bkey                                 \ encrypt boot record if not zero
2 +tkey                                 \ encrypt text if not zero
34 equ BASEBLOCK                        \ leave space for A7-35T FPGA bitstream

include ../forth/core.f
include ../forth/coreext.f
include ../forth/io_equs.f
include ../forth/redirect.f
include ../forth/frame.f
include ../forth/numout.f
include ../forth/compile.f
include ../forth/flash.f
include ../forth/interpret.f
include ../forth/tftlcd.f
include ../forth/bignum.f
\ include ../forth/ctea.f


\ Error handling

[defined] quit [if]
  :noname  ( error -- )  ?dup if  quit  then
  ; resolves throw        \ quit handles the errors
[else]
  :noname  ( error -- )  ?dup if  [ $4000 cells ] literal io!  then
  ; resolves throw        \ iomap.c sends errors to the Chad interpreter
[then]

\ Hardware loads code and data RAMs from flash. Upon coming out of reset,
\ both are initialized. The PC can launch from 0 (cold).

[defined] quit [if]

: myapp  ( -- )
    [ $18 cells ] literal dup io@       \ read gp_i
    swap io!                            \ write top gp_o
    /tft  dkred pink set-colors
    lcd page 140 test con         \ test screem
    ." May the Forth be with you!"
    0 quit
;

' myapp resolves coldboot

\ You can now run the app with "cold"

: hi ." 多么美丽的世界 " ;

[then]

\ Examples

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - recurse
    swap 2 - recurse  + ;

\ Try 25 fib, then stats
.( Total instructions: ) there . cr

\ Save to a flash memory image
[defined] lit, [if]                     \ if there's code for it...
$2000 forg  make-heads                  \ build headers in flash
$0000 forg  make-boot                   \ create a boot record in flash
fontDB load-flash ../forth/myfont.bin   \ add the fonts in raw binary
1 0. BASEBLOCK save-flash app.bin       \ save to a 'chad' file you can boot
0 0. BASEBLOCK save-flash appraw.bin    \ without boilerplate for Vivado
2 0. BASEBLOCK save-flash app.txt       \ save as hex for flash sim model
[then]

\ You can now run the app with "boot myapp.bin" or a Verilog simulator.

\ Now let's generate a language standard
only forth
gendoc ../forth/wiki/wikiforth.txt html/forth.html
previous
gendoc ../forth/wiki/wikiroot.txt html/root.html
asm +order
gendoc ../forth/wiki/wikiasm.txt html/asm.html
only forth

\ 0 there dasm \ dumps all code
