\ Compiler words

there
\ make-heads needs:
\ {noop execute compile, lit, or doLitop noCompile}

: c,       here c!  1 allot ;           \ 2.0580 c --

\ Compile to code RAM
\ This might go away if compile to flash is possible.

: !c     ( n addr -- )
   io'rxbusy io!              \ set address
   io'txbusy io!              \ write data
;

variable lastinst \ load with $100 to inhibit exit change

: ,c    ( inst -- )
   dup lastinst !
   [char] c emit  dup . \ display instead of compiling...
   cp @ !c  1 cp +!
;

\ The LEX register is cleared whenever the instruction is not LITX.
\ LITX shifts 11-bit data into LEX from the right.
\ Full 16-bit and 32-bit data are supported with 2 or 3 inst.

: extended_lit  ( k11<<11 -- )
   11 rshift  $7FF and $E000 + ,c
;

cellbits 22 > [if]
: lit,                                  \ 2.5000 u --
   dup $FFC00000 and if
      dup 11 rshift extended_lit
      dup extended_lit
   else
      dup $3FF800 and if
         dup extended_lit
      then
   then  $7FF and
   $100 /mod 9 lshift +
   $F000 + ,c
;
[else]
: lit,                                  \ 2.5000 u --
   dup $3FF800 and if
      dup extended_lit
   then  $7FF and
   $100 /mod 9 lshift +
   $F000 + ,c
;
[then]

: compile,                              \ 2.5010 xt --
   dup $FFE000 and if
      dup 13 rshift  $E000 + ,c         \ litx
   then  $1FFF and   $C000 + ,c         \ call
;
: relast  ( inst -- )
   [char] r emit
   0 invert cp +! ,c                    \ recompile the last instruction
;
: exit,                                 \ 2.5020 --
   lastinst @ dup $810C and 0= if       \ last ALU can accept return?
      $10C + relast exit  then          \ change to include a return
   $F000 2dup and  =                    \ last literal?
   if  $100 + relast exit  then         \ change to include a return
   drop $10C ,c                         \ plain return
;

: doLitOp  ( inst w -- 0 )
   or ,c 0
;
: noCompile  ( -- )
   -98 throw
;
: InstExec  ( inst -- )
   [ cm-size 2 - ] literal tuck !c      \ compile the instruction to end of
   $010C over 1+ !c  execute            \ code space and run it
;


there swap - . .( instructions used by compiler) cr
