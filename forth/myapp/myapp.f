\ Application example

\ To load: With your working directory here, type:
\ ..\chad include myapp.f  (in Windows), or
\ ../chad include myapp.f  (in Linux)
\ If SPI flash is encrypted, for example, with `1 +bkey`, launch with:
\ ..\chad 1 +bkey boot myapp.bin

\ Put text high enough in flash memory that it won't get clobbered by
\ boot code and headers. Should be a multiple of 4096.

$4000 forg                              \ strings in flash start here

1 +bkey                                 \ encrypt boot record if not zero
2 +tkey                                 \ encrypt text if not zero
0 equ BASEBLOCK                         \ space reserved for FPGA bitstream

include ../core.f
include ../coreext.f
include ../redirect.f
include ../frame.f
include ../numout.f
include ../flash.f
include ../compile.f
include ../interpret.f
\ include ../ctea.f
\ include ../bignum.f

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

\ Hardware loads code and data RAMs from flash. Upon coming out of reset,
\ both are initialized. The PC can launch from 0 (cold).

: myapp  ( -- )
    ." May the Forth be with you."
    0 quit
;

' myapp resolves coldboot

\ You can now run the app with "cold"

: hi ." 多么美丽的世界 " ;

\ Examples

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - recurse
    swap 2 - recurse  + ;

\ Try 25 fib, then stats
.( Total instructions: ) there . cr

\ Save to a flash memory image
$1C00 forg  make-heads                  \ append headers to flash
$0000 forg  make-boot                   \ create a boot record in flash
0. BASEBLOCK save-flash myapp.bin       \ save to a 'chad' file you can boot
BASEBLOCK save-flash-h myapp.txt        \ save in hex for flash memory model

\ You can now run the app with "boot myapp.bin" or a Verilog simulator.

\ Now let's generate a language standard
only forth
gendoc ../wiki/wikiforth.txt html/forth.html
previous
gendoc ../wiki/wikiroot.txt html/root.html
asm +order
gendoc ../wiki/wikiasm.txt html/asm.html
only forth

\ 0 there dasm \ dumps all code
