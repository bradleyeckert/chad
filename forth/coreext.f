\ CORE EXT

there

0 equ false                             \ 2.1000 -- false
-1 equ true                             \ 2.1010 -- true

: within  over - >r - r> u< ;           \ 2.1020 x xlo xhi -- flag
: /string >r swap r@ + swap r> - ;      \ 2.1030 addr1 u1 n -- addr2 u2
: 0<>     0= 0= ; macro                 \ 2.1040 x y -- f
: 0>      negate 0< ;                   \ 2.1050 n -- f
: u>      swap u< ;                     \ 2.1060 u1 u2 -- flag
: 2>r     swap r> swap >r swap >r >r    \ 2.1070 d -- | -- d
; no-tail-recursion
: 2r>     r> r> swap r> swap >r swap    \ 2.1080 -- d | d --
; no-tail-recursion
: 2r@  r> r> r@ swap >r swap r@ swap >r \ 2.1090 -- d | d -- d
; no-tail-recursion
: third   >r >r dup r> swap r> swap ;   \ 2.1100 x1 x2 x3 -- x1 x2 x3 x1
: count   dup 1+ swap c@ ;              \ 2.1200 a -- a+1 c
: @+      dup cell+ swap @ ;            \ 2.1210 a -- a+cell u


: 2@   _@ _dup@ swap cell + @ swap ;    \ 2.1220 a-addr -- x1 x2
: 2!   _! cell + ! ;                    \ 2.1230 x1 x2 a-addr --

\ Add a cell to a double variable and carry into the upper part

: 2+!                                   \ 2.1240 n a-addr
    cell+  tuck @ +c over !
    carry if
        -cell +  1 swap +! exit
    then  drop
;

: d+   >r swap >r +c carry r> + r> + ;  \ 2.1130 d1 d2 -- d3
: d-   dnegate d+ ;                     \ 2.1140 d1 d2 -- d3
: d2*  swap 2* swap 2*c ;               \ 2.1150 d1 -- d2
: d=   d- or 0= ;                       \ 2.1170 d1 d2 -- flag

\ 2nip saves 1 inst by using w. Same trick isn't used with 2swap
\ because carry, a, and b are not safe across calls.

: 2swap  rot >r rot r> ;                \ 2.1190 abcd -- cdab
: 2nip   a! nip nip a ;
: 2over  >r >r 2dup r> r> 2swap ;
: 3drop  drop 2drop ;

: du<                                   \ 2.1180 ud1 ud2 -- flag
    rot  2dupxor
    if  2nip swap u< exit
    then    2drop u<                    \ hi part matches, test lo
;

there swap - . .( instructions used by core ext) cr

