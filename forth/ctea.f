\ Chad Tiny Encryption Algorithm							9/19/20 BNE

\ XTEA-inspired crypto algorithm for Chad.
\ Uses 2-cell data and a 4-cell key.
\ For 18-bit cells, it's 36-bit data and a 72-bit key.

\ CTEA uses 71 instructions of code space.
\ The numeric conversion pointer `hld` is used as temporary storage.

there

\ Note: Key lengths over 56-bit may be subject to export controls.
\ The last cell in the table is 0 to make it a 54-bit key (if 18-bit cell).

align 4 cells buffer: CTkey
$179B9 equ CTdelta
18 equ CTrounds \ about 110 cycles per round

: CTshift  ( v -- v v' sum sum )
   dup 2* 2* 2* 2*  over 2/ 2/ 2/ 2/ 2/  xor  \ could be custom instruction
   over +  hld @  dup
;
: CTcalcA  CTshift [ ;
: CTdokey  3 and cells CTkey + @  +  xor  rot swap ;
: CTcalcB  CTshift  swapb 2/ 2/ 2/  CTdokey ;

: encipher  ( v0 v1 -- v0' v1' )
   0 hld !
   CTrounds for
      CTcalcA +
      CTdelta hld +!
      CTcalcB +
   next
   swap
;
: decipher  ( v0 v1 -- v0' v1' )
   [ CTdelta CTrounds * ] literal hld !
   CTrounds for
      CTcalcB -
      [ CTdelta negate ] literal  hld +!
      CTcalcA -
   next
;

there swap - . .( instructions used by ctea) cr
