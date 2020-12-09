\ TFT LCD drawing                               12/9/20 BNE

\ Font data is stored in SPI flash in compressed format. It uses 16-bit tokens
\ for various encoding types to handle glyph bitmaps that are mostly black and
\ white but with 4-bit grayscale at the edges.

there

: LCDdimensions  ( -- x y )  320 480 ;  \ physical dimensions, datasheet view

: LCDcommand [ $10 cells ] literal io! ; \ c -- \ write command byte
: LCDdata    [ $11 cells ] literal io! ; \ c -- \ write data byte
: LCDend   0 [ $12 cells ] literal io! ; \ --   \ chip select high
: LCDgram    [ $13 cells ] literal io! ; \ n -- \ write data cell (6:6:6 GRAM)

hwoptions 8 and [if]                    \ TFT support?

\ Foreground and background colors are stored in coprocessor registers

: set-colors  ( background foreground -- )
   [ $18 cotrig ]  2drop
;
: get-colors  ( -- background foreground )
   2 [ $38 cotrig ] drop                \ mload with %10
   [ $58 cotrig ]  costat               \ background color
   [ $58 cotrig ]  costat               \ foreground color
;
: g_mono  ( pattern length -- )         \ output a monochrome bit pattern
   dup if                               \ something to draw?
      swap [ $38 cotrig ] drop          \ mload the pattern
      for  [ $58 cotrig ]  costat       \ get pixel
         LCDgram
      next  exit
   then  2drop
;
: g_gray  ( scale -- color )
   [ $78 cotrig ] drop                  \ trigger interpolation
   cowait
   [ 8 cotrig ]  costat                 \ read color
;

[then]

\ Pixel interpreter
\ tokens are encoded for decoding with 16-way jump.
\ 000xxxxx_xxxxxxxx  Reserved
\ 001nnnnx_xxxxxxxx  Output 0 to 9 monochrome pixels, LSB first.
\ 0100aaaa_aabbbbbb  Output a BG pixels followed by b FG pixels.
\ 0110gggg_cccccccc  Output 4-bit g pixel followed by up to 127 BG pixels
\ 0111gggg_cccccccc  Output 4-bit g pixel followed by up to 127 FG pixels
\ 1xxxxxxx_xxxxxxxx  Output 15 monochrome pixels, LSB first.

: pixrun  ( color length -- )           \ output a run of pixels
   dup if
      for  dup LCDgram
      next  drop exit
   then  2drop
;

: _nopix   ( x -- )  drop ;
: _mono15  ( x -- )  $7FFF and  15 g_mono ;
: _mono9   ( x -- )  dup $1FF and  swap swapb 2/ $0F and  g_mono ;

: _run01   ( x -- )
   >r get-colors swap
   r@ 6 rshift $3F and pixrun           \ run of BG pixels
   r> $3F and pixrun                    \ run of FG pixels
;
: _grayX  ( x color -- )
   >r  dup>r  swapb $0F and  g_gray LCDgram
   2r>  $FF and  pixrun
;
: _gray0  ( x -- )
   get-colors drop _grayX
;
: _gray1  ( x -- )
   get-colors nip _grayX
;

16 |bits|
: bitcmd_table  exec0: [  \ index is a multiple of 4
    ' _nopix  | ' _nopix  | ' _mono9  | ' _mono9  |
    ' _run01  | ' _nopix  | ' _gray0  | ' _gray1  |
    ' _mono15 | ' _mono15 | ' _mono15 | ' _mono15 |
    ' _mono15 | ' _mono15 | ' _mono15 | ' _mono15
] literal ;

: g_bitcmd  ( n16 -- )
   dup  swapb 2/ 2/ $3C and bitcmd_table execute
;

: LCDrowcol  ( z0 z1 cmd -- )            \ set row or column entry limits
   LCDcommand  >r
   dup swapb LCDdata  LCDdata  r>
   dup swapb LCDdata  LCDdata  LCDend
;

variable cursorY                        \ cursor Y position
variable cursorX                        \ cursor X position
variable g_Y                            \ current field Y position
variable g_X                            \ current field X position
variable g_H                            \ current field height
variable g_W                            \ current field width
variable g_MADCTL                       \ state of Memory Access Control bits
variable g_cdims                        \ packed char field width:height
variable g_corner                       \ packed char field x:y corner
variable kerning                        \ amount of horizontal kerning (signed)
variable linepitch                      \ amount of vertical spacing for CR

