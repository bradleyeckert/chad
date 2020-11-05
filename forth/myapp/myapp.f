\ Application example

\ To load: With your working directory here, type:
\ ..\chad include myapp.f  (in Windows), or
\ ../chad include myapp.f  (in Linux)

include ../core.f
include ../coreext.f
include ../redirect.f
include ../frame.f
include ../numout.f
include ../ctea.f
include ../bignum.f

\ iomap.c sends errors to the Chad interpreter
\ A QUIT loop running on the CPU would do something different.

:noname  ( error -- )  ?dup if $8000 io! then
; resolves exception

\ Hardware loads code and data RAMs from flash. Upon coming out of reset,
\ both are initialized. The PC can launch from 0 (cold).

\ A very simple app would output some numbers and then hang.

: myapp  ( -- )
    cr
    10 for r@ . next
    begin noop again
;

' myapp resolves cold

\ You can now run the app with "cold"

.( 你好，世界 ) cr

\ Examples

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - recurse
    swap 2 - recurse  + ;

\ Try 25 fib, then stats

make-boot               \ create a boot record in flash
0 save-flash myapp.bin  \ save to a 'chad' file you can boot from
save-flash-h myapp.txt  \ also save in hex for flash memory model

\ You can now run the app with "boot myapp.bin".

.( Total instructions: ) there . cr
\ 0 there dasm

\ Now let's generate a language standard
only forth
gendoc ../wiki/wikiforth.txt html/forth.html
previous
gendoc ../wiki/wikiroot.txt html/root.html
asm +order
gendoc ../wiki/wikiasm.txt html/asm.html
only forth

