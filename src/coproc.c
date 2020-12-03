/*
This file is meant to be included in chad.c using #include so as to
keep it physically near the simulator code to make it cache-friendly
and to take advantage of predefined constants.
*/

#ifndef coprocGo
#define COP_OPTIONS 7

// bit 0: hardware multiplier exists, sel = SBBBBB1001x
// bit 1: hardware divider exists,	  sel = xxxxxx1010x
// bit 2: hardware shifter exists,	  sel = xxxxSL1011x

// In hardware, two different instructions operate the coprocessor.
// 1. The COP class of instructions triggers a coprocessor operation.
//    The coprocessor gets 11 bits of immediate (sel) data.
// 2. ALU operations read the result of a COP instruction. This COP data is
//    updated in real time, so it's useful for reading status. In simulation,
//    the status is always 0 (not busy) for simplicity.
// Software uses coprocGo to start an operation. It can either poll the status
// or just do a coprocRead if it knows sufficient cycles have elapsed.

static int coprocSticky;
static uint64_t cop_prod, cop_shift;
static uint32_t cop_quot, cop_rem, cop_over;

static uint32_t coprocRead(void) {
	uint32_t r = 0;				// default return value
	switch (coprocSticky) {		// get the result of the previous operation
	case 1: r = cop_over | COP_OPTIONS;               break; // trigger:
	case 2:	r = CELLMASK & (cop_prod >> CELLBITS);    break; // 9
	case 3:	r = CELLMASK & cop_prod;				  break; // 9
	case 4:	r = cop_quot;							  break; // 10
	case 5:	r = cop_rem;							  break; // 10
	case 6:	r = CELLMASK & (cop_shift >> CELLBITS);   break; // 11
	case 7:	r = CELLMASK & cop_shift;				  break; // 11
	}
	return r;
}

static void coprocGo(
	int sel,					// operation select
	uint32_t tos, 				// top of stack register
	uint32_t nos,				// next on stack register
	uint32_t w) {				// w register

	coprocSticky = sel & 0x0F;
	int mulcount = ((sel >> 5) & 0x1F) + 1;
	int mulsign = (sel >> 10) & 1;
	uint64_t ud, temp, p;
	uint32_t us;

	switch ((sel >> 1) & 0x0F) { // start a new operation
	case 9:
		p = (uint64_t)tos;
		for (int i = 0; i < mulcount; i++) {
			if (p & 1) {
				us = (uint32_t)(p >> CELLBITS);
				ud = (uint64_t)nos;
				temp = us;
				if (mulsign) {
					temp |= (uint64_t)(us & MSB) << 1;
					ud |= (uint64_t)(nos & MSB) << 1;
				}
				ud = (ud + temp) << (CELLBITS - 1);
				p = ud | ((p >> 1) & (CELLMASK>>1));
			}
			else {
				temp = p & ((uint64_t)1 << (2 * CELLBITS - 1)); // MSB
				p >>= 1;
				if (mulsign) p += temp;
			}
		}
		cop_prod = p;
		break;
	case 10: 
		ud = ((uint64_t)tos << CELLBITS) | nos;
		temp = ud / w;
		if (temp >> CELLBITS) {	// quotient doesn't fit in cell
			cop_quot = CELLMASK;
			cop_rem = CELLMASK;
			cop_over = 0x100;
		}
		else {
			cop_quot = temp & CELLMASK;
			cop_rem = ud % w;
			cop_over = 0;
		}
		break;
	case 11:
		ud = ((uint64_t)tos << CELLBITS) | nos;
		if (sel & 0x20)
			cop_shift = ud << w;
		else if (sel & 0x40)
			cop_shift = (signed)ud >> w;
		else
			cop_shift = ud >> w;
	}
}
#endif
