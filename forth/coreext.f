\ CORE EXT

there

0 equ false								<a 6.2.1485 -- false>
-1 equ true								<a 6.2.2298 -- true>

: within over - >r - r> u< ;            <a 6.2.2440 u ulo uhi -- flag>
: <>     xor 0= 0= ;					<a 6.2.0500 n1 n2 -- flag>
: 0<>    0= 0= ; macro                  <a 6.2.0260 x y -- f>
: 0>     negate 0< ;                    <a 6.2.0280 n -- f>
: u>     swap u< ;                      <a 6.2.2350 u1 u2 -- flag>
: 2>r        swap r> swap >r swap >r >r <a 6.2.0340 d -- | -- d>
; no-tail-recursion
: 2r>        r> r> swap r> swap >r swap <a 6.2.0410 -- d | d -->
; no-tail-recursion
: 2r@  r> r> r@ swap >r swap r@ swap >r <a 6.2.0415 -- d | d -- d>
; no-tail-recursion

there swap - . .( instructions used by core ext) cr
