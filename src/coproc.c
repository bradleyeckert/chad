/*
This file is meant to be included in chad.c using #include so as to
keep it physically near the simulator code to make it cache-friendly.

Already-defined variables:
cycles = 64-bit cycle count
*/
#ifndef coproc_c
#define COP_OPTIONS 7

// bit 0: hardware unsigned multiplier exists
// bit 1: hardware unsigned divider exists
// bit 2: hardware shifter exists

static uint32_t coproc_c(
	int sel,					// operation select
	uint32_t tos, 				// top of stack register
	uint32_t nos,				// next on stack register
	uint32_t w) {				// w register

	static uint64_t mtime, dtime, stime, product, shifted;
	static uint32_t quot, rem, overflow;
	uint64_t ud, temp;
	switch (sel & 0x0F) {
	case 0:
		return (cycles < mtime) | (cycles < dtime) | (cycles < stime);
	case 1:
		return overflow | COP_OPTIONS;
	case 2:
		return CELLMASK & (product >> CELLBITS);
	case 3:
		return CELLMASK & product;
	case 4:
		return quot;
	case 5:
		return rem;
	case 6:
		return CELLMASK & (shifted >> CELLBITS);
	case 7:
		return CELLMASK & shifted;
	case 8:
		mtime = cycles + CELLBITS + 1;
		product = (uint64_t)tos * (uint64_t)nos;
		return 0;
	case 9: 
		dtime = cycles + CELLBITS + 1;
		ud = ((uint64_t)tos << CELLBITS) | nos;
		temp = ud / w;
		if (temp >> CELLBITS) {		// quotient doesn't fit in cell
			quot = CELLMASK;
			rem = CELLMASK;
			overflow = 0x100;
		}
		else {
			quot = temp & CELLMASK;
			rem = ud % w;
			overflow = 0;
		}
		return 0;
	case 10:
		stime = cycles + CELLBITS + 1;
		ud = ((uint64_t)tos << CELLBITS) | nos;
		if (sel & 0x40)
			shifted = ud << w;
		else if (sel & 0x80)
			shifted = (signed)ud >> w;
		else
			shifted = ud >> w;
	default: return 0;
	}
}
#endif
