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
: fabyte  ( faddr shift -- faddr )
   >r  2dup  r> drshift drop ispcmd
;
: fcmd24  ( faddr cmd -- )      \ set start address and set command
   0 _isp  3 _isp  82 _isp      \ 4 bytes to send
   ispcmd  10 fabyte  8 fabyte  0 fabyte
   2drop
;
: c@f  ( faddr -- c )
   0B fcmd24  82 _isp  0 ispcmd \ start read command with dummy
   60 ispcmd                    \ trigger SPI transfer
   [ 3 cells ] literal io@      \ read SPI result
   80 _isp                      \ end read
;
: fcount  ( faddr -- faddr+1 c )
   2dup 1 0 d+  2swap c@f
;
: ftype  ( faddr u -- )         \ emit string in flash
   dup if
      for  fcount emit  next
   then  2drop
;
: f$type  ( sfaddr -- )         \ emit the "flash string"
   0  fcount  ftype
;

decimal there swap - . .( instructions used by flash) cr

