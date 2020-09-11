# Frame Stack

In order to limit the depths of the stacks when using library code,
library code can manually manage the hardware stacks by emptying the stacks
to data memory before doing something complex and restoring them afterwards.
`frame.f` implements a frame stack.

- `frame`  *( n -- )* Pushes the data stack except for the top n cells
and most of the return stack to the frame stack.

- `unframe`  *( -- )*  Restores the stack data saved by `frame`.

For example,

```
: foo  2 frame  type  unframe ;
```

The `frame` and `unframe` pair consumes 7 data and 5 return stack cells
plus whatever is on the stack.
At the time they are called, the stacks shouldn't be so full that calling
them causes an overflow.

Numeric conversion typically takes 5 data and 11 return stack cells.
A 16-deep stack needs some management before such conversions to prevent
overflow.

## Other possible uses

`0 frame` would push the entire data stack to the frame stack.
It could then be printed by `.s`.

Local variables could be handled by the frame stack.
For example, three local variables would be handled by pushing the
top three stack items *( x3 x2 x1 )* to the frame stack so that the
variables are stored in memory:

```
frame stack: ... x1 x2 x3 3
fp -------------------------^
```

A primitive to get the address of a local variable:

: local  ( idx -- a ) cells dp @ swap - ;

A compiler that supports locals would manage the frames and converting
locals to indices and calls to `local`.

As interesting as locals are, I find that I don't use them. 
Many Forth programmers consider them a crutch.
If your code is complex enough to benefit from locals, it's too complex.
Windows programming is an exception, but `chad` doesn't have to support
the Windows API.
 