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
\ include ../bootload.f

\ iomap.c sends errors to the Chad interpreter
\ A QUIT loop running on the CPU would do something different.

:noname  ( error -- )  ?dup if $8000 io! then
; resolves exception

\ later app

\ Without flash memory, initializing data space with non-blanks is
\ non-trivial. Cold boot starts out most of data space blank.
\ The app is responsible for initializing its variables.
\ Shared (with chad.c) variables: >in, tibs, dp, base, state.

:noname  ( -- )
	here  state
	[ dm-size state - cell / ] literal
	for  0 over ! cell +  next  drop	\ erase most everything
	dp !  decimal  fpclear				\ restore dp, base, frp
    /profile
\	app
; resolves cold


.( 你好，世界 ) cr

\ Examples

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - recurse
    swap 2 - recurse  + ;

\ Try 25 fib, then stats

0 [if]
\ I was going to control flash loading from firmware in ROM.
\ It's probably the wrong way.
\ The next step past FPGA is ASIC, so target that.
\ In an ASIC, you don't start with ROM. Too much risk.
\ Code space is RAM and a FSM loads it from flash for you.
\ Let's do the bootloader in hardware.

\ Having that FSM changes strategies for dealing with flash.
\ Time to put on the hardware hat.

: source   tib tibs @ ;
: /source  source >in @ /string ;
: \source  /source  tibs @ >in ! ;
: f\       \source  dup >s dm>s ;

4096. S_W8 open-stream		\ put data in 4K page starting here
f\ Hello World
close-stream

cm-writable torg		    \ compile the app into code RAM
:noname  s> emit ;
: app  4096. S_R8 open-stream
    s> literal times
    close-stream
;

0. S_W16 open-stream		\ put code in 4K page starting here
cm-writable there over - cm>s \ copy to flash
close-stream

save-flash hello.bin

[then]

.( Total instructions: ) there . cr
\ 0 there dasm

only forth
gendoc ../wiki/wikiforth.txt html/forth.html
previous
gendoc ../wiki/wikiroot.txt html/root.html
asm +order
gendoc ../wiki/wikiasm.txt html/asm.html
only forth

