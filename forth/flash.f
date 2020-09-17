\ SPI flash

there

4 equ flashcon0     \ SPI controller registers
5 equ flashcon1
27182 equ flwp_en   \ 2.4021 -- x\ enable for flash-wp.

variable fwren0 \ lowest 64K sector number, set by `fwall`
variable fwren1 \ inverse of fwren0, used as a backup. Must be ~fwren0.
variable sector \ 2.4000 -- a-addr
variable fp     \ 2.4010 -- a-addr

: flash-wp      \ 2.4020 sector key --
    flwp_en xor if  drop exit  then
    dup fwren0 !  invert fwren1 !
;
0 flwp_en flash-wp \ testing

: waitSPI  \ --   \ wait for SPI transfer to finish
    begin  flashcon0 io@  while  noop  repeat
;
: sendSPI  \ c -- \ transmit an SPI byte
    waitSPI  flashcon1 io!
;
: readSPI  \ -- c \ result of transfer
    waitSPI  flashcon1 io@
;
: SPIcommand  \ c --
    waitSPI   0 flashcon0 io!           \ drop CS line
    sendSPI
;
: ]read    waitSPI  [ ;                 \ 2.4080 --
: SPIend   1 flashcon0 io! ;            \ 2.4081 --
: fl_wren  6 SPIcommand ]read ;
: fl_wrdi  4 SPIcommand ]read ;
: waitflash  \ --
    begin  5 SPIcommand  0 sendSPI
           readSPI SPIend  1 and
    while  noop
    repeat
;

: sendaddr24  \ addr --
    sector @ sendSPI
    dup 8 rshift sendSPI  sendSPI
;

: ]write   ]read  fl_wrdi ;             \ 2.4050 --
: f>       0 sendSPI  readSPI ;         \ 2.4070 c --
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
    waitSPI  sendSPI  bump_fp
    is256? if  ]write      then         \ end write at end of page
    is4K?  if  erase4K     then
    is256? if  dup write[  then         \ start a new page
    drop
;
: write   \ 2.4045 c-addr u --\ Write string to flash
    dup if
        for  count  >f  next  drop
    else  2drop
    then
;
: read[   \ 2.4060 fa --\ Begin fast read
    waitflash  11 SPIcommand  sendaddr24  0 sendSPI
;

: read    \ 2.4090 c-addr u --\ Read string from flash
    dup if
        for  f> over c! char+  next  drop
    else  2drop
    then
;

\ Bootloader commands:
\ `<space>` Launch the app (if possible)
\ `!` Write next SPI byte, expect 2 hex digits.
\ `@` Read next SPI byte, return 2 hex digits.
\ `#` Start a SPI flash command, expect 2 hex digits.
\ `$` Stop SPI flash command, return `.` when flash is not busy.
\ `%` ROM version, return 2 hex digits.
\ `&` Bootloader format, return 2 hex digits.
\ `'` nop
\ `other` Ignored.


there swap - . .( instructions used by flash access) cr
