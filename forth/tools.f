
applets [if] .(     Applet bytes: { )   \ }
paged applet  paged [then]

: .s                                    \ 2.6290 ? -- ?
   _.s  ." <-Top " cr
;

: fdump  ( f-addr len -- )              \ only useful if tkey is 0
   dup if
      over 5 h.x  0 swap
      for
         over 15 and 0= if cr over 5 h.x then
         fcount h.2
      next
   then  2drop
;

\ Dump in cell and char format

16 equ DumpColumns

: udump  ( c-addr u -- padding )        \ dump in cell format
   [ 1 cells 1- ] literal + cell/       \ round up to get all bytes
   [ DumpColumns cell/ ] literal
   dup>r min  r> over -                 \ cells remainder
   [ cellbits 4 / 1+ ] literal * >r     \ addr cells | padding
   for                                  \ 1 or more cells
      @+ [ cellbits 4 / 1- ] literal h.x
   next  drop
   r>
;

: cdump  ( caddr1 u1 -- caddr2 u2 )     \ dump in char format
   dup  DumpColumns min
   for
      over c@
      dup bl 192 within 0= if drop [char] . then
      emit  1 /string
   next
;

: dump                                  \ 2.6292 ( c-addr bytes -- )
   >r [ -1 cells ] literal and r>       \ cell-align the address
   begin dup while
      over  2 h.x space
      2dup  udump 1+ spaces
      cdump  cr
   repeat  2drop
;

applets [if] end-applet  paged swap - . [then]
.( } used by tools) cr

