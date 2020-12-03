\ Interpreter and Search order

there

\ Input parsing

: toupper                               \ 2.6000 c -- C
   dup [char] a [char] { within \ }
   32 and -
;
: digit?                                \ 2.6010 c base -- n flag
   >r  toupper  [char] 0 -              \ char to digit, return `ok` flag
   dup 10 17 within or
   dup 9 > 7 and -
   dup r> u<
;
: >number                        \ 2.6020 ud1 c-addr1 u1 –– ud2 c-addr2 u2
   begin  dup   while
      over c@  base @ tuck digit? if    \ ud a u base n
         >r >r 2swap r@ um* rot r> um* d+
         r> 0 d+  2swap
      else
         2drop exit
      then
      1 /string
   repeat
;

: source   #tib 2@ ;                    \ 2.6030 -- c-addr len
: /source  source >in @ /string ;       \ 2.6040 -- c-addr len
: source?  >in 2@ u> ;                  \ -- flag   in source?
: char?    /source drop c@ ;            \ -- c  get source char
: in++     1 >in +! ;                   \ --

: _parse  ( c -- addr1 addr2 )          \ parse token from input
   begin  dup char? =  source? and
   while  in++  repeat                  \ skip leading delimiters
   /source drop swap over               ( addr1 c addr1 )
   begin  source?  while
      over char? =  in++
      if  nip exit  then  1+
   repeat nip                           \ end of input
