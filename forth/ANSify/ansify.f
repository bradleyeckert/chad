\ ANS harness for chad code

\ This file allows chad code to compile and run on an ANS Forth with the exception
\ of non-portable tricks like fall-through ( : x ... [ : y ... ; ).

\ This bag of tricks includes:
\ 1. Primitives from frame.f, useful for moving between stacks and memory.
\ 2. Frame memory based local variables.
\ 3. Chad's version of for next.

[defined] -ansify [if] -ansify [else] marker -ansify [then]
1 constant test-ansify

\ 1. Frame Stack

128 cells constant |framestack|

variable frp                            \ frame stack pointer
|framestack| buffer: frp0               \ bottom of frame stack

: fpclear  frp0 frp ! ;                 \ --
: >mem     tuck ! cell + ;              \ n a -- a'
: mem>     cell - dup @ ;               \ a -- a' n

\ Move data stack to memory
\ "4 buf ds>mem" --> mem = x3 x2 x1 x0 4   trivial case: 0
\                 addr1----^    addr2----^      addr1----^ ^----addr2
: ds>mem  ( ... n addr1 -- addr2 )      \ ... n addr1 -- addr2
    over >r  over if
        swap  0 do  >mem  loop
    else  nip
    then r>  swap  >mem
;

\ Move memory to data stack
\ "mem>ds" --> mem = x3 x2 x1 x0 4    trivial case: 0
\           addr2----^    addr1----^       addr2----^ ^----addr1
: mem>ds  ( addr1 -- ... addr2 )        \ addr1 -- ... addr2
    mem> dup if
        0 do  mem> swap  loop  exit
    then drop
;

\ 2. Extended-scope local variables based on frame stack

\ ANS Forth locals are nice, but their scope is limited to the current definition.
\ Not very useful. They are practically syntactic sugar. Most experts eschew them.
\ A proposed lexicon for locals is:

\ begin-locals  begins a locals scope and adds it to the search order
\ end-locals  ends the locals scope and removes it from the search order
\ local  ( u <name> -- )  defines name that pushes an address onto the data stack
\ (local)  ( u -- a )  run-time portion of local <name>
\ /locals  ( ... n m -- )  moves n cells onto the frame stack with m cells extra
\ locals/  ( -- )  discards the frame

\ example:
\ module
\ 0 cells local foo
\ 1 cells local bar
\ : first foo ? ;
\ : second bar ? ;
\ exportable
\ : third ( bar foo -- ) 2 0 /locals foo bar locals/ ;
\ end-module

\ This strategy works best when there is one publicly used word in the scope.
\ The other words are left visible

variable localwid

: module  ( -- )
    get-order wordlist  dup localwid !  swap 1+  set-order
    definitions
;
: exportable  ( -- )
    get-order  2 pick set-current  set-order
;
: end-module  ( -- )
    get-order  nip 1-  set-order  definitions
;
: (local) ( offset -- a )
    frp @ swap -
;
: local  ( offset <name> -- )
    get-current >r
    localwid @ set-current  create 2 cells + ,
    r> set-current
    does> @ (local)
;
: /locals  ( ... n m -- )
    dup >r cells  frp +!         frp @
    ds>mem  mem> r> + swap >mem  frp !
;
: locals/  ( -- )
    frp @ mem> negate cells + frp !
;

fpclear

\ example:
test-ansify [if]
module
0 cells local foo
1 cells local bar
cr .( foo is at ) foo .
cr .( bar is at ) bar .
: first  cr ." the first local is " foo ? ;
: second cr ." the second local is " bar ? ;
exportable
: test ( bar foo -- )
    2 0 /locals
    first second
    locals/
;
end-module
1 2 test
[then]

\ 3. for next

: for
    postpone >R
    postpone BEGIN
; immediate
: next
    postpone R>
    postpone 1-
    postpone DUP
    postpone >R
    postpone 0=
    postpone UNTIL
    postpone R>
    postpone DROP
; immediate

test-ansify [if]
: test4 3 for r@ . next ;
cr test4 .( should be 3 2 1 )
[then]

