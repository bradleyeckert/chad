empty decimal
0 equ 'TXbuf \ UART send output register
0 equ false  \ equates take up no code space. Have as many as you want.
-1 equ true

0 torg

defer cold  \ a forward reference to resolve with `is`.

CODE depth   status T->N d+1 alu  drop 31 imm  T&N d-1 RET alu  END-CODE
1234 depth   1 assert  1234 assert  \ sanity check the stack

CODE noop    T                      RET alu  END-CODE 
CODE xor     T^N            d-1     RET alu  END-CODE macro
CODE and     T&N            d-1     RET alu  END-CODE macro
CODE +       T+N    CO      d-1     RET alu  END-CODE macro
CODE -       N-T    CO      d-1     RET alu  END-CODE macro
CODE dup     T      T->N    d+1     RET alu  END-CODE macro
CODE drop    N              d-1     RET alu  END-CODE macro
CODE invert  ~T                     RET alu  END-CODE macro
CODE swap    N      T->N            RET alu  END-CODE macro
CODE over    N      T->N    d+1     RET alu  END-CODE macro
CODE nip     T              d-1     RET alu  END-CODE macro
CODE 0=      T0=                    RET alu  END-CODE macro
CODE 0<      T0<                    RET alu  END-CODE macro
CODE >r      N      T->R    d-1 r+1     alu  END-CODE macro
CODE r>      R      T->N    d+1 r-1     alu  END-CODE macro
CODE r@      R      T->N    d+1         alu  END-CODE macro
CODE 2*      T2*    CO              RET alu  END-CODE macro
CODE 2*c     T2*c   CO              RET alu  END-CODE macro
CODE 2/      T2/    CO              RET alu  END-CODE macro
CODE 2/c     cT2/   CO              RET alu  END-CODE macro
CODE carry   C      T->N    d+1     RET alu  END-CODE macro
CODE >carry  N      CO      d-1     RET alu  END-CODE macro
CODE w       W      T->N    d+1     RET alu  END-CODE macro
CODE >w      N      T->W    d-1     RET alu  END-CODE macro
CODE rshift  N>>T           d-1     RET alu  END-CODE macro
CODE lshift  N<<T           d-1     RET alu  END-CODE macro
CODE @       T                          alu
             [T]                    RET alu  END-CODE macro
CODE !       T      N->[T]  d-1         alu
             N              d-1     RET alu  END-CODE macro
CODE io@     T      _IORD_              alu
             T                          alu
             io[T]                  RET alu  END-CODE
CODE io!     T      N->io[T] d-1        alu
             T                          alu
             N              d-1     RET alu  END-CODE

\ Elided words
\ These words are supported by the hardware but are not
\ part of ANS Forth.  They are named after the word-pair
\ that matches their effect
\ Using these elided words instead of
\ the pair saves one cycle and one instruction.

CODE 2dupand   T&N   T->N          d+1 RET alu END-CODE macro
CODE 2dup+     T+N   T->N          d+1 RET alu END-CODE macro
CODE 2dupxor   T^N   T->N          d+1 RET alu END-CODE macro
CODE dup>r     T     T->R      r+1         alu END-CODE macro
CODE overand   T&N                     RET alu END-CODE macro
CODE over+     T+N   CO                RET alu END-CODE macro
CODE over-     N-T   CO                RET alu END-CODE macro
CODE overxor   T^N                     RET alu END-CODE macro
CODE rdrop     T                   r-1     alu END-CODE macro
CODE tuck!     T     N->[T]        d-1 RET alu END-CODE macro
CODE +c        T+Nc  CO            d-1 RET alu END-CODE macro
CODE dup@      T                           alu
			   [T]   T->N          d+1     alu END-CODE macro

: =  xor 0= ;

cellbits 32 = [if]
: cells 2* 2* ; macro
: cell+ 4 + ; macro
: c@  dup@ swap 3 and 3 lshift rshift $FF and ;
: w@  dup@ swap 2 and 3 lshift rshift $FFFF and ;
: (x!)  ( u w-addr bitmask wordmask )
	>w swap
	dup>r and 3 lshift dup>r lshift 
	w r> lshift invert
    r@ @ and  + r> !
;

: w! ( u w-addr -- )  2 $FFFF (x!) ;
: c! ( u w-addr -- )  3 $FF   (x!) ;
[else]
: cells 2* ; macro
: cell+ 2 + ; macro
: c@  dup@ swap 1 and 3 lshift rshift $FF and ;
: c! ( u c-addr -- )
    dup>r 1 and if
        8 lshift  $00FF
    else
        255 and   $FF00
    then
    r@ @ and  + r> !
;
[then]  \ m 1 

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
: or    invert swap invert and invert ; \ n t -- n|t

