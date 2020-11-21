\ Extra words that I don't really use

: -rot  swap >r swap r> ;

: sm/rem  \ d n -- rem quot             \ 6.1.2214
   2dup xor >r  over >r  abs >r dabs r> um/mod
   swap r> 0< if  negate  then
   swap r> 0< if  negate  then ;

: fm/mod  \ d n -- rem quot             \ 6.1.1561
   dup >r  2dup xor >r  dup >r  abs >r dabs r> um/mod
   swap r> 0< if  negate  then
   swap r> 0< if  negate  over if  r@ rot -  swap 1-  then then
   r> drop ;

: (umin)  over over- drop carry ;
: umin   (umin) if swap drop exit then  drop ;
: umax   (umin) if drop exit then  swap drop ;

: roll                                  \ 2.2980 xu..x0 u -- xu-1..x0 xu
    ?dup if
        1+  frp @  ds>mem  mem>
        1-  over cell -                 ( a u' 'xu )
        dup @ >r  !
        mem>ds drop  r>
    then
;

hex
\ Attempt to convert utf-8 code point
: nextutf8  \ n a -- n' a'              \ add to utf-8 xchar
   >r 6 lshift r> count                 \ expect 80..BF
   dup 0C0 and 80 <> -0D and throw  \ n' a c
   3F and  swap >r  +  r>
;
: isutf8  \ addr len -- xchar
   over c@ 0F0 <  over 1 = and  if      \ plain ASCII
      drop c@ exit
   then
   over c@ 0E0 <  over 2 = and  if      \ 2-byte utf-8
      drop count 1F and  swap  nextutf8
      drop exit
   then
   over c@ 0F0 <  over 3 = and  if      \ 3-byte utf-8
      drop count 1F and  swap  nextutf8  nextutf8
      drop exit
   then
   -0D throw
;
decimal
