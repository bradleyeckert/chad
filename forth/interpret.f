\ Interpreter and Search order

there

\ `dpl` is how many digits to the right of the decimal.
\ `echoing` enables character echo during `accept`.

variable dpl
variable echoing                        \ 2.6130 -- a-addr

\ Since these are postponed, don't define in an applet

: [        0 state ! ;  immediate       \ 2.6300 --
: ]        1 state ! ;                  \ 2.6310 --

\ Text input parsing uses an applet that fits in 512 bytes of flash.

applets [if] .(     Applet bytes: { )   \ }
paged applet  paged [then]

\ Number input, about 323 bytes of flash.
\ Assumes that string-to-number conversion isn't time-critical.

: toupper                               \ 2.6000 c -- C
   dup [char] a [char] { within \ }
   32 and -
;
: digit?                                \ 2.6010 c base -- n flag
   >r  toupper
   [ char 0 negate ] literal +          \ char to digit, return `ok` flag
   dup 10 17 within or
   dup 9 > 7 and -
   dup r> u<
;
: >number                        \ 2.6020 ud1 c-addr1 u1 -- ud2 c-addr2 u2
   begin  dup   while
      over c@  base @ digit? if         \ uL uH ca cu digit
         swap >r  2swap                 \ ca digit uL uH | cu
         base @ *  swap                 \ ca digit vH uL | cu
         base @ um* d+                  \ ca ((digit vH) + (wL wH)) | cu
         rot r>
      else
         drop  exit
      then
      1 /string
   repeat
;

\ swap >r  2swap  base @ *  swap base @ um* d+
\ uL uH ca cu digit
\ uL uH ca digit | cu
\ ca digit uL uH | cu
\ ca digit vH wL wH | cu

\ Number parsing inspired by swapforth with dpl added and some tidying up.
\ Prefixes accepted: $, #, %, '

: has?  ( caddr u ch -- caddr' u' f )
    over if
       >r over c@ r> =  over 0<> and
       dup>r negate /string r>
    exit then  dup xor                  \ don't test empty string
;
: (number)  ( c-addr u -- x 0 | x x -1 )
    0 0 2swap  0 dpl !
    [char] - has? >r  >number
    [char] . has? r> 2>r                \ 0 is single, -1 is double
    dup if  dup dpl !  >number  then    \ digits after the decimal
    nip if  2drop                       \ any chars remain: error
       -13 throw exit
    then
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
       drop 1+ c@ false  exit
    then  (number)
;

applets [if] end-applet  paged swap - . [then]

\ Input parsing, about 235 bytes of flash
\ Getting the next blank-delimited string from the input stream involves loading
\ this applet (about 25us) if the caller is not an applet.

applets [if] paged applet  paged [then]

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

\ Cooked terminal input doesn't need echoing. It lets you edit the line before
\ sending it, at which point it sends the string all at once with an ending LF.
\ The EOL chars are stripped. If you fill the input buffer, `accept` terminates.

: key?   io'rxbusy io@ ;                \ 2.6100 -- n
: key  begin key? until  io'udata io@ ; \ 2.6120 -- c

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

applets [if] end-applet  paged swap - . [then]

\ Search order words, about 173 bytes of flash.

applets [if] paged applet  paged [then]

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
: +order ( wid -- )
   >r get-order r> swap 1+ set-order
;
: set-current  current ! ;              \ 2.6200 wid --
: get-current  current @ ;              \ 2.6210 -- wid
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

applets [if] end-applet  paged swap - . [then]

\ Wordlist display, about 229 bytes of applet flash

applets [if] paged applet  paged [then]

\ Header structures are in flash. Up to 8 wordlists may be in the
\ search order. WIDs are indices into `wids`, an array in data space.
\ The name of the wordlist is just before the first link.
\ The count is after the name instead of before it so it's stored as plaintext.

: (.wid)  \ f-addr --                   \ f-addr points to the link that's 0
   1-  dup /text c@f  tuck -  swap      \ f-addr len
   31 > if drop [char] ? emit exit then \ no name
   1-  f$type
;

: .wid   \ wid --                       \ display WID identifier (for order)
   wid    dup                           \ get the pointer
   begin  nip dup /text @f              \ skip to beginning
   dup 0= until  drop
   (.wid) space
;

