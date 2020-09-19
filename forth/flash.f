\ SPI flash

there

\ I/O registers       Read        Write
4 equ SPIdata       \ retrig      spitx
5 equ SPIformat     \ result      format

27182 equ flwp_en   \ 2.4021 -- x\ enable for flash-wp.

variable fwren0     \ lowest 64K sector number, set by `fwall`
variable fwren1     \ inverse of fwren0, used as a backup. Must be ~fwren0.
variable sector     \ 2.4000 -- a-addr
variable fp         \ 2.4010 -- a-addr

: flash-wp          \ 2.4020 sector key --
    flwp_en xor if  drop exit  then
    dup fwren0 !  invert fwren1 !
;
0 flwp_en flash-wp  \ testing

: readSPI    \ -- c \ result of transfer
    SPIformat io@
;
: SPIcommand  1 SPIformat io! [ ;       \ c --\ activate CS line
: sendSPI     SPIdata io! ;             \ c --\ transmit an SPI byte
: ]read       0 SPIformat io! ;         \ 2.4080 --\ end read
: fl_wren     6 SPIcommand ]read ;      \ write enable
: fl_wrdi     4 SPIcommand ]read ;      \ write disable
: waitflash   \ --                      \ wait for write or erase to finish
    begin  5 SPIcommand  0 sendSPI
           readSPI ]read  1 and
    while  noop
    repeat
;

: sendaddr24  \ addr --                 \ send address
    sector @ sendSPI
    dup swapb sendSPI  sendSPI
;

: ]write   ]read  fl_wrdi ;             \ 2.4050 --\ end write
: f>       0 sendSPI  readSPI ;         \ 2.4070 c --\ read next flash byte
: mask16b  65535 and ;                  \ x -- x16

: is4K?  \ fa -- fa flag \ is the pointer at a new sector?
    dup 4095 and 0=
;
: is256?  \ fa -- fa flag \ is the pointer at a new page?
    dup 255 and 0=
;
: erase4K  \ fa -- fa \ erase the 4K sector here
    fl_wren  32 SPIcommand  dup sendaddr24  ]read
;
: write[  \ 2.4030 fa --
    fwren0 @  dup invert
    fwren1 @  <> -81 and exception      \ corrupted wall
    sector @  <  -82 and exception      \ under the wall
    dup fp !  waitflash
    is4K? if erase4K then
    fl_wren  2 SPIcommand  sendaddr24   \ start page write
;
: bump_fp  \ -- fa \ Bump flash pointer by 1, wrap at 64K boundary
    fp @  dup mask16b                   ( fa fa16 )
    65535 = if 1 sector +! then         \ bump sector if fp will wrap
    1+  mask16b  dup fp !               \ bump fp
;
: >f      \ 2.4040 c --\ Write next byte to flash
    sendSPI  bump_fp
    is256? if  ]write      then         \ end write at end of page
    is4K?  if  erase4K     then
    is256? if  dup write[  then         \ start a new page
    drop
;
: read[   \ 2.4060 fa --\ Begin fast read
    waitflash  11 SPIcommand  sendaddr24  0 sendSPI
;

:noname  count >f ;                     \ Write string to flash
: write  literal times  drop ;          \ 2.4045 c-addr u --
:noname  f> over c! char+ ;             \ Read string from flash
: read   literal times  drop ;          \ 2.4090 c-addr u --


: key  \ -- c \ Wait for character from the UART
    begin  0 io@  dup 0< while  drop  repeat
;

\ Boot loader, not tested, don't have app launcher yet

cvariable SPIlength
cvariable BootEnabled
$1234 equ BootKey
: HexDigit  ( -- n ) key [char] 0 -  dup 9 > 7 and -  15 and ;
: HexByte   ( -- c ) HexDigit 4 lshift  HexDigit + ;
:noname  HexByte sendSPI ;
: writeNSPI ( -- )   SPIlength c@  literal times ;   			\ !
:noname  readSPI h.2  0 sendSPI ;
: readNSPI  ( -- )   SPIlength c@  literal times ;   			\ @
: setSPIlen ( -- )   HexByte  SPIlength c! ;         			\ #
: stopSPI   ( -- )   ]write  waitflash  [char] . emit ;         \ $
: startSPI  ( -- )   BootEnabled c@ if  HexByte  SPIcommand then ; \ %

: SPIboiler ( n -- c )											\ &
    $A4 h.2		\ chad tag
	0 h.2		\ protocol format 0
	0 h.2		\ ROM version
	2 h.2		\ product ID
	100 h.2		\ company ID
;

: SPIenable ( -- )												\ '
    HexByte  [ BootKey swapb 255 and ]  literal =
    HexByte  [ BootKey 255 and ]        literal = and
	BootEnabled c!
;

11 |bits|
: BootDispatch exec1: [
    ' writeNSPI | ' writeNSPI | ' readNSPI  | ' setSPIlen |
	' stopSPI   | ' startSPI  | ' SPIboiler | ' SPIenable ] literal
;

: Bootloader  \ --
    [char] ? emit
	begin key  bl -
		dup 7 invert and if  drop		\ invalid command char
		else  BootDispatch
		then
	again  [
;

\ `<space>` Launch the app (if possible)
\ `!` Write N SPI bytes, expect 2N hex digits.
\ `@` Read N SPI bytes, return 2N hex digits.
\ `#` Set `N` parameter, expect 2 hex digits.
\ `$` Stop SPI flash command, return `.` when flash is not busy.
\ `%` Start a SPI flash command.
\ `&` Boilerplate, return 2M hex digits where M is the length of the string.
\ `'` Enable the bootloader, expect 4 hex digits.
\ `other` Ignored.

there swap - . .( instructions used by flash access) cr
