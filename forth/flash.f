\ SPI flash access

\ Flash addresses are doubles to support 16-bit and 18-bit cell size.
\ Compiled strings (for `type` etc.) are assumed to have 0 for the upper cell
\ of the address. Those strings must be below flash address 2^cellsize.

there
hex

: _isp  ( c -- )                \ write ISP byte to SPIF
   [ 4 cells ] literal io!
;
: ispwait  ( -- )               \ wait for ISP command to finish
   begin  [ 4 cells ] literal io@  while  noop  repeat
;
: ispcmd  ( c -- )              \ c --
   _isp ispwait                 \ write ISP command
;

\ The gecko key is loaded by writing to a register and then triggering a load.
\ `fcmd24` is used for writing to flash, which isn't done currently

: gkey                          \ n --
   [ 5 cells ] literal io!      \ shift in a new key
;
: )gkey  ( -- )                 \ --
   48 ispcmd                    \ re-key the gecko keystream
;
: fcmd24  ( df-addr cmd len --) \ set start address and set command
   0 _isp _isp  82 _isp  ispcmd \ len is 3 + extra chars ( df-addr )
   2dup 10 drshift drop
   BASEBLOCK +   ispcmd         \ addr[23:16]
   over swapb ispcmd            \ addr[15:8]
   drop ispcmd                  \ addr[7:0]
;