: order                                 \ 2.6270 --
   ."  Context: " #order @ ?dup if
      for r@ cells [ orders 1 cells - ] literal + @ .wid
      next
   else ." <empty> " then
   cr ."  Current: " current @ .wid  cr
;

\ `words` overrides the host version, which is in `root`.
\ Use `Words` for the original version.

: _words  ( wordlist -- )
   1 stack(
   begin dup while
      dup /text @f  swap                ( link ht )
      [ cellbits 8 / ] literal +
      0 fcount ftype space
   repeat drop
   )stack
;
: words                                 \ 2.6280 --
   context _words                       \ list words in the top wordlist
;

\ Given a message table, look up the message number and print it.
\ `msg_seek` looks up the message in the list and returns 0 if not found.
\ `msg` prints the message. If not found, it defaults to message 0.
\ The list of standard FORTH errors is ~2KB, which is nothing for flash.

: msg_seek  ( idx f-addr -- f-addr' | 0 )
   begin  over  while  swap 1- swap
      /text fcount nip tuck 0= if       \ idx offset f-addr
         2drop dup xor exit
      then  +
   repeat  nip
;
: msg  \ 2.4120 idx f-addr --
   dup>r msg_seek
   ?dup if rdrop else r> then  f$type
;

fhere equ errorMsgs \ starting at -2 and going negative
           ,"  "
   (  -3 ) ," Stack overflow"
   (  -4 ) ," Stack underflow"
   (  -5 ) ," Return stack overflow"
   (  -6 ) ," Return stack underflow"
   (  -7 ) ," Do-loops nested too deeply during execution"
   (  -8 ) ," Dictionary overflow"
   (  -9 ) ," Invalid memory address"
   ( -10 ) ," Division by zero"
   ( -11 ) ," Result out of range"
   ( -12 ) ," Argument type mismatch"
   ( -13 ) ," Word not found"
   ( -14 ) ," Interpreting a compile-only word"
   ( -15 ) ," Invalid FORGET"
   ( -16 ) ," Attempt to use zero-length string as a name"
   ( -17 ) ," Pictured numeric output string overflow"
   ( -18 ) ," Parsed string overflow"
   ( -19 ) ," Definition name too long"
   ( -20 ) ," Write to a read-only location"
   ( -21 ) ," Unsupported operation"
   ( -22 ) ," Control structure mismatch"
   ( -23 ) ," Address alignment exception"
   ( -24 ) ," Invalid numeric argument"
   ( -25 ) ," Return stack imbalance"
   ( -26 ) ," Loop parameters unavailable"
   ( -27 ) ," Invalid recursion"
   ( -28 ) ," User interrupt"
   ( -29 ) ," Compiler nesting"
   ( -30 ) ," Obsolescent feature"
   ( -31 ) ," >BODY used on non-CREATEd definition"
   ( -32 ) ," Invalid name argument (e.g., TO xxx)"
   ( -33 ) ," Block read exception"
   ( -34 ) ," Block write exception"
   ( -35 ) ," Invalid block number"
   ( -36 ) ," Invalid file position"
   ( -37 ) ," File I/O exception"
   ( -38 ) ," File not found"
   ( -39 ) ," Unexpected end of file"
   ( -40 ) ," Invalid BASE for floating point conversion"
   ( -41 ) ," Loss of precision"
   ( -42 ) ," Floating-point divide by zero"
   ( -43 ) ," Floating-point result out of range"
   ( -44 ) ," Floating-point stack overflow"
   ( -45 ) ," Floating-point stack underflow"
   ( -46 ) ," Floating-point invalid argument"
   ( -47 ) ," Compilation wordlist deleted"
   ( -48 ) ," Invalid POSTPONE"
   ( -49 ) ," Search-order overflow"
   ( -50 ) ," Search-order underflow"
   ( -51 ) ," Compilation wordlist changed"
   ( -52 ) ," Control-flow stack overflow"
   ( -53 ) ," Exception stack overflow"
   ( -54 ) ," Floating-point underflow"
   ( -55 ) ," Floating-point unidentified fault"
   ( -56 ) ," QUIT"
   ( -57 ) ," Exception in sending or receiving a character"
   ( -58 ) ," [IF], [ELSE], or [THEN] exception"
   ( -59 ) ," Missing literal before opcode"
   ( -60 ) ," Attempt to write to non-blank flash memory"
   ( -61 ) ," Macro expansion failure"
   ( -62 ) ," Input buffer overflow, line too long"
   ( -63 ) ," Bad arguments to RESTORE-INPUT"
   ( -64 ) ," Write to non-existent data memory"
   ( -65 ) ," Read from non-existent data memory"
   ( -66 ) ," PC is in non-existent code memory"
   ( -67 ) ," Write to non-existent code memory"
   ( -68 ) ," Test failure"
   ( -69 ) ," Page fault writing flash memory"
   ( -70 ) ," Bad I/O address"
   ( -71 ) ," Writing to flash without issuing WREN first"
   ( -72 ) ," Invalid ALU opcode"
   ( -73 ) ," Bitfield is 0 or too wide for a cell"
   ( -74 ) ," Resolving a word that's not a DEFER"
   ( -75 ) ," Too many WORDLISTs used"
   ( -76 ) ," Internal API calls are blocked"
   ( -77 ) ," Invalid CREATE DOES> usage"
   ( -78 ) ," Nesting overflow during include"
   ( -79 ) ," Compiling an execute-only word"
   ( -80 ) ," Dictionary full"
   ( -81 ) ," Writing to invalid flash sector"
   ( -82 ) ," Flash string space overflow"
   ( -83 ) ," Invalid SPI flash address"
   ( -84 ) ," Invalid coprocessor field"
   ( -85 ) ," Can't postpone an applet word"
   ," " \ empty string = end of list

applets [if] end-applet  paged swap - . [then]

\ Quit messages, about 123 bytes of applet flash

applets [if] paged applet  paged [then]

: .error  ( error -- )
   dup if
      cr ." Error "  dup .
      invert 1-  dup 1 84 within if
         errorMsgs msg space
      else
         drop
      then
      cr source type
      cr >in @ $7F and spaces ." ^-- >in"
      exit
   then  drop
;

: _.s  \ ? -- ?
   depth  begin dup while               \ if negative depth,
      dup pick .  1-                    \ depth rolls back around to 0
   repeat drop
;

: prompt  ( ? -- ? )                    \ "ok>" includes stack dump
   depth if ." \ " _.s then
   ." ok>"
;

applets [if] end-applet  paged swap - . [then]

\ ------------------------------------------------------------------------------

\ `interpret` wants to be outside the applet.

: interpret  ( -- ? )
   begin  parse-name  dup while
      hfind over if                     \ not found
         2 stack(  (xnumber)  )stack
         if
            state @ if swap lit, lit, then
         else
            state @ if lit, then
         then
      else
         2drop
         @f> @f> @f>
         @f> api !  )@f                 ( w xte xtc )
         state @ if swap then drop execute
      then
   repeat 2drop
