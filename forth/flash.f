\ SPI flash access

\ Flash addresses are doubles to support 16-bit and 18-bit cell size.
\ Compiled strings (for `type` etc.) are assumed to have 0 for the upper cell
\ of the address. Those strings must be below flash address 2^cellsize.

there
hex

: _isp  ( c -- )                \ write ISP byte to SPIF
   io'isp io!
;
: ispwait  ( -- )               \ wait for ISP command to finish
   begin  io'isp io@  while  noop  repeat
;
: ispcmd  ( c -- )              \ c --
   _isp ispwait                 \ write ISP command
;
: ispnum  ( n -- )
   3F and _isp                  \ 6-bit number command
;

\ The gecko key is loaded by writing to a register and then triggering a load.
\ `fcmd24` is used for writing to flash, which isn't done currently

: gkey                          \ n --
   io'gkey io!                  \ shift in a new key
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

\ Load a boot stream from flash starting at a specified page.
\ If the data is glitched, such as from an ESD hit, the CRC32 won't match
\ so retry until it's okay.

: spifload  ( page -- )
   api !
   begin
      api @
      dup 6 rshift ispnum ispnum \ set page number
      44 ispcmd                  \ interpret the flash stream
   io'boot io@ bootokay and until
;

\ Large applications are supported by caching, which is enabled by an exception.
\ The `api_recover` exception is triggered when R>1FFFh.
\ Instead of popping PC from the return stack, execution jumps to a fixed addr.
\ `api_recover` gets the required page from R and masks off the page number.

\ `xexec` executes a word at a specified xxt (extended execution token)
\ consisting of the flash page number packed with a 13-bit address.
\ in the format 11.13 where the upper 11 bits are the flash page number
\ (a page is 256 bytes) and the lower 13 bits are the xt.

: xexec  ( xxt -- ) ( R: addr -- page|addr )
   api @ 0d lshift r> + >r              \ add page to return address
   1fff invert overand                  ( xxt new_page )
   0d rshift spifload
   1fff and  >r                         \ execute
; no-tail-recursion
' xexec resolves api_trap

\ still has an occasional problem with return stack underflow
\ `xcall` saves the return address into old code, which `api_trap` appends a
\ current page number to. The new page is loaded and execution starts at the
\ new page's code. Upon execute, the return stack has the old page number.

\ When a return address with page<>0 is encountered, the pc jumps to api_recover
\ while the questionable return address is on the return stack.
\ The old page is reloaded before execution returns.

:noname  ( R: page|addr -- addr )       \ returning to an api word (page <> 0)
   r> 1fff overand >r
   0d rshift  spifload                          ( needed_page )
\   dup api @ xor if                     \ returning to a corrupted page
\      spifload exit
\   then drop
; resolves api_recover

decimal


\ Flash reads using hardware instead of discrete SPI transfers.
\ Double cell addresses are used but not implemented. If they are needed,
\ you can add code to handle the upper half of the address.

: fwait  ( -- )                 \ wait for flash read to finish
   begin  io'gkey io@  while  noop  repeat
;
: _x@f  ( df-addr cfg -- x )    \ hardware flash read
   nip  io'fcfg io!             \ flash read setup
   io'fread io!                 \ trigger a read
   fwait  io'fread io@          \ get result
;
: c@f>  ( -- c )
   [ 2 2* 2* ] literal
   io'fcfg io!                  \ flash read setup
[ ;
: @f>  ( -- x )                 \ read using the default setup
   io'fnext dup io!             \ trigger a read-next
   fwait  io'fread io@          \ get result
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

: fbuf                         \ 2.4065 df-addr c-addr u --
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

tkey or [if]
: /text  ( f-addr -- df-addr )  \ synchronize keystream
   tkey gkey gkey  dup gkey )gkey  0
;
[else]
: /text  ( f-addr -- df-addr )
   0
;
[then]

: f$type                        \ 2.4080 f-addr --
   /text  fcount  ftype         \ emit the "flash string"
;

: [wid]   ( wid -- addr )               \ wid is indexed from 1
   cells [ wids cell - ] literal +
;
: wid    [wid] @ ;                      \ wid -- f-addr


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
            io'fcfg io!   exit          \ don't end the read yet
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

there swap - . .( instructions used by flash) cr
