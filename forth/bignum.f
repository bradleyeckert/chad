\ Double Number Arithmetic by Wil Baden, tweaked by Brad Eckert
\
\ TUM* TUM/ triple Unsigned Mixed Multiply and Divide.
\
\ T+ T- triple Add and Subtract.
\
\ DU/MOD Double Unsigned Division with Remainder.  Given an unsigned 2-
\ cell dividend and an unsigned 2-cell divisor,  return a 2-cell
\ remainder and a 2-cell quotient.  The algorithm is based on Knuth's
\ algorithm in volume 2 of his Art of Computer Programming, simplified
\ for two-cell dividend and two-cell divisor.

there
applets [if] .(     Applet bytes: { )   \ }
paged applet  paged [then]

: +carry  ( a b -- a+b carry )          \ 0 tuck d+
   +c carry                             \ speeds up t
;
: -borrow ( a b -- a-b borrow )         \ 0 tuck d-
   swap invert +c invert carry negate   \ speeds up t-
;

: tum* ( n . mpr -- t . . ) 2>r  r@ um*  0 2r>  um* d+ ;
: tum/ ( t . . dvr -- n . ) dup >r um/mod r> swap >r um/mod nip r> ;

: t+  ( t1 . . t2 . . -- t3 . . )
   >r rot >r  >r swap >r +carry  0 r> r> +carry d+ r> r> + +
;
: t-  ( t1 . . t2 . . -- t3 . . )
   >r rot >r  >r swap >r -borrow  s>d r> r> -borrow d+ r> r> - +
;

: normalize-divisor  ( divr . -- divr' . shift )
   0 >r  begin  dup 0< 0=  while
      d2*  r> 1+ >r
   repeat  r> ;

: du/mod ( divd . divr . -- rem . quot . )
   4 stack(
   ?dup 0= if  ( there is a leading zero "digit" in divisor. )
      >r  0 r@ um/mod  r> swap >r  um/mod  0 swap r>  )stack exit
   then  normalize-divisor dup >r rot rot 2>r
   1 swap lshift tum*
   ( guess leading "digit" of quotient. )
   dup  r@ = if  -1  else  2dup  r@ um/mod nip  then
   ( multiply divisor by trial quot and subtract from divd. )
   2r@  rot dup >r  tum*  t-
   dup 0< if ( if negative, decrement quot and add to dividend. )
      r> 1-  2r@  rot >r  0 t+
      dup 0< if ( if still negative, do it one more time. )
         r> 1-  2r@  rot >r  0 t+
   then  then ( undo normalization of dividend to get remainder. )
   r>  2r> 2drop  1 r>  rot >r  lshift tum/  r> 0  )stack
;

\ Ratio search, based on the Farey sequence, by Brad Eckert
\
\ Given an unsigned double number `frac` between 0 and 1 scaled to
\ 2^(2*cellsize) = 1, find two integers that fit into a specified bit
\ width and most closely approximate `frac` using unsigned integer
\ division.
\
\ For vast majority of cases, a very accurate fraction can be found.
\ Less than 0.1% of the time, there is significant error.
\ If you can work around these cases, it's a good way to get very
\ precise scale factors.

2variable ratio_x1                      \ a c
2variable ratio_x2                      \ b d
2variable expected                      \ unsigned 0 to 1
variable maxden                         \ maximum allowed denominator

: dfrac  ( num denom -- d_frac )        \ (num << (2*b/cell)) / den
   >r >r 0 dup r> r> tum/
;
: exhausted?  ( -- flag )               \ finished with search?
   ratio_x2 2@  maxden @ u<  swap maxden @ u<  and 0=
;
: /ratio  ( maxden -- )                 \ initialize
   maxden !
   0 1 ratio_x1 2!
   1 1 ratio_x2 2!
;
: ratio/  ( flag -- n d )
   0=  cell and                         \ true returns c d
   dup>r ratio_x1 + @  ratio_x2 r> + @  \ false returns a b
;

\ Find the (num, den) pair that best satisfies frac = num / den.
\ `bits` is the width of the num and den results.
\ Don't search for anything very close to 0, it will take forever.

: ratio  ( d_frac maxden -- num den )
   3 stack(
   /ratio  expected 2!
   begin
      ratio_x1 2@ +  ratio_x2 2@ +  2dup dfrac    \ a+c b+d d_actual
      2dup expected 2@ d= if            \ exact match
         2drop  dup
         maxden @ u< if exit then       \ a+c b+d
         2drop  ratio_x2 2@ u< ratio/  exit
      then
      expected 2@ du<  cell and
      dup>r ratio_x2 + !  r> ratio_x1 + !
   exhausted? until
   ratio_x2 @ maxden @ u<  ratio/
   )stack
;

\ For 24-bit cells and 20-bit results, you can usually get to within
\ 0.01 PPB on the approximation of d_frac. The error of the compound
\ number (a + b/c) would be less by a factor of a.
\
\ Examples on a 24-bit machine:
\ 100000000005000. 1048575 ratio swap . .  \ dfrac = 323978 / 911917
\ 100000000005500. 1048575 ratio swap . .  \ dfrac = 194159 / 546509
\
\ `ud*` supports scaling of d_frac at this precision.

applets [if] end-applet  paged swap - . .( }; ) [then]

\ Probably want this in the kernel to keep it fast.
\ A short applet would save 40 instructions.

: d+c  ( d1 d2 -- d3 carry )            \ double add with carry out
   >r swap >r +c  carry r> +  r> +c carry
;

\ Unsigned double * double -> quad product
: ud*  ( ud1 ud2 -- uq )
   over >r  ratio_x2 2!
   over >r  ratio_x1 2!  r> r>  um*
   ratio_x1 @  dup>r
   ratio_x2 @  dup>r  um*               \ d_low d_hi | H1 H2
   r> [ ratio_x1 cell + ] literal @ um*
   r> [ ratio_x2 cell + ] literal @ um*  d+c  t+
;

there swap - . .( instructions used by bignum) cr
