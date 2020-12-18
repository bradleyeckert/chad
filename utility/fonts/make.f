
include fontcmp.f

\ H6: 16-pel text field, 10-pel letters
\ H5: 24-pel text field, 14-pel letters
\ H4: 32-pel text field, 20-pel letters  <-- default
\ H3: 48-pel text field, 30-pel letters
\ H2: 64-pel text field, 40-pel letters

0 constant revision

revision 2 /FONTS

cr .( ASCII in H4 size )
/msg HasASCII           \ minimum set of glyphs
\ MSGfile test.txt        \ include glyphs for this text
\ ^--- this hangs MakeFont. Need to debug.
H4 MakeFont
0 maketable

cr .( Numbers in H2 size)
/msg HasNumeric
H2 MakeFont
1 maketable

cr fhere . .( bytes of data total)
save ../../forth/myfont.bin

cr .( Finished generating the fonts)

