\ Now let's get some I/O set up. ScreenProfile points to a table of xts.

there

variable ScreenProfile                  \ 2.2100 -- addr
: ExecScreen  ( n -- )
    2 min  ScreenProfile @ execute execute
;
: emit  0 ExecScreen ;                  \ 2.2110 x --
: cr    1 ExecScreen ;                  \ 2.2111 x --
: page  2 ExecScreen ;                  \ 2.2112 x --

\ stdout is the screen:

: _emit  begin io'txbusy io@ while noop repeat  io'udata io! ;
: _cr    13 _emit 10 _emit ;            \ --
: esc[x  27 emit  [char] [ emit  emit ;
: _page  [char] 2 esc[x  [char] J emit ; \ "\e[2J" for VT100/VT220

11 |bits|
: stdout_table  exec1: [                \ The xts are less than 2048
    ' _emit | ' _cr | ' _page
] literal ;

: con   ( -- )                          \ direct to console
   ['] stdout_table ScreenProfile !
; con

\ I/O sometimes needs timing, so here it is.

variable hicycles

:noname ( -- )
   hicycles @ 1 +
   hicycles !
; resolves irqtick \ clock cycle counter overflow interrupt

\ Read raw cycle count. Since io@ returns after the lower count is read,
\ it will service iqrtick if it has rolled over. hicycles is safe to read.

: rawcycles ( -- ud )
   io'cycles io@  hicycles @
;

\ Assume 100 MHz clock

: ms  ( n -- )
   100000 um* rawcycles d+              \ cycle count to wait for
   begin  2dup rawcycles du<            \ spin until time elapsed
   until  2drop
;

there swap - .(  ) . .( instructions used by I/O redirect) cr
