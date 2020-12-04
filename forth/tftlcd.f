\ TFT LCD drawing                               11/29/20 BNE

\ Font data is stored in SPI flash in compressed format. It uses 16-bit tokens
\ for various encoding types to handle glyph bitmaps that are mostly black and
\ white but with 4-bit grayscale at the edges.

\ tokens are encoded for decoding with 16-way jump.
\ 001nnnnx_xxxxxxxx  Output 0 to 9 monochrome pixels, LSB first.
\ 0100aaaa_aabbbbbb  Output a BG pixels followed by b FG pixels.
\ 0110gggg_cccccccc  Output 4-bit g pixel followed by up to 255 BG pixels
\ 0111gggg_cccccccc  Output 4-bit g pixel followed by up to 255 FG pixels
\ 1xxxxxxx_xxxxxxxx  Output 15 monochrome pixels, LSB first.

: 64*f  ( n1 frac6 -- n2 )
   [ 5  2* 2* 2* 2* 2*  $12 +  cotrig ]
   2drop  cowait
   [ 2 cotrig ]  costat
;

variable bgcolor
variable fgcolor
variable gray

\ Gray scale interpolation takes ~250 cycles in software, the equivalent of 20
\ pixel writes. At 4 or 6 gray pixels per row and 20 rows, it slows glyph
\ rendering by a factor of 6.

\ Use the "gpu" interpolation in the coprocessor instead. It's also in coproc.c.

: _gscale  ( scale -- n )
   cowait
   [ 5 cotrig ]  costat  \ scale m
   [ 5  2* 2* 2* 2* 2*  $13 +  cotrig ]
   2drop  cowait
   [ 2 cotrig ]  costat
;
: gscale  ( FG BG shift -- FG BG color )
   >carry 0 [ $16 cotrig ] swap  gray @ invert $3F and  _gscale
   >r     0 [ $16 cotrig ] swap  gray @                 _gscale
   r> +   0 [ $36 cotrig ] 2drop  cowait
   [ 5 cotrig ]  costat  \ left shift the color
;
: gray  ( gray -- color )  \ about
   gray !  fgcolor @  bgcolor @
   12 gscale >r  6 gscale >r  0 gscale >r
   2drop  r> r> + r> +
;

