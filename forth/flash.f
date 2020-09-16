\ SPI flash

there

4 equ flashcon0		\ SPI controller registers
5 equ flashcon1
27182 equ flwp_en   \ enable for flash-wp.

variable fwren0	\ lowest 64K sector number, set by `fwall`
variable fwren1	\ inverse of fwren0, used as a backup. Must be ~fwren0.
variable sector	\ 2.4000 -- a-addr
variable fp  	\ 2.4010 -- a-addr

: flash-wp		\ 2.4020 sector key --
    flwp_en xor if  drop exit  then
	dup fwren0 !  invert fwren1 !
;

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
	waitSPI   0 flashcon0 io!  			\ drop CS line
	sendSPI
;
: SPIend  \ --
	waitSPI   1 flashcon0 io!  			\ raise CS line
;
: waitflash  \ --
	begin  5 SPIcommand  0 sendSPI  
	       readSPI  1 and
	while  noop
	repeat
;
: fl_wren  6 SPIcommand SPIend ;
: fl_wrdi  4 SPIcommand SPIend ;

: sendaddr24  \ addr --
    sector @ sendSPI
	dup 8 rshift sendSPI  sendSPI
;

: ]read   \ 2.4080 --
	waitSPI  1 flashcon0 io!
;
: ]write  \ 2.4050 --
	]read  fl_wrdi
;
: write[  \ 2.4030 fa --
	fwren0 @  dup
	fwren1 @  <> -81 and exception  	\ corrupted wall
	sector @  <  -82 and exception  	\ under the wall
	fp !  waitflash
	fl_wren
	2 SPIcommand  sendaddr24
;
: >f      \ 2.4040 c --
	waitSPI  sendSPI
	fp @ 1 + dup 65535 and  dup fp !	( fp fp16 )
	swap 65536 and  if 1 sector +! then \ bump sector if fp wrapped
	dup 255 and 0=
	dup>r  if  ]write  then				\ end write at end of page
	4095 and 0=							\ erase next 4K sector?
	if  fl_wren  
	    32 SPIcommand  sendaddr24 ]read
	then
	r> if  fp @ write[  then			\ start a new page
;
: read[   \ 2.4060 fa --
	waitflash  11 SPIcommand  sendaddr24
;
: f>      \ 2.4070 c --
    sendSPI  readSPI
;

\ The `>f` sequence is:
\ if `fp[7:0]` is 0, end the page program command.
\ if `fp[11:0]` is 0, erase the next 4KB sector.
\ if `fp[7:0]` is 0, start a new page program command.
\ if `fp[15:0]` is 0, clear `fp` and bump `sector`.

there swap - . .( instructions used by flash access) cr
