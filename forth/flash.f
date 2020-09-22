\ SPI flash

there

\ I/O registers       Read        Write
4 equ SPIdata       \ retrig      spitx
5 equ SPIformat     \ result      format

27182 equ flwp_en   \ 2.4021 -- x\ enable for flash-wp.

variable fwren0     \ lowest 64K sector number, set by `fwall`
variable fwren1     \ inverse of fwren0, used as a backup. Must be ~fwren0.
variable qe-flag    \ 2.4015 -- a-addr

\ Note: This will be totally re-written to match the .md file.

8 2* cells equ |flashstack|
variable flsp                           \ flash stack pointer
|flashstack| buffer: flashstack

0 equ FL_R8                             \ 8-bit read mode
1 equ FL_R16                            \ 16-bit read mode
2 equ FL_W8                             \ 8-bit write mode
3 equ FL_W16                            \ 16-bit write mode

\ Flash status uses a stack of:
\ 1 byte: mode = {read8, read16, write8, write16}       <-- flsp
\ 1 byte: sector = current 64K sector                   <-- flsp+1
\ 2 bytes: fp = flash pointer, next byte to read/write  <-- flsp+2

: pushFL  \ fp sector mode --
    4 flsp +!                           \ pre-increment SP
    flsp @  tuck c!  1+
    tuck c!  2 +  w!
;

: FLsector  flsp @ 1+ ;                 \ -- c-addr \ current 64K sector
: FLdp      flsp @ 2 + ;                \ -- a-addr \ current byte in sector

: flash-wp                              \ 2.4020 sector key --
    flwp_en xor if  drop exit  then
    dup fwren0 !  invert fwren1 !
;

: readSPI    \ -- c \ result of transfer
    SPIformat io@
;

: SPIcommand  1 SPIformat io! [ ;       \ c --\ activate CS line
: sendSPI     SPIdata io! ;             \ c --\ transmit an SPI byte
: ]read       0 SPIformat io! ;         \ 2.4080 --\ end read
: fl_wren     6 SPIcommand ]read ;      \ write enable
: fl_wrdi     4 SPIcommand ]read ;      \ write disable
: _fc>        0 sendSPI  readSPI ;      \ 2.4070 -- c\ read next flash byte
: fc>         SPIdata io@ ;             \ 2.4071 -- c\ read and trigger flash
: FLdepth     flsp @  [ flashstack 4 - ] literal  2/ 2/ ; \ -- depth

\ Initialize the flash: Clear the flash stack and read the QE bit
: /flash      \ --
    [ flashstack 4 - ] literal flsp !   \ clear flash stack
    53 SPIcommand  _fc>  2 and qe-flag ! ]read \ upper status byte
    0 flwp_en flash-wp                  \ enable writes to 0
;

/flash

: waitflash   \ --                      \ wait for write or erase to finish
    5 SPIcommand
    begin  _fc> 1 and  while  noop  repeat ]read
;

: sendaddr24  \ addr --                 \ send address using 3 bytes
    FLsector c@ sendSPI
    dup swapb sendSPI  sendSPI
;

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

\ Open the flash memory for writing. The Page Program (02 command)
\ is used for programming flash.
: create-flash  \ 2.4030 fa --
    fwren0 @  dup invert
    fwren1 @   <> -81 and exception     \ corrupted wall
    FLsector c@ < -82 and exception     \ under the wall
    dup FLdp !  waitflash
    is4K? if erase4K then
    fl_wren  2 SPIcommand  sendaddr24   \ start page write
;
: close-flash  \ 2.4050 --\ end write
    ]read  fl_wrdi                      \ end the current flash operation
    -4 flsp +!                          \ un-nest to previous flash operation
    FLdepth if                          \ was there something going on before?
    then
;
: bump_fp  \ -- fa \ Bump flash pointer by 1, wrap at 64K boundary
    FLdp @  dup mask16b                   ( fa fa16 )
    65535 = if 1 sector +! then         \ bump sector if fp will wrap
    1+  mask16b  dup FLdp !             \ bump fp
;

\ Write a byte to the next free space in flash. The 256-byte Page Program
\ is managed so as to freely cross into subsequent pages and sectors.
: c,f      \ 2.4040 c --\ Write next byte to flash
    sendSPI  bump_fp
    is256? if  close-flash      then    \ end write at end of page
    is4K?  if  erase4K     then
    is256? if  dup create-flash  then   \ start a new page
    drop
;

\ formats:
\ 000 = 8-bit SPI
\ 001 = 16-bit SPI
\ 100 = 8-bit QSPI mode receive
\ 101 = 16-bit QSPI mode receive
\ 110 = 8-bit QSPI mode transmit
\ 111 = 16-bit QSPI mode transmit

\ Note that the QE bit in the status register must be programmed to '1'
\ for quad rate commands to work. See the flash data sheet.
\ Flash read can be in bytes or 16-bit words. The default mode is bytes.

: open-flash  \ fa --
    waitflash
    qe-flag @ if
        $EB SPIcommand                  \ EB single
        13 SPIformat io!                \ 8-bit QSPI transmit
        sendaddr24  0 sendSPI           \ 32-bit address and mode, QSPI
        11 SPIformat io!                \ 16-bit QSPI receive:
        0 sendSPI                       \ 4 beat dummy
        9 SPIformat io!                 \ 8-bit QSPI receive:
    else
        11 SPIcommand  sendaddr24
        0 sendSPI
    then
    0 sendSPI                           \ first 8-bit read
;

\ : fw>    SPIdata io@ swapb ;          \ 2.4071 -- w\ read next flash word

\ Single rate string write and read
:noname  count c,f ;                    \ Write string to flash
: write  literal times  drop ;          \ 2.4045 c-addr u --
:noname  fc> over c! char+ ;            \ Read string from flash
: read   literal times  drop ;          \ 2.4090 c-addr u --

there swap - . .( instructions used by flash access) cr
