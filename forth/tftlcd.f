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

