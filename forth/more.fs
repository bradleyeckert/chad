: ?dup  dup if dup then ;
: d2*   swap 2* swap 2*c ;
: d2/   2/ swap 2/c swap ;
: -rot  swap >r swap r> ;
: 2drop drop drop ;
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
   
: (umin)  over over- drop carry ;
: umin   (umin) if swap drop exit then  drop ;
: umax   (umin) if drop exit then  swap drop ;
: /string >r swap r@ + swap r> - ;      \ 17.6.1.0245  a u -- a+1 u-1

depth 0 assert
2 3 d2* 6 assert 4 assert
-1 5 d2* 11 assert -2 assert
-5 -7 d2/ -4 assert -3 assert
