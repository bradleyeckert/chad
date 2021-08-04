\ Frame stack                                                   9/10/20 BNE

\ Placed near the top of data space, grows upward.
128 cells equ |framestack|

\ The frame stack is for freeing up stack space for library code to run
\ without overflowing the hardware stack.

\ stack(  ( n -- ) Pushes the return stack and most of the data stack
\ except for the top n cells to the frame stack.

\ )stack  ( -- )  Restores the stack data saved by frame.

there
variable frp                            \ frame stack pointer
variable frp1                           \ temporary frame pointer
20 cells buffer: fpad                   \ frame pad
'tib @ |framestack| - equ frp0          \ bottom of frame stack
\ See numout.f: frp0 is also the end of the numeric conversion buffer.

: fpclear  frp0 frp ! ;                 \ 2.2900 --
: >mem     _! cell + ;                  \ 2.2910 n a -- a'
: mem>     cell - _@ _dup@ ;            \ 2.2920 a -- a' n

\ Move data stack to memory
\ "4 buf ds>mem" --> mem = x3 x2 x1 x0 4   trivial case: 0
\                 addr1----^    addr2----^      addr1----^ ^----addr2
: ds>mem  ( ... n addr1 -- addr2 )      \ 2.2930 ... n addr1 -- addr2
    over >r  over if
        swap  for  >mem  next
    else  nip
    then r>  swap  >mem
;

\ Move memory to data stack
\ "mem>ds" --> mem = x3 x2 x1 x0 4    trivial case: 0
\           addr2----^    addr1----^       addr2----^ ^----addr1
: mem>ds  ( addr1 -- ... addr2 )        \ 2.2940 addr1 -- ... addr2
    mem> dup if
        for  mem> swap  next  exit
    then drop
;

\ The `stack(` and `)stack` pair consumes 7 data and 5 return stack cells
\ plus whatever is on the stack. At the time they are called, the stacks
\ shouldn't be so full that calling them causes an overflow.

\ Move the data stack to the frame stack, leaving n cells on top.
\ The return stack is emptied except for one cell to keep the sim running.
\ "11 22 33 44 55  2 stack(" --> FS = 33 22 11 3 0    stack = ( 44 55 )
\                                            fp----^
: stack(  ( ... n -- x[n-1] ... x[0] )  \ 2.2950 n --
    depth
    2dup- 0< if
        r> frp @  spstat swapb 63 and   ( RA fp rdepth )
        1 - 0 max                       \ leave a little on the return stack
        swap over                       ( RA rdepth fp cnt | ... )
        begin  dup  while 1 -
            swap r> swap  >mem  swap    \ push return stack to frame stack
        repeat
        drop  >mem  frp !  >r           \ restore return address
        over - 1 -  >r                  ( ... top | bottom )
        fpad ds>mem   frp1 !            \ save top of stack
        r> frp @ ds>mem  frp !          \ move bottom of data stack to frame
        frp1 @  mem>ds  drop            \ restore top of stack
    else
        -4 throw                        \ not enough data on the stack
    then
;

: )stack                                \ 2.2960 ? -- ?
    depth  fpad ds>mem  frp1 !          \ save whatever is on the stack
    frp @   mem>ds                      \ restore the old bottom
    r>  swap  mem>                      ( RA fp cnt )
    begin  dup  while 1 -
        swap mem> >r swap               ( RA fp n | ... x )
    repeat
    drop  frp ! >r                      \ restore return address
    frp1 @  mem>ds  drop                \ restore top
; no-tail-recursion

\ Pick pushes the data stack to the frame stack, gets xu, and pops the data
\ stack from the frame stack.
: pick                                  \ 2.2970 xu...x0 u -- xu...x0 xu
    frp @ ds>mem  over >r  mem>ds drop r>
;

\ Index into the stack frame
: (local)  ( offset -- a )
    frp @ swap -
;

\ Set up a stack frame with n cells (popped from the data stack) and m
\ uninitialized cells.
: /locals  ( ... n m -- )
    dup >r cells  frp +!         frp @
    ds>mem  mem> r> + swap >mem  frp !
;

: locals/  ( -- )
    frp @ mem> negate cells + frp !
;

there swap - . .( instructions used by stack framing) cr

fpclear
