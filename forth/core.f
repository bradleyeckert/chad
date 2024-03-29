\ Core definitions

\ You can compile to either check address alignment or not.
\ Set to 1 for testing, 0 otherwise.

0 equ check_alignment                   \ 2.0000 -- n
\ enable @, !, w@, and w! to check address alignment

0 cp _! drop
later coldboot                          \ 2.0010 -- \ boots here
later irqtick
\ space for 14 more interrupt vectors
:noname exit exit exit exit exit ; drop \ inactive interrupt vectors
:noname exit exit exit exit exit exit exit ; drop
later trap0                             \ reserved
later api_trap
later api_recover                       \ RET has its address's LSB set

later throw                             \ 2.0020 n --

: noop  nop ;                           \ 2.0100 --
: -     invert 1 + + ;                  \ 1.2090 n1 n2 -- n3

\ The I/O is allowed to drop CKE on the processor.
\ Allow for code memory to double-feed the instruction following the pause
\ by putting a nop there. Such an allowance is not made for data memory.
: io@   _io@ nop _io@_ ;                \ 2.0110 addr -- n
: io!   _io! nop drop ;                 \ 2.0120 n addr --

: =     xor 0= ;                        \ 2.0130 n1 n2 -- flag
: <>     xor 0= 0= ;                    \ 2.0135 n1 n2 -- flag
: <     - 0< ; macro                    \ 2.0140 n1 n2 -- flag
: >     swap < ;                        \ 2.0150 n1 n2 -- flag
: cell+ cell + ; macro                  \ 2.0160 a-addr1 -- a-addr2

cell 4 = [if]
    : cells 2* 2* ; macro               \ 2.0170 n1 -- n2
    : cell/ 2/ 2/ ; macro               \ 2.0171 n1 -- n2
    : _cw!  \ end a c! or w!            \ u mask addr
        >r  swap over and               \ m u' | addr
        swap invert                     \ u' mask | addr
        r@  _@ _@_  and  +
        r>  _! drop
    ;
    : c! ( u c-addr -- )                \ 2.0180 c c-addr --
        dup>r 2 and if
            r@ 1 and if  swapw  swapb  $FF000000
            else         swapw         $FF0000
            then
        else
            r@ 1 and if  swapb         $FF00
            else                       $FF
            then
        then
        r> _cw!
    ;
    : c@                                \ 2.0200 c-addr -- c
        _@ _dup@
        over 1 and if swapb then
        swap 2 and if swapw then
        $FF and
    ;

  check_alignment [if]
    : (ta)  ( a mask -- a )
          over and if  22 invert throw  then ;
    : @   3 (ta)  _@ _@_ ;              \ 2.0210 a-addr -- x
    : !   3 (ta)  _! drop ;             \ 2.0200 x a-addr --
    : w!  ( u w-addr -- )               \ 2.0190 w addr --
        1 (ta)
        dup>r 2 and if  swapw  $FFFF0000
        else  $FFFF  then
        r> _cw!
    ;
    : w@  ( w-addr -- u )               \ 2.0220 addr -- w
        1 (ta)
        _@ _dup@  swap 2 and if swapw then
        $FFFF and
    ;
  [else]
    : @   _@ _@_ ;  ( macro )           \ 2.0210 a-addr -- x
    : !   _! drop ; ( macro )           \ 2.0200 x a-addr --
    : w! ( u c-addr -- )                \ 2.0190 w w-addr --
        dup>r 2 and if  swapw  $FFFF0000
        else  $FFFF  then
        r> _cw!
    ;
    : w@                                \ 2.0220 w-addr -- w
        _@ _dup@  swap 2 and if swapw then
        $FFFF and
    ;
  [then]
