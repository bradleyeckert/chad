\ Bootloader

there

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
: stopSPI   ( -- )  close-flash  waitflash  [char] . emit ;     \ $
: startSPI  ( -- )  BootEnabled c@ if HexByte SPIcommand then ; \ %

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

there swap - . .( instructions used by boot loader) cr
