\ Application example

\ To load: With your working directory here, type:
\ ..\bin\chad include myapp.f  (in Windows), or
\ ../bin/chad include myapp.f  (in Linux)
\ If SPI flash is encrypted, for example, with `1 +bkey`, launch with:
\ ..\bin\chad 1 +bkey boot myapp.bin

\ To include the GUI stuff,
\ ..\bin\gui include myapp.f


\ Put text high enough in flash memory that it won't get clobbered by
\ boot code and headers. Should be a multiple of 4096.

$4000 forg                              \ strings in flash start here
$6000 equ fontDB                        \ font database location

1 +bkey                                 \ encrypt boot record if not zero
2 +tkey                                 \ encrypt text if not zero
0 equ BASEBLOCK                         \ space reserved for FPGA bitstream

include ../forth/core.f
include ../forth/coreext.f
include ../forth/redirect.f
include ../forth/frame.f
include ../forth/numout.f
include ../forth/compile.f
include ../forth/flash.f
include ../forth/interpret.f
\ include ../forth/tftlcd.f
\ include ../forth/ctea.f
\ include ../forth/bignum.f

variable hicycles

:noname ( -- )
   hicycles @ 1 +
   hicycles !
; resolves irqtick \ clock cycle counter overflow interrupt

\ Read raw cycle count. Since io@ returns after the lower count is read,
\ it will service iqrtick if it has rolled over. hicycles is safe to read.

: rawcycles ( -- ud )
   [ 6 cells ] literal io@
   hicycles @
;

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
    1000 [ 100 cells ] literal io!      \ test wishbone write
    [ 100 cells ] literal io@ drop      \ test wishbone read
    ." May the Forth be with you."
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
$2000 forg  make-heads                  \ build headers in flash
$0000 forg  make-boot                   \ create a boot record in flash
fontDB load-flash ../forth/myfont.bin   \ add the fonts in raw binary
0. BASEBLOCK save-flash myapp.bin       \ save to a 'chad' file you can boot
BASEBLOCK save-flash-h myapp.txt        \ save in hex for flash memory model

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
