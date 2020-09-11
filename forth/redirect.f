\ Now let's get some I/O set up. ScreenProfile points to a table of xts.

there

\ Equates take up no code space. Have as many as you want.
0 equ 'TXbuf  							<a 1.6100 -- ioa> \ output register
2 equ 'TXbusy 							<a 1.6110 -- ioa> \ tx busy flag

variable ScreenProfile					<a 1.7000 -- addr>
: ExecScreen  ( n -- ) ScreenProfile @ execute execute ;
: emit  0 ExecScreen ;					<a 6.1.1320 x -->
: cr    1 ExecScreen ;					<a 6.1.0990 -->

\ stdout is the screen:

: _emit  begin 'TXbusy io@ while noop repeat 'TXbuf io! ;
: _cr    13 _emit 10 _emit ; \ --

11 |bits|
: stdout_table  exec1: [	\ The xts are less than 2048
    ' _emit | ' _cr
] literal ;

' stdout_table ScreenProfile !	\ assign it

there swap - . .( instructions used by I/O redirect) cr