: 2dup  over over ; macro \ d -- d d
: 1+ 1 + ; macro
: 1- 1 - ; macro
: <>                xor 0= 0= ;   \ 6.2.0500  x y -- f
: 0<>                   0= 0= ; macro   \ 6.2.0260  x y -- f
: negate            invert 1+ ;
: 0>                negate 0< ;   \ 6.2.0280  n -- f
: abs   dup 0< if negate then ;   \ 6.1.0690  n -- u
: execute                  >r ;   \ 6.1.1370  xt --

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
    0 [ cellbits 2/ ] literal			\ cell is an even number of bits
    for (um*) (um*) next
    >r nip r> swap
;

\ Long division takes about 340 cycles at 16-bit.
\ Latency = 25
: (um/mod)
    >r  swap 2*c swap 2*c           	\ 2dividend | divisor
    carry if	
        r@ -   0 >carry
    else	
        dup r@  - drop              	\ test subtraction
        carry 0= if  r@ -  then     	\ keep it
    then
    r>  carry    						\ carry is safe on the stack 
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

: d2*  swap 2* swap 2*c ;
: d2/  2/ swap 2/c swap ;
: dnegate  invert swap invert 1 + swap 0 +c ;
: dabs  dup 0< if dnegate then ;
: rot   >r swap r> swap ;
: -rot  swap >r swap r> ;
: tuck  swap over ;
: 2drop drop drop ;
: ?dup  dup if dup then ;
: +!    tuck @ + swap ! ;
: 2swap rot >r rot r> ;
: 2over >r >r 2dup r> r> 2swap ;

: sm/rem  \ d n -- rem quot             \ 6.1.2214
   2dup xor >r  over >r  abs >r dabs r> um/mod
   swap r> 0< if  negate  then
   swap r> 0< if  negate  then ;

: fm/mod  \ d n -- rem quot             \ 6.1.1561
   dup >r  2dup xor >r  dup >r  abs >r dabs r> um/mod
   swap r> 0< if  negate  then
   swap r> 0< if  negate  over if  r@ rot -  swap 1-  then then
   r> drop ;

\ eForth model
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


: <   - 0< ;
: u<  - drop carry 0= 0= ;

: min    over over- 0< if swap drop exit then  drop ; \ 6.1.1870
: max    over over- 0< if drop exit then  swap drop ; \ 6.1.1880
: (umin)  over over- drop carry ;
: umin   (umin) if swap drop exit then  drop ;
: umax   (umin) if drop exit then  swap drop ;

: /string >r swap r@ + swap r> - ;      \ 17.6.1.0245  a u -- a+1 u-1
: within  over - >r - r> u< ;           \ 6.2.2440  u ulo uhi -- flag
: m*                                    \ 6.1.1810  n1 n2 -- d
    2dup xor 0< >r
    abs swap abs um*
    r> if dnegate then
;
: */mod  >r m* r> m/mod ;               \ 6.1.0110  n1 n2 n3 -- remainder n1*n2/n3
: */     */mod swap drop ;              \ 6.1.0100  n1 n2 n3 -- n1*n2/n3

\ Now let's get some I/O set up

: emit  'TXbuf io! ; \ c -- \ To terminal


1000 100 xor  908 assert
1000 100 and   96 assert
1000 100 +   1100 assert
1000 100 -    900 assert
100 dup  100 assert  drop
depth 0 assert
123 456 swap  123 assert 456 assert
123 456 over  123 assert 456 assert 123 assert
depth 0 assert
2 3 d2* 6 assert 4 assert
-1 5 d2* 11 assert -2 assert
-5 -7 d2/ -4 assert -3 assert
depth 0 assert
\ Note: Data memory is byte-addressed, allow 4-byte cells
123 4 !  456 8 !  4 @ 123 assert  8 @ 456 assert
depth 0 assert

\ Use colorForth style of recursion
\ This kind of recursion is non-ANS.
\ We don't hide a word within its definition.

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - fib
    swap 2 - fib  + ;

\ Try 25 fib, then stats

\ sample lookup tables are built with code (you can't read code space)
\ Notice the fall-through of exec2:.
\ `;` in immediate mode does not compile a return.

: exec2: 2* [ ;       \ for list of 2-cell literals
: exec:  2* r> + >r ; \ for list of 1-cell literals

cellbits |bits|
: table  exec2: [ 123 | 456 | 789 | 321 ] literal ;
11 |bits|
: table1  exec: [ 123 | 456 | 789 | 321 ] literal ;
cellbits |bits|

\ Bit fields you can test with

6 bvar base     10 base b!       \ to handle up to base 36
1 bvar state     0 state b!      \ yup
7 bvar percent  33 percent b!    \ for numbers 0 to 100
8 bvar mybyte   47 mybyte b!     \ an actual byte
16 bvar classic 12345 classic b! \ old school 16-bit value

' fib is cold

there . .( instructions used) cr
\ 0 there dasm
