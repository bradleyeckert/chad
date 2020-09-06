# Differences from ANS Forth

## Non-standard words

- `assert` *( n1 n2 -- )* Displays an error message if n1 <> n2.
- `cellbits` *( -- n )* The number of bits in a cell.

### Compilation

- `:` *( <name> -- )* Starts a definition. The stack is not changed.
- `;` *( -- )* Finishes a definition.

`;` in immediate mode does not compile a return.
This allows the definition to fall through to the next definition.
Forths that separate code and header spaces allow this Non-ANS trick.

### Defer and is

- `defer` *( <name> -- )* Defines a forward reference.
- `is` *( xt <name> -- )* Resolves a forward reference.

`defer` and `is` are strictly for forward references.
Forward references are compiled as a single `jmp` instruction whose
address is resolved by `is`.
Do not use `defer` for indirection where `is` changes it at run time.
For indirection, declare a variable to hold the *xt*.
Better yet, use an array of *xt* to control a personality.

### Wordlist management

- `empty` *( -- )* Empties the dictionary.
- `lexicon` *( <name> -- )* --> name *( -- wid )* Defines a named wordlist.
- `root` *( -- wid )* The root wordlist.
- `asm` *( -- wid )* The assembler wordlist.
- `_forth` *( -- wid )* The Forth wordlist.
- `forth` *( -- )* Replaces the top of the search order with `forth`.
- `only` *( -- )* Sets the search order to "root forth".

`lexicon` is similar to "WORDLIST CONSTANT" but it also saves the name
so that `order` lists it.
The host's version of `wordlist` is not usable in definitions.
Instead, `lexicon` is provided.

`only` sets the search order to "root forth" so to differentiate between 
host words (in `root`) and loaded definitions (in `forth`).
You can list different sets of words by typing:

- `forth words`
- `assembler words`
- `root 1 set-order words`

To put definitions in a new wordlist, you can:

```
lexicon myvoc
myvoc +order definitions
( definitions go here )
previous definitions
```

### Lookup tables in code space

- `|bits|` *( n -- )* Sets the number of bits your lookup table will need.
- `|` *( n -- )* Compiles literal instruction(s) with the RET bit set.

Code space is not randomly readable.
That's a nice security feature if you can keep the ROM image secret.
It also simplifies the CPU design.
As a result, some words for building lookup tables are added.

Lookup tables that aren't in data space are built with code.
Notice the fall-through of exec2:.

```forth
: exec2: 2* [ ;       \ for list of 2-cell literals
: exec:  2* r> + >r ; \ for list of 1-cell literals

16 |bits|
: table  exec2: [ 123 | 456 | 789 | 321 ] literal ;
11 |bits|
: table1  exec: [ 123 | 456 | 789 | 321 ] literal ;
cellbits |bits|
```

### Lookup tables in data space

Tables in data space are classic Forth.
Cross compilers call it IDATA, but no need here.
Hardware (or code) is expected to initialize data space at startup.
A typical use case would keep initial data in SPI flash
and load it into data space at boot.

### Loading and Saving code and data spaces

- `save-code` *( <filename> -- )* Saves the code space to a binary file.
- `save-data` *( <filename> -- )* Saves the data space to a binary file.
- `load-code` *( <filename> -- )* Loads the code space from a binary file.
- `load-data` *( <filename> -- )* Loads the data space from a binary file.

The word data types of code and data are simply cast to `char*` so the binary
is not endian-agnostic. This only matters if your desktop is big-endian.
The rest of the world is little-endian.
