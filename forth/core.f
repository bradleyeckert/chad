\ Core definitions

\ You can compile to either check address alignment or not.
\ Set to 0 when everything looks stable. The difference is 25 instructions.

0 equ check_alignment 					<a checkalign>
\ enable @, !, w@, and w! to check address alignment

0 torg
later cold  	                        <a cold -->        \ boots here
later exception                         <a exception n --> \ error detected

: noop  nop ;							<a 1.6000 -->
: io@   _io@ nop _io@_ ;				<a 1.6010 addr -- n>
: io!   _io! nop drop ;					<a 1.6020 n addr -->
: =     xor 0= ;						<a 6.1.0530 n1 n2 -- flag>
: <     - 0< ; macro					<a 6.1.0480 n1 n2 -- flag>
: >     swap < ;						<a 6.1.0540 n1 n2 -- flag>
: cell+ cell + ; macro					<a 6.1.0880 addr1 -- addr2>
: rot   >r swap r> swap ;				<a 6.1.2160 x1 x2 x3 -- x2 x3 x1>

: c@    _@ dup@ swap mask rshift wand ; <a 6.1.0870 addr -- c>

cell 4 = [if]
    : cells 2* 2* ; macro				<a 6.1.0890 n -- n*4>
    : (x!)  ( u w-addr bitmask wordmask )
        >carry swap
        dup>r and 3 lshift dup>r lshift
        w r> lshift invert
        r@ _@ _@_ and  + r> _! drop
    ;
    : c!  ( u c-addr -- ) 3 $FF  (x!) ; <a 6.1.0850 c addr -->
  check_alignment [if]
    : (ta)  ( a mask -- a )
          over and if  22 invert exception  then ;
    : @   3 (ta)  _@ _@_ ;				<a 6.1.0650 addr -- x>
    : !   3 (ta)  _! drop ;				<a 6.1.0010 x addr -->
    : w!  ( u w-addr -- )
          1 (ta) 2 $FFFF (x!) ;
    : w@  ( w-addr -- u )
          1 (ta) _@ dup@ swap 2 and 3 lshift rshift $FFFF and ;
  [else]
    : @   _@ _@_ ; macro			    <a 6.1.0650 addr -- x>
    : !   _! drop ; macro				<a 6.1.0010 x addr -->
    : w!  2 $FFFF (x!) ;
    : w@  _@ dup@ swap 2 and 3 lshift rshift $FFFF and ;
  [then]
[else] \ 16-bit or 18-bit cells
    : cells 2* ; macro					<a 6.1.0890 n -- n*2>
  check_alignment [if]
    : (ta)  over and if  22 invert exception  then ;
    : @   1 (ta)  _@ _@_ ;		    	<a 6.1.0650 addr -- x>
    : !   1 (ta)  _! drop ;				<a 6.1.0010 x addr -->
  [else]
    : @   _@ _@_ ; macro			    <a 6.1.0650 addr -- x>
    : !   _! drop ; macro				<a 6.1.0010 x addr -->
  [then]
    : c! ( u c-addr -- )				<a 6.1.0850 c addr -->
        dup>r 1 and if
            8 lshift  $00FF
        else
            255 and   $FF00
        then
        r@ _@ _@_ and  + r> _! drop
    ;
[then]

\ Your code can usually use + instead of OR, but if it's needed:
: or    invert swap invert and invert ; <a 6.1.1980 n m -- n|m>

: execute  2* >r ; no-tail-recursion 	<a 6.1.1370 xt -->

: 2dup   over over ; macro              <a 6.1.0380 d -- d d>
: 2drop  drop drop ;                    <a 6.1.0370 d -->
: char+ [ ;								<a 6.1.0897 a -- a+1>
: 1+     1 + ; ( macro )				<a 6.1.0290 n -- n+1>
: 1-     1 - ; ( macro )				<a 6.1.0300 n -- n-1>
: negate invert 1+ ;					<a 6.1.1910 n -- -n>
: tuck   swap over ; macro              <a 6.2.2300 n1 n2 -- n2 n1 n2>
: +!     tuck @ + swap ! ;				<a 6.1.0130 x addr -->

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
: um*  									<a 6.1.2360 u1 u2 -- ud>
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
: um/mod                                <a 6.1.2370 ud u -- ur uq>
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

: *     um* drop ;                      <a 6.1.0090 n1 n2 -- n3>
: dnegate                               <a 8.6.1.1230  d -- -d>
        invert swap invert 1 + swap 0 +c ;
: abs   dup 0< if negate then ;			<a 6.1.0690 n -- u>
: dabs  dup 0< if dnegate then ;        <a 8.6.1.1160 n -- u>

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
: /mod   over 0< swap m/mod ;           <a 6.1.0240 n1 n2 -- rem quot>
: mod    /mod drop ;                    <a 6.1.1890 n1 n2 -- rem>
: /      /mod nip ;                     <a 6.1.0230 n1 n2 -- quot>
: m*                                    <a 6.1.1810 n1 n2 -- d>
    2dup xor 0< >r
    abs swap abs um*
    r> if dnegate then
;
: */mod  >r m* r> m/mod ;               <a 6.1.0110 n1 n2 n3 -- rem n1*n2/n3>
: */     */mod swap drop ;              <a 6.1.0100 n1 n2 n3 -- n1*n2/n3>

\ In order to use CREATE DOES>, we need ',' defined here.

dp cell+ dp ! \ variables shared with chad's interpreter
variable base							<a 6.1.0750 -- addr>
variable state							<a 6.1.2250 -- addr>
align
: aligned  [ cell 1- ] literal +		<a 6.1.0706 addr1 -- addr2>
           [ cell negate ] literal and ;
: align    dp @ aligned dp ! ;			<a 6.1.0705 -->
: allot    dp +! ;						<a 6.1.0710 n -->
: here     dp @ ;						<a 6.1.1650 -- addr>
: ,        align here !  cell allot ;	<a 6.1.0150 x -->
: c,       here c!  1 allot ;			<a 6.1.0860 c -->

\ We're about at 300 instructions at this point.
\ Paul Bennett's recommended minimum word set is mostly present.
\ DO, I, J, and LOOP are not included. Use for next r@ instead.
\ CATCH and THROW are not included. They use stack.
\ DOES> needs a compilable CREATE.

: u<     - drop carry 0= 0= ;			<a 6.1.2340 u1 u2 -- flag>
: min    over over- 0< if   			<a 6.1.1870 n1 n2 -- n3>
         swap drop exit then  drop ;
: max    over over- 0< if  				<a 6.1.1880 n1 n2 -- n3>
         drop exit then  swap drop ;

CODE depth								<a 6.1.1200 -- n>
    status T->N d+1 alu   drop 31 imm   T&N d-1 RET alu
END-CODE

: exec2: 2* [ ;             <a tables>	\ for list of 2-inst literals
: exec1: 2* r> + >r ;       <a tables>	\ for list of 1-inst literals

there . .( instructions used by core) cr
