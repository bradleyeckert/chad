# Strings in Chad

Strings are stored in either SPI flash or RAM.
Either way, they are a departure from ANS Forth.
ANS Forth uses an *addr length* cell pair as a string specifier.
It assumes that characters are addressable bytes.
That's a lot to assume and codify in a standard
whether it's a C standard or a Forth standard.

The SPI flash is storage for boot code, text strings, dictionary headers,
tables, and bitmaps. Characters in a SPI flash are a stream of bytes.
You set the start address and read characters sequentially without
further addressing. It's a different paradigm.

Numbers are stored in SPI flash in big-endian format.
Data elements such as strings and numbers are associated with a keystream
so as to be encrypted. Hardware decrypts data from flash as it's read.

`flash.f` is most of the implementation.

