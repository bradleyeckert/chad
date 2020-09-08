\ Numeric conversion and text I/O
\ The buffer for numeric conversion is at the very top of data space.

there
variable hld \ numeric conversion pointer

: count   dup 1+ swap c@ ;  \ a -- a+1 c
: hex     16 base c! ;
: decimal 10 base c! ;

: type  \ addr len --                   \ 6.1.2310  send chars
          dup if  for  count emit  next  drop
          else  2drop
          then
;

: s>d     dup 0< ;                      \ 6.1.2170  n -- d
: space   bl emit ;                     \ 6.1.2220  --
: spaces  dup 1- 0< if  drop exit  then \ 6.1.2230  n --
          for space next ;    

\ Numeric conversion, from eForth mostly.

: digit   dup 10 - 0< 6 invert and + [char] 7 + ;
: <#      dm-size  hld ! ;              \ 6.1.0490
: hold    hld dup >r @ 1- dup r> ! c! ; \ 6.1.1670
: _#_     um/mod swap digit hold ;
: #       dup  base c@ >r  if           \ ud -- ud/base
            0 r@ um/mod r> swap         \ 6.1.0030
              >r _#_ r> exit
          then  r> _#_ 0
;
: #s      begin # 2dup or 0= until ;    \ 6.1.0050
: sign    0< if [char] - hold then ;    \ 6.1.2210
: #>      2drop hld @ dm-size over - ;  \ 6.1.0040
: s.r     over - spaces type ;          \ length width --  
: d.r     >r dup >r dabs                \ 8.6.1.1070  d width --
          <# #s r> sign #> r> s.r ;
: u.r     0 swap d.r ;                  \ 6.2.2330  u width --
: .r      >r s>d r> d.r ;               \ 6.2.0210  n width --
: d.      0 d.r space ;                 \ 8.6.1.1060  d --
: u.      0 d. ;                        \ 6.1.2320  u --
: .       base c@ 10 xor if             \ 6.1.0180  n|u
             u. exit                    \           unsigned if hex
          then  s>d d. ;                \           signed if decimal
: ?       @ . ;                         \ 15.6.1.0220  a --
: <#>     >r  <# negate begin # next #s #> ;  \ ud digits-1
: h.x     base c@ >r hex  0 swap <#> r> base c!  type space ;

there swap - . .( instructions used by numeric output) cr

\ stats for "123456789 d." are: 5824 cycles, MaxSP=7, MaxRP=12, latency=31
\ at cell size of 18 bits. At 100 MIPS, 58 usec.
