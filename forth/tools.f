
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

8 equ DumpColumns

: dump  ( c-addr bytes -- )             \
    >r [ -1 cells ] literal and r>      \ cell-align the address
    begin dup while
        over  2 h.x space
        2dup  DumpColumns
        dup >r min  r> over -
        [ cellbits 4 / 1+ ] literal * >r \ a u addr len | padding
        begin dup while >r              \ dump cells in 32-bit hex
            @+ [ cellbits 4 / 1- ] literal h.x r> 1-
        repeat  2drop  r> 1+ spaces
        2dup  [ DumpColumns cells ] literal min
        begin dup while >r              \ dump chars in ASCII
            count
            dup bl 192 within 0= if drop [char] . then
            emit  r> 1-                 \ outside of 32 to 191 is '.'
        repeat 2drop
        [ DumpColumns cells ] literal /string
        0 max  cr
    repeat  2drop
;

applets [if] end-applet  paged swap - . [then]
.( } used by tools) cr

