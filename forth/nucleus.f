[defined] -kernel [if] -kernel [else] marker -kernel
only forth definitions
decimal

0 equ 'TXbuf  	\ UART send output register
2 equ 'TXbusy 	\ UART transmit busy flag
0 equ false   	\ equates take up no code space. Have as many as you want.
-1 equ true
32 equ bl

\ You can compile to either check address alignment or not.
\ Set to 0 when everything looks stable. The difference is 25 instructions.

0 equ check_alignment \ enable @, !, w@, and w! to check address alignment

0 torg
later cold  	\ boots here
later exception \ error detected

: noop  nop ;							\ call to reduce interrupt latency
: io@   _io@ nop _io@_ ;				\ addr -- n \ I/O read
: io!   _io! nop drop ;					\ n addr -- \ I/O write
: =     xor 0= ;
: <>    xor 0= 0= ;
: <     - 0< ; macro
: >     swap < ;
: cell+ cell + ; macro
: rot   >r swap r> swap ;

: c@    _@ dup@ swap mask rshift wand ;

cell 4 = [if]
    : cells 2* 2* ; macro				\ 6.1.0890  n -- n*4
    : (x!)  ( u w-addr bitmask wordmask )
        >carry swap
        dup>r and 3 lshift dup>r lshift
        w r> lshift invert
        r@ _@ _@_ and  + r> _! drop
    ;
    : c!  ( u c-addr -- ) 3 $FF  (x!) ; \ 6.1.0850  c addr --
  check_alignment [if]
    : (ta)  ( a mask -- a )
	      over and if  22 invert exception  then ;
    : @   3 (ta)  _@ _@_ ;
    : !   3 (ta)  _! drop ;				\ 6.1.0010  x addr --
    : w!  ( u w-addr -- )
          1 (ta) 2 $FFFF (x!) ;
    : w@  ( w-addr -- u )
          1 (ta) _@ dup@ swap 2 and 3 lshift rshift $FFFF and ;
  [else]
    : @   _@ _@_ ; macro
    : !   _! drop ; macro				\ 6.1.0010  x addr --
    : w!  2 $FFFF (x!) ;
    : w@  _@ dup@ swap 2 and 3 lshift rshift $FFFF and ;
  [then]
[else] \ 16-bit or 18-bit cells
    : cells 2* ; macro					\ 6.1.0890  n -- n*2
  check_alignment [if]
    : (ta)  over and if  22 invert exception  then ;
    : @   1 (ta)  _@ _@_ ;
    : !   1 (ta)  _! drop ;				\ 6.1.0010  x addr --
  [else]
    : @   _@ _@_ ; macro
    : !   _! drop ; macro				\ 6.1.0010  x addr --
  [then]
    : c! ( u c-addr -- )				\ 6.1.0850  c addr --
        dup>r 1 and if
            8 lshift  $00FF
        else
            255 and   $FF00
        then
        r@ _@ _@_ and  + r> _! drop
    ;
[then]

\ Your code can usually use + instead of OR, but if it's needed:
: or    invert swap invert and invert ; \ 6.1.1980  n m -- n|m

: execute  2* >r ; no-tail-recursion 	\ 6.1.1370  xt --

: 2dup   over over ; macro \ d -- d d
: char+ [ ;
: 1+     1 + ; \ macro
: 1-     1 - ; \ macro					\ 6.1.0300  n -- n-1
: negate invert 1+ ;					\ 6.1.1910  n -- -n
: tuck   swap over ;
: +!     tuck @ + swap ! ;				\ 6.1.0130  x addr --

\ Math iterations are subroutines to minimize the latency of lazy interrupts.
\ These interrupts modify the RET operation to service ISRs.
\ RET ends the scope of carry and W so that ISRs may trash them.
\ Latency is the maximum time between returns.

\ Multiplication using shift-and-add, 160 to 256 cycles at 16-bit.
\ Latency = 17
: (um*)
    2* >r 2*c carry
    if  over r> + >r carry +
    then  r>
;
: um*  \ u1 u2 -- ud
    0 [ cellbits 2/ ] literal           \ cell is an even number of bits
    for (um*) (um*) next
    >r nip r> swap
;

\ Long division takes about 340 cycles at 16-bit.
\ Latency = 25
: (um/mod)
    >r  swap 2*c swap 2*c               \ 2dividend | divisor
    carry if
        r@ -   0 >carry
    else
        dup r@  - drop                  \ test subtraction
        carry 0= if  r@ -  then         \ keep it
    then
    r>  carry                           \ carry is safe on the stack
;
: um/mod  \ ud u -- ur uq               \ 6.1.2370
    over over- drop carry
    if  drop drop dup xor
        dup invert  exit                \ overflow = 0 -1
    then
    [ cellbits 2/ ] literal
    for (um/mod) >carry
        (um/mod) >carry
    next
    drop swap 2*c invert                \ finish quotient
;

: *     um* drop ;
: dnegate  invert swap invert 1 + swap 0 +c ;
: abs   dup 0< if negate then ;
: dabs  dup 0< if dnegate then ;

: m/mod
    dup 0< dup >r
    if negate  >r
       dnegate r>
    then >r dup 0<
    if r@ +
    then r> um/mod
    r> if
       swap negate swap
    then
;
: /mod   over 0< swap m/mod ;           \ 6.1.0240
: mod    /mod drop ;                    \ 6.1.1890
: /      /mod nip ;                     \ 6.1.0230

: m*                                    \ 6.1.1810  n1 n2 -- d
    2dup xor 0< >r
    abs swap abs um*
    r> if dnegate then
;
: */mod  >r m* r> m/mod ;               \ 6.1.0110  n1 n2 n3 -- rem n1*n2/n3
: */     */mod swap drop ;              \ 6.1.0100  n1 n2 n3 -- n1*n2/n3

\ In order to use CREATE DOES>, we need ',' defined here.

dp cell+ dp ! \ variables shared with chad's interpreter
cvariable base
cvariable state
align
: aligned  [ cell 1- ] literal + cell negate and ;
: align    dp @ aligned dp ! ;
: allot    dp +! ;
: here     dp @ ;
: ,        align here !  cell allot ;
: c,       here c!  1 allot ;

\ We're about at 300 instructions at this point.
\ Paul Bennett's recommended minimum word set is mostly present.
\ DO, I, J, and LOOP are not included. Use for next r@ instead.
\ CATCH and THROW are not included. They use stack.
\ DOES> needs a compilable CREATE.

: u<     - drop carry 0= 0= ;
: within over - >r - r> u< ;            \ 6.2.2440  u ulo uhi -- flag
: min    over over- 0< if swap drop exit then  drop ; \ 6.1.1870
: max    over over- 0< if drop exit then  swap drop ; \ 6.1.1880
: exec2: 2* [ ;             			\ for list of 2-inst literals
: exec1: 2* r> + >r ;       			\ for list of 1-inst literals
: 2drop  drop drop ;

CODE depth
	status T->N d+1 alu   drop 31 imm   T&N d-1 RET alu
END-CODE

1234 depth  1 assert  1234 assert  		\ sanity check the stack


there . .( instructions used by nucleus) cr