[else] \ 16-bit or 18-bit cells
    : cells 2* ; macro                  \ 2.0170 n1 -- n2
    : cell/ 2/ ; macro                  \ 2.0171 n1 -- n2
  check_alignment [if]
    : (ta)  over and if  22 invert throw  then ;
	: w@  [ ;
    : @   1 (ta)  _@ _@_ ;              \ 2.0210 a-addr -- x
	: w!  [ ;
    : !   1 (ta)  _! drop ;             \ 2.0200 x a-addr --
  [else]
	: w@  [ ;
    : @   _@ _@_ ; ( macro )            \ 2.0210 a-addr -- x
	: w!  [ ;
    : !   _! drop ; ( macro )           \ 2.0200 x a-addr --
  [then]
    : c! ( u c-addr -- )                \ 2.0180 c c-addr --
        dup>r 1 and if  swapb  $FF00  else  $FF  then
        swap over and                   \ m u' | addr
        swap invert                     \ u' mask | addr
        r@ _@ _@_ and  +
        r> _! drop
    ;
    : c@                                \ 2.0200 c-addr -- c
        _@ _dup@  swap 1 and if swapb then
        $FF and
    ;
[then]

\ Your code can usually use + instead of OR, but if it's needed:
: or    invert swap invert and invert ; \ 2.0300 n m -- n|m
: rot   >r swap r> swap ;               \ 2.0310 x1 x2 x3 -- x2 x3 x1

: execute  >r ; no-tail-recursion       \ 2.0320 i*x xt -- j*x
: ?dup   dup if dup then ;              \ 2.0325 x -- 0 | x x
: 2dup   over over ; ( macro )          \ 2.0330 d -- d d
: 2drop  drop drop ;                    \ 2.0340 d --
: char+ [ ;                             \ 2.0350 c-addr1 -- c-addr2
: 1+     1 + ;  ( macro )               \ 2.0360 n -- n+1
: 1-    -1 + ;  ( macro )               \ 2.0370 n -- n-1
: negate invert 1+ ;                    \ 2.0380 n -- -n
: tuck   swap over ;  ( macro )         \ 2.0390 n1 n2 -- n2 n1 n2
: +!     tuck @ + swap ! ;              \ 2.0400 n a-addr --
: ?exit  if rdrop then ; no-tail-recursion \ flag --
: d2/    2/ swap 2/c swap ;             \ 2.1160 d1 -- d2

\ This really comes in handy, although there is a small (9T) time penalty.
: times                                 \ 2.0405 n xt --
   swap dup 1- 0< if  2drop exit  then  \ do 0 times
   for  dup>r execute r>  next          \ do 1 or more times
   drop
;

: cowait  ( -- )                        \ wait until coprocessor finishes
   [ 0 cotrig ] begin costat while noop repeat
;

\ Math iterations are subroutines to minimize the latency of lazy interrupts.
\ These interrupts modify the RET operation to service ISRs.
\ RET ends the scope of carry and W so that ISRs may trash them.
\ Latency is the maximum time between returns.

hwoptions 1 and [if]                    \ hardware multiply?
: um*                                   \ 2.0410 u1 u2 -- ud
   [ cellbits 1-  2* 2* 2* 2* 2*  $12 +  cotrig ]
   2drop  cowait                        \ um* is a special case of fractional *
   [ 3 cotrig ]  costat
   [ 2 cotrig ]  costat
;
[else]

\ Multiplication using shift-and-add, 160 to 256 cycles at 16-bit.
\ Latency = 17
: (um*)
   2* >r 2*c carry
   if  over r> +c >r carry +
   then  r>
;
: um*                                   \ 2.0410 u1 u2 -- ud
   0 [ cellbits 2/ ] literal            \ cell is an even number of bits
   for (um*) (um*) next
   >r nip r> swap
;
[then]

hwoptions 2 and [if]                    \ hardware divide?
: um/mod                                \ 2.0420 ud u -- ur uq
   a! [ $14 cotrig ]  2drop cowait
   [ 5 cotrig ]  costat
   [ 4 cotrig ]  costat
;
[else]
\ Long division takes about 340 cycles at 16-bit.
\ Latency = 25
: (um/mod)
   >r  swap 2*c swap 2*c                \ 2dividend | divisor
   carry if
      r@ -   0 >carry
   else
      dup r@  swap invert +c invert     \ test subtraction
      carry if drop else nip then
   then
   r> carry                             \ carry is safe on the stack
;

: um/mod                                \ 2.0420 ud u -- ur uq
   2dup swap invert +c drop carry 0=
   if  drop drop dup xor
       dup invert  exit                 \ overflow = 0 -1
   then
   [ cellbits 2/ ] literal
   for (um/mod) >carry
       (um/mod) >carry
   next
   drop swap 2*c invert                 \ finish quotient
;
[then]

hwoptions 4 and [if]                    \ hardware shifter?
: )dshift                               \ d1 -- d2
   2drop  cowait                        \ SL1_011x
   [ 7 cotrig ]  costat
   [ 6 cotrig ]  costat
;
: drshift                               \ d1 u -- d2
   a!  [ $56 cotrig ]  )dshift
;
: dlshift                               \ d1 u -- d2
   a!  [ $36 cotrig ]  )dshift
;
: lshift  over swap dlshift drop ;	\ 2.1110 x1 u -- x2
: rshift  0 swap drshift drop ;		\ 2.1120 x1 u -- x2

[else]
: lshift  				\ 2.1110 x1 u -- x2
    dup if  for  2*  next  exit
    then drop
;
: rshift  				\ 2.1120 x1 u -- x2
    dup if  for  0 >carry 2/c  next  exit
    then drop
;
: drshift  				\ 2.1130 d1 u -- d2
    dup if  for  d2/  next  exit
    then drop
;
[then]

: *     um* drop ;                      \ 2.0430 n1 n2 -- n3
: dnegate                               \ 2.0440 d -- -d
        invert swap invert 1 +c swap carry + ;
: abs   dup 0< if negate then ;         \ 2.0450 n -- u
: dabs  dup 0< if dnegate then ;        \ 2.0460 d -- ud

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
: /mod   over 0< swap m/mod ;           \ 2.0470 n1 n2 -- rem quot
: mod    /mod drop ;                    \ 2.0480 n1 n2 -- rem
: /      /mod nip ;                     \ 2.0490 n1 n2 -- quot
: m*                                    \ 2.0500 n1 n2 -- d
    2dup xor 0< >r
    abs swap abs um*
    r> if dnegate then
;
: */mod  >r m* r> m/mod ;               \ 2.0510 n1 n2 n3 -- rem quot
: */     */mod swap drop ;              \ 2.0520 n1 n2 n3 -- n4

: aligned  [ cell 1- ] literal +        \ 1.1050 addr1 -- addr2
           [ cell negate ] literal and ;
: align    dp @ aligned dp ! ;          \ 1.1060 --
: allot    dp +! ;                      \ 2.0550 n --
: here     dp @ ;                       \ 2.0560 -- addr
: ,        align here !  cell allot ;   \ 2.0570 x --
: w,       here w!  2 allot ;           \ 2.0590 c --

\ Paul Bennett's recommended minimum word set is mostly present.
\ DO, I, J, and LOOP are not included. Use for next r@ instead.
\ CATCH is not included. THROW jumps directly to QUIT.
\ DOES> needs a compilable CREATE.

: u<  swap invert +c drop carry 0= 0= ; \ 2.0700 u1 u2 -- flag
: min    2dup - 0< if                   \ 2.0710 n1 n2 -- n3
         drop exit then  swap drop ;
: max    2dup - 0< if                   \ 2.0720 n1 n2 -- n3
         swap drop exit then  drop ;

CODE depth                              \ 2.0730 -- +n
    status T->N s+ alu   drop 31 imm   T&N s- ret alu
;CODE

there . .( instructions used by core) cr
