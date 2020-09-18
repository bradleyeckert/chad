\ CORE EXT

there

0 equ false                             \ 2.1000 -- false
-1 equ true                             \ 2.1010 -- true

: within over - >r - r> u< ;            \ 2.1020 x xlo xhi -- flag
: /string >r swap r@ + swap r> - ;      \ 2.1030 addr1 u1 n -- addr2 u2
: 0<>    0= 0= ; macro                  \ 2.1040 x y -- f
: 0>     negate 0< ;                    \ 2.1050 n -- f
: u>     swap u< ;                      \ 2.1060 u1 u2 -- flag
: 2>r        swap r> swap >r swap >r >r \ 2.1070 d -- | -- d
; no-tail-recursion
: 2r>        r> r> swap r> swap >r swap \ 2.1080 -- d | d --
; no-tail-recursion
: 2r@  r> r> r@ swap >r swap r@ swap >r \ 2.1090 -- d | d -- d
; no-tail-recursion
: third  >r >r dup r> swap r> swap ;    \ 2.1100 x1 x2 x3 -- x1 x2 x3 x1

\ lshift and rshift are hardly ever used so they are slow

: lshift  								\ 2.1110 x1 u -- x2
    dup if  for  2*  next  exit
    then drop
;

: rshift  								\ 2.1120 x1 u -- x2
    dup if  for  0 >carry 2/c  next  exit
    then drop
;

there swap - . .( instructions used by core ext) cr
