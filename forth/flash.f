\ SPI flash access

\ Flash addresses are doubles to support 16-bit and 18-bit cell size.
\ Compiled strings (for `type` etc.) are assumed to have 0 for the upper cell
\ of the address. Those strings must be below flash address 2^cellsize.

\ Single-byte reads from flash close the SPI flash after reading.
\ There is no assumption of continuity: Font bitmaps may be read between bytes.
\ So, c@f is slow. If you need speed, read flash in chunks.

there hex

: _isp  ( c -- )                \ write ISP byte to SPIF
   [ 4 cells ] literal io!
;
: ispwait  ( -- )               \ wait for ISP command to finish
   begin  [ 4 cells ] literal io@  while  noop  repeat
;
: ispcmd  ( c -- )              \ write ISP command
   _isp ispwait
;

\ The gecko key is loaded by writing to a register and then triggering a load.

: gkey  ( n -- )                \ shift in a new key
   [ 5 cells ] literal io!
;
: )gkey  ( n -- )               \ re-key the gecko keystream
   48 ispcmd
;
: fabyte  ( df-addr shift -- df-addr )
   >r  2dup  r> drshift drop ispcmd
;
: fcmd24  ( df-addr cmd -- )    \ set start address and set command
   0 _isp  3 _isp  82 _isp      \ 4 bytes to send
   ispcmd  10 fabyte  8 fabyte  0 fabyte
   2drop
;

: c@f(  ( df-addr -- )          \ start 0B read command
   0B fcmd24  82 _isp  0 ispcmd
;
: _c@f  ( -- c )                \ read byte from flash
   60 ispcmd                    \ trigger SPI transfer
   [ 3 cells ] literal io@      \ read SPI result
;
: _@f  ( -- n )                 \ read cell from flash
   0 [ cellbits 8 / ] literal for
      8 lshift _c@f +
   next
;
: )c@f  ( -- )                  \ end read
   80 _isp
;
: c@f  ( df-addr -- c )  c@f( _c@f )c@f ;
: @f   ( df-addr -- c )  c@f( _@f  )c@f ;

: fcount  ( df-addr -- df-addr+1 c )
   2dup 1 0 d+  2swap c@f
;
: ftype  ( df-addr u -- )       \ emit string in flash
   dup if
      for  fcount emit  next
   then  2drop
;
\ to do: roll together fcount and ftype so decryption will work
: f$type  ( f-addr -- )         \ emit the "flash string"
\   tkey gkey gkey dup gkey )gkey \ set the decryption key
   0  fcount  ftype
;

: fdump  ( f-addr len -- )      \ only useful if tkey is 0
   over 5 h.x  0 swap
   for
      over 0F and 0= if cr over 5 h.x then
      fcount h.2
   next 2drop
;

\ Header structures are in flash. Up to 8 wordlists may be in the
\ search order. WIDs are indices into `wids`, an array in data space.
\ The name of the wordlist is just before the first link.

: (.wid)  \ f-addr --                   \ f-addr points to the link that's 0
   1-  dup 0 c@f  tuck - 0 rot          \ daddr-f len
   dup 31 > if 2drop [char] ? emit exit then \ no name
   ftype
;
: [wid]   ( wid -- addr )               \ wid is indexed from 1
   cells [ wids cell - ] literal +
;
: wid    [wid] @ ;                      \ wid -- f-addr

: .wid   \ wid --                       \ display WID identifier (for order)
   wid  dup                             \ get the pointer
   begin nip dup 0 @f dup 0= until drop \ skip to beginning
   (.wid) space
;

\ | Length  | Name  | Usage                |
\ | ------- |:-----:| --------------------:|
\ | M bytes | link  | Link to next header  |
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
      count ( tolower ) _c@f xor if
         rdrop dup xor exit             \ mismatch in string
      then
   next  drop 1
;

\ Search one wordlist, returning the address of header data.
: _hfind  \ addr len wid -- addr len 0 | addr len ht
   wid  over 31 u> -19 and exception    \ name too long
   over 0= if dup xor exit then         \ addr 0 0   zero length string
   begin
      dup>r  0 c@f(  _@f >r  _c@f       \ addr len1 len2 | head link
      over = if
         2dup match if                  \ found
            rdrop dup r> +
            [ cellbits 8 / 1 + ] literal +
            )c@f exit
         then
      then )c@f r>  rdrop               \ end flash read
   dup 0= until                         \ not found
;

: hfind  \ addr len -- addr len | 0 ht  \ search the search order
   #order @  begin  dup  while  1-      \ addr len idx
      dup>r  cells orders + @ _hfind    \ addr len 0/ht
      ?dup if
         rdrop 2drop 0 swap exit        \ found, exit
      then
   r> repeat  drop
;

decimal there swap - . .( instructions used by flash) cr
