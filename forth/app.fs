\ Application example

include nucleus.fs
include redirect.fs
include numout.fs
include frame.fs

\ iomap.c sends errors to the Chad interpreter
\ A QUIT loop running on the CPU would do something different.

:noname  ( error -- )  $8002 io! ; is exception



\ Examples

\ Use colorForth style of recursion
\ This kind of recursion is non-ANS.
\ We don't hide a word within its definition.

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - fib
    swap 2 - fib  + ;

\ Try 25 fib, then stats

' fib is cold

: frtest1  2 >r 1 >r  6 5 4 3  2 frame  spstat . cr 
          unframe r> . r> .  . . . . ;

.( Total instructions: ) there . cr
\ 0 there dasm
