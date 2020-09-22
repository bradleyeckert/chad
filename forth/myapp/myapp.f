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
include ../ctea.f
include ../bootload.f

\ iomap.c sends errors to the Chad interpreter
\ A QUIT loop running on the CPU would do something different.

:noname  ( error -- )  ?dup if $8000 io! then
; resolves exception

later app

\ Without flash memory, initializing data space with non-blanks is
\ non-trivial. Cold boot starts out most of data space blank.
\ The app is responsible for initializing its variables.
\ Shared (with chad.c) variables: >in, tibs, dp, base, state.

:noname  ( -- )
	here  state
	[ dm-size state - cell / ] literal
	for  0 over ! cell +  next  drop	\ erase most everything
	dp !  decimal  fpclear				\ restore dp, base, frp
\	app
; resolves cold


.( 你好，世界 ) cr

\ Examples

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - recurse
    swap 2 - recurse  + ;

\ Try 25 fib, then stats

: source   tib tibs @ ;
: /source  source >in @ /string ;
: \source  /source  tibs @ >in ! ;
: f\       \source  dup c,f write ;

0 flwp_en flash-wp		\ enable flash writing
\ 4096 create-flash		\ put data in 4K page starting here
\ f\ Hello World
\ close-flash

cm-writable torg		\ compile the app here
: app  4096 open-flash ;

.( Total instructions: ) there . cr
\ 0 there dasm

only forth
gendoc ../wiki/wikiforth.txt html/forth.html
previous
gendoc ../wiki/wikiroot.txt html/root.html
asm +order
gendoc ../wiki/wikiasm.txt html/asm.html
only forth

