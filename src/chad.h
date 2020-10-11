//===============================================================================
// chad.h
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

// Writing to memory is a function of spif simulator in iomap.
void chadToCode(uint32_t addr, uint32_t x);
void chadToData(uint32_t addr, uint32_t x);

// Get data from the header structure so that Forth can reconstruct headers.
uint32_t chadGetHeader (uint32_t select);

void chadError(int32_t error); // Report an error

uint64_t chadCycles(void); // total number of processor cycles

#endif // __CHAD_H__
