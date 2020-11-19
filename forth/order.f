\ Search order and interpreter

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

\ `words` overrides the host version, which is in `root` so you can still use
\ it if you don't have `forth` (forth-wordlist) in the search order.

: _words  ( wordlist -- )
   begin dup while
      dup /text @f  swap                ( link ht )
      [ cellbits 8 / ] literal +
      0 fcount ftype space
   repeat drop
;
: words  ( -- )
   context _words
;

\ Text input uses shared data so >in can be manipulated here

: \                                     \ 1.1020 ccc<EOL> --
   #tib @ >in !
; immediate

: source   #tib 2@ ;                    \ 3.0000 -- c-addr len
: /source  source >in @ /string ;       \ 3.0010 -- c-addr len
: [        0 state ! ;  immediate       \ 3.0020 --
: ]        1 state ! ;                  \ 3.0030 --

\ The QUIT loop avoids CATCH and THROW for stack depth reasons.
\ If an error occurs, `exception` restarts `quit`.

: quit  ( error_id -- )
   hld !
   begin  spstat  $1F00 and  while  rdrop  repeat  \ empty R
   begin  spstat  $1F and  while  drop  repeat     \ empty S
   decimal  postpone [
   hld @ .error
   begin
      noop \ put interpret loop here
   again
;

there swap - . .( instructions used by order) cr

