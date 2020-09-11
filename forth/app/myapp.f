\ Application example

\ To load: With your working directory here, type:
\ ..\chad include myapp.f  (in Windows), or
\ ../chad include myapp.f  (in Linux)

include ../core.f
include ../coreext.f
include ../redirect.f
include ../numout.f
include ../frame.f

\ iomap.c sends errors to the Chad interpreter
\ A QUIT loop running on the CPU would do something different.

:noname  ( error -- )  $8002 io! ; resolves exception



\ Examples

\ Use colorForth style of recursion
\ This kind of recursion is non-ANS.
\ We don't hide a word within its definition.

: fib ( n1 -- n2 )
    dup 2 < if drop 1 exit then
    dup  1 - fib
    swap 2 - fib  + ;

\ Try 25 fib, then stats

' fib resolves cold

: frtest1  2 >r 1 >r  6 5 4 3  2 f[  spstat . cr
          ]f r> . r> .  . . . . ;

.( Total instructions: ) there . cr
\ 0 there dasm
