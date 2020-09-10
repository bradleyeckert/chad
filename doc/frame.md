# Frame Stack

In order to limit the depths of the stacks when using library code,
library code can manually manage the hardware stacks by emptying the stacks
to data memory before doing something complex and restoring them afterwards.

- `frame`  *( n -- )* Pushes the data stack except for the top n cells
and most of the return stack to the frame stack.

- `unframe`  *( -- )*  Restores the stack data saved by `frame`.

For example,

```
: foo  2 frame  type  unframe ;
```

The `frame` and `unframe` pair consume 7 data and 5 return stack cells
plus whatever is on the stack.
At the time they are called, the stacks shouldn't be so full that calling
them causes an overflow.

Numeric conversion typically takes 5 data and 11 return stack cells.
A 16-deep stack needs some management before such conversions to prevent
overflow.

`0 frame` would push the entire data stack to the frame stack.
It could then be printed by `.s`.