;

\ The QUIT loop avoids CATCH and THROW for stack depth reasons.
\ If an error occurs, `throw` restarts `quit`.
\ The stacks are cleared. One item is allowed on the return stack
\ to keep the simulator happy.

\ Since `throw` targets it, `quit` can't be in an applet.

: quit                                  \ 2.6320 error_id --
   state !  decimal
   \ If stacks are more than 8 deep, limit them to 8
   begin spstat $18 and while drop repeat
   begin spstat swapb $18 and while rdrop repeat
   state @  postpone [  .error cr
   depth if  ." Data stack -> "
      begin spstat 7 and while . repeat  cr
   then
   spstat swapb $1F and  ( rdepth )
   dup 1 > if  ." Return stack -> "         hex
      begin 1- dup while  r> .  repeat  cr  decimal
   then drop
   0 api !
   fpclear
   [ dm-size |tib| - ] literal 'tib !
   begin
      prompt
      refill drop
      interpret
   again
;

\ `only` can't be in the applet because set-current can't execute
\ until end-applet writes the applet to the flash memory image.

root set-current                        \ escape hatch from root
: only         -1 set-order ;           \ 2.6220 --
forth-wordlist set-current

0 [if]
\ Text input uses shared data (chad.c and the Forth) so >in can be manipulated
\ here. However, if `\` is defined here the host version will stop compiling
\ HTML code after \. So, don't define it until you need it.

: \   #tib @ >in ! ; immediate          \ 2.6080 ccc<EOL> --

[then]

.( }; ) there swap - . .( instructions used by interpret) cr
