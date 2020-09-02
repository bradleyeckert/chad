# Bit Field Addressing

Chad uses byte addressing.

My original thinking regarding bit field addressing was that it would be rather
clean to declare variables with only the size you need and still have them look
like variables. It would be handy on a cell-addressed machine.
After implementing bit fields, I decided I had better use byte addressing anyway.
So, there's not much to be gained here.

Reasons to use bit fields:

- Saves data space: Use only the bits in data memory you need. 
- The range is automatically limited, so a narrow bit field can safely use a 2^n sized lookup table.
- `b@` is slightly faster than `c@`.

Reasons not to: 

- They are a little slower, especially on write.
- An ANS compatibility harness will be even slower.
- Backward compatibility to ANS will cost you.

So, maybe it was a dead-end experiment.
It did demonstrate exactly how many cycles you would need for `b@` and `b!`.

A bit fields could be used instead of `variable` when raw speed is not needed.
The bit field specifier, or *bf*, consists of packed address, shift, and width fields.
A 16-bit cell would address a bit field within a 256-cell block of RAM.
Okay, not much, but a 32-bit cell would address 4M cells.
Some bit field keywords are:

- `bvar` *( <name> -- )* Declare a bit field variable that returns a *bf*. 
- `b!` *( u bf -- )* Stores *u* to a bit field.
- `b@` *( u bf -- )* Fetches *u* from a bit field.
- `bit+` *( bf1 -- bf2 )* Skips to the next field in an array of bit fields.
- `balign` *( -- )* Align the next bit field on a cell boundary.

Example use of bit fields:

```forth
5 bvar myvar  \ declare a 5-bit variable
11 myvar b!   \ store 11 to it
myvar b@ .    \ read and print it
```

## Bitfield primitives in the Chad ISA:

Bit field read is 6 cycles.

```
CODE b@  ( bf -- n )
    mask    T->N    d+1     alu \ ( bf addr )
    T                       alu \ wait for read to settle
    [T]                     alu \ read the cell
    N       T->N            alu
    N>>T            d-1     alu
    T&W     RET         r-1 alu \ apply the mask
END-CODE
```

Bit field write is 22 cycles. Is that bad?
You read them a lot more often than you write them.
If it's too slow, use a `variable`.
    
```
CODE b!  ( n bf -- )
    N       T->N            alu \ ( bf n )
    N       T->R    d-1 r+1 alu
    mask    T->N    d+1     alu
    N       T->N    d+1     alu
    R       T->N    d+1 r-1 alu
    N       T->N            alu
    N<<T            d-1     alu \ T is shifted and aligned n
    N       T->R    d-1 r+1 alu
    N       T->N            alu
    W       T->N    d+1     alu
    N       T->N            alu
    N<<T            d-1     alu
    ~T                      alu \ T is mask for read-modify-write
    N       T->N    d+1     alu
    T                       alu \ wait for read to settle
    [T]                     alu
    T&N             d-1     alu \ Zero the bits in the read data
    R       T->N    d+1 r-1 alu
    T+N             d-1     alu \ merge n
    N       T->N            alu
    T       N->[T]  d-1     alu \ save it
    N       RET     d-1 r-1 alu
END-CODE
```

Bit fields are useful on processors with bit-packed peripherals.
They are designed to be usable with C's bitfield structures.
A similar usage would be portable to commercial MCUs.
In that case, you would set the base address of the peripheral
and use `b@` and `b!` to access within the peripheral.

