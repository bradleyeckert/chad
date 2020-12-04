/*
This file is meant to be included in chad.c using #include so as to
keep it physically near the simulator code to make it cache-friendly
and to take advantage of predefined constants.
*/

#ifndef coprocGo
#define COP_OPTIONS 15

// bit 0: hardware multiplier exists, trig = SBBBBB1001x, read = xxxxxx0001x
// bit 1: hardware divider exists,	  trig = xxxxxx1010x, read = xxxxxx0010x
// bit 2: hardware shifter exists,	  trig = xxxxSL1011x, read = xxxxxx0011x
// bit 3: hardware LCD color exists,  trig = xxxxMM1100x, read = xxxMMM0100x

// In hardware, two different instructions operate the coprocessor.
// 1. The COP class of instructions triggers a coprocessor operation.
//    The coprocessor gets 11 bits of immediate (sel) data.
// 2. ALU operations read the result of a COP instruction. This COP data is
//    updated in real time, so it's useful for reading status. In simulation,
//    the status is always 0 (not busy) for simplicity.
// Software uses coprocGo to start an operation. It can either poll the status
// or just do a coprocRead if it knows sufficient cycles have elapsed.

static uint32_t colorPlane(uint8_t gray6, uint8_t shift, uint32_t fg, uint32_t bg) {
	uint16_t fg6 = ((fg >> shift) & 0x3F) * gray6;
	uint16_t bg6 = ((bg >> shift) & 0x3F) * (gray6 ^ 0x3F);
	return ((fg6 + bg6) >> 6) << shift;
}

static uint32_t colorInterpolate(int gray4, uint32_t fg, uint32_t bg) {
	int gray6 = (gray4 << 2) | (gray4 >> 2);
	uint32_t r;
	r  = colorPlane(gray6,  0, fg, bg);
	r += colorPlane(gray6,  6, fg, bg);
	r += colorPlane(gray6, 12, fg, bg);
	return r;
}

static int coprocSticky;
static uint64_t cop_prod, cop_shift;
static uint32_t cop_quot, cop_rem, cop_over;
static uint32_t cop_fgcolor, cop_bgcolor, cop_monobits, cop_color;

static uint32_t coprocRead(void) {
	uint32_t r = 0;						// default return value
	switch (coprocSticky & 0x0F) {		// get the result of the previous operation
	case 1: r = cop_over | COP_OPTIONS;               break; // trigger:
	case 2:	r = CELLMASK & (cop_prod >> CELLBITS);    break; // 9
	case 3:	r = CELLMASK & cop_prod;				  break; // 9
	case 4:	r = cop_quot;							  break; // 10
	case 5:	r = cop_rem;							  break; // 10
	case 6:	r = CELLMASK & (cop_shift >> CELLBITS);   break; // 11
	case 7:	r = CELLMASK & cop_shift;				  break; // 11
	case 8:
		switch ((coprocSticky >> 5) & 7) {
		case 0: r = (cop_color >> 10) & 0xFC;         break; // RRRRRR00
		case 1: r = (cop_color >> 4) & 0xFC;          break; // GGGGGG00
		case 2: r = (cop_color << 2) & 0xFC;          break; // BBBBBB00
		case 3: r = cop_color;                        break; // RRRRRRGGGGGGBBBBBB
		case 4: r = ((cop_color >> 10) & 0xF8)               // RRRRRGGG
			      | ((cop_color >> 9) & 7);  		  break;
		case 5: r = (cop_color >> 1) & 0xFF;          break; // GGGBBBBB
		case 6: r = (cop_color >> 9) & 0x1FF;         break; // RRRRRGGGG
		case 7: r = cop_color & 0x1FF;                break; // GGGBBBBBB
		}
		break;
	}
	return r;
}

static void coprocGo(
	int sel,							// operation select
	uint32_t tos, 						// top of stack register
	uint32_t nos,						// next on stack register
	uint32_t w) {						// w register

	coprocSticky = sel;
	int mulcount = ((sel >> 5) & 0x1F) + 1;
	int mulsign = (sel >> 10) & 1;
	uint64_t ud, temp, p;
	uint32_t us;

	switch ((sel >> 1) & 0x0F) {		// start a new operation
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
		if (temp >> CELLBITS) {			// quotient doesn't fit in cell
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
		if (sel & 0x80) {	// 32-bit rotate right
			us = (uint32_t)ud;
			temp = ((ud << 32) | us) >> (w & 0x1F);
			cop_shift = (uint32_t)temp;
		}
		else if (sel & 0x20)
			cop_shift = ud << w;
		else if (sel & 0x40)
			cop_shift = (signed)ud >> w;
		else
			cop_shift = ud >> w;
		break;
	case 12: // actions: cload, mload, gray, mono
		switch ((sel >> 5) & 3) {
		case 0: // cload
			cop_fgcolor = tos;
			cop_bgcolor = nos;
			break;
		case 1: // mload
			cop_monobits = w;
			break;
		case 2: // mono
			cop_color = (cop_monobits & 1) ? cop_fgcolor : cop_bgcolor;
			cop_monobits >>= 1;
			break;
		case 3: // gray
			cop_color = colorInterpolate(tos, cop_fgcolor, cop_bgcolor);
			break;
		}
		break;
	}
}
#endif
