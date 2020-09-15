\ Numeric conversion and text I/O
\ The buffer for numeric conversion is at the very top of data space.
\ The output string grows downward in memory.

there
decimal
variable hld                            \ 2.3000 -- c-addr
32 equ bl                               \ 2.3010 -- char

: count   dup 1+ swap c@ ;              \ 2.3110 a u -- a+1 u-1
: decimal 10 base ! ;
: hex     16 base ! ;
: type    dup if                        \ 2.3140 c-addr u --
            for  count emit  next  drop
          else  2drop
          then
;
: s>d     dup 0< ;                      \ 2.3150 n -- d
: space   bl emit ;                     \ 2.3160 --
: spaces  dup 1- 0< if  drop exit  then \ 2.3170 n --
          for space next ;

\ Numeric conversion. `d.r` uses frame stack protection to prevent overflow
\ when the stacks have significant content. Since `d.r` ia typically at the
\ end of a definition, its tail call doesn't increase the stack.

: digit   dup 10 - 0< 6 invert and      \ 2.3180 n -- char
          + [char] 7 + ;
: <#      dm-size  hld ! ;              \ 2.3190 ud1 -- ud1
: hold    hld dup >r @ 1- dup r> ! c! ; \ 2.3200 char --
: _#_     um/mod swap digit hold ;
: #       dup  base @ >r  if            \ 2.3210 ud1 -- ud2
              0 r@ um/mod r> swap
              >r _#_ r> exit
          then  r> _#_ 0
;
: #s      begin # 2dup or 0= until ;    \ 2.3220 ud1 -- ud2
: sign    0< if [char] - hold then ;    \ 2.3230 n --
: #>      2drop hld @ dm-size over - ;  \ 2.3240 ud -- c-addr u
: s.r     over - spaces type ;          \ length width --
: d.r     3 f[ >r dup >r dabs           \ 2.3250 d width --
          <# #s r> sign #> r> s.r ]f ;  \ prevent stack overflow
: u.r     0 swap d.r ;                  \ 2.3260 u width --
: .r      >r s>d r> d.r ;               \ 2.3270 n width --
: d.      0 d.r space ;                 \ 2.3280 d --
: u.      0 d. ;                        \ 2.3290 u --
: ?       @ [ ;                         \ 2.3310 a --
: .       s>d d. ;                      \ 2.3300 n --
: <#>     >r  <# begin # next #s #> ;   \ ud digits-1
: h.x     base @ >r hex  0 swap <#> r>  \ 2.3320 u n --
          base !  type space ;

there swap - . .( instructions used by numeric output) cr
