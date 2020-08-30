//===============================================================================
// chad.h
// Assembler defines for chad.c
// You might not want to include this everywhere due to name collisions.
//===============================================================================
#ifndef __CHAD_H__
#define __CHAD_H__

// The Forth QUIT loop and simulator
// Returns a return code: 0 = BYE
// line: a line of text to evaluate upon entry to chad.
// maxlength: the maximum length of the line buffer.
int chad(char * line, int maxlength);

// Write to code space is a function of iomap.
// In real hardware, an I/O write can (maybe) write to code space.
void chadToCode (uint32_t addr, uint32_t x);

// Pack a string into the top of data memory.
// Returns a packed address and length.
// delimiter is the character used as a delimiter, 0=none.

// This lets chad code evaluate a line of text from the PC source.
// For example, S" would use chadGetSource('"') (via an io write) to load data
// into data memory.
uint32_t chadGetSource (char delimiter);

// Get data from the header structure so that Forth can reconstruct headers.
uint32_t chadGetHeader (uint32_t select);

void chadError (int error); // Report an error

#endif // __CHAD_H__
