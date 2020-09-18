\ Chad Tiny Encryption Algorithm							9/17/20 BNE

\ XTEA-inspired crypto algorithm for Chad.
\ Uses 2-cell data and a 4-cell key.
\ For 18-bit cells, it's 36-bit data and a 72-bit key.

\ This uses a fixed key, but it can easily be variable if needed.
\ CTEA is used for firmware upload to flash when an FPGA has user flash.
\ For SPI flash, it's like locking the door but leaving the window open.
\ However, flash updates shouldn't be in plaintext so it's better to keep
\ the data private now and shut the window later.

\ Terminal access to Forth in plaintext also leaves the window open.
\ CTEA isn't SSH, but it's something. A stdio-to-COM-port app wouldn't be
\ hard to write. But where do you hide the key?
\ Unless, well, you write it in 8th and encrypt the app.

\ The numeric conversion pointer `hld` is used as temporary storage.

there

\ Note: Key lengths over 56-bit may be subject to export controls.
\ The last cell in the table is 0 to make it a 54-bit key.

cellbits |bits|
: xkey  3 and exec2: [ 123456 | 654321 | 111111 | 0 ] literal ;
$179B9 equ xdelta
20 equ xrounds

: xshift  ( v -- v v' )
    dup 2* 2* 2* 2*  over 2/ 2/ 2/ 2/ 2/  xor  over +
;
: xterma  ( v -- v v' )
    xshift  hld @  dup xkey +  xor
;
: xtermb  ( v -- v v' )
    xshift  hld @  dup swapb 2/ 2/ 2/ xkey +  xor
;

: encipher  ( v0 v1 -- v0' v1' )
    0 hld !
    xrounds for
		xterma rot +
		xdelta hld +!
		xtermb rot +
	next
;
: decipher  ( v0 v1 -- v0' v1' )
    [ xdelta xrounds * ] literal hld !
	swap
    xrounds for
	    xtermb rot swap -
		[ xdelta negate ] literal  hld +!
	    xterma rot swap -
	next
;

there swap - . .( instructions used by ctea) cr
