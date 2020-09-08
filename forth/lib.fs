[defined] -kernel [if] -kernel [else] marker -kernel
only forth definitions 
decimal

0 equ 'TXbuf  \ UART send output register
2 equ 'TXbusy \ UART transmit busy flag
0 equ false   \ equates take up no code space. Have as many as you want.
-1 equ true

\ You can compile to either check address alignment or not.
\ Set to 0 when everything looks stable. The difference is 25 instructions.

1 equ check_alignment \ enable @, !, w@, and w! to check address alignment

0 >verbose

0 torg
defer cold  	\ boots here
defer exception \ error detected

CODE depth   
	status T->N d+1 alu   drop 31 imm   T&N d-1 RET alu  
END-CODE

1234 depth  1 assert  1234 assert  \ sanity check the stack

: noop  nop ;
: io@   _io@ nop _io@_ ;
: io!   _io! nop drop ;
: =     xor 0= ;
: or    invert swap invert and invert ;
: <>    xor 0= 0= ;
: <     - 0< ; macro
: >     swap < ;
: cell+ cell + ; macro
: rot   >r swap r> swap ;

cellbits 32 = [if]
    : cells 2* 2* ; macro
    : c@  _@ dup@ swap 3 and 3 lshift rshift $FF and ;
    : (x!)  ( u w-addr bitmask wordmask )
        >carry swap
        dup>r and 3 lshift dup>r lshift
        w r> lshift invert
        r@ _@ _@_ and  + r> _! drop
    ;
    : c!  ( u c-addr -- )  3 $FF  (x!) ;
  check_alignment [if]
    : (ta)  ( a mask -- a )
	      over and if  22 invert exception  then ;
    : @   3 (ta)  _@ _@_ ;
    : !   3 (ta)  _! drop ;
    : w!  ( u w-addr -- )
          1 (ta) 2 $FFFF (x!) ;
    : w@  ( w-addr -- u )
          1 (ta) _@ dup@ swap 2 and 3 lshift rshift $FFFF and ;
  [else]
    : @   _@ _@_ ; macro
    : !   _! drop ; macro
    : w!  2 $FFFF (x!) ;
    : w@  _@ dup@ swap 2 and 3 lshift rshift $FFFF and ;
  [then]
[else] \ 16-bit or 18-bit cells
    : cells 2* ; macro
  check_alignment [if]
    : (ta)  over and if  22 invert exception  then ;
    : @   1 (ta)  _@ _@_ ;
    : !   1 (ta)  _! drop ;
  [else]
    : @   _@ _@_ ; macro
    : !   _! drop ; macro
  [then]
    : c@  _@ dup@ swap 1 and 3 lshift rshift $FF and ;
    : c! ( u c-addr -- )
        dup>r 1 and if
            8 lshift  $00FF
        else
            255 and   $FF00
        then
        r@ _@ _@_ and  + r> _! drop
    ;
[then]

\ Bit field operators
\ Read is easy: Read, shift, and mask.
\ Write needs a read-modify-write: limit and align n, read and mask
\ the old data, add the new data, and write back the result.

CODE b@  \ bs -- n              \ Read a bit field from packed bitspec
    mask    T->N    d+1     alu \ ( count addr )
    T                       alu \ wait for read to settle
    [T]                     alu \ read the cell
    N       T->N            alu \ swap: ( data count )
    N>>T            d-1     alu \ value
    T&W             RET r-1 alu \ bits
END-CODE

CODE b!  \ n bs --              \ Write to a packed bitspec
    N       T->N            alu \ swap
    N       T->R    d-1 r+1 alu \ >r
    mask    T->N    d+1     alu \ ( shift addr | n ) W = mask
    N       T->N    d+1     alu \ over: ( shift addr shift | n )
    R       T->N    d+1 r-1 alu \ r>
    N       T->N            alu \ swap: ( shift addr n shift )
    N<<T            d-1     alu \ lshift: ( shift addr n' )
    N       T->R    d-1 r+1 alu \ >r: ( shift addr | n' )
    N       T->N            alu \ swap
    W       T->N    d+1     alu \ w: ( addr shift mask | n' )
    N       T->N            alu \ swap
    N<<T            d-1     alu \ lshift: ( addr mask' | n' )
    ~T                      alu
    N       T->N    d+1     alu \ over: ( addr mask' addr | n' )
    T                       alu \ wait for read to settle
    [T]                     alu \ @
    T&N             d-1     alu \ and: ( addr data' | n' )
    R       T->N    d+1 r-1 alu \ r>
    T+N             d-1     alu \ +: ( addr data" )
    N       T->N            alu \ swap
    T       N->[T]  d-1     alu \ !
    N       RET     d-1 r-1 alu
END-CODE

\ Your code can usually use + instead of OR, but if it's needed:
: or     invert swap invert and invert ; \ n t -- n|t

: execute  2* >r ; notail   		\ 6.1.1370  xt --

: 2dup   over over ; macro \ d -- d d
: char+ [ ;
: 1+     1 + ; macro
: 1-     1 - ; macro
: negate invert 1+ ;
: tuck   swap over ;
: +!     tuck @ + swap ! ;

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
: */mod  >r m* r> m/mod ;               \ 6.1.0110  n1 n2 n3 -- remainder n1*n2/n3
: */     */mod swap drop ;              \ 6.1.0100  n1 n2 n3 -- n1*n2/n3

\ In order to use CREATE DOES>, we need ',' defined here.

dp cell+ dp ! \ start variables after dp
: aligned  dup [ cell 1- ] literal + cell negate and ;
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


1000 100 xor  908 assert
1000 100 and   96 assert
1000 100 +   1100 assert
1000 100 -    900 assert
100 dup  100 assert  drop
depth 0 assert
123 456 swap  123 assert 456 assert
123 456 over  123 assert 456 assert 123 assert
depth 0 assert
\ Note: Data memory is byte-addressed, allow 4-byte cells
123 4 !  456 8 !
4 @ 123 assert
8 dup drop @ dup drop 456 assert
depth 0 assert

\ Now let's get some I/O set up. ScreenProfile points to a table of xts.

variable ScreenProfile
: ExecScreen  ( n -- ) ScreenProfile @ execute execute ;
: emit  0 ExecScreen ;
: cr    1 ExecScreen ;

\ stdout is the screen:

: _emit  begin 'TXbusy io@ while noop repeat 'TXbuf io! ;
: _cr    13 _emit 10 _emit ; \ --

11 |bits|
: stdout_table  exec1: [	\ The xts are less than 2048
    ' _emit | ' _cr 
] literal ; 

' stdout_table ScreenProfile !	\ assign it

\ iomap.c sends errors to the Chad interpreter
\ A QUIT loop running on the CPU would do something different.

:noname  ( error -- )  $8002 io! ; is exception

\ Examples

\ Use colorForth style of recursion
\ This kind of recursion is non-ANS.
\ We don't hide a word within its definition.

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - fib
    swap 2 - fib  + ;

\ Try 25 fib, then stats


\ Bit fields you can test with
\ They got broken when I changed to byte addressing, need to be fixed.

6 bvar base     10 base b!       \ to handle up to base 36
1 bvar state     0 state b!      \ yup
7 bvar percent  33 percent b!    \ for numbers 0 to 100
8 bvar mybyte   47 mybyte b!     \ an actual byte
16 bvar classic 12345 classic b! \ old school 16-bit value

' fib is cold

there . .( instructions used) cr
\ 0 there dasm
