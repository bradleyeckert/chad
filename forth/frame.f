\ Frame stack													9/10/19 BNE

\ Placed near the top of data space, grows upward.
64 cells equ |framestack|
\ Leave enough room above the frame stack for numeric conversion.

\ The frame stack is for freeing up stack space for library code to run
\ without overflowing the hardware stack.

\ f[  ( n -- ) Pushes the return stack and most of the data stack
\ except for the top n cells to the frame stack.

\ ]f  ( -- )  Restores the stack data saved by frame.

there
variable fp                             \ frame stack pointer
variable fp1                            \ frame pointer
64 cells buffer: fpad                   \ frame pad
dm-size |framestack| - equ fp0          \ empty frame stack

: fpclear  fp0 fp ! ;       \ 2.2900 -- \ clear the frame stack
: >mem     _! cell + ;      \ 2.2910 n a -- a'
: mem>     cell - _@ dup@ ; \ 2.2920 a -- a' n

\ Move data stack to memory
\ "4 buf ds>mem" --> mem = x3 x2 x1 x0 4   trivial case: 0
\                 addr1----^    addr2----^      addr1----^ ^----addr2
: ds>mem  ( ... n addr1 -- addr2 )		\ 2.2930 ... n addr1 -- addr2
    over >r  over if
        swap  for  >mem  next
    else  nip
    then r>  swap  >mem
;

\ Move memory to data stack
\ "mem>ds" --> mem = x3 x2 x1 x0 4    trivial case: 0
\           addr2----^    addr1----^       addr2----^ ^----addr1
: mem>ds  ( addr1 -- ... addr2 )		\ 2.2940 addr1 -- ... addr2
    mem> dup if
        for  mem> swap  next  exit
    then drop
;

\ Move the data stack to the frame stack, leaving n cells on top.
\ The return stack is emptied except for one cell to keep the sim running.
\ "11 22 33 44 55  2 f[" --> FS = 33 22 11 3 0    stack = ( 44 55 )
\                                           fp----^
: f[  ( ... n -- x[n-1] ... x[0] )		\ 2.2950 n --
    depth
    2dup- 0< if
        r> fp @  spstat 8 rshift 63 and ( RA fp rdepth )
		1 - 0 max  						\ leave a little on the return stack
        swap over                       ( RA rdepth fp cnt | ... )
        begin  dup  while 1 -
            swap r> swap  >mem  swap    \ push return stack to frame stack
        repeat
        drop  >mem  fp !  >r            \ restore return address
        over - 1 -  >r                  ( ... top | bottom )
        fpad ds>mem   fp1 !             \ save top of stack
        r> fp @ ds>mem  fp !            \ move bottom of data stack to frame
        fp1 @  mem>ds  drop             \ restore top of stack
    else
        -4 exception                    \ not enough data on the stack
    then
;

: ]f									\ 2.2960 ? -- ?
    depth  fpad ds>mem  fp1 !           \ save whatever is on the stack
	fp @   mem>ds                  		\ restore the old bottom
    r>  swap  mem>                      ( RA fp cnt )
    begin  dup  while 1 -
        swap mem> >r swap               ( RA fp n | ... x )
    repeat
    drop  fp ! >r                       \ restore return address
    fp1 @  mem>ds  drop                 \ restore top
; no-tail-recursion

there swap - . .( instructions used by f[ and ]f framing) cr

fpclear

: frtest 2 >r 1 >r  6 5 4 3  2 f[
          ]f r> r> 2drop 2drop 2drop ;