: )@f  ( -- )                   \ 2.4030 --
   80 _isp                      \ end read (raise CS#)
;

decimal

\ Flash reads using hardware instead of discrete SPI transfers.
\ Double cell addresses are used but not implemented. If they are needed,
\ you can add code to handle the upper half of the address.

: fwait  ( -- )                 \ wait for flash read to finish
   begin  [ 5 cells ] literal io@  while  noop  repeat
;
: _x@f  ( df-addr cfg -- x )    \ hardware flash read
   nip
   [ 6 cells ] literal io!      \ flash read setup
   [ 11 cells ] literal io!     \ trigger a read
   fwait
   [ 11 cells ] literal io@     \ get result
;
: c@f>  ( -- c )
   [ 2 2* 2* ] literal
   [ 6 cells ] literal io!      \ flash read setup
[ ;
: @f>  ( -- x )                 \ read using the default setup
   [ 10 cells ] literal dup io! \ trigger a read-next
   fwait
   [ 11 cells ] literal io@     \ get result
;
: @f(  ( df-addr -- x )         \ 3-byte big-endian read
   [ 2 2* 2*  2 + ] literal     \ format=2, size=2
   _x@f
;
: @f  ( df-addr -- x )          \ 3-byte big-endian read
   @f(  )@f                     \ raise CS afterwards
;
: w@f(  ( df-addr -- x )        \ first 2-byte big-endian read
   [ 2 2* 2*  1 + ] literal
   _x@f
;
: w@f  ( df-addr -- x )         \ 2-byte big-endian read
   w@f(  )@f
;
: c@f(  ( df-addr -- x )        \ first 1-byte read
   [ 2 2* 2* ] literal
   _x@f
;
: c@f  ( df-addr -- x )         \ 1-byte read
   c@f(  )@f
;

: d@f    @f 0 ;                 \ 2.4055 df-addr -- d

: fcount                        \ 2.4060 df-addr -- df-addr+1 c
   2dup 1 0 d+  2swap c@f
;
: 3*   ( n -- 3n ) dup 2* + ;   \ multiply by 3, goes with f@

\ `emit` may require reading font bitmaps from flash, so `f$type` reads the
\ string into a RAM buffer because the bitmap read disrupts keystream sync.
\ This is a good place for `pad`. Make it big enough for app usage.
\
\ `fbuf` moves a string from flash to RAM.
\ The keystream is assumed to be in sync.

: fbuf                         \ 2.4060 df-addr c-addr u --
   >r >r  c@f(  r@ c!  r> r>   ( c-addr u ) \ 1st char
   begin  1 /string  dup while
      over @f> swap c!
   repeat  2drop  )@f
;

256 equ |pad|
|pad| buffer: pad

: ftype                         \ 2.4070 df-addr u --
   >r pad r@ fbuf  pad r> type
;
: /text  ( f-addr -- df-addr )  \ synchronize keystream
   tkey 2dup or 0= if 2drop exit then
   gkey gkey dup gkey )gkey
   0
;
: f$type                        \ 2.4080 f-addr --
   /text  fcount  ftype         \ emit the "flash string"
;
: fdump  ( f-addr len -- )      \ only useful if tkey is 0
   over 5 h.x  0 swap
   for
      over 15 and 0= if cr over 5 h.x then
      fcount h.2
   next 2drop
;

\ Header structures are in flash. Up to 8 wordlists may be in the
\ search order. WIDs are indices into `wids`, an array in data space.
\ The name of the wordlist is just before the first link.
\ The count is after the name instead of before it so it's stored as plaintext.

: (.wid)  \ f-addr --                   \ f-addr points to the link that's 0
   1-  dup /text c@f  tuck -  swap      \ f-addr len
   31 > if drop [char] ? emit exit then \ no name
   1-  f$type
;
: [wid]   ( wid -- addr )               \ wid is indexed from 1
   cells [ wids cell - ] literal +
;
: wid    [wid] @ ;                      \ wid -- f-addr

: .wid   \ wid --                       \ display WID identifier (for order)
   wid    dup                           \ get the pointer
   begin  nip dup /text @f              \ skip to beginning
   dup 0= until  drop
   (.wid) space
;

\ | Length  | Name  | Usage                |
\ | ------- |:-----:| --------------------:|
\ | M bytes | link  | Link to next header  | <-- keystream
\ | 1 byte  | N     | Length of `name`     |
\ | N bytes | name  | Name string          |
\ | M bytes | xte   | *xt* for Execution   | <-- ht
\ | M bytes | xtc   | *xt* for Compilation |
\ | M bytes | w     | Optional data        |
\ | 1 byte  | flags | Packed flags (0=on)  |
\ | 1 byte  | app   | Applet ID            |
\
\ For `find`, the SPI read sequence is continued until it doesn't match.
\ `match` compares a key in data space to the flash byte stream.
\ It's a case-sensitive comparison. For a case-insensitive search, insert a
\ tolower function.

: match  \ addr len -- found?
   for                                  \ addr' | len'
      count ( tolower ) @f> xor if
         rdrop dup xor exit             \ mismatch in string
      then
   next  drop 1                         \ all bytes have been read
;

\ Search one wordlist, returning the address of header data.
: _hfind  \ 2.4100 addr len wid -- addr len 0 | addr len ht
   wid  over 31 u> -19 and throw        \ name too long
   over 0= if dup xor exit then         \ addr 0 0   zero length string
   begin
      dup>r  /text
      @f( >r  c@f>                      \ addr len1 len2 | head link
      over = if
         2dup match if                  \ found
            rdrop dup r> +              \ 'link + NameLength + 1 + cellbytes
            [ cellbits 7 + 8 /  1 + ] literal +
            [ 2 2* 2*  2 + ] literal    \ next reads will be 24-bit
            [ 6 cells ] literal io!
            exit                        \ don't end the read yet
         then
      then )@f r>  rdrop                \ end flash read
   dup 0= until                         \ not found
;

\ A primitive for `find` that returns a ht.
: hfind  \ 2.4110 addr len -- addr len | 0 ht  \ search the search order
   #order @  begin  dup  while  1-      \ addr len idx
      dup>r  cells orders + @ _hfind    \ addr len 0/ht
      ?dup if
         rdrop 2drop 0 swap exit        \ found, exit
      then
   r> repeat  drop
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
   ," " \ empty string = end of list

there swap - . .( instructions used by flash) cr
