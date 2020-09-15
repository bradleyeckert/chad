\ Now let's get some I/O set up. ScreenProfile points to a table of xts.

there

\ Equates take up no code space. Have as many as you want.
0 equ 'TXbuf                            \ 2.2000 -- ioa \ output register
2 equ 'TXbusy                           \ 2.2010 -- ioa \ tx busy flag

variable ScreenProfile                  \ 2.2100 -- addr
: ExecScreen  ( n -- ) ScreenProfile @ execute execute ;
: emit  0 ExecScreen ;                  \ 2.2110 x --
: cr    1 ExecScreen ;                  \ 2.2111 x --
: page  2 ExecScreen ;                  \ 2.2112 x --

\ stdout is the screen:

: _emit  begin 'TXbusy io@ while noop repeat 'TXbuf io! ;
: _cr    13 _emit 10 _emit ; \ --
: esc[x  27 emit  [char] [ emit  emit ;
: _page  [char] 2 esc[x  [char] J emit ; \ "\e[2J" for VT100/VT220

11 |bits|
: stdout_table  exec1: [    \ The xts are less than 2048
    ' _emit | ' _cr | ' _page
] literal ;

' stdout_table ScreenProfile !  \ assign it

there swap - . .( instructions used by I/O redirect) cr
