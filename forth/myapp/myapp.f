\ Application example

\ To load: With your working directory here, type:
\ ..\chad include myapp.f  (in Windows), or
\ ../chad include myapp.f  (in Linux)

include ../core.f
include ../coreext.f
include ../redirect.f
include ../frame.f
include ../numout.f
include ../flash.f

\ iomap.c sends errors to the Chad interpreter
\ A QUIT loop running on the CPU would do something different.

:noname  ( error -- )  ?dup if $8002 io! then
; resolves exception

: hi [char] 你 ;

.( 你好，世界 ) cr

\ Examples

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - recurse
    swap 2 - recurse  + ;

\ Try 25 fib, then stats

' fib resolves cold

: source   tib tibs @ ;
: /source  source >in @ /string ;
: \source  /source  tibs @ >in ! ;

: f\
	0 flwp_en flash-wp
	0 sector !
    \source  0 write[ dup >f write ]write
;


.( Total instructions: ) there . cr
\ 0 there dasm

only forth
gendoc ../wiki/wikiforth.txt html/forth.html
previous
gendoc ../wiki/wikiroot.txt html/root.html
asm +order
gendoc ../wiki/wikiasm.txt html/asm.html
only forth

