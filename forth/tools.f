
.(     Applet bytes: { )                \ }
paged applet
paged

: fdump  ( f-addr len -- )              \ only useful if tkey is 0
   over 5 h.x  0 swap
   for
      over 15 and 0= if cr over 5 h.x then
      fcount h.2
   next 2drop
;

end-applet
paged swap - . .( } used by tools) cr
