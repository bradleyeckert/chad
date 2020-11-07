#include <stdlib.h>
#include <stdint.h>

#define OPTIONS 3

// bit 0: hardware unsigned multiplier exists
// bit 1: hardware unsigned divider exists

static uint64_t mtime, dtime, stime, product, shifted;
static uint32_t quot, rem, overflow;

uint32_t coproc_c(
	int sel,					// operation select
	int bits,					// bits per cell
	uint64_t cycles, 			// simulator cycle count
	uint32_t tos, 				// top of stack register
	uint32_t nos,				// next on stack register
	uint32_t w) {				// w register
	uint64_t ud, temp;
	uint32_t mask = -1;		    // "bits" 1s
	if (bits < 32) 
		mask = mask >> (32 - bits);
	switch (sel) {
	case 0:
		return (cycles < mtime) | (cycles < dtime) | (cycles < stime);
	case 1:
		return overflow | OPTIONS;
	case 2:
		return mask & (product >> bits);
	case 3:
		return mask & product;
	case 4:
		return quot;
	case 5:
		return rem;
	case 6:
		return mask & (shifted >> bits);
	case 7:
		return mask & shifted;
	case 8:
		mtime = cycles + bits + 1;
		product = (uint64_t)tos * (uint64_t)nos;
		return 0;
	case 9: 
		dtime = cycles + bits + 1;
		ud = ((uint64_t)tos << bits) | nos;
		temp = ud / w;
		if (temp >> bits) {		// quotient doesn't fit in cell
			quot = mask;
			rem = mask;
			overflow = 0x100;
		}
		else {
			quot = temp & mask;
			rem = ud % w;
			overflow = 0;
		}
		return 0;
	case 10:
		dtime = cycles + bits + 1;
		ud = ((uint64_t)tos << bits) | nos;
		if (sel & 0x40)
			shifted = ud << w;
		else if (sel & 0x80)
			shifted = (signed)ud >> w;
		else
			shifted = ud >> w;
	default: return 0;
	}
}