: g_setmac  ( c -- )
   dup g_MADCTL !
   $36 LCDcommand  LCDdata              \ Set bits MY, MX, MV, ...
;

\ Bits 7:5 of the LCD controller's MADCTL (36h) register determines the image
\ orientation. Real hardware would flip the display immediately after the bits
\ are changed. In simulation, changes don't show until the screen is redrawn.

\ MV=1 mode does not work in C simulation.

: _g_wh  ( -- x y )  LCDdimensions  g_MADCTL @ $20 and if swap then ;
: g_width  ( -- x )  _g_wh  drop ;
: g_height  ( -- y ) _g_wh  nip ;

: at     ( x y -- )                     \ cursor positioning
   cursorY 2!
;

: g_at   ( x y -- )                     \ top left corner of graphic box
   g_Y 2!
;

: g_box  ( w h -- )                     \ set up pour-box at the cursor
   2dup g_H 2!                          \ save the field dimensions
   1- >r  1- >r  g_Y 2@  swap           ( y x | h w )
   dup r> + $2A LCDrowcol
   dup r> + $2B LCDrowcol
;

: g_fill  ( color -- )                  \ put color in the g_box
   g_H 2@ * ?dup if
      $2C LCDcommand
      for  dup LCDgram  next
      LCDend
   then  drop
;

: g_page  ( -- )                        \ fill with background color
   0 0 g_at  g_width g_height g_box
   get-colors drop g_fill
   0 0 at                               \ home the cursor
;

\ After a xchar has been drawn, its width is known. Calculate the amount to
\ advance the cursor. It may be negative to handle right-to-left languages.

: g_Xpitch  ( -- n )
   [ g_corner 1 + ] literal c@          \ left edge of glyph
   [ g_cdims 1 + ] literal c@  +        \ plus width
   kerning @ dup>r abs +                \ plus kerning
   r> 0< if negate then
;

variable FontID                         \ 0 = main font

: havefont  ( -- flag )                 \ is FontID okay?
   fontDB 0 c@f  FontID @ >
;

\ Look up a font character in flash.

\ `faddr` returns a double cell address.
\ The bottom of the font database must be addressable by a single cell.
\ The rest of the database uses double addressing.

: faddr  ( xchar -- df-addr | 0 0 )
   >r  )gkey
   [ fontDB 4 + ] literal               \ skip the font revision number
   FontID @ 3* + 0 d@f  fontDB 0 d+     \ 'tables for this FontID
   2dup  r@ 6 rshift 2* 0 d+  w@f  dup if   ( 'fine offset )
      0 d+  fcount  r> $3F and              ( 'glyphs max index )
      tuck > 0= if  2drop 0 dup exit  then  \ beyond the end
      3* 0 d+ d@f  exit
   then  rdrop dup                      \ fine table does not exist
;

: byte-split  ( w -- hi lo )
   dup swapb $FF and  swap $FF and
;

: g_emit  ( xchar -- )
   faddr over if
      fontDB 0 d+ w@f(                  \ get packed width:height
      dup g_corner !
      byte-split  cursorY 2@  d+  g_at  \ offset from cursor
      @f>  dup g_cdims !
      byte-split g_box                  \ set bitmap dimensions
      @f> ?dup if                       \ get number of commands
         $2C LCDcommand
         for  @f> g_bitcmd  next        \ process 16-bit bitmap commands
         LCDend
      then
      )@f
   else  2drop
   then
   g_Xpitch cursorX +!                  \ bump cursor
;

: qq  \ test dump 10 digits 9 to 0
   g_page
   10 for r@ 47 + g_emit next
;

\ define some colors

8 base !
777777 equ white   770000 equ red    007700 equ green     000077 equ blue
202020 equ dkgray  400000 equ dkred  004000 equ dkgreen   000040 equ dkblue
606060 equ ltgray  774040 equ ltred  407740 equ ltgreen   404077 equ ltblue
000000 equ black   007777 equ cyan   770077 equ magenta   777700 equ yellow
404040 equ gray    004040 equ dkcyan 400040 equ dkmagenta 404000 equ dkyellow
776063 equ pink    407777 equ ltcyan 774077 equ ltmagenta 777740 equ ltyellow
decimal

black white set-colors \ for testing

there swap - . .( instructions used by LCD) cr

\ To do:
\ Add some compact fixed fonts for programming stuff.
\ For example: 5x7 chars on a 6 pixel pitch would fit 53 chars in 320 pels or
\ 80 chars in 480 pels. Enough for a terminal.
