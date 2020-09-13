\ CORE EXT

there

0 equ false								\ 2.1000 -- false
-1 equ true								\ 2.1010 -- true

: within over - >r - r> u< ;            \ 2.1020 u ulo uhi -- flag
: <>     xor 0= 0= ;					\ 2.1030 n1 n2 -- flag
: 0<>    0= 0= ; macro                  \ 2.1040 x y -- f
: 0>     negate 0< ;                    \ 2.1050 n -- f
: u>     swap u< ;                      \ 2.1060 u1 u2 -- flag
: 2>r        swap r> swap >r swap >r >r \ 2.1070 d -- | -- d
; no-tail-recursion
: 2r>        r> r> swap r> swap >r swap \ 2.1080 -- d | d --
; no-tail-recursion
: 2r@  r> r> r@ swap >r swap r@ swap >r \ 2.1090 -- d | d -- d
; no-tail-recursion

there swap - . .( instructions used by core ext) cr