;
: parse-name  bl [ ;                    \ 2.6060 <name> -- addr len
: parse       _parse over - ;           \ 2.6070 delimiter -- addr len

\ Text input uses shared data so >in can be manipulated here.

: \   #tib @ >in ! ; immediate          \ 2.6080 ccc<EOL> --

\ Cooked terminal input doesn't need echoing. It lets you edit the line before
\ sending it, at which point it sends the string all at once with an ending LF.
\ The EOL chars are stripped. If you fill the input buffer, `accept` terminates.

: key?                                  \ 2.6100 -- n
   [ 1 cells ] literal io@
;
: key                                   \ 2.6120 -- c
   begin key? until
   [ 0 cells ] literal io@
;

variable echoing                        \ 2.6130 -- a-addr

: accept                                \ 2.6140 c-addr +n1 -- +n2
   >r dup dup r> + >r                   \ a a | limit
   begin  dup r@ xor  while  key
      dup 13 =  over 10 =  or           \ CR or LF = EOL
      if  drop
         r> drop swap - exit
      then                              ( a a' c | limit )
      dup bl < if  drop  else           \ ignore invalid chars
         echoing @ if
            dup emit                    \ echo if enabled
         then
         over c! 1+
      then
   repeat  r> drop swap -               \ filled
;

: refill                                \ 2.6150 -- okay?
  'tib @ |tib| accept  #tib !
  0 >in !  true
;

\ Number parsing inspired by swapforth with dpl added and some tidying up.
\ `dpl` is how many digits to the right of the decimal.
\ Prefixes accepted: $, #, %, '

variable dpl

: has?  ( caddr u ch -- caddr' u' f )
    >r over c@ r> =  over 0<> and
    dup>r negate /string r>
;
: (number)  ( c-addr u -- x 0 | x x -1 )
    0 0 2swap  0 dpl !
    [char] - has? >r  >number
    [char] . has? r> 2>r                \ 0 is single, -1 is double
    dup if  dup dpl !  >number  then    \ digits after the decimal
    nip if  2drop  -13 throw  then      \ any chars remain: error
    r> if dnegate then                  \ is negative
    r> ?dup and                         \ if single, remove high cell
;
: base(number)  ( c-addr u radix -- x 0 | x x -1 )
    base @ >r base !  (number)  r> base !
;
: is'  ( f caddr -- f' )                \ f remains true if caddr is '
   c@ [char] ' = and
;
: (xnumber)  ( c-addr u -- x 0 | x x -1 )
    [char] $ has? if  16 base(number) exit  then
    [char] # has? if  10 base(number) exit  then
    [char] % has? if   2 base(number) exit  then
    2dup 3 = over is'  swap 2 + is'  if
       drop 1+ c@ false exit
    then  (number)
;

\ The search order is implemented as a stack that grows upward, with #order the
\ offset into the orders array as well as the number of WIDs in the list.

: 'context  ( -- a )                    \ point to top of order
   #order @ cells [ orders cell - ] literal +
;
: context                               \ 2.6160 -- f-addr
   'context @ wid
;

:noname @+ swap ;
: get-order                             \ 2.6170 -- widn ... wid1 n
   orders  #order @  literal times
   drop    #order @
;
: set-order                             \ 2.6180 widn .. wid1 n --
   dup 0< if  drop root forth-wordlist 2  then
   dup 8 > -49 and throw                \ search order overflow
   dup #order !  orders over cells +    \ ... wid n dest
   begin over while
      cell -  swap 1- >r  tuck !  r> swap
   repeat  2drop
;

: set-current  current ! ;              \ 2.6200 wid --
: get-current  current @ ;              \ 2.6210 -- wid
: only         -1 set-order ;           \ 2.6220 --
: also         get-order over swap 1+   \ 2.6230 --
               set-order
;
: previous     get-order nip 1-         \ 2.6240 --
               set-order
;
: definitions                           \ 2.6250 --
   get-order  over set-current  set-order
;
: forth        get-order nip            \ 2.6260 --
               forth-wordlist swap set-order
;
: order                                 \ 2.6270 --
   ."  Context: " #order @ ?dup if
      for r@ cells [ orders 1 cells - ] literal + @ .wid
      next
   else ." <empty> " then
   cr ."  Current: " current @ .wid  cr
;

\ `words` overrides the host version, which is in `root` so you can still
\ use it if you don't have `forth` (forth-wordlist) in the search order.

: _words  ( wordlist -- )
   begin dup while
      dup /text @f  swap                ( link ht )
      [ cellbits 8 / ] literal +
      0 fcount ftype space
   repeat drop
;
: words                                 \ 2.6280 --
   context _words                       \ list words in the top wordlist
;

: _.s  \ ? -- ?
   depth  begin dup while               \ assumes non-negative depth
      dup pick .  1-
   repeat drop
;
: .s                                    \ 2.6290 ? -- ?
   _.s  ." <-Top " cr
;

: .error  ( error -- )
   dup if
      cr dup ." Error " .
      dup -82 -2 within if
         dup invert 1- errorMsgs msg space
      then
      cr source type
      cr >in @ $7F and spaces ." ^-- >in"
   then  drop
;

: [        0 state ! ;  immediate       \ 2.6300 --
: ]        1 state ! ;                  \ 2.6310 --

: interpret  ( -- ? )
   begin  parse-name  dup while
      hfind over if                     \ not found
         (xnumber) if
            state @ if swap lit, lit, then
         else
            state @ if lit, then
         then
      else
         2drop _@f _@f _@f )@f          ( w xte xtc )
         state @ if swap then drop execute
      then
   repeat 2drop
;

: prompt  ( ? -- ? )                    \ "ok>" includes stack dump
   depth if ." \ " _.s then
   ." ok>"
;

\ The QUIT loop avoids CATCH and THROW for stack depth reasons.
\ If an error occurs, `throw` restarts `quit`.
\ The stacks are cleared. One item is allowed on the return stack
\ to keep the simulator happy.

: quit                                  \ 2.6320 error_id --
   state !  decimal
   \ If stacks are more than 8 deep, limit them to 8
   begin spstat $18 and while drop repeat
   begin spstat 8 rshift $18 and while rdrop repeat
   state @ postpone [  .error cr
   depth if  ." Data stack -> "
      begin spstat 7 and while . repeat  cr
   then
   spstat 8 rshift $1F and  ( rdepth )
   dup 1 > if  ." Return stack -> "         hex
      begin 1- dup while  r> .  repeat  cr  decimal
   then drop
   [ dm-size |tib| - ] literal 'tib !
   begin
      prompt  refill drop  interpret
   again
;

there swap - . .( instructions used by interpret) cr
