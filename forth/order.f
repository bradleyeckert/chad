\ SPI flash access

\ Flash addresses are doubles to support 16-bit and 18-bit cell size.
\ Compiled strings (for `type` etc.) are assumed to have 0 for the upper cell
\ of the address. Those strings must be below flash address 2^cellsize.

\ Single-byte reads from flash close the SPI flash after reading.
\ There is no assumption of continuity: Font bitmaps may be read between bytes.
\ So, c@f is slow. If you need speed, read flash in chunks.

there

\ The search order is implemented as a stack that grows upward, with #order the
\ offset into the orders array as well as the number of WIDs in the list.

: 'context  ( -- a )                    \ point to top of order
   #order @ cells [ orders cell - ] literal +
;
: context  ( -- f-addr )
   'context @ wid
;

:noname @+ swap ;
: get-order  \ -- widn ... wid1 n       \ 16.6.1.1647  get search order
   orders  #order @  literal times
   drop    #order @
;
: set-order  \ widn .. wid1 n --        \ 16.6.1.2197  set search order
   dup 0< if  drop root forth-wordlist 2  then
   dup 8 > -49 and exception            \ search order overflow
   dup #order !  orders over cells +    \ ... wid n dest
   begin over while
      cell -  swap 1- >r  tuck !  r> swap
   repeat  2drop
;

: set-current  current ! ;              \ 16.6.1.2195 \ wid --
: get-current  current @ ;              \ 16.6.1.1643 \ -- wid
: only         -1 set-order ;           \ 16.6.2.1965 \ --
: also         get-order over swap 1+   \ 16.6.2.0715
               set-order ;
: previous     get-order nip 1-         \ 16.6.2.2037
               set-order ;
: definitions  \ --                     \ 16.6.1.1180
   get-order  over set-current  set-order
;
: /forth       root forth-wordlist dup 2 set-order  set-current ;
: forth        get-order nip            \ 16.6.2.1590
               forth-wordlist swap set-order ;

:noname @+ .wid ;
: order  \ --                           \ 16.6.2.1985
   ."  Context: "    orders  #order @  literal times  drop
   cr ."  Current: " current @ .wid  cr
;

there swap - . .( instructions used by order) cr

