\ Numeric conversion and text I/O
\ The buffer for numeric conversion is at the very top of data space.
\ The output string grows downward in memory.

there
decimal
variable hld 							\ numeric conversion pointer
32 equ bl								<a 6.1.0770 -- ' '>

: count   dup 1+ swap c@ ; 				<a 17.6.1.0245 a u -- a+1 u-1>
: decimal 10 base ! ;                   <a 6.1.1170 -->
: hex     16 base ! ;                   <a 6.2.1660 -->
: type    dup if                        <a 6.1.2310 addr len -->
			for  count emit  next  drop
          else  2drop
          then
;
: s>d     dup 0< ;                      <a 6.1.2170 n -- d>
: space   bl emit ;                     <a 6.1.2220 -->
: spaces  dup 1- 0< if  drop exit  then <a 6.1.2230 n -->
          for space next ;

\ Numeric conversion, from eForth mostly.

: digit   dup 10 - 0< 6 invert and + [char] 7 + ;
: <#      dm-size  hld ! ;              <a 6.1.0490 ud -- ud'>
: hold    hld dup >r @ 1- dup r> ! c! ; <a 6.1.1670 c -->
: _#_     um/mod swap digit hold ;
: #       dup  base @ >r  if            <a 6.1.0030 ud -- ud/base>
              0 r@ um/mod r> swap
              >r _#_ r> exit
          then  r> _#_ 0
;
: #s      begin # 2dup or 0= until ;    <a 6.1.0050 d -- 00>
: sign    0< if [char] - hold then ;    <a 6.1.2210 n -->
: #>      2drop hld @ dm-size over - ;  <a 6.1.0040 d -- addr u>
: s.r     over - spaces type ;          \ length width --
: d.r     >r dup >r dabs         		<a 8.6.1.1070 d width -->
          <# #s r> sign #> r> s.r ;
: u.r     0 swap d.r ;                  <a 6.2.2330 u width -->
: .r      >r s>d r> d.r ;               <a 6.2.0210 n width -->
: d.      0 d.r space ;                 <a 8.6.1.1060 d -->
: u.      0 d. ;                        <a 6.1.2320 u -->
: .       base @ 10 xor if              <a 6.1.0180 n|u -->
             u. exit                    \           unsigned if hex
          then  s>d d. ;                \           signed if decimal
: ?       @ . ;                         <a 15.6.1.0220 a -->
: <#>     >r  <# negate begin # next #s #> ;  \ ud digits-1
: h.x     base @ >r hex  0 swap <#> r> base !  type space ;

there swap - . .( instructions used by numeric output) cr

\ stats for "123456789 d." are: 5824 cycles, MaxSP=7, MaxRP=12, latency=31
\ at cell size of 18 bits. At 100 MIPS, 58 usec.
