//===============================================================================
// chad.h
// Assembler defines for chad.c
// You might not want to include this everywhere due to name collisions.
//===============================================================================
#ifndef __CHAD_H__
#define __CHAD_H__
#include <stdint.h>
#include "config.h"

// The Forth QUIT loop and simulator
// Returns a return code: 0 = BYE
// line: a line of text to evaluate upon entry to chad.
// maxlength: the maximum length of the line buffer.
int chad(char * line, int maxlength);

// Write to code space is a function of iomap.
// In real hardware, an I/O write can (maybe) write to code space.
void chadToCode (uint32_t addr, uint32_t x);

// Get data from the header structure so that Forth can reconstruct headers.
uint32_t chadGetHeader (uint32_t select);

void chadError(int error); // Report an error

#endif // __CHAD_H__
